classdef ConsoleProgressBar < handle
%CONSOLEPROGRESSBAR Single-line console progress bar with indentation.
%   A lightweight progress indicator that renders an ASCII/Unicode bar
%   on a single console line, overwriting itself on each update via
%   backspace characters. Supports optional leading indentation so
%   multiple bars can be stacked hierarchically.
%
%   The typical lifecycle is:  construct -> start -> update (loop) ->
%   freeze or finish. Calling freeze() prints a newline to make the
%   current state permanent, allowing a subsequent bar to render on a
%   fresh line below. Calling finish() sets progress to 100 % and
%   freezes automatically.
%
%   On GNU Octave the bar uses ASCII characters (# and -). On MATLAB
%   it uses Unicode block characters for a smoother appearance.
%
%   ConsoleProgressBar Properties:
%     Label     — current text label (max 12 chars displayed)
%     Current   — current progress count
%     Total     — total progress count
%     BarWidth  — character width of the bar graphic (default: 30)
%     Indent    — number of leading spaces (set at construction)
%     IsStarted — true after start() has been called
%     IsFrozen  — true after freeze() or finish()
%     LastLen   — character count of last printed line (for backspace)
%
%   ConsoleProgressBar Methods:
%     ConsoleProgressBar — constructor; optionally set indentation
%     start              — begin rendering the progress bar
%     update             — set current count, total, and optional label
%     freeze             — make current state permanent (print newline)
%     finish             — set to 100 %, freeze, and mark done
%
%   Example:
%     pb = ConsoleProgressBar(2);   % 2-space indent
%     pb.start();
%     for k = 1:8
%         pb.update(k, 8, 'Tile 1');
%         pause(0.1);
%     end
%     pb.freeze();   % becomes permanent line
%
%   See also FastSense, FastSenseGrid, FastSenseDock.

    properties (Access = private)
        Label    = ''
        Current  = 0
        Total    = 0
        BarWidth = 30
        Indent   = 0       % number of leading spaces
        IsStarted = false
        IsFrozen  = false
        LastLen   = 0
    end

    methods
        function obj = ConsoleProgressBar(indent)
        %CONSOLEPROGRESSBAR Construct a progress bar instance.
        %   pb = ConsoleProgressBar() creates a bar with no indentation.
        %
        %   pb = ConsoleProgressBar(indent) creates a bar with the
        %   specified number of leading spaces. Use indentation to
        %   visually nest progress bars in multi-level operations.
        %
        %   Input:
        %     indent — non-negative integer; number of leading spaces
        %              prepended to every printed line (optional,
        %              default: 0)
        %
        %   Output:
        %     pb — ConsoleProgressBar handle object
            if nargin >= 1
                obj.Indent = indent;
            end
        end

        function start(obj)
        %START Initialize and render the progress bar for the first time.
        %   pb.start() resets the frozen/started state and prints the
        %   initial (empty) bar. Must be called before update() will
        %   have any visible effect.
            obj.IsStarted = true;
            obj.IsFrozen  = false;
            obj.LastLen   = 0;
            obj.printBar();
        end

        function update(obj, current, total, label)
        %UPDATE Set progress counters and redraw the bar.
        %   pb.update(current, total) updates the progress fraction
        %   to current/total and redraws the bar in-place.
        %
        %   pb.update(current, total, label) also changes the text
        %   label shown to the left of the bar. Labels longer than
        %   12 characters are truncated.
        %
        %   Has no visible effect if the bar has not been started or
        %   has already been frozen.
        %
        %   Inputs:
        %     current — numeric; progress count so far
        %     total   — numeric; total expected count
        %     label   — char; descriptive label (optional)
            obj.Current = current;
            obj.Total   = total;
            if nargin >= 4
                obj.Label = label;
            end
            if obj.IsStarted && ~obj.IsFrozen
                obj.printBar();
            end
        end

        function freeze(obj)
        %FREEZE Make the current bar state permanent by printing a newline.
        %   pb.freeze() redraws the bar one final time, appends a
        %   newline character, and sets IsFrozen to true. Subsequent
        %   calls to update() are silently ignored. Use this when you
        %   want the bar to remain visible while a new bar starts on
        %   the next line.
        %
        %   Does nothing if the bar was never started or is already
        %   frozen.
            if ~obj.IsStarted || obj.IsFrozen; return; end
            obj.printBar();
            fprintf('\n');
            obj.IsFrozen = true;
        end

        function finish(obj)
        %FINISH Set progress to 100 %, freeze, and mark the bar done.
        %   pb.finish() fills the bar to completion, prints a newline
        %   (if not already frozen), and sets IsStarted to false. This
        %   is a convenience shortcut equivalent to calling
        %   pb.update(total, total) followed by pb.freeze().
        %
        %   Does nothing if the bar was never started.
            if ~obj.IsStarted; return; end
            obj.Current = obj.Total;
            if ~obj.IsFrozen
                obj.printBar();
                fprintf('\n');
            end
            obj.IsStarted = false;
            obj.IsFrozen  = true;
        end
    end

    methods (Access = private)
        function printBar(obj)
        %PRINTBAR Redraw the bar using backspace chars to erase previous output.
        %   printBar(obj) erases the previously printed line by emitting
        %   backspace characters (\b) equal to the last printed length,
        %   then prints the updated bar string. This avoids flicker and
        %   keeps output on a single console line.
        %
        %   On Octave, ASCII characters '#' and '-' are used because
        %   Unicode block characters may not render correctly. On MATLAB,
        %   Unicode full-block and light-shade characters are used for a
        %   smoother visual appearance.

            % Choose bar glyphs based on runtime environment
            if exist('OCTAVE_VERSION', 'builtin')
                filled = '#';
                empty  = '-';
            else
                filled = char(9608);  % Unicode full block: █
                empty  = char(9617);  % Unicode light shade: ░
            end

            % Build indentation prefix
            prefix = repmat(' ', 1, obj.Indent);

            % Truncate label to 12 characters and left-justify
            lbl = obj.Label;
            if numel(lbl) > 12; lbl = lbl(1:12); end
            lbl = sprintf('%-12s', lbl);

            % Compute number of filled vs empty bar segments
            if obj.Total > 0
                nFilled = round(obj.BarWidth * obj.Current / obj.Total);
            else
                nFilled = 0;
            end
            nFilled = max(0, min(obj.BarWidth, nFilled));  % clamp to valid range
            nEmpty  = obj.BarWidth - nFilled;

            % Assemble the complete line
            barStr = [repmat(filled, 1, nFilled), repmat(empty, 1, nEmpty)];
            line = sprintf('%s%s [%s] %d/%d', prefix, lbl, barStr, obj.Current, obj.Total);

            % Erase previous output with backspaces, then print new line
            if obj.LastLen > 0
                fprintf(repmat('\b', 1, obj.LastLen));
            end
            fprintf('%s', line);
            obj.LastLen = numel(line);
        end
    end
end

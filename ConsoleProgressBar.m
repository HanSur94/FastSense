classdef ConsoleProgressBar < handle
%CONSOLEPROGRESSBAR Console progress bar for batch rendering.
%   Lightweight helper that uses fprintf + ANSI escape codes to display
%   one or more progress bars in the terminal. Each bar slot shows a
%   label, a Unicode block-character bar, and a current/total counter.
%
%   Usage:
%     pb = ConsoleProgressBar(3);   % 3 bar slots
%     pb.start();
%     for k = 1:8
%         pb.update(1, k, 8, 'Figures');
%         pause(0.1);
%     end
%     pb.finish();
%
%   Bar format:
%     Label        [||||||||||||||||||||||||||||] 8/8
%
%   See also FastPlot, FastPlotDashboard.

    properties (Access = private)
        NumBars      (1,1) double = 1
        Labels       cell
        Currents     double
        Totals       double
        BarWidth     (1,1) double = 30
        IsStarted    (1,1) logical = false
        LinesWritten (1,1) double = 0
    end

    methods
        function obj = ConsoleProgressBar(numBars)
        %CONSOLEPROGRESSBAR Construct a progress bar with numBars slots.
        %   pb = ConsoleProgressBar()      — single bar
        %   pb = ConsoleProgressBar(n)     — n bar slots
            if nargin < 1; numBars = 1; end
            obj.NumBars  = numBars;
            obj.Labels   = repmat({''}, 1, numBars);
            obj.Currents = zeros(1, numBars);
            obj.Totals   = zeros(1, numBars);
        end

        function start(obj)
        %START Initialize the progress display.
            obj.IsStarted    = true;
            obj.LinesWritten = 0;
            obj.printBars();
        end

        function update(obj, barIndex, current, total, label)
        %UPDATE Update a specific bar slot.
        %   pb.update(barIndex, current, total, label)
        %
        %   Inputs:
        %     barIndex — which bar to update (1-based)
        %     current  — current progress value
        %     total    — total value (defines 100%)
        %     label    — string label shown to the left of the bar
            obj.Currents(barIndex) = current;
            obj.Totals(barIndex)   = total;
            if nargin >= 5
                obj.Labels{barIndex} = label;
            end
            if obj.IsStarted
                obj.printBars();
            end
        end

        function finish(obj)
        %FINISH Finalize the display — leave bars visible and print newline.
            % Set all bars to 100%
            obj.Currents = obj.Totals;
            obj.printBars();
            fprintf('\n');
            obj.IsStarted = false;
        end
    end

    methods (Access = private)
        function printBars(obj)
        %PRINTBARS Redraw all bar lines using ANSI escape codes.
            ESC    = char(27);     % ANSI escape character
            filled = char(9608);   % Unicode full block
            empty  = char(9617);   % Unicode light shade

            % Move cursor up to overwrite previous output
            if obj.LinesWritten > 0
                fprintf('%s[%dA', ESC, obj.LinesWritten);
            end

            for k = 1:obj.NumBars
                % Clear the current line
                fprintf('%s[2K', ESC);

                % Pad label to 12 characters (ASCII labels only)
                lbl = obj.Labels{k};
                if numel(lbl) > 12
                    lbl = lbl(1:12);
                end
                lbl = sprintf('%-12s', lbl);

                cur = obj.Currents(k);
                tot = obj.Totals(k);

                % Compute filled portion
                if tot > 0
                    nFilled = round(obj.BarWidth * cur / tot);
                else
                    nFilled = 0;
                end
                nFilled = max(0, min(obj.BarWidth, nFilled));
                nEmpty  = obj.BarWidth - nFilled;

                barStr = [repmat(filled, 1, nFilled), ...
                          repmat(empty,  1, nEmpty)];

                fprintf('%s [%s] %d/%d\n', lbl, barStr, cur, tot);
            end

            obj.LinesWritten = obj.NumBars;
        end
    end
end

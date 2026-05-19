function [events, parseStats] = ndjsonDecode(text)
%NDJSONDECODE Decode a multi-line NDJSON char buffer into a struct array.
%   [events, parseStats] = ndjsonDecode(text)
%
%   Input:  text — char row vector containing zero or more NDJSON lines
%                  (each terminated by newline()). Comment lines (starting
%                  with '#') and blank lines are silently skipped.
%                  Lines that fail jsondecode are skipped and counted on
%                  parseStats.SkippedLineCount per EVTLOG-02 contract.
%                  Non-struct JSON values (numbers, arrays, strings) are
%                  also skipped and counted — events MUST be objects.
%   Output:
%     events     — struct array (1xN). [] when no lines decoded successfully.
%     parseStats — struct with fields:
%                    SkippedLineCount  (double)  — number of lines skipped
%                    SkippedLines      (cell)    — {lineNumber, rawText, errMsg}
%                                                  triples for diagnostics
%
%   Defensive parsing contract (EVTLOG-02): malformed JSON, empty lines,
%   partial lines, non-ASCII content, and comment/header lines (starting
%   with '#') all skip-and-count. The decoder NEVER aborts the read —
%   corrupt lines from SMB/NFS line tearing are tolerated transparently.
%
%   Sibling to libs/Concurrency/ndjsonEncode.m. Public (not private/) so
%   EventLog (Plan 02) and EventLogReader (Plan 03) at libs/Concurrency/
%   can call it directly — mirrors the Phase 1029-04 SUMMARY deviation #1
%   that placed ndjsonEncode.m at the same public location.
%
%   Both MATLAB R2016b+ and Octave 5+ ship jsondecode. No external
%   dependencies required.
%
%   See also ndjsonEncode.

    parseStats = struct('SkippedLineCount', 0, 'SkippedLines', {{}});
    events = [];

    if nargin < 1 || isempty(text)
        return;
    end

    % Normalize to char and split on any newline variant.
    rawText = char(text);
    lines = strsplit(rawText, {sprintf('\n'), sprintf('\r\n')}, ...
                     'CollapseDelimiters', false);

    out = struct([]);   % growable struct array
    idx = 0;

    for k = 1:numel(lines)
        ln = lines{k};

        % Strip stray carriage returns; trim trailing whitespace only.
        ln = regexprep(ln, '\r$', '');

        % Blank line — silent skip (not corruption).
        if isempty(ln)
            continue;
        end

        % Comment / header line (e.g. '#FASTSENSE_EVENTLOG_V1') — silent skip.
        if ln(1) == '#'
            continue;
        end

        % Attempt JSON decode. Any throw -> skip + count.
        s = [];
        errMsg = '';
        try
            s = jsondecode(ln);
        catch e
            errMsg = e.message;
        end

        if isempty(s) && ~isempty(errMsg)
            % jsondecode threw — corrupt line.
            parseStats.SkippedLineCount = parseStats.SkippedLineCount + 1;
            parseStats.SkippedLines{end + 1} = {k, ln, errMsg};
            continue;
        end

        % Events MUST be struct objects. Numbers, strings, arrays are rejected.
        if ~isstruct(s)
            parseStats.SkippedLineCount = parseStats.SkippedLineCount + 1;
            parseStats.SkippedLines{end + 1} = {k, ln, 'not a JSON object'};
            continue;
        end

        idx = idx + 1;
        if isempty(out)
            out = s;
        else
            % Struct-array growth requires matching fields; missing fields
            % on either side are padded with [] via an idempotent field union.
            % This tolerates heterogeneous event/ack records (Phase 1032 will
            % mix {"type":"event",...} and {"type":"ack",...} lines).
            out = ndjsonDecode_mergeStruct_(out, s, idx);
        end
    end

    if idx == 0
        events = [];
    else
        events = out;
    end
end

function out = ndjsonDecode_mergeStruct_(out, s, idx)
%NDJSONDECODE_MERGESTRUCT_ Idempotent field-union merge for struct-array growth.
%   Pads missing fields on both sides with [] before appending s at out(idx).
%   Required because MATLAB and Octave reject struct-array indexing when the
%   new element has different fields than the existing array.

    fA = fieldnames(out);
    fB = fieldnames(s);

    % Add any fields present in s but missing from the array — set to [] on
    % all existing rows so the array remains valid.
    %
    % NOTE: `[out(:).(fB{k})] = deal([])` is the MATLAB-idiomatic broadcast
    % assignment, but Octave 11.1 rejects it as "invalid assignment to cs-list
    % outside multiple assignment". The explicit for-loop works in both runtimes.
    for k = 1:numel(fB)
        if ~isfield(out, fB{k})
            for i = 1:numel(out)
                out(i).(fB{k}) = [];
            end
        end
    end

    % Add any fields present in the array but missing from s — pad s with [].
    for k = 1:numel(fA)
        if ~isfield(s, fA{k})
            s.(fA{k}) = [];
        end
    end

    out(idx) = s;
end

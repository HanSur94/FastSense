function h = computeRowHash(entry)
%COMPUTEROWHASH Hash key over Message + sorted metadata values.
%   h = COMPUTEROWHASH(entry) accepts a struct or PlantLogEntry whose
%   public fields include .Message (char) and .Metadata (struct). Builds
%   a hash input string by concatenating Message + char(31) + every
%   metadata field value (sorted by field name) joined with char(31)
%   between values. Calls djb2Hash on the result and returns the 16-char
%   hex output.
%
%   The unit-separator char(31) ('\x1F') is used between fields so that
%   adjacent field values cannot accidentally collide (e.g., 'ab','c'
%   vs 'a','bc' would hash to the same input without the separator).
%
%   Field-name sort order ensures hash stability: two entries built from
%   the same logical row in different metadata-field orderings produce
%   the same RowHash.
%
%   Inputs:
%     entry — struct or PlantLogEntry with .Message (char) and .Metadata
%             (struct, possibly empty). Other fields are ignored.
%
%   Outputs:
%     h — 1x16 char vector, lowercase hex (from djb2Hash).
%
%   This function is a private helper for PlantLog. PlantLogEntry calls
%   it from its constructor when no explicit RowHash is supplied.
%
%   See also djb2Hash, PlantLogEntry.

    if ~isstruct(entry) && ~isa(entry, 'PlantLogEntry')
        error('PlantLog:invalidInput', ...
            'computeRowHash expected struct or PlantLogEntry; got %s.', class(entry));
    end

    message = '';
    hasMessage = false;
    if isa(entry, 'PlantLogEntry')
        hasMessage = true;
    elseif isstruct(entry) && isfield(entry, 'Message')
        hasMessage = true;
    end
    if hasMessage
        message = entry.Message;
        if isstring(message); message = char(message); end
        if ~ischar(message); message = ''; end
    end

    metadata = struct();
    hasMetadata = false;
    if isa(entry, 'PlantLogEntry')
        hasMetadata = true;
    elseif isstruct(entry) && isfield(entry, 'Metadata')
        hasMetadata = true;
    end
    if hasMetadata
        md = entry.Metadata;
        if ~isempty(md) && isstruct(md)
            metadata = md;
        end
    end

    SEP = char(31); % ASCII unit separator
    fn = sort(fieldnames(metadata));
    parts = cell(1, numel(fn) + 1);
    parts{1} = message;
    for k = 1:numel(fn)
        parts{k + 1} = stringifyValue_(metadata.(fn{k}));
    end
    joined = strjoin(parts, SEP);

    h = djb2Hash(joined);
end

function s = stringifyValue_(v)
%STRINGIFYVALUE_ Render a metadata value to a char vector for hashing.
    if ischar(v)
        s = v;
    elseif isstring(v)
        s = char(v);
    elseif isnumeric(v) || islogical(v)
        if isscalar(v)
            s = sprintf('%.17g', double(v));
        else
            s = sprintf('%.17g,', double(v(:)));
            s(end) = '';
        end
    elseif isstruct(v) || iscell(v)
        % Recursively stringify nested containers in a deterministic way.
        try
            s = jsonencode(v);
        catch
            s = sprintf('<unsupported:%s>', class(v));
        end
    else
        s = sprintf('<unsupported:%s>', class(v));
    end
end

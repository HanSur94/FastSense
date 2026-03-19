function datenumField = extractDatenumField(moduleStruct, callerName)
%EXTRACTDATENUMFIELD Extract the datenum field name from a module struct.
%   datenumField = extractDatenumField(moduleStruct, callerName) reads the
%   .doc metadata to find the shared datenum field name. The .doc struct
%   contains one sub-field per data field, each with .name and .datum
%   properties. The .datum value names the datenum field.
%
%   callerName is used in error identifiers for clear diagnostics.
%
%   See also loadModuleData, loadModuleMetadata.

    if ~isfield(moduleStruct, 'doc')
        error([callerName ':missingDoc'], ...
            'Module struct must contain a ''doc'' field.');
    end

    doc = moduleStruct.doc;
    docFields = fieldnames(doc);

    if isempty(docFields)
        error([callerName ':emptyDoc'], ...
            'Module struct .doc has no fields.');
    end

    % Read .datum from the first doc entry
    firstEntry = doc.(docFields{1});

    if ~isstruct(firstEntry) || ~isfield(firstEntry, 'datum')
        error([callerName ':missingDatum'], ...
            'Module struct .doc.%s must be a struct with a ''datum'' field.', ...
            docFields{1});
    end

    datenumField = firstEntry.datum;

    if ~ischar(datenumField)
        error([callerName ':invalidDatum'], ...
            'Module struct .doc.%s.datum must be a char (field name), got %s.', ...
            docFields{1}, class(datenumField));
    end

    if ~isfield(moduleStruct, datenumField)
        error([callerName ':missingDatenum'], ...
            'Datenum field ''%s'' (from doc.%s.datum) not found in module struct.', ...
            datenumField, docFields{1});
    end
end

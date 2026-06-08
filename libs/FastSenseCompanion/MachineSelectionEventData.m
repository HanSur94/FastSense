classdef MachineSelectionEventData < event.EventData
%MACHINESELECTIONEVENTDATA Payload for MachineSelectorPane.MachineSelectionChanged.
%
%   Usage (inside MachineSelectorPane.onMachineSelected_):
%     ed = MachineSelectionEventData(selectedId);
%     notify(obj, 'MachineSelectionChanged', ed);
%
%   The orchestrator's listener receives ed as the second arg:
%     addlistener(pane, 'MachineSelectionChanged', @(src, ed) onSwitch(src, ed));
%   and reads ed.MachineId to resolve the machine via Fleet.getMachine.
%
%   Properties (read-only after construction):
%     MachineId - char; the selected machine's Id (from the listbox ItemsData)
%
%   See also MachineSelectorPane, FastSenseCompanion, event.EventData.

    properties (SetAccess = immutable)
        MachineId = ''
    end

    methods
        function obj = MachineSelectionEventData(machineId)
        %MACHINESELECTIONEVENTDATA Construct payload with the selected machine Id (char).
            if nargin < 1
                error('FastSenseCompanion:invalidEventData', ...
                    'MachineSelectionEventData requires a machineId.');
            end
            if ~ischar(machineId)
                error('FastSenseCompanion:invalidEventData', ...
                    'MachineSelectionEventData: machineId must be char.');
            end
            obj.MachineId = machineId;
        end
    end
end

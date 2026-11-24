classdef State < handle
    %STATE  The shared selection of the application: one scenario, one control, one unit, one time index.
    %   Every screen listens to Changed, so a selection made on one screen is the selection of all.
    properties
        Key char = ''          % scenario key in the record's grammar, e.g. '25_1000_09TF'
        Code char = 'v'        % control code of app_laws.json
        Unit double = NaN      % grid-forming unit number
        TimeIndex double = 1   % index into the time base of the run shown
        View char = ''         % 'traces': the Run screen opens the selected run's traces on its next show
        Set char = ''          % the set of app_runs.json of the cell chosen ('' = any set)
    end
    events
        Changed
    end
    methods
        function set(obj, varargin)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i + 1};
            end
            notify(obj, 'Changed');
        end
    end
end

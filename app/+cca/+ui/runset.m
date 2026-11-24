function s = runset(D, keys)
%RUNSET  The set of the list of the paper's runs (app_runs.json) that a group of grid cells belongs to: the one set
%   that the Current Compass's rows of every key share (their "set" field), read from the data, never typed; '' where
%   no single set holds them all.
%   s = cca.ui.runset(D, keys)   keys: the scenario keys (or load-step events) of one tab or one group of rows
s = '';
if ~isfield(D, 'runlist') || isempty(keys)
    return
end
R = D.runlist;
keys = cellstr(keys);
m = strcmp(R.code, 'v') & ismember(R.key, keys);
k = R.key(m);
st = R.set(m);
common = {};
for q = 1:numel(keys)
    names = strtrim(strsplit(strjoin(st(strcmp(k, keys{q})), ' + '), ' + '));
    names = unique(names(~cellfun(@isempty, names)), 'stable');
    if q == 1
        common = names;
    else
        common = intersect(common, names, 'stable');
    end
    if isempty(common)
        return
    end
end
if isscalar(common)
    s = common{1};
end
end

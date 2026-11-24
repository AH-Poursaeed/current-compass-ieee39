function D = load(root)
%LOAD  Read app/data once at start (read-only). Every number a screen prints comes from D.
%   D = cca.data.load(root)   root = the app folder (the folder of ccapp.m)
dd = fullfile(root, 'data');
if ~isfile(fullfile(dd, 'app_numbers.json'))
    error('cca:data:missing', ['app/data is missing. Generate it from the repository root with: ' ...
        'python app/tools/make_app_data.py']);
end
D.root = root;
D.repo = fileparts(root);
N = readjson(fullfile(dd, 'app_numbers.json'));
D.record = N.record;
D.leafmap = containers.Map('KeyType', 'char', 'ValueType', 'any');
L = N.leaves;
if iscell(L)
    L = [L{:}];
end
for i = 1:numel(L)
    D.leafmap(L(i).path) = L(i).value;
end
D.series = N.series;
D.constants = N.constants;
W = readjson(fullfile(dd, 'app_laws.json'));
D.laws = W.laws;
D.others = W.others;
D.lawsrc = W.sources;
D.grid = readjson(fullfile(dd, 'app_grid.json'));
X = readjson(fullfile(dd, 'app_text.json'));
D.text = X.texts;
D.paper = readjson(fullfile(dd, 'app_paper.json'));
% every printed number of the paper by its place (the numbers view's data, regenerated from the released record)
Pr = readjson(fullfile(dd, 'app_printed.json'));
D.printed = Pr.rows;
R = readjson(fullfile(dd, 'runs', 'index.json'));
D.runs = R.runs;
if isempty(D.runs)                       % no run file in this build: an empty list with the index's fields
    D.runs = struct('key', {}, 'code', {}, 'file', {}, 'sha256', {});
end
% the list of the paper's runs (app_runs.json): one row a row of the campaign table, one cell array of char a column
% (D.runlist.<col>, every value a string), and the file's sets, laws, outcome words and join (D.runinfo)
J = readjson(fullfile(dd, 'app_runs.json'));
D.runlist = J.data;
for c = reshape(fieldnames(D.runlist), 1, [])
    D.runlist.(c{1}) = cellstr(D.runlist.(c{1}));
    D.runlist.(c{1}) = D.runlist.(c{1})(:);
end
D.runinfo = rmfield(J, 'data');
D.manifest = readjson(fullfile(dd, 'MANIFEST.json'));
% the commit and the time of the data step's run are written in MANIFEST.json alone (the data files hold only what
% the inputs give, so that a regeneration from the same inputs is byte-equal)
for f = {'commit', 'generated_utc'}
    if isfield(D.manifest.record, f{1})
        D.record.(f{1}) = D.manifest.record.(f{1});
    else
        D.record.(f{1}) = '';
    end
end
end

function s = readjson(f)
s = jsondecode(fileread(f));
end

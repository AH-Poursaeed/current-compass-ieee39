function S = compare(host, D, T, app)
%COMPARE  Screen 04: every control on every common scenario (the grid of app_grid.json), and each compared law's
%   own losses on them (the grid's totals, the counts that the paper prints law by law).
lf = @(p) cca.data.leaf(D, p);
g = uigridlayout(host, [1 2], 'RowHeight', {'1x'}, 'ColumnWidth', {'1x', 334}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 0, 'BackgroundColor', T.c.ground);
G = D.grid;
L = D.laws;
if iscell(L), L = [L{:}]; end
cols = G.cols(:).';
% the columns, in Table II's order
C = struct('code', {}, 'name', {}, 'colour', {}, 'line', {}, 'setting', {});
for j = 1:numel(cols)
    w = L(strcmp({L.code}, cols{j}));
    C(j) = struct('code', w.code, 'name', w.name, 'colour', w.colour, 'line', w.line, 'setting', w.setting);
end
% the rows
cells = G.cells(:);
keys = G.keys(:);
cls = G.cls(:);
cp = G.compass;
if iscell(cp), cp = [cp{:}]; end
set101 = cca.ui.runset(D, keys);     % the set of the list of the paper's runs that these cells open in
rows = struct('key', {}, 'cls', {}, 'cells', {}, 'label', {}, 'longLabel', {}, 'text', {}, 'set', {});
for i = 1:numel(keys)
    c = cells{i};
    counted = c(2:end) ~= 'N';
    nLost = sum(c(2:end) == 'L');
    % the compared laws' outcome first, then the Current Compass's
    if c(1) == 'R'
        tr = cp(i).t_ret_s;
        if isempty(tr)
            vTxt = 'the Current Compass returns';
        else
            vTxt = sprintf('the Current Compass returns in %s', cca.ui.fmt('sec', tr));
        end
    else
        vTxt = 'the Current Compass loses synchronism';
    end
    txt = sprintf('%d of the %d compared settings eligible here lose synchronism; %s.', nLost, sum(counted), vTxt);
    rows(i) = struct('key', keys{i}, 'cls', cls{i}, 'cells', c, 'label', cca.data.scenario(D, keys{i}, "short"), ...
        'longLabel', cca.data.scenario(D, keys{i}), 'text', txt, 'set', set101);
end
nScen = lf('s60r.v6.r15.sets.c101.n_keys');
% the foot row: Table II's Lost column, from the record's totals ("a/b": of the b where the law is eligible)
v101 = cell(1, numel(cols));
for j = 1:numel(cols)
    t = G.totals.(cols{j});
    v101{j} = lostPrint(t.n_lost, t.n_eligible, nScen);
end
tot = struct('label', 'Lost', 'sub', sprintf('of %d', nScen), 'vals', {v101});
P = G.parsed;
if iscell(P), P = [P{:}]; end
dur = [P.dur_ms] / 1000;
isS = strcmp(cls(:).', 'SHORT');
groups = struct('cls', {'SHORT', 'LONG'}, ...
    'label', {sprintf('%g to %g s', min(dur(isS)), max(dur(isS))), sprintf('%g to %g s', min(dur(~isS)), max(dur(~isS)))}, ...
    'n', {lf('s60r.v6.r15.sets.c101.n_short'), lf('s60r.v6.r15.sets.c101.n_long')});
tabSet = tableNumber(D, 'cc_tab_set');
% the ablation tab: the Current Compass and its parts on the same scenarios (app_grid.json ablation_cells: the rows
% of Table III, the law first, each counted on every common scenario)
O = D.others;
if iscell(O), O = [O{:}]; end
aCodes = [{'v'}, {O.code}];
A = struct('code', {}, 'name', {}, 'colour', {}, 'line', {}, 'setting', {});
aCells = repmat(' ', numel(keys), numel(aCodes));
for j = 1:numel(aCodes)
    if strcmp(aCodes{j}, 'v')
        w = L(strcmp({L.code}, 'v'));
        aCells(:, j) = char(cellfun(@(c) c(1), cells));
    else
        w = O(strcmp({O.code}, aCodes{j}));
        aCells(:, j) = G.ablation_cells.(aCodes{j})(:);
    end
    A(j) = struct('code', w.code, 'name', w.name, 'colour', w.colour, 'line', w.line, 'setting', 'parts');
end
% the foot rows: Table III's two columns of the common scenarios, the short and the long ones
aTot = footOf(aCells, {isS(:), ~isS(:)}, {groups.label}, ...
    {sprintf('lost, of %d', nnz(isS)), sprintf('lost, of %d', nnz(~isS))}, false);
abl = struct('cols', A, 'cells', {cellstr(aCells)}, 'totals', aTot, 'tableParts', tableNumber(D, 'cc_tab_parts'), ...
    'hasN', any(aCells(:) == 'N'), 'note', sprintf(['The Current Compass and its parts on the %d common scenarios: ' ...
    'the rows of %s, %s.'], nScen, cca.data.paperref(D, "table", "cc_tab_parts"), tableTitle(D, 'cc_tab_parts')));
% the fault-location tab: the ladder of app_grid.json (the three-phase faults of 0.3 to 5 s and the SLG faults of
% at the ladder's buses, the three-phase faults of 0.15 to 1 s through the low fault resistance), one row a
% fault bus, type, resistance and duration; E: a return that ends with a limiter engaged, read per run where the
% record holds it (the groups' engaged_read); the decisive faults of the paper marked (the record's d1)
Lg = G.ladder;
lCodes = Lg.cols(:).';
LC = columnsOf(L, O, lCodes, 'ladder');
lKeys = Lg.keys(:);
lCells = char(Lg.cells(:));
lCls = Lg.cls(:);
isMark = logical(Lg.marks(:));
Dk = Lg.decisive;
secD = cca.data.paperref(D, "subsection", sprintf('%s Decisive Faults', lf('s60r.v6.r17.d1.n_word_cap')));
lRows = struct('key', {}, 'cls', {}, 'cells', {}, 'label', {}, 'longLabel', {}, 'text', {}, 'open', {}, 'mark', {});
for i = 1:numel(lKeys)
    mk = '';
    if isMark(i)
        mk = sprintf('A decisive fault of %s.', secD);
    end
    lRows(i) = struct('key', lKeys{i}, 'cls', lCls{i}, 'cells', lCells(i, :), ...
        'label', cca.data.scenario(D, lKeys{i}, "short"), 'longLabel', cca.data.scenario(D, lKeys{i}), ...
        'text', '', 'open', true, 'mark', mk);     % every cell opens its run in the list of the paper's runs
end
LG = Lg.groups;
if iscell(LG), LG = [LG{:}]; end
W = G.words;
lGroups = struct('cls', {}, 'label', {}, 'n', {}, 'sub', {});
for q = 1:numel(LG)
    lGroups(q) = struct('cls', LG(q).cls, 'label', sprintf('%s %g s', W.type_short.(LG(q).type), ...
        LG(q).dur_ms / 1000), 'n', LG(q).n, 'sub', sprintf('through %g pu', lf(LG(q).rf_leaf)));
end
% each group's set of the list of the paper's runs (read from the list: the set its cells open in), and the foot
% rows by set, as Table III counts the ladder (its families: through either resistance, 4 and 5 s, SLG)
gSet = arrayfun(@(x) cca.ui.runset(D, lKeys(strcmp(lCls, x.cls))), LG, 'UniformOutput', false);
for i = 1:numel(lRows)
    lRows(i).set = gSet{strcmp({LG.cls}, lCls{i})};
end
fams = unique(gSet, 'stable');
if any(cellfun(@isempty, fams))
    fMask = {true(numel(lKeys), 1)};
    fLab = {'Lost'};
else
    fMask = cellfun(@(f) ismember(lCls, {LG(strcmp(gSet, f)).cls}), fams, 'UniformOutput', false);
    fLab = fams;
end
lTot = footOf(lCells, fMask, fLab, cellfun(@(m) sprintf('lost, of %d', nnz(m)), fMask, 'UniformOutput', false), false);
isT = strcmp({LG.type}, 'T');
nBusLad = lf('s60r.v6.r16.sets.c101_fault_buses_n');
hide = Lg.not_shown;
hideTxt = sprintf('%s at its published setting is not eligible here: %s%s.', hide.name, lower(hide.reason(1)), ...
    hide.reason(2:end));
% who ran the ladder's families and the counts on them, the compared settings first
ranTxt = '';
if lf('s60r.v6.r17.ran.all_three_groups_ran_by_the_law_its_parts_and_the_twelve')
    ranTxt = ' Every column ran every fault.';
end
capName = lowerFirst(O(strcmp({O.code}, 'c')).name);
cb = lf('s60r.v6.r16.r1.c.buses_lost');
cbTxt = '';
if isscalar(cb)
    cbTxt = sprintf(', all at bus %s', words(cb));
elseif numel(cb) > 1
    cbTxt = sprintf(', at buses %s', words(cb));
end
none1 = lf('s60r.v6.r17.q1.twelve.none_codes');
famTxt = sprintf(['On the %s, %s %s none and the other %d compared settings lose %s; %s%s. On the %s, %s loses ' ...
    '%d and the other %d compared settings lose %s; %s.'], lf('s60r.v6.r16.sets.r1.print'), lawNames(L, none1), ...
    pluralVerb(numel(none1)), numel(lf('s60r.v6.r17.q1.twelve.others_codes')), ...
    lf('s60r.v6.r17.q1.twelve.others_range_print'), ...
    ownTxt(lf('s60r.v6.r16.r1.v.lost'), lf('s60r.v6.r16.r1.c.lost'), capName), cbTxt, ...
    lf('s60r.v6.r16.sets.r3.print'), lawNames(L, {'k'}), lf('s60r.v6.r17.q2.twelve.k_lost'), ...
    numel(lf('s60r.v6.r17.q2.twelve.eleven_others.codes')), lf('s60r.v6.r17.q2.twelve.eleven_others.range_print'), ...
    ownTxt(lf('s60r.v6.r16.r3.v.lost'), lf('s60r.v6.r16.r3.c.lost'), capName));
% the decisive faults of the paper (the record's d1), in the paper's words, the compared settings' outcome first;
% printed only where the cells show it
jt = ismember(lCodes, Dk.twelve);
decTxt = '';
if any(isMark) && all(all(lCells(isMark, jt) == 'L')) && all(ismember(lCells(isMark, strcmp(lCodes, 'v')), 'RE'))
    alsoTxt = '';
    if all(lCells(isMark, strcmp(lCodes, 'n')) == 'L')
        alsoTxt = sprintf(', as does the %s', lowerFirst(O(strcmp({O.code}, 'n')).name));
    end
    decTxt = sprintf([' Marked: the %s decisive faults of %s, on which all %d compared settings eligible on the ' ...
        'ladder lose synchronism%s; the Current Compass returns from all %s.'], lf('s60r.v6.r17.d1.n_word'), secD, ...
        nnz(jt), alsoTxt, lf('s60r.v6.r17.d1.n_word'));
end
ladNote = sprintf(['At base load in the base network.%s %s%s Violet: a return that ends with a limiter engaged, ' ...
    'read per run on the SLG faults and on the three-phase faults of %s s. %s'], ranTxt, famTxt, decTxt, ...
    words([LG(isT & [LG.engaged_read]).dur_ms] / 1000), hideTxt);
lad = struct('cols', LC, 'rows', lRows, 'groups', lGroups, 'cells', {cellstr(lCells)}, 'totals', lTot, ...
    'note', ladNote, 'hasE', true, 'hasN', any(lCells(:) == 'N'), 'noteTall', true, ...
    'detail', {cellstr(Lg.detail(:))}, 'hasMark', any(isMark), 'markLabel', 'decisive fault');
% the load-step tab: the six load steps without a fault of Section V-F (app_grid.json loadsteps), one row an
% event, the same columns as the ladder; every code ran every event
Sg = G.loadsteps;
sCodes = Sg.cols(:).';
SC = columnsOf(L, O, sCodes, 'loadsteps');
sCells = char(Sg.cells(:));
SR = Sg.rows;
if iscell(SR), SR = [SR{:}]; end
SGr = Sg.groups;
if iscell(SGr), SGr = [SGr{:}]; end
% the two steps in the paper's words: the smaller step and the larger (the data's word where they hold it, else the
% lower load in MW of the data's print)
if isfield(SGr, 'step')
    stepWord = {SGr.step};
else
    mwLow = arrayfun(@(x) sscanf(x.MW_print, '%f', 1), SGr);
    stepWord = repmat({'larger'}, 1, numel(SGr));
    stepWord(mwLow == min(mwLow)) = {'smaller'};
end
isSmall = strcmp(stepWord, 'smaller');
vNameLs = L(strcmp({L.code}, 'v')).name;
setLs = cca.ui.runset(D, {SR.event});
sRows = struct('key', {}, 'cls', {}, 'cells', {}, 'label', {}, 'longLabel', {}, 'text', {}, 'open', {}, 'set', {});
for i = 1:numel(SR)
    wq = stepWord{strcmp({SGr.cls}, SR(i).group)};
    if isfield(SR, 'name')     % the data's own words of the row ('bus 23, 541 MW')
        rName = SR(i).name;
    else
        rName = sprintf('bus %d, %s MW', SR(i).bus, SR(i).P_MW_print);
    end
    sRows(i) = struct('key', SR(i).event, 'cls', SR(i).group, 'cells', sCells(i, :), ...
        'label', rName, ...
        'longLabel', sprintf('Bus %d, the %s step: %s MW in the run of the %s', SR(i).bus, wq, SR(i).P_MW_print, ...
        vNameLs), 'text', '', 'open', true, 'set', setLs);
end
sGroups = struct('cls', {}, 'label', {}, 'n', {});
for q = 1:numel(SGr)
    if isfield(SGr, 'name')
        gName = SGr(q).name;
    else
        gName = sprintf('the %s step, %s MW', stepWord{q}, SGr(q).MW_print);
    end
    sGroups(q) = struct('cls', SGr(q).cls, 'label', gName, 'n', SGr(q).n);
end
% the foot rows: Table III's lost load steps, then its limiter column, as the data print it ("0 of 6")
sTot = footOf(sCells, {true(size(sCells, 1), 1)}, {'Lost'}, {sprintf('of %d', size(sCells, 1))}, false);
engV = cellfun(@(c) Sg.totals.(c).engaged_print, sCodes, 'UniformOutput', false);
sTot(2) = struct('label', 'limited at end', 'sub', 'of the returns', 'vals', {engV});
lsNote = sprintf(['Rows: the %s of %s, the smaller step above, by bus (the load in MW in the run of the %s). ' ...
    'Columns: as on the ladder. Violet: a return that ends with a limiter engaged. %s'], ...
    lf('s60r.v6.r16.sets.r2.print'), cca.data.paperref(D, "subsection", "Robustness"), vNameLs, hideTxt);
lsT = struct('cols', SC, 'rows', sRows, 'groups', sGroups, 'cells', {cellstr(sCells)}, 'totals', sTot, ...
    'note', lsNote, 'hasE', true, 'hasN', false, ...
    'test', {loadStepTest(D, L, O, SR, SGr, sCodes, sCells, isSmall)});
data = struct('cols', C, 'rows', rows, 'totals', tot, 'groups', groups, 'sel', app.state.Key, ...
    'nScen', nScen, 'nBus', nBusLad, 'tableSet', tabSet, 'abl', abl, 'lad', lad, 'ls', lsT, ...
    'nLs', lf('s60r.v6.r16.sets.r2.n'));
h = uihtml(g, 'HTMLSource', fullfile(D.root, 'html', 'cgrid.html'));
h.Layout.Row = 1; h.Layout.Column = 1;
h.Data = data;
h.HTMLEventReceivedFcn = @(~, e) onEvent(e);

% ------------------------------------------------------------------ the side panel
side = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
side.Layout.Row = 1; side.Layout.Column = 2;
sg = uigridlayout(side, [5 1], 'RowHeight', {24, 32, 22, '1x', 92}, 'Padding', [18 14 18 12], ...
    'RowSpacing', 4, 'BackgroundColor', T.c.surface);
t1 = uilabel(sg, 'Text', 'Losses on the common scenarios', 'FontName', T.font.chromeBold, 'FontSize', 15, ...
    'FontColor', T.c.ink);
t1.Layout.Row = 1;
t2 = uilabel(sg, 'Text', sprintf('each compared setting on the %d common scenarios, the Lost column of %s', ...
    nScen, cca.data.paperref(D, "table", "cc_tab_set")), 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
t2.Layout.Row = 2;
lg = uilabel(sg, 'Text', 'Blue: returns; red: lost; grey: not eligible. At the right: lost.', ...
    'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3);
lg.Layout.Row = 3;
ax = uiaxes(sg);
ax.Layout.Row = 4;
n = numel(cols) - 1;
V = zeros(n, 3);
names = cell(n, 1);
for j = 2:numel(cols)
    x = G.totals.(cols{j});
    V(j - 1, :) = [x.n_returned x.n_lost nScen - x.n_eligible];
    names{j - 1} = C(j).name;
end
% the granted control of [13], under its two rows: its own losses at its two settings first, then
% the control's returns with the fault-on reactance granted (non-causal, as the paper says)
r4c = {lf('s60r.v6.r16.r4.published.code'), lf('s60r.v6.r16.r4.selected.code')};
r4row = find(ismember(cols(2:end), r4c), 1, 'last');
r4txt = {sprintf('loses %d (published) and %d (selected) of the %d;', ...
    lf('s60r.v6.r16.r4.published.law_losses_on_101'), lf('s60r.v6.r16.r4.selected.law_losses_on_101'), ...
    lf('s60r.v6.r16.r4.published.of')), 'granted the fault-on reactance (non-causal),', ...
    r4returns(lf('s60r.v6.r16.r4.both_settings_return_on_all_101'), lf('s60r.v6.r16.r4.published.of'), ...
    lf('s60r.v6.r16.r4.print'))};
gapR4 = numel(r4txt) * 0.42;
yPos = (1:n) + gapR4 * ((1:n) > r4row);
hb = barh(ax, yPos, V, 0.30, 'stacked', 'EdgeColor', 'none');
hb(1).BaseLine.Visible = 'off';
hb(1).FaceColor = T.c.accent; hb(2).FaceColor = T.c.lossInk; hb(3).FaceColor = T.c.sunken;
hold(ax, 'on');
total = sum(V(1, :));
for i = 1:n
    y = yPos(i);
    text(ax, 0, y - 0.24, names{i}, 'FontName', T.font.chrome, 'FontSize', 11, 'Color', T.c.ink, ...
        'VerticalAlignment', 'bottom');
    lostTxt = sprintf('%d', V(i, 2));
    if V(i, 3) > 0                       % a law not eligible on every scenario: its losses of its eligible ones
        lostTxt = sprintf('%d/%d', V(i, 2), V(i, 1) + V(i, 2));
    end
    text(ax, total * 1.06, y, lostTxt, 'FontName', T.font.chrome, 'FontSize', 11, 'Color', T.c.lossInk);
end
r4note = text(ax, 0, yPos(r4row) + 0.24, r4txt, 'FontName', T.font.chrome, 'FontSize', 10, 'Color', T.c.ink2, ...
    'VerticalAlignment', 'top');
hold(ax, 'off');
ax.YDir = 'reverse';
ax.YLim = [0.3 yPos(end) + 0.5];
ax.XLim = [0 total * 1.2];
ax.Visible = 'off';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
figCmp = figureNumber(D, 'cc_fig_compare');
nt = uilabel(sg, 'Text', sprintf(['Lost: the common scenarios on which the setting loses synchronism; a/b: of ' ...
    'the b where it is eligible. Fig. %d of the paper compares the laws on these scenarios. Click a cell of the ' ...
    'grid, then open its run in the list of the paper''s runs.'], figCmp), ...
    'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3, 'WordWrap', 'on', 'VerticalAlignment', 'top');
nt.Layout.Row = 5;

S.grid = g;
S.html = h;
S.side = ax;
S.values = V;
S.r4note = r4note;
S.onShow = @() refresh();
S.setTab = @setTab;
S.help = cca.ui.help(app, T, helpContent(D, nScen, groups, nBusLad, r4c));

    function setTab(name)
        % opens a tab of the html region ('scenario', 'location', 'loadsteps', 'ablation'), as a click on it would
        d = h.Data;
        d.tab = char(name);
        h.Data = d;
        sideFor(char(name));
    end

    function sideFor(name)
        % the side panel counts the common scenarios' losses: it stands beside the first tab only
        on = strcmp(name, 'scenario');
        side.Visible = matlab.lang.OnOffSwitchState(on);
        if on
            g.ColumnWidth = {'1x', 334};
        else
            g.ColumnWidth = {'1x', 0};
        end
    end

    function refresh()
        if ~strcmp(h.Data.sel, app.state.Key)
            d = h.Data;
            if isfield(d, 'tab')    % a selection keeps the tab the reader is on
                d = rmfield(d, 'tab');
            end
            d.sel = app.state.Key;
            h.Data = d;
        end
    end

    function onEvent(e)
        switch e.HTMLEventName
            case 'openRun'
                openRun(e.HTMLEventData);
            case 'select'
                app.state.set('Key', char(e.HTMLEventData));
            case 'tab'
                sideFor(char(e.HTMLEventData));
            case 'export'
                app.act('Export the comparison table to a CSV file chosen by the user', @() exportTable());
        end
    end

    function openRun(v)
        % a cell of the grid opens its run in the list of the paper's runs: the row with the cell's code, key and
        % set (the list's join); a key alone selects the scenario's runs, the chosen control's run first
        if isstruct(v)
            a = {'Key', char(v.key), 'Code', char(v.code)};
            if isprop(app.state, 'Set')
                a = [a, {'Set', char(v.set)}];
            end
            app.state.set(a{:});
        else
            app.state.set('Key', char(v));
        end
        app.show("run");
    end

    function exportTable()
        [f, p] = uiputfile('*.csv', 'Export the comparison table', 'compare_table.csv');
        if isequal(f, 0)
            return
        end
        Tt = cell2table([keys, cellfun(@(c) {c}, cells)], 'VariableNames', {'scenario', 'cells'});
        writetable(Tt, fullfile(p, f));
    end
end

function C = helpContent(D, nScen, groups, nBus, r4c)
% the page of explanations of the Compare screen (cca.ui.help): the colours, eligibility and a/b, the four tabs, the
% buttons, the side panel, how a cell opens its run; every number read from the data
lf = @(p) cca.data.leaf(D, p);
ref = @(kind, key) cca.data.paperref(D, kind, key);
t2 = ref("table", "cc_tab_set");
t3 = ref("table", "cc_tab_parts");
W = D.runinfo.laws;                       % the law of [13] as the list of runs names it, with its reference
if iscell(W), W = [W{:}]; end
q13 = lowerFirst(W(strcmp({W.code}, r4c{1})).law);
C.title = 'How to read the Compare screen';
C.intro = {['Each cell of the grid is one run of the paper: the law or part of its column on the scenario, fault or ' ...
    'load step of its row. The colour of a cell is the outcome of that run as the record of the paper holds it, ' ...
    'and each foot row counts the losses of its column as the paper prints them.']};
C.sections = [ ...
    cca.ui.helpsec('The colours of a cell', {}, { ...
    'light blue', ['the run returns: the grid-forming units stay in synchronism after the fault (the column of the ' ...
    'Current Compass is drawn in a stronger blue and framed)']; ...
    'red', 'the run loses synchronism'; ...
    'violet', ['the run returns, but a current limiter is still engaged at the end of its record (on the tabs By ' ...
    'fault location and Load steps)']; ...
    'light grey', 'the law is not eligible on this scenario: the paper does not count it for that law'}), ...
    cca.ui.explain(D, "eligible"), ...
    cca.ui.helpsec('The four tabs', {}, { ...
    'By scenario', sprintf(['the %d common scenarios in two groups, %s (%d scenarios) and %s (%d). The columns are ' ...
    'the Current Compass and the compared settings, in the order of %s. The foot row is the Lost column of %s: ' ...
    'the losses of each column on the %d.'], nScen, groups(1).label, groups(1).n, groups(2).label, groups(2).n, ...
    t2, t2, nScen); ...
    'By fault location', sprintf(['the ladder of %s: every fault type, duration and fault resistance at its %d ' ...
    'buses, for the Current Compass, its parts and the compared settings eligible on the ladder, at base load in ' ...
    'the base network. The foot rows count the losses of each column as %s counts them. A black mark left of a ' ...
    'row marks a decisive fault of %s.'], ref("section", "cc_sec4_test_system"), nBus, t3, ...
    ref("subsection", sprintf('%s Decisive Faults', lf('s60r.v6.r17.d1.n_word_cap')))); ...
    'Load steps', sprintf(['the %s of %s, the smaller step above the larger, one row a bus. The foot rows give ' ...
    'the losses and the returns that end with a limiter engaged; the text under the grid gives the test of the ' ...
    'smaller step that was fixed before the runs, with its result at each bus.'], lf('s60r.v6.r16.sets.r2.print'), ...
    ref("subsection", "Robustness")); ...
    'Parts', sprintf(['the Current Compass and its parts on the %d common scenarios: the rows of %s. The foot rows ' ...
    'count the losses of each part in the short and in the long group. A part is the law with one or more of its ' ...
    'channels changed or taken out (the circular limiter alone has none of them), so this tab shows what each ' ...
    'channel adds (%s).'], nScen, t3, ref("subsection", "What Each Part of the Law Buys"))}), ...
    cca.ui.helpsec('The buttons of the first tab', { ...
    sprintf(['Family keeps the columns of one family: Published setting (a law at the values of its paper), ' ...
    'Selected setting (a setting chosen before its runs, as the note of %s says), Baseline limiter (the two ' ...
    'baselines of this work); All shows every column. Duration shows or hides the short or the long group of ' ...
    'rows.'], t2), ...
    ['Export table saves the grid as a CSV file: one row a scenario, with its key and one letter a column in the ' ...
    'order of the columns (R returns, L lost, N not eligible). MATLAB asks where to save it.']}), ...
    cca.ui.helpsec('The side panel of the first tab', { ...
    sprintf(['The bars count, for each compared setting, its returns (blue), its losses (red) and the common ' ...
    'scenarios where it is not eligible (grey). The number at the right is its Lost count of %s, printed as a/b ' ...
    'where it is eligible on b of the %d.'], t2, nScen), ...
    sprintf(['Under %s, the lines give its losses at its two settings and its returns when it is granted the ' ...
    'fault-on reactance, a non-causal grant (%s).'], q13, ref("subsection", "The Comparison on the Common Scenarios"))}), ...
    cca.ui.helpsec('Opening the run of a cell', {['Point at a cell: a small card shows the scenario and the outcome ' ...
    'of the cell''s run. Click the cell to keep the card, then click "Open this run in the list of the paper''s ' ...
    'runs": the Run screen opens with that run selected, and its card gives the fault, the outcome and the places ' ...
    'of the paper that count it. Click outside the cells to close the card.']}), ...
    cca.ui.explain(D, "limited"), ...
    cca.ui.explain(D, "decisive"), ...
    cca.ui.explain(D, "test")];
end

function C = columnsOf(L, O, codes, setting)
% the columns of a table of codes: the laws' and the parts' names, colours and line styles (app_laws.json)
C = struct('code', {}, 'name', {}, 'colour', {}, 'line', {}, 'setting', {});
for j = 1:numel(codes)
    w = L(strcmp({L.code}, codes{j}));
    if isempty(w), w = O(strcmp({O.code}, codes{j})); end
    C(j) = struct('code', w.code, 'name', w.name, 'colour', w.colour, 'line', w.line, 'setting', setting);
end
end

function F = footOf(cells, masks, labels, subs, frac)
% the foot rows of a grid: per foot row, each column's losses (L) on the rows of its mask, counted from the cells,
% as the paper prints a loss count ("a/b": of the b where the law is eligible, when frac)
F = struct('label', {}, 'sub', {}, 'vals', {});
for q = 1:numel(masks)
    c = cells(masks{q}, :);
    v = cell(1, size(c, 2));
    for j = 1:size(c, 2)
        v{j} = lostPrint(sum(c(:, j) == 'L'), sum(c(:, j) ~= 'N'), size(c, 1) * frac);
    end
    F(q) = struct('label', labels{q}, 'sub', subs{q}, 'vals', {v});
end
end

function s = lostPrint(nLost, nOf, nAll)
% a loss count in the paper's print form: "a" where the law is eligible on every scenario, else "a/b"
if nOf < nAll
    s = sprintf('%d/%d', nLost, nOf);
else
    s = sprintf('%d', nLost);
end
end

function s = r4returns(allBoth, nOf, printed)
% the granted law's returns in the paper's words ("returns on all 101 at both settings"), else the record's print
if allBoth
    s = sprintf('it returns on all %d at both settings.', nOf);
else
    s = sprintf('it returns on %s at both settings.', printed);
end
end

function s = printedOf(D, path)
% the paper's print form of one printed number (app_printed.json, the numbers view's data); '' where absent
P = D.printed;
if iscell(P), P = [P{:}]; end
m = P(strcmp({P.path}, path));
s = '';
if ~isempty(m)
    s = m(1).printed;
end
end

function s = words(x, conj)
% numbers in words of a list: 'a', 'a and b', 'a, b and c' (or with the conjunction given)
if nargin < 2
    conj = 'and';
end
x = arrayfun(@(v) sprintf('%g', v), x, 'UniformOutput', false);
if numel(x) <= 1
    s = strjoin(x, '');
else
    s = [strjoin(x(1:end - 1), ', ') ' ' conj ' ' x{end}];
end
end

function s = lowerFirst(s)
% a name inside a sentence: its first letter in lower case
s = [lower(s(1)) s(2:end)];
end

function s = pluralVerb(n)
% the verb lose for one or for several subjects
if n > 1
    s = 'lose';
else
    s = 'loses';
end
end

function s = noneOr(n)
% a count, in words where it is zero
if n == 0
    s = 'none';
else
    s = sprintf('%d', n);
end
end

function s = ownTxt(nv, nc, capName)
% the Current Compass's own count and the cap alone's, after the compared settings'
if nv == 0 && nc == 0
    s = sprintf('the Current Compass and the %s lose none', capName);
else
    s = sprintf('the Current Compass loses %s and the %s %s', noneOr(nv), capName, noneOr(nc));
end
end

function s = lawNames(L, codes)
% the compared laws of the codes (app_laws.json), in their order, a law's two settings named once with "at both
% settings"; each name inside a sentence
codes = cellstr(codes);
modes = cellfun(@(c) L(strcmp({L.code}, c)).mode, codes, 'UniformOutput', false);
first = cellfun(@(x) find(strcmp(modes, x), 1), modes);
keep = first(:).' == (1:numel(codes));
names = cell(1, nnz(keep));
q = 0;
for i = find(keep)
    w = L(strcmp({L.code}, codes{i}));
    q = q + 1;
    if sum(strcmp(modes, modes{i})) > 1
        names{q} = lowerFirst(sprintf('%s at both settings', regexprep(w.name, ', selected$', '')));
    else
        names{q} = lowerFirst(w.name);
    end
end
if numel(names) <= 1
    s = strjoin(names, '');
else
    s = [strjoin(names(1:end - 1), ', ') ' and ' names{end}];
end
end

function s = loadStepTest(D, L, O, SR, SGr, codes, cells, isSmall)
% the smaller load step's test, fixed before the runs (s60r.v6.r17.vf), in the paper's words and print forms
% (Section V-F; the print forms from app_printed.json): the passed test first, the cap's binding and the frequencies
% as the paper prints their range, the larger step where the cells show it; then every bus's run (the author's word
% a passed test is reported as passed, a detail for every member)
lf = @(p) cca.data.leaf(D, p);
pf = @(p) printedOf(D, p);
nName = lowerFirst(O(strcmp({O.code}, 'n')).name);
vName = L(strcmp({L.code}, 'v')).name;
b = lf('s60r.v6.r17.vf.buses');
s = {};
nb = pf('s60r.v6.r17.vf.buses (count, as a word)');
if lf('s60r.v6.r17.vf.passed_at_all_three') && ~isempty(nb)
    s{end + 1} = sprintf(['Without a fault, with a resistive load of %s MW on for %s s at bus %s, the %s passes the ' ...
        'test fixed before the runs at all %s buses: its largest frequency deviation and return time are the %s''s ' ...
        'within tolerance.'], SGr(isSmall).MW_print, pf('s60r.v6.r19.vf.event_dur_print'), words(b, 'or'), vName, ...
        nb, nName);
end
cb = pf('s60r.v6.r17.vf.per_bus.<23, 25, 29>.cap_longest_bind_s (smallest to largest, two decimals)');
f1 = pf('s60r.v6.r17.vf.per_bus.<23, 25>.df_max_print_up (rounded up)');
f2 = pf('s60r.v6.r17.vf.per_bus.29.df_max_print_up (rounded up)');
f2b = pf('s60r.v6.r17.vf.per_bus (the bus of the other value)');
if ~any(cellfun(@isempty, {cb, f1, f2, f2b}))
    s{end + 1} = sprintf(['Its cap binds for %s s at the longest and its GFM frequencies stay within %s Hz of that ' ...
        'limiter''s (%s Hz at bus %s).'], cb, f1, f2, f2b);
end
jn = strcmp(codes, 'n');
jv = strcmp(codes, 'v');
big = find(~isSmall);
if isscalar(big)
    inBig = strcmp({SR.group}, SGr(big).cls);
    if any(inBig) && all(cells(inBig, jn) == 'L') && all(ismember(cells(inBig, jv), 'RE'))
        s{end + 1} = sprintf('At %s MW, that limiter loses synchronism and the %s returns to rest.', ...
            SGr(big).MW_print, vName);
    end
end
s = [s, arrayfun(@(k) busLine(D, k), reshape(b, 1, []), 'UniformOutput', false)];
end

function s = busLine(D, k)
% one bus of the smaller step's test: its verdict, then its details (s60r.v6.r17.vf.per_bus)
lf = @(p) cca.data.leaf(D, sprintf(p, k));
if lf('s60r.v6.r17.vf.per_bus.%d.passed')
    v = 'passed';
else
    v = 'not passed';
end
s = sprintf(['Bus %d: %s; the cap binds for %s s at the longest; the GFM frequencies differ from that limiter''s by ' ...
    '%s Hz at the largest; return time %s s, that limiter''s %s s.'], k, v, ...
    lf('s60r.v6.r17.vf.per_bus.%d.cap_longest_bind_print_3'), lf('s60r.v6.r17.vf.per_bus.%d.df_max_print_3'), ...
    lf('s60r.v6.r17.vf.per_bus.%d.law_T_RET_s'), lf('s60r.v6.r17.vf.per_bus.%d.limiter_alone_T_RET_s'));
end

function n = figureNumber(D, key)
F = D.paper.figures;
if iscell(F), F = [F{:}]; end
n = F(strcmp({F.key}, key)).number;
end

function n = tableNumber(D, key)
X = D.paper.tables;
if iscell(X), X = [X{:}]; end
n = X(strcmp({X.key}, key)).number;
end

function s = tableTitle(D, key)
% a table's title as the paper prints it (app_paper.json), in the paper's curly quotation marks
X = D.paper.tables;
if iscell(X), X = [X{:}]; end
s = [char(8220) X(strcmp({X.key}, key)).title char(8221)];
end

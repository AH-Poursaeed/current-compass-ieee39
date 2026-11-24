function S = run(host, D, T, app)
%RUN  Screen 03: the paper's runs. Every row of the campaign table of the paper's runs (app_runs.json, one row a
%   run, in the table's order) with its set, law, setting, fault, load, network state and outcome; filters by set,
%   by law and by outcome, and a line that counts the runs shown (computed from the data); the selected run's card
%   with every field and the paper's place that counts it; and, for a run whose traces ship (app/data/runs), its
%   traces with the dial, the power plane and one time cursor for all of them.
Rl = D.runlist;
I = D.runinfo;
n = numel(Rl.tag);
OUT = asArray(I.outcomes);
SETS = asArray(I.sets);
LAWS = asArray(I.laws);
L = asArray(D.laws);
O = asArray(D.others);

% ------------------------------------------------------------------ the rows, computed once
setNames = {SETS.name};
padded = strcat({' + '}, Rl.set, {' + '});        % a row of two sets is in both (the names joined by " + ")
inSet = false(n, numel(setNames));
for j = 1:numel(setNames)
    inSet(:, j) = contains(padded, [' + ' setNames{j} ' + ']);
end
lawCodes = {LAWS.code};
lawItems = lawLabels(LAWS, Rl);
[~, cLoc] = ismember(Rl.outcome, {OUT.word});
classes = [OUT.class];
cls = repmat('C', n, 1);
cls(cLoc > 0) = classes(cLoc(cLoc > 0));
fault = faultWords(Rl, D.grid.words);
C = [Rl.set, Rl.law, Rl.setting, fault, strcat(Rl.load, {', '}, Rl.network), Rl.outcome];
traceShips = ~strcmp(Rl.trace, '-');

% ------------------------------------------------------------------ the layout
g = uigridlayout(host, [2 2], 'RowHeight', {58, '1x'}, 'ColumnWidth', {'1x', 290}, 'Padding', [0 0 0 0], ...
    'RowSpacing', T.px.gutter, 'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);
bar = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
bar.Layout.Row = 1; bar.Layout.Column = [1 2];
bg = uigridlayout(bar, [2 6], 'RowHeight', {16, 24}, 'ColumnWidth', {220, 340, 270, 'fit', '1x', 'fit'}, ...
    'Padding', [14 4 14 6], 'RowSpacing', 2, 'ColumnSpacing', 12, 'BackgroundColor', T.c.surface);
lab(bg, 1, 1, 'Set', 11, T.c.ink3, false);
lab(bg, 1, 2, 'Law or part', 11, T.c.ink3, false);
lab(bg, 1, 3, 'Outcome', 11, T.c.ink3, false);
ddSet = uidropdown(bg, 'Items', [{'All sets'}, setNames], 'ItemsData', [{''}, setNames], 'FontName', ...
    T.font.chrome, 'FontSize', 12);
ddSet.Layout.Row = 2; ddSet.Layout.Column = 1;
ddLaw = uidropdown(bg, 'Items', [{'All laws and parts'}, lawItems], 'ItemsData', [{''}, lawCodes], ...
    'FontName', T.font.chrome, 'FontSize', 12);
ddLaw.Layout.Row = 2; ddLaw.Layout.Column = 2;
ddOut = uidropdown(bg, 'Items', [{'All outcomes'}, {OUT.word}], 'ItemsData', [{''}, {OUT.word}], 'FontName', ...
    T.font.chrome, 'FontSize', 12);
ddOut.Layout.Row = 2; ddOut.Layout.Column = 3;
cbTr = uicheckbox(bg, 'Text', 'With traces only', 'FontName', T.font.chrome, 'FontSize', 12, 'Visible', ...
    matlab.lang.OnOffSwitchState(any(traceShips)));
cbTr.Layout.Row = 2; cbTr.Layout.Column = 4;
bAll = uibutton(bg, 'Text', 'Show every run', 'FontName', T.font.chrome, 'FontSize', 12, 'Visible', 'off');
bAll.Layout.Row = 2; bAll.Layout.Column = 6;

% the centre: the list (its count line above it), or the traces of the selected run
mid = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
mid.Layout.Row = 2; mid.Layout.Column = 1;
mg = uigridlayout(mid, [1 1], 'Padding', [10 8 10 10], 'BackgroundColor', T.c.surface);
listPane = uigridlayout(mg, [2 1], 'RowHeight', {48, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4, ...
    'BackgroundColor', T.c.surface);
listPane.Layout.Row = 1; listPane.Layout.Column = 1;
countLine = uilabel(listPane, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2, ...
    'VerticalAlignment', 'top', 'WordWrap', 'on');
countLine.Layout.Row = 1;
tbl = uitable(listPane, 'ColumnName', {'Set', 'Law or part', 'Setting', 'Fault or event', 'Load, network', ...
    'Outcome'}, 'RowName', {}, 'ColumnWidth', {176, '1x', 84, 150, 96, 156}, 'FontName', T.font.chrome, ...
    'FontSize', 11, 'SelectionType', 'row', 'Multiselect', 'off');
tbl.Layout.Row = 2;
tracePane = uigridlayout(mg, [2 2], 'RowHeight', {30, '1x'}, 'ColumnWidth', {'1x', 250}, 'Padding', [0 0 0 0], ...
    'RowSpacing', 6, 'ColumnSpacing', 12, 'BackgroundColor', T.c.surface, 'Visible', 'off');
tracePane.Layout.Row = 1; tracePane.Layout.Column = 1;
th = uigridlayout(tracePane, [1 3], 'ColumnWidth', {'fit', '1x', 'fit'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 8, 'BackgroundColor', T.c.surface);
th.Layout.Row = 1; th.Layout.Column = [1 2];
bBack = uibutton(th, 'Text', [char(8249) ' Back to the list'], 'FontName', T.font.chrome, 'FontSize', 12);
traceTitle = lab(th, 1, 2, '', 13, T.c.ink, true);
ug = uigridlayout(th, [1 4], 'ColumnWidth', {'fit', 'fit', 'fit', 'fit'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4, 'BackgroundColor', T.c.surface);
ug.Layout.Column = 3;
plotPanel = uipanel(tracePane, 'BackgroundColor', T.c.surface, 'BorderType', 'none');
plotPanel.Layout.Row = 2; plotPanel.Layout.Column = 1;
rg = uigridlayout(tracePane, [7 1], 'RowHeight', {18, 190, 50, 18, '1x', 30, 70}, 'Padding', [0 0 0 0], ...
    'RowSpacing', 4, 'BackgroundColor', T.c.surface);
rg.Layout.Row = 2; rg.Layout.Column = 2;
dialSub = lab(rg, 1, 1, '', 11, T.c.ink3, false);
axDial = uiaxes(rg);
axDial.Layout.Row = 2;
readout = uilabel(rg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'VerticalAlignment', 'top');
readout.Layout.Row = 3;
pqLabel = lab(rg, 4, 1, 'P against Q of the unit', 11, T.c.ink, true);
axPQ = uiaxes(rg);
axPQ.Toolbar.Visible = 'off';
axPQ.Layout.Row = 5;
sg = uigridlayout(rg, [1 2], 'ColumnWidth', {30, '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
    'BackgroundColor', T.c.surface);
sg.Layout.Row = 6;
bPlay = uibutton(sg, 'Text', char(9654), 'FontSize', 12);
sl = uislider(sg, 'MajorTicks', [], 'MinorTicks', []);
sl.Layout.Column = 2;
note = uilabel(rg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 10, 'FontColor', T.c.ink3, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
note.Layout.Row = 7;

% the right: the selected run's card
right = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
right.Layout.Row = 2; right.Layout.Column = 2;
hasHandler = ~isempty(app.handler);
cardRows = {22, '1x', 'fit', 'fit', 34};
if hasHandler
    cardRows{end + 1} = 34;
end
cg = uigridlayout(right, [numel(cardRows) 1], 'RowHeight', cardRows, 'Padding', [14 10 14 12], ...
    'RowSpacing', 6, 'BackgroundColor', T.c.surface);
lab(cg, 1, 1, 'The run', 15, T.c.ink, true);
card = uitextarea(cg, 'Editable', 'off', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink, ...
    'BackgroundColor', T.c.surface);   % every field whole, its long values wrapped
card.Layout.Row = 2;
cardFields = cell(0, 2);
meaning = uilabel(cg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
meaning.Layout.Row = 3;
setNote = uilabel(cg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
setNote.Layout.Row = 4;
bTrace = uibutton(cg, 'Text', 'Show its traces', 'FontName', T.font.chromeBold, 'FontSize', 13, ...
    'BackgroundColor', T.c.accent, 'FontColor', T.c.white, 'Visible', 'off');
bTrace.Layout.Row = 5;
bRun = [];
if hasHandler
    st = app.handler("status");
    bRun = uibutton(cg, 'Text', 'Run it with the model', 'FontName', T.font.chrome, 'FontSize', 13, ...
        'Enable', st.available, 'Tooltip', st.reason);
    bRun.Layout.Row = 6;
    bRun.ButtonPushedFcn = @(~, ~) runWithHandler();
end

% ------------------------------------------------------------------ the state of the screen
cur = struct('R', [], 'ax', [], 'cursor', [], 'pq', [], 'unit', NaN, 'units', [], 'row', 0);
unitButtons = gobjects(0);
shown = (1:n).';
keyFilter = '';
lastAsked = {'', '', ''};
ddSet.ValueChangedFcn = @(~, ~) refilter();
ddLaw.ValueChangedFcn = @(~, ~) refilter();
ddOut.ValueChangedFcn = @(~, ~) refilter();
cbTr.ValueChangedFcn = @(~, ~) refilter();
bAll.ButtonPushedFcn = @(~, ~) clearKey();
tbl.SelectionChangedFcn = @(~, e) onRow(e);
bTrace.ButtonPushedFcn = @(~, ~) showTraces();
bBack.ButtonPushedFcn = @(~, ~) showList();
bPlay.ButtonPushedFcn = @(~, ~) play();
sl.ValueChangingFcn = @(~, e) moveCursor(e.Value);
sl.ValueChangedFcn = @(~, e) moveCursor(e.Value);
refilter();

S.grid = g;
S.onShow = @() onShowScreen();
S.handles = struct('table', tbl, 'card', card, 'count', countLine, 'set', ddSet, 'law', ddLaw, 'outcome', ddOut, ...
    'traces', cbTr, 'showTraces', bTrace, 'back', bBack, 'slider', sl, 'runButton', bRun, 'all', bAll, ...
    'tracePane', tracePane, 'listPane', listPane);
S.refilter = @refilter;
S.shownRows = @getShown;
S.cardFields = @getCardFields;
S.selectRow = @selectGlobal;
S.showTraces = @showTraces;
S.moveCursor = @moveCursor;
S.current = @getCur;

    % ================================================================== the list
    function c = getCur()
        c = cur;
    end

    function r = getShown()
        % the rows of the campaign table that the list shows now (an anonymous handle would keep the first ones)
        r = shown;
    end

    function f = getCardFields()
        % the selected run's card: its fields and their values, as the card shows them
        f = cardFields;
    end

    function onShowScreen()
        % a cell chosen on another screen (Compare, Scenarios, the Overview): its scenario's runs in the list, and the
        % run of the control chosen there selected: the row whose counts_in names the cell's set, else the row whose
        % set names it, else the first row that a printed count holds, else the first
        asked = {app.state.Key, app.state.Code, app.state.Set};
        if ~isempty(app.state.Key) && ~isequal(asked, lastAsked)
            lastAsked = asked;
            if ~strcmp(app.state.Key, keyFilter)
                keyFilter = app.state.Key;
                ddSet.Value = '';
                ddLaw.Value = '';
                ddOut.Value = '';
                cbTr.Value = false;
                refilter();
            end
            m = find(strcmp(Rl.key(shown), keyFilter) & strcmp(Rl.code(shown), app.state.Code));
            if ~isempty(m)
                k = [];
                if ~isempty(app.state.Set)
                    k = m(find(namesSet(Rl.counts_in(shown(m)), app.state.Set), 1));
                    if isempty(k)
                        k = m(find(namesSet(Rl.set(shown(m)), app.state.Set), 1));
                    end
                end
                if isempty(k)
                    k = m(find(~strcmp(Rl.counts_in(shown(m)), '-'), 1));
                end
                if isempty(k), k = m(1); end
                selectShown(k);
            end
        end
        if strcmp(app.state.View, 'traces') && cur.row > 0 && traceShips(cur.row)
            showTraces();
        end
        app.state.View = '';
    end

    function refilter()
        m = true(n, 1);
        if ~isempty(ddSet.Value)
            m = m & inSet(:, strcmp(setNames, ddSet.Value));
        end
        if ~isempty(ddLaw.Value)
            m = m & strcmp(Rl.code, ddLaw.Value);
        end
        if ~isempty(ddOut.Value)
            m = m & strcmp(Rl.outcome, ddOut.Value);
        end
        if cbTr.Value
            m = m & traceShips;
        end
        if ~isempty(keyFilter)
            m = m & strcmp(Rl.key, keyFilter);
        end
        shown = find(m);
        tbl.Data = C(shown, :);
        removeStyle(tbl);
        colourOutcomes();
        countLine.Text = countWords();
        bAll.Visible = matlab.lang.OnOffSwitchState(~isempty(keyFilter));
        if ~isempty(shown)
            selectShown(1);
        else
            fillCard(0);
        end
    end

    function colourOutcomes()
        ink = struct('L', T.c.lossInk, 'E', T.c.limited, 'N', T.c.ink3, 'C', T.c.ink2);
        for q = 'LENC'
            r = find(cls(shown) == q);
            if ~isempty(r)
                addStyle(tbl, uistyle('FontColor', ink.(q)), 'cell', [r, repmat(6, numel(r), 1)]);
            end
        end
    end

    function s = countWords()
        % the runs shown, of all; then each outcome word of the runs shown with its count (counted from the rows)
        parts = {};
        for q = 1:numel(OUT)
            k = sum(strcmp(Rl.outcome(shown), OUT(q).word));
            if k > 0
                parts{end + 1} = sprintf('%s %s', OUT(q).word, cca.ui.fmt('count', k)); %#ok<AGROW>
            end
        end
        s = sprintf('%s of %s runs shown', cca.ui.fmt('count', numel(shown)), cca.ui.fmt('count', n));
        if ~isempty(ddSet.Value)
            % a scenario that ran more than once has several rows: the paper counts one of them in the set (the row
            % whose counts_in names it), so the rows shown and the paper's count of scenarios are both given
            k = nnz(namesSet(Rl.counts_in(shown), ddSet.Value));
            s = sprintf('%s; the paper counts %s of them in the set %s (one run a scenario)', s, ...
                cca.ui.fmt('count', k), ddSet.Value);
        end
        if ~isempty(keyFilter)
            s = sprintf('%s (the scenario %s)', s, scenarioWords(keyFilter));
        end
        if ~isempty(parts)
            s = sprintf('%s\n%s', s, strjoin(parts, '; '));
        end
    end

    function clearKey()
        keyFilter = '';
        lastAsked = {'', '', ''};
        app.state.Key = '';
        refilter();
    end

    function onRow(e)
        if isempty(e.Selection), return, end
        fillCard(shown(e.Selection(1)));
    end

    function selectShown(k)
        tbl.Selection = k;
        scroll(tbl, 'row', k);
        fillCard(shown(k));
    end

    function selectGlobal(i)
        % select the row i of the campaign table, clearing the filters that hide it
        k = find(shown == i, 1);
        if isempty(k)
            ddSet.Value = ''; ddLaw.Value = ''; ddOut.Value = ''; cbTr.Value = false; keyFilter = '';
            refilter();
            k = find(shown == i, 1);
        end
        selectShown(k);
    end

    function fillCard(i)
        cur.row = i;
        if i == 0
            cardFields = cell(0, 2);
            card.Value = {''};
            meaning.Text = '';
            setNote.Text = '';
            bTrace.Visible = 'off';
            return
        end
        F = {'Tag', Rl.tag{i}; 'Set', Rl.set{i}; 'Law or part', Rl.law{i}; 'Setting', Rl.setting{i}; ...
            'Fault bus', Rl.fault_bus{i}; 'Fault', Rl.fault_kind{i}; 'Duration, ms', Rl.fault_ms{i}; ...
            'Fault resistance, pu', Rl.fault_r_pu{i}; 'Event', Rl.event{i}; 'Load', Rl.load{i}; ...
            'Network', Rl.network{i}; 'Scenario key', Rl.key{i}; 'Outcome', Rl.outcome{i}; ...
            'Detail', Rl.detail{i}; 'Counted in', Rl.counts_in{i}; 'The paper''s place', Rl.place{i}; ...
            'Traces', Rl.trace{i}; 'Hash of the arguments', Rl.args_sha256{i}};
        cardFields = F;
        card.Value = strcat(F(:, 1), {': '}, F(:, 2));
        w = OUT(strcmp({OUT.word}, Rl.outcome{i}));
        if isempty(w)
            meaning.Text = '';
        else
            meaning.Text = sprintf('%s: %s', Rl.outcome{i}, w(1).meaning);
        end
        own = strtrim(strsplit(Rl.set{i}, ' + '));
        sn = SETS(ismember(setNames, own));
        setNote.Text = strjoin(arrayfun(@(x) sprintf('%s: %s', x.name, x.note), sn, 'UniformOutput', false), ...
            newline);
        bTrace.Visible = matlab.lang.OnOffSwitchState(traceShips(i));
        if strcmp(tracePane.Visible, 'on')
            if traceShips(i)
                showTraces();
            else
                showList();
            end
        end
    end

    function runWithHandler()
        i = cur.row;
        if i == 0, return, end
        req = struct('D', D, 'key', Rl.key{i}, 'code', Rl.code{i}, 'tag', Rl.tag{i}, 'dry', app.dry);
        try
            R = app.handler("run", req);
            app.act(sprintf('Start the run %s: %s', Rl.tag{i}, R.statement), @() []);
            setNote.Text = sprintf('Started: %s. Its log: %s', R.statement, R.log);
        catch err
            setNote.Text = err.message;
        end
    end

    % ================================================================== the traces
    function showList()
        tracePane.Visible = 'off';
        listPane.Visible = 'on';
    end

    function showTraces()
        i = cur.row;
        if i == 0 || ~traceShips(i), return, end
        R = cca.data.runpack(D, Rl.key{i}, Rl.code{i}, Rl.trace{i});
        if isempty(R), return, end
        listPane.Visible = 'off';
        tracePane.Visible = 'on';
        cur.R = R;
        traceTitle.Text = sprintf('%s: %s', Rl.law{i}, scenarioWords(Rl.key{i}));
        delete(plotPanel.Children);
        delete(unitButtons);
        unitButtons = gobjects(0);
        drawTraces(R);
        info = cca.ui.dial(axDial, T, D, R, 0);
        if isnan(info.psi)
            dialSub.Text = 'no rotation in this law''s run';
        else
            dialSub.Text = sprintf('rotation of unit %d at the cursor', R.meta.unit);
        end
        drawPQ(R);
        sl.Limits = R.meta.window_s(:).';
        sl.Value = 0;
        moveCursor(0);
        note.Text = sprintf(['Unit %d at bus %d; time after clearing, the fault shaded. Each series is kept as its ' ...
            'extremes in %d bins, so no peak is hidden.'], R.meta.unit, R.meta.unit_bus, R.meta.nbin);
        rel = releaseWord(R);
        if ~isempty(rel)
            note.Text = sprintf('%s Made with MATLAB %s.', note.Text, rel);
        end
    end

    function drawTraces(R)
        % one panel a series that the run file holds, in the figure's order: the units' relative angles or the
        % largest of them, the terminal voltage, the output current over its limit, P and Q, the limiter, psi
        names = {};
        units = [];
        if isfield(R.meta, 'gfm_units'), units = R.meta.gfm_units(:).'; end
        if ~isempty(units) && all(arrayfun(@(u) isfield(R.series, sprintf('rel_u%d', u)), units))
            names{end + 1} = 'rel';
        end
        if isfield(R.series, 'relmax'), names{end + 1} = 'relmax'; end
        if isfield(R.series, 'Vt'), names{end + 1} = 'vt'; end
        if isfield(R.series, 'Iout_join'), names{end + 1} = 'iout'; end
        if isfield(R.series, 'Pu') && isfield(R.series, 'Qu'), names{end + 1} = 'pq'; end
        if isfield(R.meta, 'sat'), names{end + 1} = 'lim'; end
        if isfield(R.series, 'psi') && any(~isnan(R.series.psi.y)), names{end + 1} = 'psi'; end
        nt = numel(names);
        tl = tiledlayout(plotPanel, nt, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
        ax = gobjects(nt, 1);
        fw = R.meta.fault_window_s(:).';
        cur.units = units;
        cur.unit = R.meta.unit;
        for q = 1:nt
            ax(q) = nexttile(tl);
            a = ax(q);
            hold(a, 'on');
            switch names{q}
                case 'rel'
                    for u = units(units ~= cur.unit)
                        s = R.series.(sprintf('rel_u%d', u));
                        plot(a, s.t, s.y, '-', 'Color', T.c.other, 'LineWidth', T.px.line);
                    end
                    s = R.series.(sprintf('rel_u%d', cur.unit));
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    ylabel(a, 'Rel. angle (deg)');
                case 'relmax'
                    s = R.series.relmax;
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    ylabel(a, 'Largest rel. angle (deg)');
                case 'vt'
                    s = R.series.Vt;
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    ylabel(a, 'Terminal voltage (pu)');
                case 'iout'
                    s = R.series.Iout_join;
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    yline(a, 1, ':', 'the limit', 'Color', T.c.ink3, 'FontName', T.font.plot, 'FontSize', 9, ...
                        'LabelHorizontalAlignment', 'right');
                    ylabel(a, 'Current / limit');
                case 'pq'
                    s = R.series.Pu;
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    s = R.series.Qu;
                    plot(a, s.t, s.y, '--', 'Color', T.c.ink2, 'LineWidth', T.px.line);
                    ylabel(a, 'P (MW), Q (Mvar)');
                case 'lim'
                    [tt, ff] = satSteps(R);
                    stairs(a, tt, ff, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    a.YLim = [-0.2 1.2];
                    a.YTick = [0 1];
                    a.YTickLabel = {'off', 'on'};
                    ylabel(a, 'Limiter');
                case 'psi'
                    s = R.series.psi;
                    plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
                    yline(a, 90, ':', 'quarter-turn clamp', 'Color', T.c.ink3, 'FontName', T.font.plot, ...
                        'FontSize', 9, 'LabelHorizontalAlignment', 'right');
                    a.YLim = [-5 100];
                    ylabel(a, [char(968) ' (deg)']);
            end
            hold(a, 'off');
        end
        xlabel(tl, 'Time after clearing (s)', 'FontName', T.font.plot, 'FontSize', 11);
        cur.cursor = gobjects(nt, 1);
        for q = 1:nt
            a = ax(q);
            a.FontName = T.font.plot;
            a.FontSize = 10;
            a.Box = 'off';
            a.XColor = T.c.axis;
            a.YColor = T.c.axis;
            a.Toolbar.Visible = 'off';
            a.XLim = R.meta.window_s(:).';
            xregion(a, fw(1), fw(2), 'FaceColor', T.c.fault, 'FaceAlpha', 1, 'EdgeColor', T.c.faultEdge);
            ch = a.Children;
            a.Children = [ch(2:end); ch(1)];   % the band under the traces
            cur.cursor(q) = xline(a, 0, '-', 'Color', T.c.ink, 'LineWidth', 0.8);
            if q < nt
                a.XTickLabel = [];
            end
            disableDefaultInteractivity(a);
        end
        linkaxes(ax, 'x');
        cur.ax = ax;
        if any(strcmp(names, 'rel'))
            for k2 = 1:numel(units)
                b = uibutton(ug, 'state', 'Text', sprintf('Unit %d', units(k2)), 'FontName', T.font.chrome, ...
                    'FontSize', 11, 'Value', units(k2) == cur.unit);
                b.Layout.Column = k2;
                b.ValueChangedFcn = @(~, ~) selectUnit(units(k2));
                unitButtons(end + 1) = b; %#ok<AGROW>
            end
        end
    end

    function selectUnit(u)
        % the relative-angle panel highlights the unit; the other panels are the faulted unit's own series
        for k2 = 1:numel(unitButtons)
            unitButtons(k2).Value = cur.units(k2) == u;
        end
        a = cur.ax(1);
        ln = findobj(a, 'Type', 'line');
        ln = ln(~ismember(ln, cur.cursor));
        delete(ln);
        hold(a, 'on');
        for uu = cur.units(cur.units ~= u)
            s = cur.R.series.(sprintf('rel_u%d', uu));
            plot(a, s.t, s.y, '-', 'Color', T.c.other, 'LineWidth', T.px.line);
        end
        s = cur.R.series.(sprintf('rel_u%d', u));
        plot(a, s.t, s.y, '-', 'Color', lawColour(), 'LineWidth', T.px.lineSel);
        hold(a, 'off');
    end

    function drawPQ(R)
        cla(axPQ);
        hasPQ = isfield(R.series, 'Pu') && isfield(R.series, 'Qu');
        pqLabel.Visible = matlab.lang.OnOffSwitchState(hasPQ);
        axPQ.Visible = matlab.lang.OnOffSwitchState(hasPQ);
        if hasPQ                          % no P-Q plane where the run file holds no P and Q: the slider follows
            rg.RowHeight = {18, 190, 50, 18, '1x', 30, 70};
        else
            rg.RowHeight = {18, 190, 90, 0, 0, 30, '1x'};
            cur.pq = [];
            return
        end
        % one point a bin: the middle of the bin's two extremes of P and of Q (the two series are binned
        % separately, so their extremes are not simultaneous; the middle is drawn, not a sample)
        s = R.series.Pu; q = R.series.Qu;
        pm = mean(reshape(s.y, 2, []), 1);
        qm = mean(reshape(q.y, 2, []), 1);
        plot(axPQ, pm, qm, '-', 'Color', [lawColour() 0.6], 'LineWidth', 1);
        hold(axPQ, 'on');
        cur.pq = plot(axPQ, NaN, NaN, 'o', 'MarkerSize', 7, 'MarkerFaceColor', lawColour(), ...
            'MarkerEdgeColor', T.c.surface);
        hold(axPQ, 'off');
        axPQ.FontName = T.font.plot;
        axPQ.FontSize = 9;
        axPQ.Box = 'off';
        axPQ.Toolbar.Visible = 'off';
        xlabel(axPQ, 'P (MW)');
        ylabel(axPQ, 'Q (Mvar)');
        disableDefaultInteractivity(axPQ);
    end

    function moveCursor(t)
        if isempty(cur.R), return, end
        for q = 1:numel(cur.cursor)
            if isgraphics(cur.cursor(q))
                cur.cursor(q).Value = t;
            end
        end
        R = cur.R;
        info = cca.ui.dial(axDial, T, D, R, t);
        words = {sprintf('t = %+.2f s after clearing', t)};
        if ~isnan(info.psi)
            words{end + 1} = sprintf('rotation %s = %.1f deg', char(968), info.psi);
        end
        if isfield(R.series, 'Pu') && isfield(R.series, 'Qu')
            p = valueAt(R.series.Pu, t);
            q = valueAt(R.series.Qu, t);
            if ~isempty(cur.pq) && isgraphics(cur.pq)
                cur.pq.XData = p; cur.pq.YData = q;
            end
            words{end + 1} = sprintf('P = %.0f MW, Q = %.0f Mvar', p, q);
        end
        if isfield(R.series, 'Vt')
            words{end + 1} = sprintf('terminal voltage %.3f pu', valueAt(R.series.Vt, t));
        end
        if isfield(R.series, 'Iout_join')
            words{end + 1} = sprintf('current / limit %.3f', valueAt(R.series.Iout_join, t));
        end
        if isfield(R.series, 'relmax')
            words{end + 1} = sprintf('largest rel. angle %.1f deg', valueAt(R.series.relmax, t));
        end
        readout.Text = strjoin(words, newline);
        app.state.TimeIndex = t;
    end

    function play()
        if isempty(cur.R), return, end
        ts = linspace(sl.Limits(1), sl.Limits(2), 80);
        for t = ts
            sl.Value = t;
            moveCursor(t);
            drawnow limitrate;
        end
    end

    % ================================================================== small helpers
    function c = lawColour()
        c = T.c.ink;
        if cur.row == 0, return, end
        code = Rl.code{cur.row};
        w = L(strcmp({L.code}, code));
        if isempty(w), w = O(strcmp({O.code}, code)); end
        if ~isempty(w)
            c = cca.style_rgb(w(1).colour);
            if all(c == 0), c = T.c.ink; end
        end
    end

    function s = scenarioWords(key)
        % the scenario in the words of the grid (a fault key); other keys (a load step, an operating state) as they
        % stand in the list
        try
            s = cca.data.scenario(D, key, "short");
        catch
            s = key;
        end
    end
end

% ====================================================================================================== locals
function X = asArray(X)
if iscell(X), X = [X{:}]; end
end

function tf = namesSet(field, name)
% the rows whose set field (or counts_in field) names the set (the names joined by " + ")
tf = contains(strcat({' + '}, field, {' + '}), [' + ' name ' + ']);
end

function items = lawLabels(LAWS, Rl)
% the laws and parts of the list as the paper names them; a name that two codes share carries each code's setting
names = {LAWS.law};
items = names;
for k = 1:numel(LAWS)
    if sum(strcmp(names, names{k})) > 1
        st = unique(Rl.setting(strcmp(Rl.code, LAWS(k).code)), 'stable');
        items{k} = sprintf('%s, %s', names{k}, strjoin(st, ', '));
    end
end
end

function f = faultWords(Rl, W)
% the fault of each row in words (bus, kind in the grid's short words, duration, resistance), or its event, or "no
% disturbance"
n = numel(Rl.tag);
f = repmat({'no disturbance'}, n, 1);
isF = ~strcmp(Rl.fault_bus, '-');
ms = str2double(Rl.fault_ms);
kind = Rl.fault_kind;
if isfield(W, 'type_short') && isfield(W.type_short, 'T') && isfield(W.type_short, 'S')
    kind(strcmp(kind, 'three-phase')) = {W.type_short.T};
    kind(strcmp(kind, 'SLG')) = {W.type_short.S};
end
for i = reshape(find(isF), 1, [])
    f{i} = sprintf('bus %s, %s, %g s, %s pu', Rl.fault_bus{i}, kind{i}, ms(i) / 1000, Rl.fault_r_pu{i});
end
isE = ~strcmp(Rl.event, '-');
f(isE) = Rl.event(isE);
end

function h = lab(parent, row, col, txt, size, colour, bold)
fn = 'Segoe UI';
if bold, fn = 'Segoe UI Semibold'; end
h = uilabel(parent, 'Text', txt, 'FontName', fn, 'FontSize', size, 'FontColor', colour);
h.Layout.Row = row;
h.Layout.Column = col;
end

function r = releaseWord(R)
m = '';
if isfield(R.meta, 'archive') && isfield(R.meta.archive, 'matlab')
    m = R.meta.archive.matlab;
elseif isfield(R.index, 'matlab')
    m = R.index.matlab;
end
tok = regexp(char(m), '\((R\d{4}[ab])\)\s*(Update \d+)?', 'tokens', 'once');
if isempty(tok)
    r = char(m);
else
    r = strtrim([tok{1} ' ' tok{2}]);
end
end

function [tt, ff] = satSteps(R)
% the unit's limiter flag as steps, from the export's runs (fine window, then record runs outside it)
s = R.meta.sat;
runsF = zeros(0, 2);
if isfield(s, 'fine_runs_s') && ~isempty(s.fine_runs_s)
    runsF = reshape(s.fine_runs_s, [], 2);
end
runsR = zeros(0, 2);
if isfield(s, 'record_runs_s') && ~isempty(s.record_runs_s)
    runsR = reshape(s.record_runs_s, [], 2);
end
allRuns = sortrows([runsF; runsR], 1);
w = R.meta.window_s(:).';
tt = w(1);
ff = 0;
for k = 1:size(allRuns, 1)
    tt = [tt, allRuns(k, 1), allRuns(k, 2)]; %#ok<AGROW>
    ff = [ff, 1, 0]; %#ok<AGROW>
end
tt = [tt, w(2)];
ff = [ff, 0];
[tt, o] = sort(tt);
ff = ff(o);
end

function v = valueAt(s, t)
[~, k] = min(abs(s.t - t) + 1e9 * isnan(s.y));
v = s.y(k);
end

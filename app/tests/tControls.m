classdef tControls < matlab.unittest.TestCase
    %TCONTROLS  Every control of the window pressed through its own callback, as a click calls it, and the state
    %   checked after each press: the screen shown, the shared selection, the rows kept, the text that changed.
    %   The test everyControlHasItsTest walks the window and fails on any component with a callback that the
    %   registry of this file does not hold, so a new control without a test fails the suite. Needs a display (or
    %   a batch MATLAB that renders uifigures). Run from the app folder: results = runtests('tests/tControls.m')
    properties
        fig
        app
    end
    methods (TestClassSetup)
        function open(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            [tc.fig, tc.app] = ccapp(Dry=true, Visible=true);
            tc.addTeardown(@() delete(tc.fig));
        end
    end
    methods (Test)
        function railAndTopBar(tc)
            % every entry of the rail opens its screen and marks it; the top bar's icon opens About
            A = tc.app;
            for s = A.NAMES
                post(A.rail, 'nav', char(s));
                tc.verifyEqual(A.current, s);
                tc.verifyEqual(A.rail.Data.active, char(s));
                f = fieldnames(A.screens);
                for k = 1:numel(f)
                    tc.verifyEqual(logical(A.screens.(f{k}).frame.grid.Visible), strcmp(f{k}, s), f{k});
                end
            end
            A.show("overview");
            post(A.topbar, 'nav', 'about');
            tc.verifyEqual(A.current, "about");
            tc.verifyEqual(A.rail.Data.active, 'about');
        end

        function overviewLinks(tc)
            % the four steps: Problem opens Run on the Current Compass's run whose traces ship, its traces open;
            % Idea and Proof open Model; Evidence opens Compare
            A = tc.app;
            A.show("overview");
            S = A.screens.overview;
            h = findall(S.grid, 'Type', 'uihyperlink');
            txt = ascii({h.Text});
            want = {'See one fault in Run', "run"; 'Open the law in Model', "model"; 'Read the equations', "model"; ...
                'Open Compare', "compare"};
            for k = 1:size(want, 1)
                A.show("overview");
                j = find(startsWith(txt, want{k, 1}));
                tc.assertNumElements(j, 1, want{k, 1});
                click(h(j));
                tc.verifyEqual(A.current, want{k, 2}, want{k, 1});
                if want{k, 2} == "run"
                    runs = A.D.runs;
                    if iscell(runs), runs = [runs{:}]; end
                    key = runs(find(strcmp({runs.code}, 'v'), 1)).key;
                    R = A.screens.run;
                    tc.verifyEqual(A.state.Key, key);
                    tc.verifyEqual(A.state.Code, 'v');
                    tc.verifyEqual(A.state.View, '');
                    cur = R.current();
                    tc.verifyEqual(A.D.runlist.key{cur.row}, key);
                    tc.verifyEqual(A.D.runlist.code{cur.row}, 'v');
                    tc.verifyTrue(logical(R.handles.tracePane.Visible), 'the traces open');
                    tc.verifyNotEmpty(cur.R);
                    push(R.handles.back);
                    push(R.handles.all);
                end
            end
        end

        function reproduceCards(tc)
            % every card of the gallery (a figure's picture or button, a table's button, the card Numbers) shows
            % its item in the detail panel; Back to the gallery shows the gallery again
            A = tc.app;
            A.show("reproduce");
            S = A.screens.reproduce;
            F = asArray(A.D.paper.figures);
            X = asArray(A.D.paper.tables);
            P = asArray(A.D.printed);
            cards = [findall(S.handles.gallery, 'Type', 'uiimage'); findall(S.handles.gallery, 'Type', 'uibutton')];
            tc.verifyNumElements(cards, numel(F) + numel(X) + 1);
            bBack = findall(S.handles.detail, 'Type', 'uibutton');
            bBack = bBack(contains(ascii({bBack.Text}), 'Back to the gallery'));
            tc.assertNumElements(bBack, 1);
            seen = false(1, numel(cards));
            for c = reshape(cards, 1, [])
                p = c.Parent.Parent;
                k = (p.Layout.Row - 1) * 4 + p.Layout.Column;
                seen(k) = true;
                if isa(c, 'matlab.ui.control.Image')
                    clickImage(c);
                else
                    push(c);
                end
                if k <= numel(F)
                    want = char(F(k).caption);
                    if isfield(F(k), 'shown') && ~isempty(F(k).shown) && ~logical(F(k).shown)
                        want = 'This figure is not in this build of the application.';
                    end
                    tc.verifyEqual(strjoin(cellstr(S.handles.caption.Value), newline), want, ...
                        sprintf('Fig. %d', F(k).number));
                    tc.verifyTrue(logical(S.handles.gallery.Visible));
                    tc.verifyFalse(logical(bBack.Visible));
                elseif k <= numel(F) + numel(X)
                    i = k - numel(F);
                    t = S.handles.shownTable();
                    tc.verifyEqual(size(t.cells, 1), numel(X(i).cells), X(i).number);
                    tc.verifyFalse(logical(S.handles.gallery.Visible));
                    tc.verifyTrue(logical(bBack.Visible));
                    push(bBack);
                    tc.verifyTrue(logical(S.handles.gallery.Visible));
                    tc.verifyFalse(logical(bBack.Visible));
                    tc.verifyEqual(strjoin(cellstr(S.handles.caption.Value), newline), char(F(1).caption));
                else
                    tb = findall(S.handles.host, 'Type', 'uitable');
                    tc.assertNumElements(tb, 1);
                    tc.verifyEqual(size(tb.Data, 1), numel(P));
                    push(bBack);
                end
            end
            tc.verifyTrue(all(seen), 'every card pressed once');
        end

        function reproduceRegenerateDry(tc)
            % in the Dry mode the button prints its statement and runs nothing
            A = tc.app;
            A.show("reproduce");
            S = A.screens.reproduce;
            n0 = numel(A.log);
            push(S.handles.regenerate);
            tc.verifyNumElements(A.log, n0 + 1);
            tc.verifySubstring(A.log(end), 'Run the data step');
            tc.verifySubstring(A.log(end), 'MANIFEST.json');
        end

        function reproduceNumbersSearch(tc)
            % the search field keeps the rows that hold the text, while typing and when the value is set
            A = tc.app;
            A.show("reproduce");
            S = A.screens.reproduce;
            S.handles.showNumbers();
            P = asArray(A.D.printed);
            ef = findall(S.handles.host, 'Type', 'uieditfield');
            tb = findall(S.handles.host, 'Type', 'uitable');
            tc.assertNumElements(ef, 1);
            hit = @(q) sum(contains({P.place}, q, 'IgnoreCase', true) | contains({P.name}, q, 'IgnoreCase', true) | ...
                contains({P.printed}, q, 'IgnoreCase', true));
            typing(ef, 'Table II');
            tc.verifyEqual(size(tb.Data, 1), hit('Table II'));
            settle(ef, 'Section V');
            tc.verifyEqual(size(tb.Data, 1), hit('Section V'));
            tc.verifyGreaterThan(size(tb.Data, 1), 0);
            settle(ef, '');
            tc.verifyEqual(size(tb.Data, 1), numel(P));
        end

        function runFilters(tc)
            % each drop-down item and the check box, chosen as a click does, keep exactly the runs the data say
            A = tc.app;
            S = runReset(A);
            Rl = A.D.runlist;
            n = numel(Rl.tag);
            h = S.handles;
            for v = reshape(h.set.ItemsData, 1, [])
                choose(h.set, v{1});
                if isempty(v{1})
                    want = (1:n).';
                else
                    want = find(contains(strcat({' + '}, Rl.set, {' + '}), [' + ' v{1} ' + ']));
                end
                tc.verifyEqual(S.shownRows(), want, ['set ' v{1}]);
                tc.verifySubstring(h.count.Text, sprintf('%s of %s runs shown', cca.ui.fmt('count', numel(want)), ...
                    cca.ui.fmt('count', n)));
            end
            choose(h.set, '');
            for v = reshape(h.law.ItemsData, 1, [])
                choose(h.law, v{1});
                if isempty(v{1}), want = (1:n).'; else, want = find(strcmp(Rl.code, v{1})); end
                tc.verifyEqual(S.shownRows(), want, ['law ' v{1}]);
            end
            choose(h.law, '');
            for v = reshape(h.outcome.ItemsData, 1, [])
                choose(h.outcome, v{1});
                if isempty(v{1}), want = (1:n).'; else, want = find(strcmp(Rl.outcome, v{1})); end
                tc.verifyEqual(S.shownRows(), want, ['outcome ' v{1}]);
            end
            choose(h.outcome, '');
            if strcmp(h.traces.Visible, 'on')
                toggle(h.traces, true);
                tc.verifyEqual(S.shownRows(), find(~strcmp(Rl.trace, '-')));
                toggle(h.traces, false);
            end
            tc.verifyNumElements(S.shownRows(), n);
        end

        function runRowsAndCard(tc)
            % a click on a row fills the card with that row's fields
            A = tc.app;
            S = runReset(A);
            Rl = A.D.runlist;
            choose(S.handles.outcome, 'lost');
            shown = S.shownRows();
            for k = unique([1, 2, numel(shown)])
                clickRow(S.handles.table, k);
                Fc = S.cardFields();
                tc.verifyEqual(Fc{1, 2}, Rl.tag{shown(k)});
                tc.verifyEqual(cellstr(S.handles.card.Value), strcat(Fc(:, 1), {': '}, Fc(:, 2)));
                tc.verifyEqual(logical(S.handles.showTraces.Visible), ~strcmp(Rl.trace{shown(k)}, '-'));
            end
            choose(S.handles.outcome, '');
        end

        function runTracesControls(tc)
            % a run whose traces ship: Show its traces, every unit button, the slider, the play button, Back
            A = tc.app;
            S = runReset(A);
            Rl = A.D.runlist;
            i = find(~strcmp(Rl.trace, '-'), 1);
            tc.assumeNotEmpty(i, 'no run of this build ships its traces');
            S.selectRow(i);
            push(S.handles.showTraces);
            tc.verifyTrue(logical(S.handles.tracePane.Visible));
            tc.verifyFalse(logical(S.handles.listPane.Visible));
            ub = findall(S.handles.tracePane, 'Type', 'uistatebutton');
            cur = S.current();
            for b = reshape(ub, 1, [])
                u = sscanf(b.Text, 'Unit %d');
                toggle(b, ~b.Value);
                tc.verifyTrue(b.Value, b.Text);
                others = ub(ub ~= b);
                tc.verifyFalse(any([others.Value]), b.Text);
                tc.verifyTrue(ismember(u, cur.units), b.Text);
            end
            sl = S.handles.slider;
            t = mean(sl.Limits);
            slide(sl, t);
            cur = S.current();
            for q = 1:numel(cur.cursor)
                tc.verifyEqual(cur.cursor(q).Value, t, 'AbsTol', 1e-12);
            end
            tc.verifyEqual(A.state.TimeIndex, t, 'AbsTol', 1e-12);
            % the play button: the one push button over the traces whose label is a single symbol
            bp = findall(S.handles.tracePane, 'Type', 'uibutton');
            bPlay = bp(arrayfun(@(b) isscalar(b.Text) && double(b.Text) > 127, bp));
            tc.assertNumElements(bPlay, 1);
            push(bPlay);
            tc.verifyEqual(sl.Value, sl.Limits(2), 'AbsTol', 1e-9);
            tc.verifyEqual(A.state.TimeIndex, sl.Limits(2), 'AbsTol', 1e-9);
            push(S.handles.back);
            tc.verifyTrue(logical(S.handles.listPane.Visible));
            tc.verifyFalse(logical(S.handles.tracePane.Visible));
        end

        function runShowEveryRun(tc)
            % a scenario chosen on another screen narrows the list; Show every run clears it
            A = tc.app;
            runReset(A);
            Rl = A.D.runlist;
            key = A.D.grid.keys{1};
            A.state.set('Key', key, 'Code', 'v', 'Set', '');
            A.show("run");
            S = A.screens.run;
            tc.verifyEqual(S.shownRows(), find(strcmp(Rl.key, key)));
            tc.verifyTrue(logical(S.handles.all.Visible));
            push(S.handles.all);
            tc.verifyNumElements(S.shownRows(), numel(Rl.tag));
            tc.verifyEqual(A.state.Key, '');
            tc.verifyFalse(logical(S.handles.all.Visible));
        end

        function compareEvents(tc)
            % the events the grid's page posts: a tab, a cell's selection, the pinned card's link, the export
            A = tc.app;
            runReset(A);
            A.show("compare");
            S = A.screens.compare;
            side = S.side.Parent.Parent;
            for t = {'location', 'loadsteps', 'ablation', 'scenario'}
                post(S.html, 'tab', t{1});
                tc.verifyEqual(logical(side.Visible), strcmp(t{1}, 'scenario'), t{1});
            end
            key = A.D.grid.keys{3};
            post(S.html, 'select', key);
            tc.verifyEqual(A.state.Key, key);
            L = asArray(A.D.laws);
            code = L(2).code;
            set101 = cca.ui.runset(A.D, A.D.grid.keys);
            post(S.html, 'openRun', struct('key', key, 'code', code, 'set', set101));
            tc.verifyEqual(A.current, "run");
            tc.verifyEqual(A.state.Key, key);
            tc.verifyEqual(A.state.Code, code);
            tc.verifyEqual(A.state.Set, set101);
            R = A.screens.run;
            Rl = A.D.runlist;
            row = R.current().row;
            tc.verifyEqual(Rl.key{row}, key);
            tc.verifyEqual(Rl.code{row}, code);
            push(R.handles.all);
            A.show("compare");
            n0 = numel(A.log);
            post(S.html, 'export', 'all');
            tc.verifyNumElements(A.log, n0 + 1);
            tc.verifySubstring(A.log(end), 'Export the comparison table');
        end

        function scenariosControls(tc)
            % the three chips, a ring, a row of the table, Open in Run and Open in Compare
            A = tc.app;
            runReset(A);
            A.show("scenarios");
            S = A.screens.scenarios;
            G = A.D.grid;
            P = asArray(G.parsed);
            bus = [P.bus];
            cls = G.cls(:).';
            chips = findall(S.grid, 'Type', 'uistatebutton');
            tc.assertNumElements(chips, 3);
            lab = findall(S.grid, 'Type', 'uilabel');
            lab = lab(~cellfun(@isempty, regexp(ascii({lab.Text}), '^bus \d+: \d+ scenarios$', 'once')));
            tc.assertNumElements(lab, 1);
            isAll = startsWith({chips.Text}, 'All');
            for c = reshape(chips, 1, [])
                toggle(c, ~c.Value);
                tc.verifyTrue(c.Value, ascii(c.Text));
                tc.verifyFalse(any([chips(chips ~= c).Value]), ascii(c.Text));
                b = sscanf(lab.Text, 'bus %d');
                if startsWith(c.Text, 'All')
                    m = true(size(bus));
                else
                    lo = sscanf(c.Text, '%f');
                    dur = [P.dur_ms] / 1000;
                    which = unique(cls(abs(dur - lo(1)) < 1e-9));
                    m = strcmp(cls, which{1});
                end
                tc.verifyEqual(size(S.handles.table.Data, 1), nnz(bus == b & m), ascii(c.Text));
            end
            toggle(chips(isAll), true);
            % a ring and its bus label: each chooses its bus (the rings are drawn again at each choice, so each
            % is found again before its click)
            for kind = {'patch', 'text'}
                g = findall(S.handles.axes, 'Type', kind{1});
                g = g(~cellfun(@isempty, {g.ButtonDownFcn}));   % the rings and their labels, not the axes' titles
                tc.assertNotEmpty(g, kind{1});
                g = g(end);
                clickGraphic(g);
                b = sscanf(lab.Text, 'bus %d');
                tc.verifyTrue(ismember(b, bus), kind{1});
                tc.verifyEqual(size(S.handles.table.Data, 1), nnz(bus == b), kind{1});
            end
            b = sscanf(lab.Text, 'bus %d');
            keys = G.keys(bus == b);
            r = numel(keys);
            clickRow(S.handles.table, r);
            tc.verifyEqual(A.state.Key, keys{r});
            bRun = findall(S.grid, 'Type', 'uibutton', 'Text', 'Open in Run');
            bCmp = findall(S.grid, 'Type', 'uibutton', 'Text', 'Open in Compare');
            push(bRun);
            tc.verifyEqual(A.current, "run");
            tc.verifyEqual(A.state.Key, keys{r});
            tc.verifyEqual(A.state.Set, cca.ui.runset(A.D, G.keys));
            R = A.screens.run;
            tc.verifyEqual(R.shownRows(), find(strcmp(A.D.runlist.key, keys{r})));
            A.show("scenarios");
            push(bCmp);
            tc.verifyEqual(A.current, "compare");
            tc.verifyEqual(A.screens.compare.html.Data.sel, keys{r});
            push(R.handles.all);
        end

        function modelTreeWalkAndLaws(tc)
            % the tree's laws, the path above the picture, Back, Next, Fit and the drop-down Control shown
            A = tc.app;
            A.show("model");
            S = A.screens.model;
            h = S.handles;
            L = asArray(A.D.laws);
            nodes = findall(h.tree, 'Type', 'uitreenode');
            lawNodes = nodes(~cellfun(@isempty, {nodes.NodeData}));
            tc.verifyNumElements(lawNodes, numel(L));
            for nd = reshape(lawNodes, 1, [])
                before = S.law();
                clickNode(h.tree, nd);
                w = L(strcmp({L.code}, nd.NodeData));
                tc.verifyEqual(A.state.Code, w.code);
                tc.verifySubstring(h.card.Text, w.name);
                c = S.lawFor(w.code);
                if isempty(c)
                    tc.verifyEqual(S.law(), before, w.code);
                else
                    tc.verifyEqual(S.law(), c, w.code);
                    tc.verifyEqual(h.law.Value, c, w.code);
                end
            end
            % the drop-down: every law with pictures, its controller at level three, its blocks at level four, the
            % caption naming the law as the list of the paper's runs names it; a law of the tree selected there
            W = asArray(A.D.runinfo.laws);
            tc.verifyEqual(isempty(h.law.ValueChangedFcn), isempty(S.index.laws), ...
                'the drop-down acts exactly when the laws'' pictures exist');
            laws = {};
            if ~isempty(h.law.ValueChangedFcn)
                laws = reshape(h.law.ItemsData, 1, []);
                tc.verifyEqual(laws, {S.index.laws.code});
            end
            for v = laws
                choose(h.law, v{1});
                tc.verifyEqual(S.law(), v{1});
                S.go(3);
                tc.verifySubstring(char(h.pic.Children(1).ImageSource), sprintf('law_%s_controller', v{1}));
                m = W(strcmp({W.code}, v{1}));
                tc.assertNumElements(m, 1, v{1});
                tc.verifySubstring(h.caption.Text, m.law, v{1});
                own = [reshape(asArray(A.D.laws), [], 1); reshape(asArray(A.D.others), [], 1)];
                tc.verifySubstring(h.card.Text, own(find(strcmp({own.code}, v{1}), 1)).name, v{1});
                if S.levels() >= 4
                    S.go(4);
                    tc.verifySubstring(char(h.pic.Children(1).ImageSource), sprintf('law_%s_blocks', v{1}));
                    tc.verifySubstring(h.caption.Text, m.law, v{1});
                end
                if any(strcmp({L.code}, v{1}))
                    tc.verifyEqual(h.tree.SelectedNodes.NodeData, v{1});
                end
            end
            if ~isempty(laws)
                choose(h.law, laws{1});
            end
            % Back, Next and Fit as a click calls them; every link of the path opens its level
            S.go(1);
            nLv = S.levels();
            for k = 2:nLv
                push(h.next);
                tc.verifyEqual(S.level(), k);
            end
            tc.verifyFalse(logical(h.next.Enable));
            push(h.back);
            tc.verifyEqual(S.level(), nLv - 1);
            toggle(h.fit, false);
            tc.verifyEqual(S.level(), nLv - 1);
            toggle(h.fit, true);
            tc.verifyEqual(S.level(), nLv - 1);
            for k = 1:nLv
                S.go(k);
                links = findall(h.crumbs, 'Type', 'uihyperlink');
                tc.verifyNumElements(links, nLv - 1);
                qs = sort([links.UserData]);           % the levels the links open (the path is drawn again at
                tc.verifyEqual(qs, setdiff(1:nLv, k));  % each click, so each link is found again before its click)
                for q = qs
                    S.go(k);
                    links2 = findall(h.crumbs, 'Type', 'uihyperlink');
                    click(links2([links2.UserData] == q));
                    tc.verifyEqual(S.level(), q);
                end
            end
            S.go(1);
        end

        function provenanceSearch(tc)
            % the search field keeps the leaves whose path or value holds the text typed
            A = tc.app;
            A.show("provenance");
            S = A.screens.provenance;
            k = keys(A.D.leafmap);
            vals = cellfun(@(p) cca.data.safetext(A.D.leafmap(p)), k, 'UniformOutput', false);
            q = 'system.n_';
            typing(S.handles.search, q);
            tc.verifyEqual(size(S.handles.leaves.Data, 1), nnz(contains(lower(k), q) | contains(lower(vals), q)));
            tc.verifyGreaterThan(size(S.handles.leaves.Data, 1), 0);
            typing(S.handles.search, '');
            tc.verifyEqual(size(S.handles.leaves.Data, 1), numel(k));
        end

        function aboutCopyDry(tc)
            % in the Dry mode the button prints its statement instead of copying
            A = tc.app;
            A.show("about");
            S = A.screens.about;
            n0 = numel(A.log);
            push(S.handles.copy);
            tc.verifyNumElements(A.log, n0 + 1);
            tc.verifyEqual(A.log(end), "Copy the citation to the clipboard");
        end

        function helpButtons(tc)
            % a screen's button "How to read this screen" opens its page in place of the screen; a second press
            % closes it (screens that have the button)
            A = tc.app;
            for s = A.NAMES
                A.show(s);
                S = A.screens.(s);
                if ~isfield(S, 'help') || isempty(S.help) || isempty(S.help.button)
                    continue
                end
                b = S.help.button;
                push(b);
                tc.verifyTrue(S.help.isShown(), char(s));
                tc.verifyFalse(logical(S.frame.content.Visible), char(s));
                pg = S.help.page();
                tc.verifyNotEmpty(pg, char(s));
                C = S.help.content();
                tc.verifyEqual(pg.Data.title, C.title, char(s));
                push(b);
                tc.verifyFalse(S.help.isShown(), char(s));
                tc.verifyTrue(logical(S.frame.content.Visible), char(s));
            end
        end

        function everyControlHasItsTest(tc)
            % the window walked after every screen and every part that is built on demand (the numbers view, a
            % run's traces, every help page) has been opened: every component with a callback is matched by an
            % entry of the registry, every entry that is not optional matches a component, and every entry names
            % a test of this class
            A = tc.app;
            for s = A.NAMES
                A.show(s);
            end
            A.screens.reproduce.handles.showNumbers();
            R = A.screens.run;
            i = find(~strcmp(A.D.runlist.trace, '-'), 1);
            if ~isempty(i)
                R.selectRow(i);
                R.showTraces();
            end
            for s = A.NAMES
                S = A.screens.(s);
                if isfield(S, 'help') && ~isempty(S.help) && ~isempty(S.help.button)
                    S.help.show(true);
                end
            end
            found = controlKeys(tc.fig, A);
            reg = registry();
            ok = false(size(found));
            used = false(size(reg, 1), 1);
            for k = 1:numel(found)
                hit = cellfun(@(p) ~isempty(regexp(found{k}, ['^' p '$'], 'once')), reg(:, 1));
                ok(k) = any(hit);
                used = used | hit;
            end
            tc.verifyEmpty(found(~ok), ['controls without a test: ' strjoin(found(~ok), newline)]);
            stale = reshape(reg(~used & ~[reg{:, 3}].', 1), 1, []);
            tc.verifyEmpty(stale, ['registry entries that match no control: ' strjoin(stale, newline)]);
            ts = matlab.unittest.TestSuite.fromClass(?tControls);
            tc.verifyEmpty(setdiff(unique(reg(:, 2)), {ts.ProcedureName}), 'registry entries that name no test');
            for s = A.NAMES
                S = A.screens.(s);
                if isfield(S, 'help') && ~isempty(S.help) && ~isempty(S.help.button)
                    S.help.show(false);
                end
            end
            push(R.handles.back);
            A.show("overview");
        end
    end
end

% ===================================================================================================== the registry
function reg = registry()
% every kind of control: the pattern of its key (screen|class|label|callback property), the test that presses it,
% and whether it may be absent from a build (true: a control that a screen builds in some states and not in others)
reg = {
    'shell\|HTML\|rail\.html\|HTMLEventReceivedFcn', 'railAndTopBar', false
    'shell\|HTML\|topbar\.html\|HTMLEventReceivedFcn', 'railAndTopBar', false
    'overview\|Hyperlink\|See one fault in Run ~\|HyperlinkClickedFcn', 'overviewLinks', false
    'overview\|Hyperlink\|Open the law in Model ~\|HyperlinkClickedFcn', 'overviewLinks', false
    'overview\|Hyperlink\|Read the equations ~\|HyperlinkClickedFcn', 'overviewLinks', false
    'overview\|Hyperlink\|Open Compare ~\|HyperlinkClickedFcn', 'overviewLinks', false
    'reproduce\|Image\|card\|ImageClickedFcn', 'reproduceCards', false
    'reproduce\|Button\|(Figure|Table|Numbers)\|ButtonPushedFcn', 'reproduceCards', false
    'reproduce\|Button\|~ Back to the gallery\|ButtonPushedFcn', 'reproduceCards', false
    'reproduce\|Button\|Regenerate the application''s data\|ButtonPushedFcn', 'reproduceRegenerateDry', false
    'reproduce\|EditField\|Search by place, name or printed value\|Value(Changing|Changed)Fcn', ...
    'reproduceNumbersSearch', false
    'run\|DropDown\|All sets\|ValueChangedFcn', 'runFilters', false
    'run\|DropDown\|All laws and parts\|ValueChangedFcn', 'runFilters', false
    'run\|DropDown\|All outcomes\|ValueChangedFcn', 'runFilters', false
    'run\|CheckBox\|Runs with recorded traces\|ValueChangedFcn', 'runFilters', false
    'run\|Button\|Show every run\|ButtonPushedFcn', 'runShowEveryRun', false
    'run\|Table\|Set\|SelectionChangedFcn', 'runRowsAndCard', false
    'run\|Button\|Show its traces\|ButtonPushedFcn', 'runTracesControls', false
    'run\|Button\|~ Back to the list\|ButtonPushedFcn', 'runTracesControls', false
    'run\|StateButton\|Unit \d+\|ValueChangedFcn', 'runTracesControls', true
    'run\|Button\|~\|ButtonPushedFcn', 'runTracesControls', false
    'run\|Slider\|slider\|Value(Changing|Changed)Fcn', 'runTracesControls', false
    'compare\|HTML\|cgrid\.html\|HTMLEventReceivedFcn', 'compareEvents', false
    'scenarios\|StateButton\|(All \. \d+|[\d.]+ to [\d.]+ s)\|ValueChangedFcn', 'scenariosControls', false
    'scenarios\|Patch\|ring\|ButtonDownFcn', 'scenariosControls', false
    'scenarios\|Text\|bus label\|ButtonDownFcn', 'scenariosControls', false
    'scenarios\|Table\|Scenario\|SelectionChangedFcn', 'scenariosControls', false
    'scenarios\|Button\|Open in (Run|Compare)\|ButtonPushedFcn', 'scenariosControls', false
    'model\|Tree\|tree\|SelectionChangedFcn', 'modelTreeWalkAndLaws', false
    'model\|DropDown\|.+\|ValueChangedFcn', 'modelTreeWalkAndLaws', true
    'model\|Hyperlink\|.+\|HyperlinkClickedFcn', 'modelTreeWalkAndLaws', false
    'model\|Button\|~ Back\|ButtonPushedFcn', 'modelTreeWalkAndLaws', false
    'model\|Button\|Next ~\|ButtonPushedFcn', 'modelTreeWalkAndLaws', false
    'model\|StateButton\|Fit\|ValueChangedFcn', 'modelTreeWalkAndLaws', false
    'provenance\|EditField\|Search a number or a leaf path\|Value(Changing|Changed)Fcn', 'provenanceSearch', false
    'about\|Button\|Copy citation\|ButtonPushedFcn', 'aboutCopyDry', false
    '[a-z]+\|Button\|(How to read this screen|~ Back to the screen)\|ButtonPushedFcn', 'helpButtons', true
    };
end

function keysOut = controlKeys(fig, A)
% the key of every callback of every component of the window: screen|class|label|property; MATLAB's own axes
% toolbars and the figure itself left out
objs = findall(fig);
keysOut = {};
for i = 1:numel(objs)
    h = objs(i);
    c = class(h);
    if h == fig || startsWith(c, 'matlab.ui.controls.') || contains(c, '.internal.') || ...
            ~(startsWith(c, 'matlab.ui.') || startsWith(c, 'matlab.graphics.'))
        continue
    end
    pr = properties(h);
    pr = pr(endsWith(pr, 'Fcn') | endsWith(pr, 'Callback'));
    pr = setdiff(pr, {'CreateFcn', 'DeleteFcn'});
    for q = 1:numel(pr)
        v = h.(pr{q});
        if isempty(v) || (ischar(v) && isempty(strtrim(v)))
            continue
        end
        keysOut{end + 1} = sprintf('%s|%s|%s|%s', screenOf(h, A), shortClass(c), labelOf(h), pr{q}); %#ok<AGROW>
    end
end
keysOut = unique(keysOut);
end

function s = screenOf(h, A)
% the screen whose frame holds the component, or the shell (the top bar and the rail)
s = 'shell';
f = fieldnames(A.screens);
p = h;
while ~isempty(p) && isprop(p, 'Parent')
    for k = 1:numel(f)
        if p == A.screens.(f{k}).frame.grid
            s = f{k};
            return
        end
    end
    p = p.Parent;
end
end

function c = shortClass(c)
c = c(find(c == '.', 1, 'last') + 1:end);
end

function t = labelOf(h)
% the words that name the component on the screen
c = shortClass(class(h));
switch c
    case {'Button', 'StateButton', 'CheckBox', 'Hyperlink'}
        t = h.Text;
    case 'DropDown'
        t = h.Items{1};
    case 'EditField'
        t = h.Placeholder;
    case 'HTML'
        [~, n, e] = fileparts(h.HTMLSource);
        t = [n e];
    case 'Table'
        t = h.ColumnName{1};
    case 'Tree'
        t = 'tree';
    case 'Image'
        t = 'card';
    case 'Slider'
        t = 'slider';
    case 'Patch'
        t = 'ring';
    case 'Text'
        t = 'bus label';
    otherwise
        t = '';
end
t = ascii(t);
end

function t = ascii(t)
% the label with every character outside printable ASCII shown as a tilde (the arrows of Back and Next)
if iscell(t)
    t = cellfun(@ascii, t, 'UniformOutput', false);
    return
end
t = regexprep(char(t), '[^\x20-\x7E]', '~');
end

% ============================================================================ the presses, as a click calls them
function push(b)
fire(b, 'ButtonPushedFcn', struct('Source', b, 'EventName', 'ButtonPushed'));
end

function toggle(b, v)
old = b.Value;
b.Value = v;
fire(b, 'ValueChangedFcn', struct('Value', v, 'PreviousValue', old, 'Source', b, 'EventName', 'ValueChanged'));
end

function choose(dd, v)
old = dd.Value;
dd.Value = v;
fire(dd, 'ValueChangedFcn', struct('Value', v, 'PreviousValue', old, 'Source', dd, 'EventName', 'ValueChanged'));
end

function typing(ef, txt)
% the text typed into the field: its changing callback with the text (where the field has one), then the value set
% and its changed callback (where it has one); a field with neither fails
assert(~isempty(ef.ValueChangingFcn) || ~isempty(ef.ValueChangedFcn), 'tControls:noCallback', ...
    'the field has no callback');
if ~isempty(ef.ValueChangingFcn)
    fire(ef, 'ValueChangingFcn', struct('Value', txt, 'Source', ef, 'EventName', 'ValueChanging'));
end
settle(ef, txt);
end

function settle(ef, txt)
old = ef.Value;
ef.Value = txt;
if ~isempty(ef.ValueChangedFcn)
    fire(ef, 'ValueChangedFcn', struct('Value', txt, 'PreviousValue', old, 'Source', ef, 'EventName', ...
        'ValueChanged'));
end
end

function slide(sl, t)
fire(sl, 'ValueChangingFcn', struct('Value', t, 'Source', sl, 'EventName', 'ValueChanging'));
old = sl.Value;
sl.Value = t;
fire(sl, 'ValueChangedFcn', struct('Value', t, 'PreviousValue', old, 'Source', sl, 'EventName', 'ValueChanged'));
end

function clickRow(tbl, k)
old = tbl.Selection;
tbl.Selection = k;
fire(tbl, 'SelectionChangedFcn', struct('Selection', k, 'PreviousSelection', old, 'Source', tbl, ...
    'EventName', 'SelectionChanged'));
end

function clickNode(tr, nd)
old = tr.SelectedNodes;
tr.SelectedNodes = nd;
fire(tr, 'SelectionChangedFcn', struct('SelectedNodes', nd, 'PreviousSelectedNodes', old, 'Source', tr, ...
    'EventName', 'SelectionChanged'));
end

function click(h)
fire(h, 'HyperlinkClickedFcn', struct('Source', h, 'EventName', 'HyperlinkClicked'));
end

function clickImage(im)
fire(im, 'ImageClickedFcn', struct('Source', im, 'EventName', 'ImageClicked'));
end

function clickGraphic(g)
fire(g, 'ButtonDownFcn', struct('Source', g, 'EventName', 'Hit', 'Button', 1));
end

function post(h, name, data)
% an event that a page of the window posts to MATLAB (sendEventToMATLAB)
fire(h, 'HTMLEventReceivedFcn', struct('HTMLEventName', name, 'HTMLEventData', data, 'Source', h, ...
    'EventName', 'HTMLEventReceived'));
end

function fire(h, prop, evt)
% a callback as MATLAB calls it: a function handle with the component and the event, or a cell {fn, args...}
f = h.(prop);
assert(~isempty(f), 'tControls:noCallback', 'the %s has no %s', class(h), prop);
if iscell(f)
    f{1}(h, evt, f{2:end});
else
    f(h, evt);
end
drawnow;
end

function S = runReset(A)
% the Run screen as a reader finds it first: no scenario chosen elsewhere, every filter off, the list shown
A.state.set('Key', '', 'Code', 'v', 'Set', '', 'View', '');
A.show("run");
S = A.screens.run;
push(S.handles.all);
h = S.handles;
for dd = [h.set, h.law, h.outcome]
    if ~isempty(dd.Value)
        choose(dd, '');
    end
end
if h.traces.Value
    toggle(h.traces, false);
end
if strcmp(h.tracePane.Visible, 'on')
    push(h.back);
end
end

function X = asArray(X)
if iscell(X), X = [X{:}]; end
end

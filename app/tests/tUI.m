classdef tUI < matlab.unittest.TestCase
    %TUI  The application's window tests (Dry mode): the shell and its navigation, the Run screen's list of the
    %   paper's runs (its filters, its count line, the run's card, the traces and their cursor), the Compare grid's
    %   link to Run, the Model walk, Reproduce's tables and numbers. Needs a display (or a batch MATLAB that renders
    %   uifigures). Run from the app folder: results = runtests('tests/tUI.m')
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
        function shellSizeAndPill(tc)
            tc.verifyEqual(tc.fig.Position(3:4), [1440 900]);
            d = tc.app.topbar.Data;
            tc.verifySubstring(d.pill, tc.app.D.record.sha256_8);
            tc.verifySubstring(d.pill, tc.app.D.record.group);
        end

        function railShowsEveryScreen(tc)
            for s = tc.app.NAMES
                tc.app.onHtml(struct('HTMLEventName', 'nav', 'HTMLEventData', char(s)));
                tc.verifyEqual(tc.app.current, s);
                tc.verifyEqual(tc.app.rail.Data.active, char(s));
                tc.verifyTrue(logical(tc.app.screens.(s).frame.grid.Visible));
            end
        end

        function compareOpensRun(tc)
            % a cell of Compare opens its scenario's runs in the Run list, the selected control's run selected
            tc.app.show("compare");
            S = tc.app.screens.compare;
            G = tc.app.D.grid;
            key = G.keys{end};
            tc.app.state.Code = 'v';
            S.html.HTMLEventReceivedFcn(S.html, struct('HTMLEventName', 'openRun', 'HTMLEventData', key));
            tc.verifyEqual(tc.app.current, "run");
            tc.verifyEqual(tc.app.state.Key, key);
            R = tc.app.screens.run;
            Rl = tc.app.D.runlist;
            shown = R.shownRows();
            tc.verifyEqual(shown, find(strcmp(Rl.key, key)));
            sel = shown(R.handles.table.Selection(1));
            tc.verifyEqual(Rl.key{sel}, key);
            tc.verifyEqual(Rl.code{sel}, 'v');
            R.handles.all.ButtonPushedFcn(R.handles.all, []);
            tc.verifyNumElements(R.shownRows(), numel(Rl.tag));
        end

        function runListEveryRow(tc)
            % the Run screen lists every row of the campaign table; the filters by set, by law and by outcome keep
            % exactly the rows that the data say; the count line is computed from the rows shown
            tc.app.show("run");
            S = tc.app.screens.run;
            Rl = tc.app.D.runlist;
            I = tc.app.D.runinfo;
            n = numel(Rl.tag);
            tc.verifyEqual(n, I.n_rows);
            S.handles.set.Value = '';
            S.handles.law.Value = '';
            S.handles.outcome.Value = '';
            S.refilter();
            tc.verifyEqual(size(S.handles.table.Data, 1), n);
            tc.verifySubstring(S.handles.count.Text, sprintf('%s of %s runs shown', cca.ui.fmt('count', n), ...
                cca.ui.fmt('count', n)));
            SETS = I.sets;
            if iscell(SETS), SETS = [SETS{:}]; end
            for k = 1:numel(SETS)
                S.handles.set.Value = SETS(k).name;
                S.refilter();
                own = cellfun(@(s) any(strcmp(strtrim(strsplit(s, ' + ')), SETS(k).name)), Rl.set);
                tc.verifyEqual(S.shownRows(), find(own), SETS(k).name);
                tc.verifyEqual(nnz(own), SETS(k).rows, SETS(k).name);
            end
            % with a set and a law chosen, the count line gives the rows shown and the scenarios that the paper counts
            % among them in that set (the rows whose counts_in names the set): both counted from the rows
            LAWS = I.laws;
            if iscell(LAWS), LAWS = [LAWS{:}]; end
            S.handles.set.Value = SETS(1).name;
            S.handles.law.Value = LAWS(1).code;
            S.refilter();
            mine = strcmp(Rl.code, LAWS(1).code) & ...
                contains(strcat({' + '}, Rl.set, {' + '}), [' + ' SETS(1).name ' + ']);
            counted = mine & contains(strcat({' + '}, Rl.counts_in, {' + '}), [' + ' SETS(1).name ' + ']);
            tc.verifyEqual(S.shownRows(), find(mine));
            tc.verifySubstring(S.handles.count.Text, sprintf('%s of %s runs shown; the paper counts %s of them', ...
                cca.ui.fmt('count', nnz(mine)), cca.ui.fmt('count', n), cca.ui.fmt('count', nnz(counted))));
            S.handles.set.Value = '';
            S.handles.law.Value = LAWS(1).code;
            OUT = I.outcomes;
            if iscell(OUT), OUT = [OUT{:}]; end
            S.handles.outcome.Value = OUT(1).word;
            S.refilter();
            tc.verifyEqual(S.shownRows(), find(strcmp(Rl.code, LAWS(1).code) & strcmp(Rl.outcome, OUT(1).word)));
            S.handles.law.Value = '';
            S.handles.outcome.Value = '';
            S.refilter();
        end

        function runCardEveryField(tc)
            % the selected run's card holds every field of its row, the paper's place among them
            tc.app.show("run");
            S = tc.app.screens.run;
            Rl = tc.app.D.runlist;
            i = find(~strcmp(Rl.place, '-'), 1);
            S.selectRow(i);
            Fc = S.cardFields();
            V = Fc(:, 2);
            tc.verifyEqual(cellstr(S.handles.card.Value), strcat(Fc(:, 1), {': '}, Fc(:, 2)));
            want = {Rl.tag{i}; Rl.set{i}; Rl.law{i}; Rl.setting{i}; Rl.fault_bus{i}; Rl.fault_kind{i}; ...
                Rl.fault_ms{i}; Rl.fault_r_pu{i}; Rl.event{i}; Rl.load{i}; Rl.network{i}; Rl.key{i}; ...
                Rl.outcome{i}; Rl.detail{i}; Rl.counts_in{i}; Rl.place{i}; Rl.trace{i}; Rl.args_sha256{i}};
            tc.verifyEqual(V, want);
        end

        function runNoControlWithoutTheHandler(tc)
            % started by ccapp alone, the Run screen holds no control that starts a run
            tc.app.show("run");
            S = tc.app.screens.run;
            tc.verifyEmpty(S.handles.runButton);
            b = findall(S.grid, 'Type', 'uibutton');
            tc.verifyFalse(any(contains(string({b.Text}), 'model', 'IgnoreCase', true)));
        end

        function compareAblationTab(tc)
            tc.app.show("compare");
            S = tc.app.screens.compare;
            S.setTab('ablation');
            tc.verifyEqual(S.html.Data.tab, 'ablation');
            A = S.html.Data.abl.cols;
            tc.verifyEqual({A.code}, {'v', 'u1', 'f', 'z', 'c', 'e', 'n'});
            S.setTab('location');
            Lc = S.html.Data.lad.cols;
            tc.verifyEqual({Lc.code}, tc.app.D.grid.ladder.cols(:).');
            tc.verifyEqual(numel(S.html.Data.lad.rows), numel(tc.app.D.grid.ladder.keys));
            tc.verifyTrue(all([S.html.Data.lad.rows.open]));   % every ladder cell opens its run in the Run list
            % the ladder's note: the counts on the two families of rule R145 from the leaves; the runs' words
            for p = ["s60r.v6.r17.q1.twelve.others_range_print", "s60r.v6.r17.q2.twelve.eleven_others.range_print"]
                tc.verifySubstring(S.html.Data.lad.note, cca.data.leaf(tc.app.D, char(p)));
            end
            tc.verifyEqual(numel(S.html.Data.lad.detail), numel(tc.app.D.grid.ladder.keys));
            % the decisive faults of the paper: marked on their rows (s60r.v6.r17.d1), named in the note by the
            % record's word and the paper's own section label
            R = S.html.Data.lad.rows;
            tc.verifyEqual(~cellfun(@isempty, {R.mark}), logical(tc.app.D.grid.ladder.marks(:).'));
            tc.verifyEqual(nnz(~cellfun(@isempty, {R.mark})), cca.data.leaf(tc.app.D, 's60r.v6.r17.d1.n'));
            tc.verifySubstring(S.html.Data.lad.note, ['Marked: the ' cca.data.leaf(tc.app.D, 's60r.v6.r17.d1.n_word')]);
            tc.verifyFalse(contains(S.html.Data.lad.note, 'not in the record'));
            G = S.html.Data.lad.groups;
            tc.verifyTrue(all(startsWith({G.sub}, 'through ')));
            S.setTab('loadsteps');
            tc.verifyEqual(S.html.Data.tab, 'loadsteps');
            Sc = S.html.Data.ls.cols;
            tc.verifyEqual({Sc.code}, tc.app.D.grid.loadsteps.cols(:).');
            tc.verifyEqual(numel(S.html.Data.ls.rows), numel(tc.app.D.grid.loadsteps.events));
            % the smaller step's test (the author's word R144): passed, then every bus's details from the leaves
            lsTxt = strjoin(cellstr(S.html.Data.ls.test), ' ');
            tc.verifySubstring(lsTxt, 'passes the test fixed before the runs at all');
            for b = reshape(cca.data.leaf(tc.app.D, 's60r.v6.r17.vf.buses'), 1, [])
                for f = ["cap_longest_bind_print_3", "df_max_print_3", "law_T_RET_s"]
                    tc.verifySubstring(lsTxt, cca.data.leaf(tc.app.D, ...
                        char(sprintf('s60r.v6.r17.vf.per_bus.%d.%s', b, f))));
                end
            end
            tc.verifySubstring(strjoin(cellstr(S.r4note.String), ' '), ...
                sprintf('returns on all %d at both settings', cca.data.leaf(tc.app.D, 's60r.v6.r16.r4.published.of')));
            S.setTab('scenario');
        end

        function runCursorMovesTogether(tc)
            % a run whose traces ship (the list's trace field): its traces open, and one cursor moves every panel,
            % the dial and the power point together; where no trace ships, no trace control shows
            tc.app.show("run");
            S = tc.app.screens.run;
            Rl = tc.app.D.runlist;
            i = find(~strcmp(Rl.trace, '-'), 1);
            if isempty(i)
                tc.verifyFalse(logical(S.handles.traces.Visible));
                tc.verifyFalse(logical(S.handles.showTraces.Visible));
                return
            end
            S.selectRow(i);
            tc.verifyTrue(logical(S.handles.showTraces.Visible));
            S.showTraces();
            tc.verifyTrue(logical(S.handles.tracePane.Visible));
            S.moveCursor(-0.5);
            cur = S.current();
            tc.verifyNotEmpty(cur.R);
            for q = 1:numel(cur.cursor)
                tc.verifyEqual(cur.cursor(q).Value, -0.5);
            end
            tc.verifyEqual(tc.app.state.TimeIndex, -0.5);
            S.handles.back.ButtonPushedFcn(S.handles.back, []);
            tc.verifyTrue(logical(S.handles.listPane.Visible));
            % every run file of the index belongs to a row of the list
            runs = tc.app.D.runs;
            if iscell(runs), runs = [runs{:}]; end
            tc.verifyTrue(all(ismember(strcat('runs/', {runs.file}), Rl.trace)));
        end

        function modelWalk(tc)
            tc.app.show("model");
            S = tc.app.screens.model;
            S.go(1);
            tc.verifyEqual(S.level(), 1);
            tc.verifyFalse(logical(S.handles.back.Enable));
            S.go(99);
            tc.verifyFalse(logical(S.handles.next.Enable));
            % the network level: fitted, the display copy; at full size, the print itself
            S.go(1);
            tc.verifyTrue(endsWith(string(S.handles.pic.Children(1).ImageSource), "level1_network_view.png"));
            S.handles.fit.Value = false;
            S.go(1);
            tc.verifyTrue(endsWith(string(S.handles.pic.Children(1).ImageSource), "level1_network.png"));
            S.handles.fit.Value = true;
            S.go(1);
        end

        function modelButtons(tc)
            % the buttons as a click calls them: Next walks every level, Back returns one, Fit keeps the level
            tc.app.show("model");
            S = tc.app.screens.model;
            S.go(1);
            b = S.handles;
            for k = 2:4
                b.next.ButtonPushedFcn(b.next, []);
                tc.verifyEqual(S.level(), k);
            end
            b.back.ButtonPushedFcn(b.back, []);
            tc.verifyEqual(S.level(), 3);
            b.fit.Value = false;
            b.fit.ValueChangedFcn(b.fit, struct('Value', false));
            tc.verifyEqual(S.level(), 3);
            b.fit.Value = true;
            b.fit.ValueChangedFcn(b.fit, struct('Value', true));
            tc.verifyEqual(S.level(), 3);
            S.go(1);
        end

        function reproduceTables(tc)
            % every table of the paper shows every cell as the paper prints it, the bold cells bold and the spanning
            % heads where the data hold them; Table IV lists its scenarios
            tc.app.show("reproduce");
            S = tc.app.screens.reproduce;
            X = tc.app.D.paper.tables;
            if iscell(X), X = [X{:}]; end
            esc = @(x) strrep(strrep(strrep(char(x), '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
            for i = 1:numel(X)
                S.handles.showTable(i);
                t = S.handles.shownTable();
                tc.verifyClass(t.html, 'matlab.ui.control.HTML');
                tc.verifyEqual(size(t.cells, 1), numel(X(i).cells), X(i).number);
                src = char(t.html.HTMLSource);
                for c = reshape(t.cells(~cellfun(@isempty, t.cells)), 1, [])
                    tc.verifySubstring(src, esc(c{1}), X(i).number);
                end
                % the bold cells: as many as the paper's flags (the spanning heads drawn bold beside them)
                tc.verifyEqual(numel(strfind(src, 'class="b"')), nnz(t.bold), X(i).number);
                tc.verifyEqual(numel(strfind(src, 'class="span"')), size(t.heads, 1), X(i).number);
                if strcmp(X(i).key, 'cc_tab_rob')
                    v = string(S.handles.caption.Value);
                    tc.verifyEqual(sum(endsWith(v, ["; eligible", "; not eligible"])), ...
                        double(tc.app.D.grid.robust.n));
                end
            end
        end

        function reproduceNumbers(tc)
            % the numbers view lists every printed number of the paper (app_printed.json), and its search keeps
            % exactly the rows that hold the text
            tc.app.show("reproduce");
            S = tc.app.screens.reproduce;
            S.handles.showNumbers();
            P = tc.app.D.printed;
            if iscell(P), P = [P{:}]; end
            ng = S.handles.host.Children(1);
            tb = findobj(ng, 'Type', 'uitable');
            ef = findobj(ng, 'Type', 'uieditfield');
            tc.verifyEqual(size(tb.Data, 1), numel(P));
            tc.verifyEqual(tb.Data(:, 2), reshape({P.printed}, [], 1));
            ef.Value = 'Table III';
            ef.ValueChangedFcn(ef, struct('Value', ef.Value));
            hit = @(c) contains(c, 'Table III', 'IgnoreCase', true);
            tc.verifyEqual(size(tb.Data, 1), sum(hit({P.place}) | hit({P.name}) | hit({P.printed})));
            tc.verifyGreaterThan(size(tb.Data, 1), 0);
        end
    end
end

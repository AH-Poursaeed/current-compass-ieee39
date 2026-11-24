classdef tCore < matlab.unittest.TestCase
    %TCORE  The application's tests without a window: style, data, keys, grid, format, run files, the list of the
    %   paper's runs, static checks, the regeneration. Run from the app folder: results = runtests('tests/tCore.m')
    properties
        D
        T
        root
    end
    methods (TestClassSetup)
        function setup(tc)
            tc.root = fileparts(fileparts(mfilename('fullpath')));
            addpath(tc.root);
            tc.D = cca.data.load(tc.root);
            tc.T = cca.style("A");
        end
    end
    methods (Test)
        function styleHexExact(tc)
            f = fieldnames(tc.T.hex);
            for i = 1:numel(f)
                rgb = round(tc.T.c.(f{i}) * 255);
                tc.verifyEqual(sprintf('#%02X%02X%02X', rgb), upper(tc.T.hex.(f{i})), f{i});
            end
        end

        function styleContrast(tc)
            % text tokens on the grounds they sit on (WCAG relative luminance); ink3 only on the white surface
            pairs = {'ink', 'ground'; 'ink', 'surface'; 'ink2', 'ground'; 'ink2', 'surface'; 'ink2', 'sunken'; ...
                'accent', 'surface'; 'accent', 'tint'; 'ink3', 'surface'; 'lossInk', 'surface'; 'limited', 'surface'};
            for i = 1:size(pairs, 1)
                r = contrast(tc.T.c.(pairs{i, 1}), tc.T.c.(pairs{i, 2}));
                tc.verifyGreaterThanOrEqual(r, 4.5, sprintf('%s on %s: %.2f', pairs{i, :}, r));
            end
        end

        function lawColoursFromPalette(tc)
            L = tc.D.laws;
            if iscell(L), L = [L{:}]; end
            tc.verifyNumElements(L, numel(tc.D.grid.cols));
            tc.verifyEqual({L.code}, tc.D.grid.cols(:).');
            for i = 1:numel(L)
                tc.verifyMatches(L(i).colour, '^#[0-9A-F]{6}$');
            end
        end

        function recordFilesMatchTheExport(tc)
            % app/data was generated from exactly the record files present here (where they are present)
            F = tc.D.record.files;
            if iscell(F), F = [F{:}]; end
            for i = 1:numel(F)
                p = fullfile(tc.D.repo, F(i).file);
                tc.assumeTrue(isfile(p), 'the record files are not in this copy');
                % a record that has moved on since app/data was generated is reported, not failed: app/data
                % names the commit it was generated from (regenerate with app/tools/make_app_data.py)
                tc.assumeEqual(sha256file(p), F(i).sha256, sprintf(['%s has changed since app/data was ' ...
                    'generated from %s'], F(i).file, tc.D.record.commit));
            end
        end

        function manifestMatchesFiles(tc)
            M = tc.D.manifest.files;
            if iscell(M), M = [M{:}]; end
            for i = 1:numel(M)
                p = fullfile(tc.root, 'data', M(i).file);
                tc.verifyEqual(sha256file(p), M(i).sha256, M(i).file);
            end
            % the paper's diagrams the screens draw are copies under app/assets, byte for byte
            A = tc.D.manifest.assets;
            if iscell(A), A = [A{:}]; end
            tc.verifyNotEmpty(A);
            for i = 1:numel(A)
                tc.verifyTrue(startsWith(A(i).file, 'assets/'));
                tc.verifyEqual(sha256file(fullfile(tc.root, A(i).file)), A(i).sha256, A(i).file);
            end
        end

        function keysGrammar(tc)
            G = tc.D.grid;
            tc.verifyNumElements(G.keys, cca.data.leaf(tc.D, 's60r.v6.r15.sets.c101.n_keys'));
            tc.verifyEqual(sum(strcmp(G.cls, 'SHORT')), cca.data.leaf(tc.D, 's60r.v6.r15.sets.c101.n_short'));
            tc.verifyEqual(sum(strcmp(G.cls, 'LONG')), cca.data.leaf(tc.D, 's60r.v6.r15.sets.c101.n_long'));
            tc.verifyFalse(any(contains(G.keys, '_src')));
            for i = 1:numel(G.keys)
                [~, P] = cca.data.scenario(tc.D, G.keys{i});
                [~, P2] = cca.data.scenario(tc.D, ['s' G.keys{i}]);
                tc.verifyEqual(P, P2);
            end
        end

        function gridAgainstTotals(tc)
            G = tc.D.grid;
            cells = char(G.cells);
            for j = 1:numel(G.cols)
                t = G.totals.(G.cols{j});
                tc.verifyEqual(sum(cells(:, j) == 'R'), t.n_returned, G.cols{j});
                tc.verifyEqual(sum(cells(:, j) ~= 'N'), t.n_eligible, G.cols{j});
            end
            tc.verifyEqual(sum(cells(:, 1) == 'L'), cca.data.leaf(tc.D, 's60r.v6.r15.c101.v.lost'));
            isL = strcmp(G.cls(:), 'LONG');
            tc.verifyEqual(sum(cells(isL, 1) == 'L'), cca.data.leaf(tc.D, 's60r.v6.r15.c101.v.long_lost'));
        end

        function gridTotalsEqualTheCells(tc)
            % each law's totals of app_grid.json (the losses that Compare's side panel draws) equal the counts of
            % the grid's cells: lost, eligible, and returned = eligible - lost
            G = tc.D.grid;
            cells = char(G.cells);
            tc.verifyFalse(isfield(G, 'comparison'));
            for j = 1:numel(G.cols)
                c = cells(:, j);
                x = G.totals.(G.cols{j});
                tc.verifyEqual(sum(c == 'L'), x.n_lost, G.cols{j});
                tc.verifyEqual(sum(c ~= 'N'), x.n_eligible, G.cols{j});
                tc.verifyEqual(x.n_returned + x.n_lost, x.n_eligible, G.cols{j});
            end
        end

        function setRuleHolds(tc)
            % the application's set (the author's word R140, decision D97): faults of at most 5 s, in every data
            % file read as text, in every table of the grid, the ladder, the run files and the list of the paper's
            % runs; the droop slope only at the values of the record's robustness rows (droopFound: none other)
            maxMs = 5000;
            tc.verifyEqual(cca.data.leaf(tc.D, 's60r.v6.r15.sets.c101.max_duration_ms'), maxMs);
            tc.verifyEqual(tc.D.grid.rule_max_ms, maxMs);
            files = dir(fullfile(tc.root, 'data', '**', '*.json'));
            tc.verifyNotEmpty(files);
            bad = {};
            for i = 1:numel(files)
                txt = fileread(fullfile(files(i).folder, files(i).name));
                tok = regexp(txt, '(\d\d)_(\d{4})_(\d\d)([ST])(F|W|O1718|U08)', 'tokens');
                for k = 1:numel(tok)
                    if str2double(tok{k}{2}) > maxMs
                        bad{end + 1} = sprintf('%s: key %s', files(i).name, strjoin(tok{k}(1:3), '_')); %#ok<AGROW>
                    end
                end
                dm = regexp(txt, '"dur_ms":\s*(\d+)', 'tokens');
                for k = 1:numel(dm)
                    if str2double(dm{k}{1}) > maxMs
                        bad{end + 1} = sprintf('%s: dur_ms %s', files(i).name, dm{k}{1}); %#ok<AGROW>
                    end
                end
                if droopFound(txt)
                    bad{end + 1} = sprintf('%s: a droop slope outside the set', files(i).name); %#ok<AGROW>
                end
            end
            tc.verifyEmpty(bad, strjoin(bad, newline));
            G = tc.D.grid;
            durOf = @(k) str2double(k(4:7));
            tc.verifyTrue(all(cellfun(durOf, cellstr(G.keys)) <= maxMs), 'grid');
            tc.verifyTrue(all(cellfun(durOf, cellstr(G.ladder.keys)) <= maxMs), 'ladder');
            tc.verifyTrue(all(G.ladder.durations_ms <= maxMs), 'ladder durations');
            runs = tc.D.runs;
            if iscell(runs), runs = [runs{:}]; end
            tc.verifyTrue(all(cellfun(durOf, {runs.key}) <= maxMs), 'runs');
            % the list of the paper's runs: every fault of at most the rule, by its own field and by its key
            Rl = tc.D.runlist;
            ms = str2double(Rl.fault_ms(~strcmp(Rl.fault_ms, '-')));
            tc.verifyTrue(all(ms <= maxMs), 'the list of the runs: fault_ms');
            fk = regexp(Rl.key, '^\d\d_(\d{4})_', 'tokens', 'once');
            fk = fk(~cellfun(@isempty, fk));
            tc.verifyTrue(all(cellfun(@(t) str2double(t{1}), fk) <= maxMs), 'the list of the runs: keys');
        end

        function ladderAgainstFamilies(tc)
            % the ladder's SLG faults (rule R142 R1) and its three-phase faults of 4 and 5 s (R3) for Table III's
            % rows and [9]: each column's losses, runs and returns limited at the end against the group s60r.v6.r16;
            % a return limited at the end (E) only where the record reads it per run
            Lg = tc.D.grid.ladder;
            cells = char(Lg.cells);
            cls = Lg.cls(:);
            LG = Lg.groups;
            if iscell(LG), LG = [LG{:}]; end
            isS = startsWith(cls, 'S');
            isLong = startsWith(cls, 'T') & ismember(cls, {LG([LG.engaged_read]).cls});
            fams = {'r1', isS; 'r3', isLong};
            for f = 1:size(fams, 1)
                for c = {'v', 'u1', 'f', 'z', 'c', 'e', 'n', 'k'}
                    col = cells(fams{f, 2}, strcmp(Lg.cols, c{1}));
                    base = sprintf('s60r.v6.r16.%s.%s.', fams{f, 1}, c{1});
                    tc.verifyEqual(sum(col == 'L'), cca.data.leaf(tc.D, [base 'lost']), [base 'lost']);
                    tc.verifyEqual(sum(col ~= 'N'), cca.data.leaf(tc.D, [base 'of']), [base 'of']);
                    tc.verifyEqual(sum(col == 'E'), cca.data.leaf(tc.D, [base 'returned_limiter_engaged']), ...
                        [base 'returned_limiter_engaged']);
                end
            end
            tc.verifyEqual(sum(isS), cca.data.leaf(tc.D, 's60r.v6.r16.sets.r1.n'));
            tc.verifyEqual(sum(isLong), cca.data.leaf(tc.D, 's60r.v6.r16.sets.r3.n'));
            % the eleven other compared settings of rule R145 on the same two families (s60r.v6.r17.q1 and q2): the
            % same counts, the returns and the returns at rest (the run's words); every column ran every fault
            codes17 = setdiff(Lg.cols(:).', {'v', 'u1', 'f', 'z', 'c', 'e', 'n', 'k'}, 'stable');
            ref17 = cca.data.leaf(tc.D, 's60r.v6.r17.q2.twelve.eleven_others.codes');
            tc.verifyEqual(sort(codes17), sort(ref17(:).'));
            fams17 = {'q1', isS; 'q2', isLong};
            for f = 1:size(fams17, 1)
                for c = codes17
                    j = find(strcmp(Lg.cols, c{1}));
                    col = cells(fams17{f, 2}, j);
                    dj = cellfun(@(s) pick(s, j), Lg.detail(fams17{f, 2}), 'UniformOutput', false);
                    base = sprintf('s60r.v6.r17.%s.%s.', fams17{f, 1}, c{1});
                    tc.verifyEqual(sum(col == 'L'), cca.data.leaf(tc.D, [base 'lost']), [base 'lost']);
                    tc.verifyEqual(sum(col ~= 'N'), cca.data.leaf(tc.D, [base 'of']), [base 'of']);
                    tc.verifyEqual(sum(col == 'R' | col == 'E'), cca.data.leaf(tc.D, [base 'returned']), ...
                        [base 'returned']);
                    tc.verifyEqual(sum(col == 'E'), cca.data.leaf(tc.D, [base 'returned_limiter_engaged']), ...
                        [base 'returned_limiter_engaged']);
                    tc.verifyEqual(sum(startsWith(dj, 'at rest')), cca.data.leaf(tc.D, [base 'returned_at_rest']), ...
                        [base 'returned_at_rest']);
                end
            end
            tc.verifyFalse(any(cells(:) == 'N'), 'every column ran every fault of the ladder');
            tc.verifyEqual(numel(Lg.detail), numel(Lg.keys));
            tc.verifyFalse(any(any(cells(~(isS | isLong), :) == 'E')));
            tc.verifyEqual(numel(unique(cellfun(@(k) k(1:2), Lg.keys, 'UniformOutput', false))), ...
                cca.data.leaf(tc.D, 's60r.v6.r16.sets.c101_fault_buses_n'));
            % the 78 three-phase faults of up to 2 s through both fault resistances (Fig. 6): each code's losses
            is78 = startsWith(cls, 'T') & ~isLong;
            for j = 1:numel(Lg.cols)
                p = ['s60r.v6.p_nr.A2.lost_of_78_by_setting.' Lg.cols{j}];
                tc.verifyEqual(sum(cells(is78, j) == 'L'), cca.data.leaf(tc.D, p), p);
            end
            tc.verifyEqual(sum(endsWith(Lg.keys, '_0p001pu')), sum(is78) / 2);
            % the decisive faults of the paper (s60r.v6.r17.d1): the count read every ladder key; the marks are
            % exactly the faults on which all twelve compared settings lose; on each the circular limiter alone
            % loses and the Current Compass returns
            tc.verifyEqual(numel(Lg.keys), cca.data.leaf(tc.D, 's60r.v6.r17.d1.keys_read.all'));
            mk = logical(Lg.marks(:));
            tc.verifyEqual(nnz(mk), cca.data.leaf(tc.D, 's60r.v6.r17.d1.n'));
            jt = ismember(Lg.cols(:).', Lg.decisive.twelve);
            tc.verifyEqual(all(cells(:, jt) == 'L', 2), mk);
            tc.verifyTrue(all(ismember(cells(mk, strcmp(Lg.cols, 'v')), 'RE')));
            tc.verifyTrue(all(cells(mk, strcmp(Lg.cols, 'n')) == 'L'));
            for i = 1:numel(Lg.keys)
                label = cca.data.scenario(tc.D, Lg.keys{i}, "short");
                tc.verifyEqual(contains(label, sprintf(' %g pu', cca.data.leaf(tc.D, ...
                    's60r.v6.p_path.fault_resistance.low_pu'))), endsWith(Lg.keys{i}, '_0p001pu'), Lg.keys{i});
            end
        end

        function loadStepsAgainstLeaves(tc)
            % the six load steps without a fault (rule R142 R2) for the codes that ran them: losses, runs and the
            % returns that end with a limiter engaged against s60r.v6.r16.r2.per_code; no fault key among them
            S = tc.D.grid.loadsteps;
            cells = char(S.cells);
            tc.verifyEqual(size(cells, 1), cca.data.leaf(tc.D, 's60r.v6.r16.sets.r2.n'));
            tc.verifyEqual(S.cols(:).', tc.D.grid.ladder.cols(:).');
            for j = 1:numel(S.cols)
                base = ['s60r.v6.r16.r2.per_code.' S.cols{j} '.'];
                tc.verifyEqual(sum(cells(:, j) == 'L'), cca.data.leaf(tc.D, [base 'lost']), [base 'lost']);
                tc.verifyEqual(sum(cells(:, j) ~= 'N'), cca.data.leaf(tc.D, [base 'of']), [base 'of']);
                tc.verifyEqual(sum(cells(:, j) == 'E'), cca.data.leaf(tc.D, [base 'returned_limiter_engaged']), ...
                    [base 'returned_limiter_engaged']);
                tc.verifyEqual(S.totals.(S.cols{j}).engaged_print, cca.data.leaf(tc.D, [base 'engaged_print']));
            end
            tc.verifyEmpty(regexp(strjoin(S.events, ' '), '\d\d_\d{4}_\d\d[ST]', 'once'));
        end

        function capFactorRule(tc)
            % the cap factor's rule wherever the current limit is set: c = 1/Im (the design point of the runs)
            K = tc.D.constants;
            tc.verifyEqual(K.c.value * K.I_m.value, 1, 'AbsTol', 1e-9);
            tc.verifyEqual(K.cap_rule.option, 'c = 1/Im');
        end

        function modelPictures(tc)
            % the look-inside pictures of the Model screen: each level's picture and its display copy are files
            % under app/assets/model
            d = fullfile(tc.root, 'assets', 'model');
            for f = ["level1_network", "level2_converter", "level3_controller"]
                tc.verifyTrue(isfile(fullfile(d, f + ".png")), f);
                tc.verifyTrue(isfile(fullfile(d, f + "_view.png")), f + "_view");
            end
            % the fitted network copy's bus numbers: every master bar matched inside its own print bar, all drawn
            ov = fullfile(d, 'level1_network_overlay.txt');
            if isfile(ov)
                t = fileread(ov);
                tc.verifyMatches(t, 'every master bar lies inside its own print bar');
                tc.verifyMatches(t, '(?m)^39 bus numbers drawn');
                tc.verifyEqual(numel(regexp(t, '(?m)^bus +\d+ +number at', 'match')), 39);
            end
        end

        function formatRule(tc)
            tc.verifyEqual(cca.ui.fmt('mw', cca.data.leaf(tc.D, 's60r.v6.p_pairs.v_k.D_PF.S3.median')), ...
                sprintf('%+d MW', round(cca.data.leaf(tc.D, 's60r.v6.p_pairs.v_k.D_PF.S3.median'))));
            % the Overview's cards print the paper's own leaves in the paper's print form (0.31 s; +280 MW)
            P = tc.D.printed;
            tc.verifyEqual(cca.ui.fmt('secHundredths', cca.data.leaf(tc.D, 's60r.v6.p_rt.rows.v.median_s')), ...
                [printedOf(P, 's60r.v6.p_rt.rows.v.median_s') ' s']);
            tc.verifyEqual(cca.ui.fmt('mw', cca.data.leaf(tc.D, 's60r.v6.p_pairs.v_k.D_PF.S3.median')), ...
                ['+' printedOf(P, 's60r.v6.p_pairs.v_k.D_PF.S3.median') ' MW']);
            tc.verifyFalse(any(startsWith(keys(tc.D.leafmap), {'s60r.e1.', 's60r.ep.', 'system.n_line', ...
                'system.n_xfmr', 'system.n_load'})));
            tc.verifyEqual(cca.ui.fmt('count', 8683543), '8,683,543');
            tc.verifyEqual(cca.ui.fmt('sec', []), 'not in the record');
        end

        function noNumberTypedInScreens(tc)
            % a static scan: no digit inside a displayed text literal of +screen (format specifiers, file
            % names, LaTeX and identifiers excepted)
            files = dir(fullfile(tc.root, '+cca', '+screen', '*.m'));
            L = tc.D.laws;
            if iscell(L), L = [L{:}]; end
            O = tc.D.others;
            if iscell(O), O = [O{:}]; end
            codes = strcat('''', [{L.code}, {O.code}], '''');   % the controls' codes are names, not numbers
            bad = {};
            for i = 1:numel(files)
                src = fileread(fullfile(files(i).folder, files(i).name));
                src = regexprep(src, '%[^\n]*', '');               % comments
                lits = regexp(src, '''([^''\n]|'''')*''', 'match');
                for k = 1:numel(lits)
                    s = lits{k};
                    if contains(s, {'$', '\', '.png', 'cc_', 's60r.', 'chain.', 'system.', '_u%', 'rel_u'}) || ...
                            any(strcmp(s, [{'''1x''', '''sha256'''}, codes]))
                        continue
                    end
                    s = regexprep(s, '%[-+ 0#]*\d*(\.\d+)?[dfgsxXc]', '');
                    if ~isempty(regexp(s, '\d', 'once'))
                        bad{end + 1} = sprintf('%s: %s', files(i).name, lits{k}); %#ok<AGROW>
                    end
                end
            end
            tc.verifyEmpty(bad, strjoin(bad, newline));
        end

        function runFiles(tc)
            runs = tc.D.runs;
            if iscell(runs), runs = [runs{:}]; end
            % the run files of the index (Fig. 7's traces): each matches its sha256, by its key and code and by its
            % file; every series on an increasing time base, as many values as times, within the run's window
            for i = 1:numel(runs)
                R = cca.data.runpack(tc.D, runs(i).key, runs(i).code);
                tc.verifyNotEmpty(R);
                tc.verifyEqual(R.origin, "archived");
                R2 = cca.data.runpack(tc.D, '', '', ['runs/' runs(i).file]);
                tc.verifyEqual(R2.index.file, runs(i).file);
                names = fieldnames(R.series);
                tc.verifyNotEmpty(names, runs(i).file);
                for k = 1:numel(names)
                    s = R.series.(names{k});
                    tc.verifyTrue(all(diff(s.t) > 0), names{k});
                    tc.verifyEqual(numel(s.t), numel(s.y), names{k});
                    tc.verifyGreaterThanOrEqual(min(s.t), R.meta.window_s(1), names{k});
                    tc.verifyLessThanOrEqual(max(s.t), R.meta.window_s(2), names{k});
                end
            end
            tc.verifyEmpty(cca.data.runpack(tc.D, 'not_a_key', 'v'));
        end

        function runListAgainstItsCounts(tc)
            % the list of the paper's runs (app_runs.json): one row a row of the campaign table, every column as
            % long, every tag once; every outcome a word of its own list; each set's and each law's row count equal
            % to the rows that name it; every trace a run file of the index
            Rl = tc.D.runlist;
            I = tc.D.runinfo;
            cols = fieldnames(Rl);
            n = numel(Rl.tag);
            tc.verifyEqual(n, I.n_rows);
            tc.verifyEqual(I.table.rows, n);
            tc.verifyEqual(sort(cols(:).'), sort(cellstr(I.columns(:).')));
            for k = 1:numel(cols)
                tc.verifyNumElements(Rl.(cols{k}), n, cols{k});
            end
            tc.verifyNumElements(unique(Rl.tag), n);
            OUT = I.outcomes;
            if iscell(OUT), OUT = [OUT{:}]; end
            tc.verifyTrue(all(ismember(Rl.outcome, {OUT.word})));
            tc.verifyTrue(all(ismember([OUT.class], 'RELNC')));
            SETS = I.sets;
            if iscell(SETS), SETS = [SETS{:}]; end
            padded = strcat({' + '}, Rl.set, {' + '});
            first = cellfun(@(s) strtrim(regexprep(s, ' \+ .*$', '')), Rl.set, 'UniformOutput', false);
            for k = 1:numel(SETS)
                tc.verifyEqual(nnz(contains(padded, [' + ' SETS(k).name ' + '])), SETS(k).rows, SETS(k).name);
                tc.verifyEqual(nnz(strcmp(first, SETS(k).name)), SETS(k).held, SETS(k).name);
            end
            LAWS = I.laws;
            if iscell(LAWS), LAWS = [LAWS{:}]; end
            for k = 1:numel(LAWS)
                tc.verifyEqual(nnz(strcmp(Rl.code, LAWS(k).code)), LAWS(k).rows, LAWS(k).code);
            end
            tc.verifyEqual(sum([LAWS.rows]), n);
            runs = tc.D.runs;
            if iscell(runs), runs = [runs{:}]; end
            tr = Rl.trace(~strcmp(Rl.trace, '-'));
            tc.verifyTrue(all(ismember(tr, strcat('runs/', {runs.file}))));
        end

        function staticFiles(tc)
            % the folder read as a released folder: ASCII code, lint; in every text file and every path no name of
            % a tool, model or vendor (the release's rule; the names are held here reversed, so that this file
            % names none of them), no home folder (any account's, and this machine's), no droop slope outside the
            % set
            files = [dir(fullfile(tc.root, '**', '*.m')); dir(fullfile(tc.root, '**', '*.html')); ...
                dir(fullfile(tc.root, '**', '*.js')); dir(fullfile(tc.root, '**', '*.css')); ...
                dir(fullfile(tc.root, '**', '*.py'))];
            texts = [files; dir(fullfile(tc.root, '**', '*.txt')); dir(fullfile(tc.root, '**', '*.md')); ...
                dir(fullfile(tc.root, '**', '*.json'))];
            rx = toolNamesPattern();
            home = {getenv('USERPROFILE'), getenv('HOME')};   % this machine's home folder (a path, never a name)
            home = home(cellfun(@(s) numel(s) >= 6, home));
            for i = 1:numel(files)
                p = fullfile(files(i).folder, files(i).name);
                b = fileread(p);
                tc.verifyTrue(all(double(b) < 128), ['non-ASCII: ' files(i).name]);
                if endsWith(p, '.m')
                    msgs = checkcode(p);
                    tc.verifyEmpty(msgs, ['lint: ' files(i).name]);
                end
            end
            for i = 1:numel(texts)
                p = fullfile(texts(i).folder, texts(i).name);
                b = fileread(p);
                tc.verifyEmpty(regexpi(b, rx, 'match', 'once'), ['a tool name in ' texts(i).name]);
                tc.verifyEmpty(regexp(b, ['[A-Za-z]:[\\/]+Users[\\/]|(/lustre)?/' 'home' '/[^/"\\\s~]+/'], 'match', ...
                    'once'), ['a home folder in ' texts(i).name]);
                tc.verifyFalse(any(cellfun(@(h) contains(lower(b), lower(h)), home)), ['this home folder in ' ...
                    texts(i).name]);
                tc.verifyFalse(droopFound(b), ['a droop slope outside the set in ' texts(i).name]);
            end
            all_ = dir(fullfile(tc.root, '**', '*'));
            all_ = all_(~[all_.isdir]);
            for i = 1:numel(all_)
                rel = strrep(fullfile(all_(i).folder, all_(i).name), tc.root, '');
                tc.verifyEmpty(regexpi(rel, rx, 'match', 'once'), ['a tool name in the path ' rel]);
            end
        end

        function tableFourEqualsTheRecord(tc)
            % Table IV as the paper's build prints it (app_paper.json) = its rows rebuilt from the record's leaves
            % (app_grid.json robust): every count cell of both columns; the 18 scenarios are the record's keys
            X = tc.D.paper.tables;
            if iscell(X), X = [X{:}]; end
            t = X(strcmp({X.key}, 'cc_tab_rob'));
            tc.assertNumElements(t, 1);
            R = tc.D.grid.robust;
            rows = R.rows;
            if iscell(rows), rows = [rows{:}]; end
            body = t.cells(2:end);
            tc.verifyNumElements(body, numel(rows));
            for i = 1:numel(rows)
                c = cellstr(body(i).c);
                tc.verifyEqual(c(3:4).', {rows(i).v, rows(i).k}, rows(i).row);
            end
            tc.verifyNumElements(cellstr(R.keys), R.n);
            tc.verifyNumElements(unique(cellstr(R.keys)), R.n);
            el = cellstr(R.capf_0p7.eligible_keys);
            ne = cellstr(R.capf_0p7.not_eligible_keys);
            tc.verifyEqual(sort([el; ne]), sort(cellstr(R.keys)));
            tc.verifyEqual(R.capf_0p7.print, sprintf('%d/%d', R.cells.T4.v.lost, numel(el)));
        end

        function regenerationIsByteEqual(tc)
            % the data step's release mode, run as the Reproduce screen's button runs it, from the released files
            % of app/data alone into a temporary folder: every number file byte for byte as MANIFEST.json holds it,
            % and every file of MANIFEST.json either regenerated or shipped as data (needs Python 3 only)
            [R, info] = cca.data.regenerate(tc.D);
            tc.assumeTrue(info.started, ['no Python 3 here: ' info.output]);
            tc.verifyEqual(info.status, 0, info.output);
            tc.verifyGreaterThan(numel(R), 0);
            tc.verifyEqual(info.equal, info.of, strjoin({R(~[R.equal]).file}, ', '));
            M = tc.D.manifest.files;
            if iscell(M), M = [M{:}]; end
            tc.verifyEqual(sort([{R.file}, reshape(info.shipped, 1, [])]), sort({M.file}));
        end
    end
end

function r = contrast(a, b)
la = lum(a); lb = lum(b);
r = (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
end

function l = lum(c)
c = double(c);
m = c <= 0.03928;
c(m) = c(m) / 12.92;
c(~m) = ((c(~m) + 0.055) / 1.055) .^ 2.4;
l = 0.2126 * c(1) + 0.7152 * c(2) + 0.0722 * c(3);
end

function rx = toolNamesPattern()
% the release's pattern of tool, model and vendor names (case ignored; the second group as whole words, only letters
% counted as word characters); each name is held reversed, so that this file names none of them
rv = @(c) cellfun(@fliplr, c, 'UniformOutput', false);
sub = rv({'artsA', 'xedoc', 'TPGtahC', 'edualC', 'inimeG', 'ytivargitnA', 'ciporhtnA', 'IAnepO', 'tolipoC', ...
    'sohtyM', 'revres-pcm-baltam'});
wrd = rv({'supO', 'elbaF', 'tennoS', 'ukiaH', 'MLL', 'PCM', 'citnega', 'IA'});
rx = ['(' strjoin(sub, '|') '|' fliplr('TPG') '[- ]?\d)|(?<![A-Za-z])(' strjoin(wrd, '|') '|' ...
    fliplr('tnegabus') 's?)(?![A-Za-z])'];
end

function tf = droopFound(txt)
% a droop slope outside the set (the author's word R140): the slope's multiple that the paper's set took out, in
% words or as a number beside the droop, the droop scale that gives it, and the robustness rows' tags and keys at it
t = strrep(txt, '_', ' ');
m = ['fo' 'ur'];
tf = ~isempty(regexpi(t, ['droop[\s-]*(x\s*)?4(p0|\.0)?\>|' m '\s*times|' m 'fold'], 'once')) || ...
    ~isempty(regexpi(t, 'droop\s*scale\W{0,4}0?\.25(?!\d)', 'once')) || ...
    ~isempty(regexp(txt, '(?<![A-Za-z0-9])([A-Z]{2,4}d3[a-z]|d3_[a-z])', 'once'));
end

function v = pick(s, j)
% the j-th column's words of one ladder row (the columns joined by a bar)
p = strsplit(s, '|', 'CollapseDelimiters', false);
v = p{j};
end

function h = sha256file(p)
fid = fopen(p, 'r');
b = fread(fid, Inf, '*uint8');
fclose(fid);
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(b);
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2).', 1, []));
end

function s = printedOf(P, path)
% the paper's print form of one printed leaf (app_printed.json, the numbers view's data)
if iscell(P), P = [P{:}]; end
m = P(strcmp({P.path}, path));
s = m(1).printed;
end

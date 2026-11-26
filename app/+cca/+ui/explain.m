function s = explain(D, what)
%EXPLAIN  The sections that several screens' pages of explanations share (cca.ui.help), in the paper's words where
%   the data carry them (app_paper.json texts: the paragraphs of Section IV) and in the application's words with every
%   number read from the data: "test" (how the paper judges a run), "eligible" (not eligible, and a/b), "limited"
%   (ending with a limiter engaged), "sets" (the sets of runs), "outcomes" (the outcome words), "decisive" (the
%   decisive fault and its recorded traces).
%   s = cca.ui.explain(D, "test")   one section (cca.ui.helpsec)
lf = @(p) cca.data.leaf(D, p);
sec4 = cca.data.paperref(D, "section", "cc_sec4_test_system");
switch string(what)
    case "test"
        q = paragraph(D, 'synchronism test');
        own = ['The application shows, for every run, the outcome that the record of the paper holds; it does ' ...
            'not judge a run itself. Its data step checks the counts of the runs against the counts that the ' ...
            'paper prints, and it stops if one differs.'];
        if isempty(q)
            s = cca.ui.helpsec(sprintf('How the paper judges a run (%s)', sec4), {sprintf(['A law is eligible ' ...
                'on a scenario if its run without a fault is steady. A run is lost if the relative angle of a ' ...
                'grid-forming unit, its angle minus the mean of the grid-forming units, passes half a turn after ' ...
                'clearing, or if the largest relative angle still grows at the end of the record (the thresholds ' ...
                'are in %s of the paper); otherwise it returns.'], sec4), own});
        else
            s = cca.ui.helpsec(sprintf('How the paper judges a run (%s)', sec4), {['In the paper''s words, GFM ' ...
                'means grid-forming and GFL grid-following; a fault-free run is a run without a fault.'], own}, ...
                cell(0, 2), q, sprintf('The paper, %s:', sec4));
        end
    case "eligible"
        s = cca.ui.helpsec('Not eligible, and a/b', {sprintf(['A law is eligible on a scenario if its run ' ...
            'without a fault, at the same load and network state, is steady (%s). Where a law is not eligible, ' ...
            'the paper does not count the scenario for that law: its cell is grey, its run says "not eligible", ' ...
            'and its losses are printed as a/b, that is, a losses of the b scenarios where it is eligible (%s).'], ...
            sec4, cca.data.paperref(D, "table", "cc_tab_set"))});
    case "limited"
        t3 = cca.data.paperref(D, "table", "cc_tab_parts");
        vb = cca.data.paperref(D, "subsection", "The Comparison on the Common Scenarios");
        def = noteClause(D, 'cc_tab_parts', 'Limiter engaged:');
        if ~isempty(def)
            def = sprintf(' (its note: %s)', def);
        end
        s = cca.ui.helpsec('Ending with a limiter engaged', {sprintf(['A run can return and still end with a ' ...
            'current limiter engaged. %s counts these returns in its columns "Ending with a limiter engaged"%s, ' ...
            'and %s shows them as "limited at end". The list of runs calls such a run "returned, a limiter ' ...
            'engaged at the end", and the grids draw it violet. %s reports that none of the fault runs of the ' ...
            'Current Compass in %s and %s ends with a limiter engaged.'], t3, def, ...
            cca.data.paperref(D, "figure", "cc_fig_compare"), vb, vb, ...
            cca.data.paperref(D, "subsection", "The Fault Location and the Fault Path"))});
    case "sets"
        S = asArray(D.runinfo.sets);
        items = cell(numel(S), 2);
        for k = 1:numel(S)
            items{k, 1} = sprintf('%s (%s runs)', S(k).name, cca.ui.fmt('count', S(k).rows));
            items{k, 2} = aboutOf(S(k));
        end
        s = cca.ui.helpsec('The sets of runs', {sprintf(['A set is a group of runs that the paper counts ' ...
            'together. A run that two sets share ran once and is listed in both, so the sets add up to more than ' ...
            'the %s runs of the list.'], cca.ui.fmt('count', D.runinfo.n_rows))}, items);
    case "outcomes"
        O = asArray(D.runinfo.outcomes);
        items = [{O.word}.', {O.meaning}.'];
        s = cca.ui.helpsec('The outcome words', {['The column Outcome of the list, and the card of a run, use ' ...
            'these words.']}, items);
    case "decisive"
        Lg = D.grid.ladder;
        keys = cellstr(Lg.keys(:));
        marked = keys(logical(Lg.marks(:)));
        low = marked(cellfun(@(k) throughLow(D, k), marked));    % the marked faults through the low resistance
        runs = asArray(D.runs);
        fig7 = cca.data.paperref(D, "figure", "cc_fig_fault");
        secD = cca.data.paperref(D, "subsection", sprintf('%s Decisive Faults', lf('s60r.v6.r17.d1.n_word_cap')));
        p = {sprintf(['%s names %s decisive faults: tested faults on which every compared setting eligible on ' ...
            'the ladder loses synchronism and the Current Compass returns. The Compare screen marks them (tab By ' ...
            'fault location).'], secD, lf('s60r.v6.r17.d1.n_word'))};
        if ~isempty(low) && ~isempty(runs)
            [~, P] = cca.data.scenario(D, low{1});
            b = cellfun(@(k) sscanf(k, '%d', 1), low);
            [~, Pr] = cca.data.scenario(D, runs(1).key);
            p{end + 1} = sprintf(['%s draws %s of them: the %s faults of %g s through %g pu at buses %s. The ' ...
                'application holds the recorded traces of the %d runs of the fault at bus %d that %s draws (the ' ...
                'Current Compass and the other rows of the figure).'], fig7, numberWord(numel(low)), ...
                D.grid.words.type.(P.type), P.dur_s, lf('s60r.v6.p_path.fault_resistance.low_pu'), listWords(b), ...
                numel(runs), Pr.bus, fig7);
            p{end + 1} = ['On the Run screen, tick "Runs with recorded traces", select a run and press "Show its traces". ' ...
                'Against the time after clearing (the fault shaded), the panels draw the largest relative angle of ' ...
                'the grid-forming units, the terminal voltage of the unit at the faulted bus, its output current ' ...
                'divided by its limit and, for the Current Compass, the rotation psi of its current. One cursor ' ...
                '(the slider, or the play button) moves on every panel and on the dial at once. Each series keeps ' ...
                'its largest and its smallest value in every bin of the drawing, so no peak is hidden.'];
        end
        s = cca.ui.helpsec('The decisive faults and their recorded traces', p);
    otherwise
        error('cca:explain:what', 'No shared explanation %s.', what);
end
end

% ====================================================================================================== locals
function q = paragraph(D, words)
% the first paragraph of the paper's Section IV (app_paper.json texts) that holds the words; '' where none
q = '';
if ~isfield(D.paper, 'texts') || ~isfield(D.paper.texts, 'section_iv')
    return
end
P = cellstr(D.paper.texts.section_iv);
k = find(contains(P, words), 1);
if ~isempty(k)
    q = P{k};
end
end

function c = noteClause(D, key, head)
% the clause of a table's note that starts with head (up to its semicolon), as the paper prints it; '' where none
c = '';
X = asArray(D.paper.tables);
t = X(strcmp({X.key}, key));
if isempty(t)
    return
end
n = strjoin(cellstr(t(1).notes), ' ');
tok = regexp(n, [regexptranslate('escape', head) '\s*([^;]*)'], 'tokens', 'once');
if ~isempty(tok)
    c = strtrim(tok{1});
end
end

function tf = throughLow(D, k)
% a ladder key whose fault runs through the low fault resistance (its resistance token, read by cca.data.scenario)
[~, P] = cca.data.scenario(D, k);
tf = ~isempty(P.rf);
end

function a = aboutOf(S)
% a set's words for the reader (app_runs.json sets: about), else its note
if isfield(S, 'about') && ~isempty(S.about)
    a = S.about;
else
    a = S.note;
end
end

function w = numberWord(n)
% a small count in words, as the paper writes it
W = {'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'};
if n >= 1 && n <= numel(W)
    w = W{n};
else
    w = sprintf('%d', n);
end
end

function s = listWords(x)
x = arrayfun(@(v) sprintf('%d', v), sort(x(:).'), 'UniformOutput', false);
if numel(x) <= 1
    s = strjoin(x, '');
else
    s = [strjoin(x(1:end - 1), ', ') ' and ' x{end}];
end
end

function X = asArray(X)
if iscell(X), X = [X{:}]; end
end

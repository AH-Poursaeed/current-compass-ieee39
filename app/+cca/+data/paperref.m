function s = paperref(D, kind, key)
%PAPERREF  The paper's own label of a figure, table, section or formal statement in this build (app_paper.json).
%   cca.data.paperref(D, "figure", "cc_fig_fault")       'Fig. 7'
%   cca.data.paperref(D, "table", "cc_tab_set")          'Table II'
%   cca.data.paperref(D, "section", "cc_sec2_saturated_unit")   'Section II'
%   cca.data.paperref(D, "subsection", "Robustness")     'Section V-F'
%   cca.data.paperref(D, "statement", "the circle")      'Theorem 1'
%   A label that is not in app_paper.json is "not in the record".
P = D.paper;
s = 'not in the record';
switch string(kind)
    case "figure"
        F = asStruct(P.figures);
        m = F(strcmp({F.key}, key));
        if ~isempty(m), s = sprintf('Fig. %d', m.number); end
    case "table"
        X = asStruct(P.tables);
        m = X(strcmp({X.key}, key));
        if ~isempty(m), s = sprintf('Table %s', m.number); end
    case "section"
        X = asStruct(P.sections);
        m = X(strcmp({X.module}, key));
        if ~isempty(m)
            if strcmp(m.number, 'Appendix'), s = 'the Appendix'; else, s = sprintf('Section %s', m.number); end
        end
    case "subsection"
        % a subsection by its title in this build: 'Section V-F' (lettered in its order of appearance)
        X = asStruct(P.sections);
        for q = 1:numel(X)
            sub = X(q).subsections;
            if ischar(sub), sub = {sub}; end
            k = find(strcmp(sub, key), 1);
            if ~isempty(k) && ~strcmp(X(q).number, 'Appendix')
                s = sprintf('Section %s-%s', X(q).number, char('A' + k - 1));
            end
        end
    case "statement"
        X = asStruct(P.statements);
        m = X(strcmp({X.name}, key));
        if ~isempty(m), s = sprintf('%s %d', m.kind, m.number); end
end
end

function x = asStruct(x)
if iscell(x), x = [x{:}]; end
end

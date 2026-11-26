function s = helpsec(head, paras, items, quote, quoteFrom)
%HELPSEC  One section of a screen's page of explanations (cca.ui.help): its head, its paragraphs, its terms with
%   their meanings, and the paper's own words where the section quotes them (with the place they come from).
%   s = cca.ui.helpsec("The colours", {'A cell is ...'}, {'blue', 'returns'; 'red', 'lost'})
%   s = cca.ui.helpsec("The test", {}, cell(0, 2), quoteText, 'The paper, Section IV:')
arguments
    head
    paras = {}
    items = cell(0, 2)
    quote = ''
    quoteFrom = ''
end
s.head = char(head);
if ischar(paras) || isstring(paras)
    paras = cellstr(paras);
end
s.paras = reshape(paras(~cellfun(@isempty, paras)), 1, []);
if isempty(items)
    s.items = struct('term', {}, 'text', {});
else
    s.items = struct('term', reshape(items(:, 1), 1, []), 'text', reshape(items(:, 2), 1, []));
end
s.quote = char(quote);
s.quoteFrom = char(quoteFrom);
end

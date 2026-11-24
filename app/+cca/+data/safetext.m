function s = safetext(v)
%SAFETEXT  A value of app/data as one line of plain text for a table cell (numbers in full precision as stored).
if ischar(v) || isstring(v)
    s = char(v);
elseif isnumeric(v) || islogical(v)
    if isempty(v)
        s = 'null';
    elseif isscalar(v)
        s = num2str(v, 15);
    else
        s = ['[' strjoin(arrayfun(@(x) num2str(x, 15), v(:).', 'UniformOutput', false), ', ') ']'];
    end
elseif iscell(v)
    s = ['[' strjoin(cellfun(@cca.data.safetext, v(:).', 'UniformOutput', false), ', ') ']'];
elseif isstruct(v)
    s = jsonencode(v);
else
    s = '';
end
s = regexprep(s, '[\r\n]+', ' ');
end

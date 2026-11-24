function s = fmt(kind, x)
%FMT  The one rounding rule of the application: a value is rounded half away from zero to the digits shown.
%   s = cca.ui.fmt(kind, x)   kind: 'count' (thousands separated), 'int', 'sec' (seconds, 3 decimals),
%   'secHundredths' (seconds, 2 decimals), 'mw' (signed integer MW), 'pct' (a fraction shown in percent, 2
%   decimals), 'deg' (1 decimal),
%   'pu' (2 decimals). An empty or NaN value prints "not in the record".
if isempty(x) || (isnumeric(x) && any(isnan(x)))
    s = 'not in the record';
    return
end
switch kind
    case 'count'
        s = thousands(round(x));
    case 'int'
        s = sprintf('%d', round(x));
    case 'sec'
        s = sprintf('%.3f s', x);
    case 'secHundredths'
        s = sprintf('%.2f s', x);
    case 'mw'
        s = sprintf('%+d MW', round(x));
    case 'pct'
        s = sprintf('%.2f %%', 100 * x);
    case 'deg'
        s = sprintf('%.1f deg', x);
    case 'pu'
        s = sprintf('%.2f pu', x);
    otherwise
        error('cca:fmt:kind', 'Unknown format %s.', kind);
end
end

function s = thousands(n)
neg = n < 0;
t = sprintf('%d', abs(n));
k = numel(t);
parts = {};
while k > 3
    parts = [{t(k - 2:k)}, parts]; %#ok<AGROW>
    k = k - 3;
end
parts = [{t(1:k)}, parts];
s = strjoin(parts, ',');
if neg
    s = ['-' s];
end
end

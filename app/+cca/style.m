function T = style(name, what, file)
%STYLE  The one token table of the application (style A, the light one; DESIGN_SPEC_v2 section 3).
%
%   T = cca.style("A")                     the tokens: T.c (RGB rows), T.hex, T.font, T.px
%   cca.style("A", "css", file)            writes the same tokens as CSS variables (one source for both sides)
arguments
    name (1,1) string = "A"
    what (1,1) string = "tokens"
    file (1,1) string = ""
end
if name ~= "A"
    error('cca:style:unknown', 'Only style A (the light one) is built in this release.');
end
hex = struct( ...
    'ground', '#F4F5F7', 'surface', '#FFFFFF', 'sunken', '#EEF1F5', 'border', '#E1E5EB', ...
    'border2', '#C9D0DA', 'ink', '#0E1726', 'ink2', '#4A5567', 'ink3', '#6B7280', 'accent', '#0054B4', ...
    'tint', '#E8F0FB', 'soft', '#CCDFF3', 'ret', '#E3EDF9', 'lossInk', '#A3241B', 'fault', '#FFF2D6', ...
    'faultEdge', '#E8C98A', 'ok', '#1E7A4C', 'warn', '#A86200', 'other', '#A7B1BF', 'tie', '#CBD2DC', ...
    'axis', '#262626', 'cap', '#B07A16', 'rot', '#0B6FBF', 'rel', '#1B7A4B', 'accentHover', '#00438F', ...
    'skeleton', '#E8EBEF', 'white', '#FFFFFF', ...
    'limited', '#5E3C99');   % a return that ends with a limiter engaged: the violet of Fig. 6's "limited at end"
T.name = name;
T.hex = hex;
f = fieldnames(hex);
for i = 1:numel(f)
    T.c.(f{i}) = cca.style_rgb(hex.(f{i}));
end
T.font.display = 'Cambria';
T.font.chrome = 'Segoe UI';
T.font.chromeBold = 'Segoe UI Semibold';
T.font.plot = 'Times New Roman';
T.font.math = 'Cambria Math';
T.px = struct('rail', 220, 'top', 48, 'margin', 24, 'gutter', 16, 'pad', 20, 'lineSel', 1.8, 'line', 1);
% the paper's tables as html (the Reproduce screen): the chrome font and the tokens' colours, a bold class
T.css.table = sprintf(['html,body{margin:0;font-family:"%s",Arial,sans-serif;font-size:12px;color:%s;background:%s}' ...
    'table{border-collapse:collapse;width:100%%}th,td{border:1px solid %s;padding:3px 6px;vertical-align:top;' ...
    'text-align:left}th{background:%s;font-weight:400}th.span{text-align:center;font-weight:700}' ...
    '.b{font-weight:700}'], T.font.chrome, hex.ink, hex.surface, hex.border, hex.sunken);
if what == "css"
    if strlength(file) == 0
        error('cca:style:file', 'A file name is needed for the CSS tokens.');
    end
    L = strings(numel(f) + 2, 1);
    L(1) = ":root {";
    for i = 1:numel(f)
        L(i + 1) = sprintf('  --%s: %s;', f{i}, hex.(f{i}));
    end
    L(end) = "}";
    txt = strjoin(L, newline) + newline;
    old = "";
    if isfile(file)
        old = string(fileread(file));
    end
    if old ~= txt
        fid = fopen(file, 'w');
        c = onCleanup(@() fclose(fid));
        fwrite(fid, char(txt));
    end
end
end

function rgb = style_rgb(hex)
%STYLE_RGB  '#RRGGBB' -> [r g b] in 0..1 (exact: integer channels over 255).
hex = char(hex);
if hex(1) == '#'
    hex = hex(2:end);
end
rgb = double(sscanf(hex, '%2x', 3)).' / 255;
end

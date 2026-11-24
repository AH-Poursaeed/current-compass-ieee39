function v = leaf(D, path)
%LEAF  The value of one leaf of the number record, by its dotted path (as written in app/data/app_numbers.json).
%   v = cca.data.leaf(D, 's60r.e1.returns')
%   A path that is not in app/data is an error: the screens never fill a gap from code.
if ~isKey(D.leafmap, path)
    error('cca:data:noLeaf', 'The leaf %s is not in app/data; regenerate it with app/tools/make_app_data.py.', path);
end
v = D.leafmap(path);
end

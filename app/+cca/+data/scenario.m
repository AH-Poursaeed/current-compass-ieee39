function [label, P] = scenario(D, key, form)
%SCENARIO  The words of one scenario key of the record ('38_1000_10TF' or 's38_1000_10TF'), or of a ladder key
%   through the low fault resistance ('38_1000_10TF_0p001pu': its resistance printed from the record's leaf).
%   [label, P] = cca.data.scenario(D, key)            'bus 38 . three-phase . 1 s . base load . base network'
%   label = cca.data.scenario(D, key, "short")        'bus 38 . 3-ph . 1 s'
arguments
    D struct
    key
    form (1,1) string = "long"
end
key = char(key);
if startsWith(key, 's')
    key = key(2:end);
end
tok = regexp(key, '^(\d\d)_(\d{4})_(\d\d)([ST])(F|W|O1718|U08)(_0p\d+pu)?$', 'tokens', 'once');
if isempty(tok)
    error('cca:data:key', 'Not a scenario key of the record: %s', key);
end
W = D.grid.words;
P.key = key;
P.bus = str2double(tok{1});
P.dur_s = str2double(tok{2}) / 1000;
P.load = tok{3};
P.type = tok{4};
P.state = tok{5};
P.rf = '';
rfTxt = '';
if numel(tok) >= 6 && ~isempty(tok{6})
    P.rf = tok{6}(2:end);
    rfTxt = sprintf(' . %g pu', cca.data.leaf(D, W.rf_leaf.(matlab.lang.makeValidName(P.rf))));
end
stateWord = W.state.(matlab.lang.makeValidName(P.state));
loadWord = W.load.(matlab.lang.makeValidName(P.load));
if form == "short"
    label = sprintf('bus %d . %s . %g s%s', P.bus, W.type_short.(P.type), P.dur_s, rfTxt);
else
    label = sprintf('bus %d . %s . %g s%s . %s . %s', P.bus, W.type.(P.type), P.dur_s, rfTxt, loadWord, stateWord);
end
end

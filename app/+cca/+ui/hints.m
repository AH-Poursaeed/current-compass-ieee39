function h = hints(name)
%HINTS  The one-line description under each screen's title (words only, no number).
switch string(name)
    case "overview"
        h = 'One saturated grid-forming unit with its current turned towards lagging: the idea, the proof and the evidence of the paper.';
    case "reproduce"
        h = 'Every figure and table of the paper, with the record files, the reader and the numbers behind it.';
    case "run"
        h = 'Every run of the paper with its set, law, setting, fault and outcome, and the traces of the runs that a figure draws.';
    case "compare"
        h = 'Each cell is one run of the paper: one law or part on one scenario, fault or load step, where it returns or loses synchronism.';
    case "scenarios"
        h = 'The common scenarios by fault bus: each ring shows how the Current Compass and every compared setting end at that bus.';
    case "model"
        h = ['The test system and every law as it is built in the model: a walk from the network into one ' ...
            'converter and its controller, under the Current Compass or any compared law.'];
    case "provenance"
        h = 'Where each number comes from: its path in the released record, and every file of the application''s data with its sha256.';
    case "about"
        h = 'How to cite this work, its licence, its authors and what it needs to run.';
    otherwise
        h = '';
end
end

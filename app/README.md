# The Current Compass application

A MATLAB application that shows the results of the paper "Current Compass: A Local Control Law for Synchronization Stability of Grid-Forming Converters at the Current Limit": its figures and tables, the
Current Compass, its parts and every compared setting on the scenarios of the paper's comparisons, the outcome of
every run of the paper, and where each printed number comes from.

## Start

In MATLAB, from this folder:

```matlab
ccapp                          % opens on the Overview screen
ccapp(Screen="compare")        % opens on one screen
ccapp(Screen="run")            % opens on the list of the paper's runs
```

`help ccapp` lists the other options.

## The screens

| Screen | What it shows |
|---|---|
| Overview | the idea (the dial and the three channels), the test network, three results as the paper prints them and the path from the problem to the evidence |
| Reproduce | the paper's figures and tables, each with its caption and where it comes from; every printed number of the paper with its place; the button that regenerates the application's data and compares them with the shipped files |
| Run | the list of the paper's runs: every run of the campaign table with its set, law, setting, fault, load, network state and outcome; filters by set, by law and by outcome; the card of the selected run with the places of the paper that count it; the traces that Fig. 7 draws, for its runs |
| Compare | the Current Compass and every compared setting on every common scenario, with each one's losses; the ladder of fault locations (with the five decisive faults of Section V-D marked); the load steps without a fault; the parts of the law; a cell opens its run on the Run screen |
| Scenarios | the common scenarios by fault bus, one ring a bus and one sector a law |
| Model | the test system and the laws, read-only pictures of the model's levels, and the law's equations and constants |
| Provenance | every number that the screens print, with its path in the released record, and the data's manifest |
| About | how to cite the work, its licence and the third-party notice, the authors, what the application needs, and the version of the data it shows |

## The data

Every number the application prints is read at run time from `data/`. Nothing in `data/` is edited by hand, and no
number is typed in the screens. `data/record/released_record.json` holds every number that the data step reads and
every printed number of the paper. `data/app_runs.json` holds one row for every run of the campaign table with its
outcome, and `data/runs/` the traces of Fig. 7's runs. To regenerate the number files from the released files and
compare them with the shipped ones, from the repository's root:

```
python app/tools/make_app_data.py --into regen
```

It prints, for each number file, whether it is equal to the file that `data/MANIFEST.json` names (by sha256).

## What it needs

- To show the results: MATLAB (tested with R2026a). The screens use `uifigure` and `uihtml`.
- To regenerate the number files: Python 3 (the standard library is enough).

## Tests

From this folder:

```matlab
runtests('tests/tCore.m')      % the data against the released record, the tables, the sets, static checks
runtests('tests/tUI.m')        % the window: every screen built, the tables and notes as the paper prints them
```

## Credit

The test system and its control design are the published system of X. Wang and X. Chen (see
`THIRD_PARTY_NOTICES.txt` and the About screen).

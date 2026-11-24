THE CAMPAIGN TABLE OF THE PAPER

campaign_table_paper.tsv lists every simulation run that the paper's figures, tables and printed numbers rest on:
7218 rows, sha256 b8c6782f08a336a5d747526998b0f9cb40ad66675a8f75fe87c20a190e4e8e01 (1300493 bytes).
ASCII, LF line ends, tab-separated, one header line, one line a run, sorted by set and then by tag. An empty value is "-".

WHAT A ROW IS. One run of the EMT model of the 100 % inverter-based IEEE 39-bus system: one law (or one part of the
Current Compass) at one setting, one operating state (load and network), and one fault, one load step or no
disturbance. A setting has a row on every scenario where it ran. The runs which chose the four selected settings
were made by a separate driver before the campaigns and are not rows of this table. The cases of the one-unit
harness that Table II reports in its column Harness and the cases of the one-unit bench of Section III were made by
separate programs and are not rows of this table.

HOW A TAG READS. The tag is the run's name in the simulation records (the archive of a run is case_frt_<tag>.mat).
Most fault runs end with the scenario key <bus>_<duration in ms>_<load: 10 base, 09 at 0.9><T three-phase or S SLG>
<F base network, O1718 line 17-18 out, U08 unit 8 under GFL control, W line 1-39 out>; the letters before it name
the study and the law. The columns below, not the tag, describe the run: each is derived from the run's own
arguments.

THE COLUMNS
 tag          the run's name (unique in the file).
 set          the paper's set of runs that the row serves. A run that two sets share ran once: the field names both,
              joined by " + ", and the first name is the set that holds the row. The sets:
                common scenarios        2276 rows (2276 held here)
                shortened runs           918 rows (918 held here)
                ladder 0.01 pu           857 rows (592 held here)
                ladder 0.001 pu          741 rows (741 held here)
                faults of 4 and 5 s      494 rows (475 held here)
                single-phase ladder      774 rows (660 held here)
                load steps               114 rows (114 held here)
                Table IV                1082 rows (1040 held here)
                reruns                    11 rows (11 held here)
                theory checks              8 rows (8 held here)
                module search            108 rows (108 held here)
                fault-free row           275 rows (275 held here)
              Table IV holds the runs with one setting varied and the design runs on its 18 scenarios; a
              fault-free row is the run without a fault that decides whether a law is eligible on a scenario at
              that load and network state; the module search holds the fault-free runs of [14]'s own modules.
 code         the law's code in the simulation records; law: the law as the paper names it:
                v    Current Compass
                u1   Fixed Quarter Turn
                f    Cap and fixed quarter turn, no release
                z    Cap and rotation without release
                c    Cap alone
                e    Supervised rotation without the cap
                n    Circular limiter alone
                k    Virtual active power feedback [9]
                o    Multi-objective strategy [10]
                d    Reactive power synchronization [13]
                q    Reactive power synchronization [13]
                MAd  Reactive power synchronization [13], granted the fault-on reactance
                MAq  Reactive power synchronization [13], granted the fault-on reactance
                h    Cross-forming control [14]
                y    Cross-forming control [14]
                l63  Saturated cross-forming control [15]
                l94  Saturated cross-forming control [15]
                l10  Fixed-angle priority limiter [17]
                l20  Fixed-angle priority limiter [17]
                l51  Power-angle switching [18]
                l99  Virtual-impedance limiter after [7]
                l98  Reactive-priority limiter
                x    Cross-forming control [14], own module
                l96  Cross-forming control [14], own module
                l97  Cross-forming control [14], own module
 setting      the setting as the paper prints it: design (the Current Compass and its parts), published, selected,
              baseline; a Table IV row names its one varied setting and value; a rerun names its change; a module
              search row names its module.
 fault_bus    the faulted bus; fault_kind: SLG, none, three-phase;
 fault_ms     the fault duration in ms; fault_r_pu: the fault resistance in pu on the 100 MVA system base.
 event        a load step: the resistance switched in at the bus, when and for how long; else "-".
 load         0.9, 1.0 (1.0 is the case's base load; 0.9 is load and dispatch at 0.9).
 network      base, line 1-39 out, line 17-18 out, unit 8 under GFL control.
 args_sha256  the SHA-256 (lowercase hex) of the run's complete argument string, as the run driver's table dump
              prints it (ASCII, without the line end). It fingerprints every setting of the run.

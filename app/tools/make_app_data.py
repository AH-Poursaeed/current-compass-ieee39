"""make_app_data.py - the data step of the Current Compass reproduction application: THE RELEASE MODE.

It regenerates the application's number files from the released files alone and compares them, byte for byte, with
app/data/MANIFEST.json:

    python app/tools/make_app_data.py --into DIR          writes DIR/data and prints, per number file, equal or
                                                          DIFFERENT (DIR/data/REGEN.json holds the same)
    python app/tools/make_app_data.py --into DIR --from F reads the data folder F instead of app/data

It reads ONLY app/data: the released record (data/record/released_record.json: the subtree at every record path this
step reads, and every printed number of the paper), the inputs file (data/record/inputs.json: Table II's laws and
settings, Table III's row labels, the names and colours) and app_paper.json (the paper's own texts, shipped as data).
It writes the number files: app_numbers.json, app_laws.json, app_grid.json (the grid, the ladder, the load steps and
Table IV's count cells), app_printed.json (the numbers view) and runs/index.json. It never writes app/data itself.

THE APPLICATION's SET: the faults of at most MAX_MS (5 s), every count of the set a leaf of the record's groups R15,
R16, R17 and R19; check_set() refuses a written file that holds a scenario key or a duration above the limit, a droop
slope outside the set or a home folder, and paper_sets_check() a scenario key or a code outside the paper's sets.
"""
import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
REPO = APP.parent
MODE = "release"        # the only mode of this file (a private full mode of the authors' tree sets it otherwise)
OUT = DATA = SRC_DATA = None
HOOKS = {}              # the checks of a private full mode on its full record (none here)

# THE RELEASED INPUTS (app/data/record): the released record (one JSON in the record's tree form: the subtree at every
# record path this script reads, RELEASED_LIST, and the paper's printed leaves under PRINTED_KEY, written by the number
# record's own tool) and the inputs file (the few words this script reads from files other than the record: Table II's
# families and settings, Table III's row labels, the law names and colours, one census line; written in full mode)
RELEASED = "record/released_record.json"
INPUTS = "record/inputs.json"
RELEASED_LIST = "record/released_paths.txt"
RUN_OUT = "record/run_outcomes.json"   # the per-run outcomes found under the runs' tags (values and tags only)
PRINTED_KEY = "_printed"
NUMBER_FILES = ("app_numbers.json", "app_laws.json", "app_grid.json", "app_printed.json", "app_runs.json",
                "runs/index.json")
TABLE = [None]          # the campaign table of the paper's runs (artifacts/campaign/campaign_table_paper.tsv)
READS = set()           # the record paths read by get(), recorded on the merged record only (--reads)
_ROOT = [None]
_CHECK = [False]        # True inside a check of the full mode alone: its reads are not listed for the released record

# ------------------------------------------------------------------------------------------------ the set's rule
R15 = "s60r.v6.r15"     # part 15's group: THE APPLICATION's SET, the 101 common scenarios of faults of up to 5 s (66
                        # short, 35 long: the 23 of record and the group's 12 new keys), the ladder's 26 faults of 4 and
                        # 5 s and the current limits of Table IV
TESTS = R15 + ".pooled.tests"   # the sealed network tests on the extended runs of the set (part 15, batch B3; no
                                # row of rule R142 joins them: R16.pooled.membership_note)
R16 = "s60r.v6.r16"     # part 16's group: the runs of rule R142 (R1 the 39 SLG faults of the ladder, R2 the six load
                        # steps without a fault, R3 the ladder's 26 faults of 4 and 5 s for every part, R4 the granted
                        # control of [13]) and the figures' confirmations about the files of part 16
R19 = "s60r.v6.r19"     # part 19's group (worker NUM): read where it holds the eight codes per run (ladder())
R17 = "s60r.v6.r17"     # part 18's group: the runs of rule R145 (Q1 the ladder's 39 SLG faults and Q2 its 26 faults
                        # of 4 and 5 s for the eleven other compared settings eligible at base load in the base
                        # network, per run: verdict, rest, limiter at the end, return time), the smaller load step's
                        # test (vf) and the record's statement that every column ran every fault of the ladder (ran)
MAX_MS = 5000           # the longest fault the application shows (asserted equal to R15.sets.c101.max_duration_ms)
KEY_RE = re.compile(r"^(\d\d)_(\d{4})_(\d\d)([ST])(F|W|O1718|U08)$")
KEY_ANY = re.compile(r"(\d\d)_(\d{4})_(\d\d)([ST])(F|W|O1718|U08)")
FR = "s60r.v6.p_path.fault_resistance"   # the two fault resistances of the record (base_pu, low_pu)
BASE_RF, LOW_RF = "0p01pu", "0p001pu"     # the record's tokens of the two (s60r.v6.p_nr.ladder.<code>.<token>); a
                                          # ladder key through the low one ends with "_" + LOW_RF


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def get(m, path):
    """the leaf at a dotted path (keys may hold '-', never '.')"""
    o = m
    for k in path.split("."):
        if isinstance(o, dict):
            if k not in o:
                raise KeyError(path)
            o = o[k]
        elif isinstance(o, list):
            o = o[int(k)]
        else:
            raise KeyError(path)
    if m is _ROOT[0] and not _CHECK[0]:
        READS.add(path)
    return o


def has(m, path):
    """whether the record holds a path, NOT recorded as a read (an existence test: a read under it records itself)"""
    o = m
    for k in path.split("."):
        if isinstance(o, dict) and k in o:
            o = o[k]
        else:
            return False
    return True


class At:
    """a subtree of the record read leaf by leaf: every value taken is a get() of its own path (so the released
    record holds only the leaves read); 'in' is an existence test (has)"""

    def __init__(self, m, path):
        self.m, self.path = m, path

    def __contains__(self, k):
        return has(self.m, self.path + "." + k)

    def __getitem__(self, k):
        p = self.path + "." + k
        if not has(self.m, p):
            raise KeyError(p)
        v = _peek(self.m, p)
        return At(self.m, p) if isinstance(v, dict) else get(self.m, p)

    def get(self, k, d=None):
        return self[k] if k in self else d

    def keys(self):
        """the children's names (an existence test of each, not a read)"""
        return list(_peek(self.m, self.path).keys())

    def __iter__(self):
        return iter(self.keys())

    def items(self):
        return [(k, self[k]) for k in self.keys()]


def _peek(m, path):
    o = m
    for k in path.split("."):
        o = o[k]
    return o


def opt(m, path):
    """the leaf at a dotted path, or None where the record does not hold it"""
    try:
        return get(m, path)
    except (KeyError, IndexError, ValueError):
        return None


def write_json(p, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    txt = json.dumps(obj, indent=1, ensure_ascii=True, allow_nan=False)
    p.write_text(txt + "\n", encoding="ascii", newline="\n")


def parse_key(k):
    low = k.endswith("_" + LOW_RF)               # a ladder fault through the low fault resistance
    if low:
        k = k[:-len(LOW_RF) - 1]
    g = KEY_RE.match(k[1:] if k.startswith("s") else k)
    assert g, k
    p = {"bus": int(g.group(1)), "dur_ms": int(g.group(2)), "load": g.group(3), "type": g.group(4),
         "state": g.group(5)}
    if low:
        p["rf"] = LOW_RF
    return p


def kept(k):
    """THE RULE of the application's set: a scenario is kept if its fault lasts at most MAX_MS"""
    return parse_key(k)["dur_ms"] <= MAX_MS


def order(k):
    p = parse_key(k)
    return p["bus"], p["dur_ms"], p["load"], p["type"], p["state"]


# ---------------------------------------------------------------------------------------------------- the leaves
# every scalar or list the screens print, by its path in the merged record
LEAVES = [
    "s60r._stamp.round", "s60r._stamp.date",
    # the Overview's two headline cards: the paper's own printed leaves (Table III's median return time of the law;
    # Section V's paired median of the fault-on active power against k and its count of short three-phase scenarios)
    "s60r.v6.p_rt.rows.v.median_s", "s60r.v6.p_pairs.v_k.D_PF.S3.median", "s60r.v6.p_pairs.v_k.verdicts.S3.both_return",
    R15 + ".sets.c101.max_duration_ms", R15 + ".sets.c101.n_keys", R15 + ".sets.c101.n_short",
    R15 + ".sets.c101.n_long", R15 + ".sets.c101.long_range_print", R15 + ".c101.v.lost", R15 + ".c101.v.long_lost",
    R15 + ".sets.lad26.n", R15 + ".sets.lad26.print",
    R15 + ".sets.s18.n_keys", R15 + ".lim.limits_print", R15 + ".lim.cap_rule",
    TESTS + ".T-S4.rows_v", TESTS + ".T-S4.samples_v", TESTS + ".T-S4.violations",
    "chain.census.form.compared_laws",
    "system.n_bus", "system.n_unit", "system.n_gfl",
    "system.n_gfm", "system.load_MW", "system.Vbase_kV", "system.Sbase_MVA", "system.Fref", "system.iLimPu",
    "system.loadScale_second_point",
    "s60r.v6.t_par.gfm_control.law_v_options.value", "s60r.v6.t_par.gfm_control.cap_formula.value",
    "s60r.v6.t_par.gfm_control.iLimPu.value",
]
# the leaves of the group R16 the screens print: the families' sets in the record's words, the granted control of
# [13] (R4: its own losses at its two settings, then the control's returns), the group's state
LEAVES16 = [
    R16 + ".sets.c101_fault_buses_n",
    R16 + ".sets.r1.n", R16 + ".sets.r1.print", R16 + ".sets.r1.fault_print",
    R16 + ".sets.r3.n", R16 + ".sets.r3.print", R16 + ".sets.r2.n", R16 + ".sets.r2.print",
    R16 + ".r4.print", R16 + ".r4.both_settings_return_on_all_101",
    R16 + ".r4.published.code", R16 + ".r4.published.law_losses_on_101", R16 + ".r4.published.explained",
    R16 + ".r4.published.of", R16 + ".r4.published.granted_returns",
    R16 + ".r4.selected.code", R16 + ".r4.selected.law_losses_on_101", R16 + ".r4.selected.explained",
    R16 + ".r4.selected.of", R16 + ".r4.selected.granted_returns",
]


def counts16(m, cols):
    """the per-code counts of the three families the tables are tested against (R1 and R3: Table III's rows and [9];
    R2: the 19 codes): losses, runs and the returns that end with a limiter engaged"""
    out = []
    for fam in ("r1", "r3"):
        for c in PART_CODES + ("k",):
            out += ["%s.%s.%s.%s" % (R16, fam, c, f) for f in ("lost", "of", "returned_limiter_engaged")]
    for c in cols:
        out += ["%s.r2.per_code.%s.%s" % (R16, c, f) for f in ("lost", "of", "returned_limiter_engaged",
                                                                "engaged_print")]
    return out


# the leaves of the group R17 the screens print: the ladder's note (who ran the families and the counts on them, the
# compared settings first) and the smaller load step's test (passed at each bus, then every bus's details)
VF_BUS = ("passed", "cap_longest_bind_print_3", "df_max_print_3", "law_T_RET_s", "limiter_alone_T_RET_s")
LEAVES17 = [
    R17 + ".ran.all_three_groups_ran_by_the_law_its_parts_and_the_twelve",
    R17 + ".q1.twelve.none_codes", R17 + ".q1.twelve.others_codes", R17 + ".q1.twelve.others_range_print",
    R17 + ".q2.twelve.k_lost", R17 + ".q2.twelve.eleven_others.codes", R17 + ".q2.twelve.eleven_others.range_print",
    R16 + ".r1.c.buses_lost", R17 + ".vf.passed_at_all_three", R17 + ".vf.buses",
]


def leaves17(m):
    """LEAVES17 and, per bus of the smaller load step, its test's verdict and details (VF_BUS)"""
    return LEAVES17 + ["%s.vf.per_bus.%d.%s" % (R17, b, f) for b in get(m, R17 + ".vf.buses") for f in VF_BUS]


def counts17(m):
    """the per-code counts of the eleven other compared settings on Q1 and Q2 the ladder is tested against"""
    return ["%s.%s.%s.%s" % (R17, q, c, f) for q in ("q1", "q2") for c in get(m, R17 + ".sets.codes")
            for f in ("lost", "of", "returned", "returned_at_rest", "returned_limiter_engaged")]


# the leaves the ladder prints for its faults through the two fault resistances (the groups' and the rows' words) and
# for Section V-D's count over every ladder key (R17.d1: the five decisive faults marked, the note's line)
LEAVES_LAD = [FR + ".base_pu", FR + ".low_pu", R17 + ".d1.n", R17 + ".d1.n_word", R17 + ".d1.n_word_cap",
              R17 + ".d1.circular_limiter_alone_on_all", R17 + ".d1.keys_read.all"]
# the per-run records of the ladder's faults of 0.3 to 2 s through both resistances (Fig. 6's 78 ladder faults):
# per code and duration the lost buses (through the low resistance: t_parts.lrf_0p001pu for the law, the cap alone,
# the circular limiter alone and [9]; p_lrx.per_law for seven codes; p_nr.ladder.<code>.0p001pu for the eight others)
# and per cell the verdicts of the twelve compared settings and of the seven rows of Table III (p_nr.A2.per_cell)
LRF = "s60r.v6.t_parts.lrf_0p001pu"
LRX = "s60r.v6.p_lrx.per_law"
A2 = "s60r.v6.p_nr.A2"


# the circle's test on the set's runs: carried only where its median is a number of the record (the group may hold
# a word, e.g. NOT RECOMPUTABLE, in its place); Overview prints it only where it is carried
TS1 = [TESTS + ".T-S1.n", TESTS + ".T-S1.median"]
LAW_V_OPTIONS = "s60r.v6.t_par.gfm_control.law_v_options.value"
I_LIM = "s60r.v6.t_par.gfm_control.iLimPu.value"
# the Compass's constants, parsed from the leaf above (the run driver's option names -> the paper's symbols)
CONST_NAMES = {"frtPShape": "c", "frtQfloor": "Q_f", "frtRelCv": "release_ratio", "frtRelTf": "T_f",
               "frtRelTau": "tau_r", "qGain": "k_q", "frtRelTb": "timer_s"}
ABL_CODES = ("n", "c", "e", "f", "z")   # the parts with a per-key record of their own (chain.ablation.per_key)
PART_CODES = ("v", "u1", "f", "z", "c", "e", "n")   # Table III's rows, the law first (all on every common scenario)


def constants(m):
    txt = get(m, LAW_V_OPTIONS)
    out = {}
    for opt_name, sym in CONST_NAMES.items():
        g = re.search(r"(?:^|[ ,])" + opt_name + r" ([0-9.eE+-]+)", txt)
        assert g, opt_name
        out[sym] = {"value": float(g.group(1)), "option": opt_name, "src": LAW_V_OPTIONS}
    assert re.search(r"frtLim qrot", txt)
    # the cap factor's rule wherever the current limit Im is set: c = 1/Im, the cap at the unit's rating at nominal
    # voltage (decision D97); the design point of the runs holds it (c x Im = 1, asserted)
    im = float(get(m, I_LIM))
    assert abs(out["c"]["value"] * im - 1.0) < 1e-9, ("the cap factor's rule c = 1/Im", out["c"]["value"], im)
    out["I_m"] = {"value": im, "option": "iLimPu", "src": I_LIM}
    out["cap_rule"] = {"value": out["c"]["value"] * im, "option": "c = 1/Im",
                       "src": "derived: the product of %s (frtPShape) and %s, asserted equal to 1" % (LAW_V_OPTIONS,
                                                                                                  I_LIM)}
    return out


SHORT_KEYS = "chain.ablation.per_code.v.SHORT.missing_keys"       # the 66 short keys
LONG_KEYS = "chain.headline.set_R1.long_common_keys.keys"         # the record's long common keys
WORD = {"RETURNS SETTLED": "R", "RETURNS NOT SETTLED": "R", "LOST": "L"}


CLASSES = ("d0300ms", "d0500_1000ms", "long_to5s")   # the group's classes of the 101 (0.3 s; 0.5 and 1 s; 2 to 5 s)


def required(m):
    """the leaves of the group R15 this script needs; all missing ones are named at once"""
    laws = list(get(m, "chain.census.form.compared_laws"))
    need = [p for p in LEAVES if p.startswith(R15)]
    need += [R15 + ".sets.c101.keys", R15 + ".sets.c101.new_keys", R15 + ".sets.c101.new_n",
             R15 + ".sets.c101.of_record_n", R15 + ".sets.lad26.keys_4s", R15 + ".sets.lad26.keys_5s"]
    for c in ["v"] + laws:
        need += ["%s.c101.laws.%s.%s" % (R15, c, f) for f in ("lost", "of", "long_lost", "long_of", "lost_keys")]
        need += ["%s.c101.laws.%s.%s.%s" % (R15, c, k, f) for k in CLASSES
                 for f in ("lost", "of", "lost_keys", "not_eligible_keys")]
    for c in ABL_CODES + ("u1",):
        need += ["%s.c101.parts.%s.%s" % (R15, c, f) for f in ("lost", "of", "lost_keys", "long_lost", "long_of")]
    for c in ("v", "k", "c"):
        need += ["%s.lad26.%s.%s" % (R15, c, f) for f in ("lost", "of", "lost_keys")]
        need += ["%s.lad26.%s.%s.%s" % (R15, c, d, f) for d in ("d4000ms", "d5000ms") for f in ("lost", "of")]
    # the group R16 (rule R142): the sets, R1 and R3 per code and duration, R2 per code and event, R4
    need += list(LEAVES16) + [R16 + ".sets.r1.keys", R16 + ".sets.r1.buses", R16 + ".sets.r1.by_duration_ms",
                              R16 + ".sets.c101_fault_buses", R16 + ".sets.r3.keys", R16 + ".sets.r2.events",
                              R16 + ".sets.r2.buses", R16 + ".sets.r2.sizes_pu", R16 + ".r2.P_path_by_size",
                              "s60r.v6.p_nr.h_not_eligible_reason", "s60r.v6.t_parts.ladder.c",
                              "s60r.v6.p_nr.ladder"]
    for fam, durs in (("r1", ("d1000ms", "d2000ms", "d5000ms")), ("r3", ("d4000ms", "d5000ms"))):
        for c in PART_CODES + ("k",):
            need += ["%s.%s.%s.%s" % (R16, fam, c, f) for f in ("lost", "of", "lost_keys", "returned_limiter_engaged")]
            need += ["%s.%s.%s.%s.%s" % (R16, fam, c, d, f) for d in durs for f in ("lost", "of")]
    for c in laws[:]:
        if c != "h":
            need += ["%s.r2.per_code.%s.%s" % (R16, c, f) for f in ("lost", "of", "returned", "engaged_print")]
    for c in PART_CODES:
        need += ["%s.r2.per_code.%s.lost" % (R16, c), "%s.c101.parts.%s.lost_keys" % (R15, c)]
    # the group R17 (rule R145): the eleven codes per run on Q1 and Q2 and their counts; the note's and the test's leaves
    need += [R17 + ".sets.codes", R17 + ".q1.keys", R17 + ".q2.keys", R17 + ".ran.lad78.every_cell_every_code",
             R17 + ".vf.per_bus"] + list(LEAVES17) + [R16 + ".r1.v.lost", R16 + ".r1.c.lost", R16 + ".r3.v.lost",
                                                      R16 + ".r3.c.lost"]
    for c in (opt(m, R17 + ".sets.codes") or []):
        for q, durs in (("q1", ("d1000ms", "d2000ms", "d5000ms")), ("q2", ("d4000ms", "d5000ms"))):
            need += ["%s.%s.%s.%s" % (R17, q, c, f) for f in (
                "lost", "of", "lost_keys", "returned", "returned_at_rest", "returned_not_at_rest",
                "returned_limiter_engaged", "returned_limiter_engaged_keys", "not_eligible_keys", "per_key",
                "rows_of_record", "rows_of_record_n", "rows_new_n", "new_tags")]
            need += ["%s.%s.%s.%s.%s" % (R17, q, c, d, f) for d in durs for f in ("lost", "of")]
    # the ladder's faults through the low fault resistance, the 78's per-cell verdicts and Section V-D's count (d1)
    need += list(LEAVES_LAD) + [LRF, LRX, A2 + ".per_cell", A2 + ".lost_of_78_by_setting",
                                A2 + ".compared_settings_of_the_ladder", R17 + ".ran.lad78.cells",
                                R17 + ".ran.lad78.codes", R17 + ".d1.of_record_78.cells",
                                R17 + ".d1.of_record_78.per_cell", R17 + ".d1.q1.keys", R17 + ".d1.q2.keys"]
    return [p for p in need if opt(m, p) is None]


INP = {}                 # the inputs file (data/record/inputs.json), read once in either mode


def laws_table(m):
    """the 14 columns: the Current Compass, then Table II of the paper in its order (PUBLISHED and BASELINES,
    families grouped as FAMILIES there); names and colours of the inputs file (INP)"""
    published, baselines, family, families = INP["published"], INP["baselines"], INP["family"], INP["families"]
    names, pal = INP["names"], INP["colours"]
    pub_of = {fam: (ref, pub, sel) for fam, ref, pub, sel in published}
    rows = [{"code": "v", "name": names["compass"], "mode": "compass", "group": "This paper",
             "setting": "this paper", "colour": pal["compass"], "line": "-", "ref": ""}]
    for label, fams in families:
        for fam in fams:
            ref, pub, sel = pub_of[fam]
            rows.append({"code": pub, "name": names[fam], "mode": fam, "group": label.rstrip(":"),
                         "setting": "published", "colour": pal[fam], "line": "-", "ref": ref})
            if sel:
                rows.append({"code": sel, "name": names[fam] + ", selected", "mode": fam,
                             "group": label.rstrip(":"), "setting": "selected", "colour": pal[fam], "line": ":",
                             "ref": ref})
    for fam, code in baselines:
        rows.append({"code": code, "name": names[fam], "mode": fam, "group": "Baselines",
                     "setting": "baseline", "colour": pal[fam], "line": "-", "ref": ""})
    compared = get(m, "chain.census.form.compared_laws")
    assert sorted(r["code"] for r in rows[1:]) == sorted(compared), "Table II and the census differ"
    for r in rows[1:]:
        assert family[r["code"]] == r["mode"], r
    # the parts of the law: the rows of Table III with the paper's own row labels (the inputs file's parts), in
    # the order of PART_CODES (the law's neighbours first); the circular limiter, the rotation and the cap in their
    # palette hues; the forms that carry the Compass's turn without its palette entry in the Compass's hue: the Fixed
    # Quarter Turn dashed, the cap and fixed quarter turn without release dash-dot, the cap and rotation without
    # release dotted (part 16, the decider's ruling of 21:16 UTC)
    parts = dict(INP["parts"])
    assert sorted(parts) == sorted(PART_CODES) and parts["v"] == rows[0]["name"], parts
    look = {"u1": ("fixedturn", pal["compass"], "--"), "f": ("fixedturn", pal["compass"], "-."),
            "z": ("norel", pal["compass"], ":"), "c": ("cap", pal["cap"], "-"), "e": ("rot", pal["rot"], "-"),
            "n": ("native", pal["native"], "-")}
    others = [{"code": c, "name": parts[c], "mode": look[c][0], "group": "Ablation", "setting": "ablation",
               "colour": look[c][1], "line": look[c][2], "ref": ""} for c in PART_CODES[1:]]
    return rows, others, {"published": "data/record/inputs.json published, baselines, families",
                          "family": "data/record/inputs.json family", "names": "data/record/inputs.json names",
                          "parts": "data/record/inputs.json parts (Table III's row labels)",
                          "colours": "data/record/inputs.json colours"}


def h_ineligible_short(m):
    """h's ineligible SHORT keys (the census line of the inputs file); the eligible keys are the rest"""
    return INP["h_short_ineligible"]["keys"], INP["h_short_ineligible"]["src"]


def scenario_words(m):
    """the words of the key grammar, as Section IV of the paper words the scenarios ("at
    base load or with load and dispatch at <system.loadScale_second_point>", "without line 17-18 or with unit 8
    under GFL control", "with or without line 1-39"; three-phase or single-line-to-ground (SLG) faults)"""
    ls = get(m, "system.loadScale_second_point")
    assert abs(ls - 0.9) < 1e-12  # the key writes it as 09
    return {"type": {"T": "three-phase", "S": "single-line-to-ground"},
            "type_short": {"T": "3-ph", "S": "SLG"},
            "load": {"10": "base load", "09": "load and dispatch at %g" % ls},
            "state": {"F": "base network", "W": "without line 1-39", "O1718": "without line 17-18",
                      "U08": "unit 8 under GFL control"},
            # a ladder key's fault resistance token (the key's end), by the leaf the label prints
            "rf_leaf": {LOW_RF: FR + ".low_pu"},
            "src": "Section IV of the paper (the sentence of the common scenarios); "
                   "system.loadScale_second_point; %s (the ladder's keys through the low resistance)" % FR}


def scenario_keys(m):
    """THE ONE PLACE where the application's scenario table is built: the group R15's 101 common scenarios
    (sets.c101.keys), every one kept by the set's rule (kept), in the order bus, duration, load, type, network; the
    short ones (0.3 to 1 s) equal the record's short keys (SHORT_KEYS), the long ones (2 to 5 s) equal the record's
    long keys plus the group's 12 new keys (sets.c101.new_keys); every count asserted"""
    assert get(m, R15 + ".sets.c101.max_duration_ms") == MAX_MS, "the set's rule differs from the record's"
    keys = list(get(m, R15 + ".sets.c101.keys"))
    assert len(set(keys)) == len(keys) and all(kept(k) for k in keys), "the group's keys break the set's rule"
    short = sorted((k for k in keys if parse_key(k)["dur_ms"] <= 1000), key=order)
    long_ = sorted((k for k in keys if parse_key(k)["dur_ms"] > 1000), key=order)
    new = sorted(get(m, R15 + ".sets.c101.new_keys"))
    rec_short = sorted(k for k in get(m, SHORT_KEYS) if kept(k))
    assert sorted(short) == rec_short, "the short scenarios differ from the record's"
    if MODE == "full":                           # the older record's list of the long keys: a check of the full mode
        _CHECK[0] = True
        rec_long = sorted(k for k in get(m, LONG_KEYS) if kept(k))
        assert not set(new) & set(rec_long) and sorted(long_) == sorted(rec_long + new), "the long scenarios"
        _CHECK[0] = False
    rec_long = sorted(set(long_) - set(new))
    assert len(short) == get(m, R15 + ".sets.c101.n_short"), (len(short), "short")
    assert len(long_) == get(m, R15 + ".sets.c101.n_long"), (len(long_), "long")
    assert len(keys) == get(m, R15 + ".sets.c101.n_keys")
    assert len(new) == get(m, R15 + ".sets.c101.new_n")
    assert len(rec_short) + len(rec_long) == get(m, R15 + ".sets.c101.of_record_n")
    return short, long_, set(new)


def class_of(k):
    """the group R15's class of a common scenario: 0.3 s, 0.5 and 1 s, or 2 to 5 s"""
    d = parse_key(k)["dur_ms"]
    return "d0300ms" if d == 300 else ("d0500_1000ms" if d in (500, 1000) else "long_to5s")


def grid(m, laws):
    """the scenario table: one row a common scenario of the group R15 (101), one cell a law (R returns, L loses
    synchronism, N not counted), read from R15.c101.laws.<code> (its classes' lost and not-eligible keys); the 89
    scenarios of record are checked against the census (short) and the census's long lost keys kept by the rule"""
    short, long_, new = scenario_keys(m)
    keys = short + long_
    ns = len(short)
    cls = ["SHORT"] * ns + ["LONG"] * len(long_)
    e1 = get(m, "s60r.e1.per_key")
    abl = At(m, "chain.ablation.per_key.v")
    lv = get(m, R15 + ".c101.laws.v")
    cols = [r["code"] for r in laws]
    cells, compass = [], {}
    for k, cl in zip(keys, cls):
        row = []
        for c in cols:
            if c == "v":
                if cl == "SHORT":
                    w = e1[k]["word"]
                    compass[k] = {"key": k, "word": w, "t_ret_s": e1[k]["t_ret_s"], "t_lost_s": None,
                                  "swing_fine_deg": e1[k]["swing_fine_deg"], "src": "s60r.e1.per_key." + k}
                    row.append(WORD[w])
                elif k not in new:
                    w = abl["s" + k]["word"]
                    compass[k] = {"key": k, "word": w, "t_ret_s": abl["s" + k]["t_s"] if w != "LOST" else None,
                                  "t_lost_s": abl["s" + k]["t_s"] if w == "LOST" else None,
                                  "swing_fine_deg": None, "src": "chain.ablation.per_key.v.s" + k}
                    row.append(WORD[w])
                else:                            # a new key of the group: its verdict from the group R15; its return
                    w = "LOST" if k in lv["lost_keys"] else "RETURNS"     # time where R16 holds it (part 16)
                    tr = opt(m, "%s.app.v_t_ret_s.%s" % (R16, k)) if w == "RETURNS" else None
                    assert tr is None or (isinstance(tr, (int, float)) and tr > 0), (k, tr)
                    compass[k] = {"key": k, "word": w, "t_ret_s": tr, "t_lost_s": None, "swing_fine_deg": None,
                                  "src": R15 + ".c101.laws.v (lost_keys)" + (
                                      "; %s.app.v_t_ret_s.%s" % (R16, k) if tr is not None else "")}
                    row.append("L" if w == "LOST" else "R")
                continue
            lw = get(m, "%s.c101.laws.%s.%s" % (R15, c, class_of(k)))
            row.append("N" if k in lw["not_eligible_keys"] else ("L" if k in lw["lost_keys"] else "R"))
        cells.append("".join(row))
    # the assertions: every column against the group R15 (on the whole set, per class, the long part, the lost
    # keys) and, on the scenarios of record, against the census
    vcol = [r[0] for r in cells]
    rec = [k not in new for k in keys]
    h_ine, h_src = h_ineligible_short(m)
    if "h" in cols:
        jh = cols.index("h")
        assert sorted(k for k, r in zip(short, cells[:ns]) if r[jh] == "N") == sorted(h_ine), "h short eligibility"
    for j, c in enumerate(cols):
        col = [r[j] for r in cells]
        sh, lo = col[:ns], col[ns:]
        lw = get(m, "%s.c101.laws.%s" % (R15, c))
        assert col.count("L") == lw["lost"], (c, col.count("L"), lw["lost"])
        assert col.count("L") + col.count("R") == lw["of"], (c, "of")
        assert lo.count("L") == lw["long_lost"] and lo.count("L") + lo.count("R") == lw["long_of"], (c, "long")
        assert sorted(k for k, r in zip(keys, col) if r == "L") == sorted(lw["lost_keys"]), (c, "lost_keys")
        for q in CLASSES:
            cq = [r for k, r in zip(keys, col) if class_of(k) == q]
            assert cq.count("L") == lw[q]["lost"] and cq.count("L") + cq.count("R") == lw[q]["of"], (c, q)
            assert cq.count("N") == len(lw[q]["not_eligible_keys"]), (c, q, "not eligible")
        if c == "v":
            assert sh.count("R") == get(m, "s60r.e1.returns")
            assert col.count("L") == get(m, R15 + ".c101.v.lost"), ("v", col.count("L"))
            assert lo.count("L") == get(m, R15 + ".c101.v.long_lost"), ("v long", lo.count("L"))
            assert "N" not in col
            continue
        if MODE != "full":                       # the census of the older record: a check of the full mode
            continue
        _CHECK[0] = True
        pl = get(m, "chain.census.per_law.%s.SHORT" % c)
        assert sh.count("L") == pl["n_lost"], (c, "SHORT")
        assert sh.count("R") == pl["n_returned"], (c, "SHORT")
        assert sh.count("N") == pl["n_ineligible"], (c, "SHORT")
        pll = get(m, "chain.census.per_law.%s.LONG" % c)
        if pll["n_ineligible"] == 0:
            lo_rec = [r for r, ok in zip(lo, rec[ns:]) if ok]
            assert lo_rec.count("L") == len([q for q in pll["lost_keys"] if kept(q)]), (c, "LONG of record")
        _CHECK[0] = False
    # the parts of the law (Table III's rows u1, f, z, c, e, n) on every common scenario, from the group's parts; on
    # the scenarios of record checked against chain.ablation.per_key.<code> and s60r.e2; the run tags of record
    # (a live run reruns a tag of record; the Compass's short rows are FMCv<key>, s60r.e1._src); a new key
    # scenario carries no tag here (no live run is offered for it)
    if MODE == "full":                           # the record's own words of its tags: a check of the full mode
        assert "FMCv<key>" in get(m, "s60r.e1.per_key._src_all")
    tags = {"v": ["FMCv" + k if cl == "SHORT" else ("" if k in new else abl["s" + k]["tag"])
                  for k, cl in zip(keys, cls)]}
    abl_cells = {}
    assert sorted(ABL_CODES + ("u1",)) == sorted(PART_CODES[1:])
    for code in PART_CODES[1:]:
        pr = get(m, "%s.c101.parts.%s" % (R15, code))
        assert pr["of"] == len(keys), (code, "counted on every common scenario")
        ac = "".join("L" if k in pr["lost_keys"] else "R" for k in keys)
        assert ac.count("L") == pr["lost"] and ac[ns:].count("L") == pr["long_lost"], code
        assert pr["long_of"] == len(long_), code
        if code == "u1":
            e2 = get(m, "s60r.e2.per_key")
            assert MODE != "full" or "FMCu1<key>" in e2["_src_all"]
            assert all(WORD[e2[k]["word"]] == ac[i] for i, k in enumerate(short)), "u1 short against s60r.e2"
            assert ac[:ns].count("R") == get(m, "s60r.e2.returns") and ac[:ns].count("L") == get(m, "s60r.e2.lost")
            tags["u1"] = ["FMCu1" + k if cl == "SHORT" else "" for k, cl in zip(keys, cls)]
        else:
            pk = At(m, "chain.ablation.per_key." + code)
            for i, k in enumerate(keys):
                if k not in new:
                    assert WORD.get(pk["s" + k]["word"], "?") == ac[i], (code, k, "against the per-key record")
            # the parts' run tags of record: the runs' own tags, from the inputs of the runs' outcomes (the record's
            # tag fields of these keys name the reader's files, which the released record does not hold)
            tg = RO["tags_of_record"][code]
            tags[code] = ["" if k in new else tg.get(k, "") for k in keys]
        abl_cells[code] = ac
    # the totals: every law's from the group R15 (returned = of - lost)
    totals = {}
    for c in cols:
        lw = get(m, "%s.c101.laws.%s" % (R15, c))
        totals[c] = {"n_returned": lw["of"] - lw["lost"], "n_eligible": lw["of"], "n_lost": lw["lost"],
                     "src": "derived: %s.c101.laws.%s of and lost (returned = of - lost)" % (R15, c)}
    # wins, ties and losses of the Compass against each law: the grid's per-key cells counted; on the short
    # scenarios equal to s60r.comparison.per_law.<c>.SHORT, on the long scenarios of record to the per-key leaves
    # win_keys and loss_keys of s60r.comparison.per_law.<c>.LONG kept by the set's rule; the group's new keys counted
    # from their cells
    cmp_ = {}
    for j, c in enumerate(cols):
        if c == "v":
            continue
        col = [r[j] for r in cells]

        def tally(idx):
            w = t = lo_ = nc = 0
            for i in idx:
                vv, cc = vcol[i], col[i]
                if cc == "N":
                    nc += 1
                elif vv == "R" and cc == "L":
                    w += 1
                elif vv == "L" and cc == "R":
                    lo_ += 1
                elif vv == cc:
                    t += 1
            return w, t, lo_, nc
        ws, ts, ls, ncs = tally(range(ns))
        wl, tl, ll, ncl = tally([i for i in range(ns, len(keys)) if rec[i]])
        if MODE == "full":                       # the older record's comparison: a check of the full mode
            _CHECK[0] = True
            x = get(m, "s60r.comparison.per_law.%s.SHORT" % c)
            assert (ws, ts, ls) == (x["wins"], x["ties"], x["losses"]), (c, "SHORT", ws, ts, ls)
            assert ns - ncs == x["n_eligible"], (c, "SHORT eligible")
            y = get(m, "s60r.comparison.per_law.%s.LONG" % c)
            assert wl == len([q for q in y["win_keys"] if kept(q)]), (c, "LONG wins")
            assert ll == len([q for q in y["loss_keys"] if kept(q)]), (c, "LONG losses")
            _CHECK[0] = False
        wn, tn, ln, ncn = tally([i for i in range(ns, len(keys)) if not rec[i]])
        cmp_[c] = {"wins": ws + wl + wn, "ties": ts + tl + tn, "losses": ls + ll + ln,
                   "not_counted": ncs + ncl + ncn, "n": len(keys),
                   "src": "derived: the grid's per-key cells counted; the short scenarios' counts equal "
                          "s60r.comparison.per_law.%s.SHORT, the long ones of record its LONG win_keys and loss_keys "
                          "of the set; the %d new keys of the group from %s.c101.laws" % (c, len(new), R15)}
    return {"cols": cols, "keys": keys, "cls": cls, "parsed": [parse_key(k) for k in keys], "cells": cells,
            "rule_max_ms": get(m, R15 + ".sets.c101.max_duration_ms"),
            "words": scenario_words(m), "ablation_cells": abl_cells, "tags": tags,
            "codes": {"R": "returns", "L": "loses synchronism", "N": "not eligible"},
            "compass": [compass[k] for k in keys], "totals": totals,
            "sources": {"keys": [R15 + ".sets.c101.keys", SHORT_KEYS],
                        "compass": "s60r.e1.per_key (the short scenarios), chain.ablation.per_key.v and "
                                   + R15 + ".c101.laws.v (the long ones)",
                        "laws": R15 + ".c101.laws.<code>.<class>.lost_keys and not_eligible_keys",
                        "h_short_eligibility": h_src,
                        "ablation": R15 + ".c101.parts.<code>; checked against chain.ablation.per_key.<code> and "
                                    "s60r.e2"}}


SHORT_LAD_MS = (300, 1000, 2000)     # the ladder's three-phase faults of record below 4 s (s60r.e3.ladder)
H_CUT = " (MH0h_10F)"                # the reason's own record reference, cut from the words the screen prints


def ladder(m, laws, others, grid_):
    """the fault-location ladder at the ladder's 13 buses, at base load in the base network: the three-phase faults
    of 0.3, 1 and 2 s (s60r.e3.cells, words; s60r.v6.t_parts.ladder.c and s60r.v6.p_nr.ladder.<code>.0p01pu, the lost
    buses per duration, for the codes s60r.e3 does not hold), the three-phase faults of 4 and 5 s (R15.lad26 for the
    law, the cap alone and [9], asserted equal to R16.r3; R16.r3 for the other parts), the SLG faults of 1, 2 and 5 s
    of rule R142 R1 (R16.r1); and the three-phase faults of 0.15, 0.3 and 1 s through the low fault resistance (FR
    low_pu; the keys end "_0p001pu"; per code and duration from LRF, LRX or p_nr.ladder.<code>.0p001pu, per cell
    checked against A2.per_cell, as the faults of 0.3 to 2 s through the base resistance are). Cells: R returns, E
    returns with a limiter engaged at the end (a limiter flag in the last 1 s; read per key on R1 and R3 only), L
    loses synchronism, N not run. The columns: Table III's rows (the
    law first) and the compared settings in Table II's order; the published setting of cross-forming control is not
    shown (not eligible at base load in the base network: s60r.v6.p_nr.h_not_eligible_reason). Every count asserted
    per code and duration; every ladder key that is also a common scenario asserted equal to the grid's cell. The
    five decisive faults of Section V-D are marked from the record's own keys (R17.d1), and the marks are asserted
    to be exactly the ladder's faults on which all twelve compared settings lose"""
    e3c = At(m, "s60r.e3.cells")
    e3l = At(m, "s60r.e3.ladder")
    tp = get(m, "s60r.v6.t_parts.ladder")
    nr = get(m, "s60r.v6.p_nr.ladder")
    L26 = get(m, R15 + ".lad26")
    R1 = get(m, R16 + ".r1")
    R3 = get(m, R16 + ".r3")
    # the faults through the low resistance: one record of lost buses per code and duration; the per-cell verdicts
    lrf, lrx = get(m, LRF), get(m, LRX)
    pcell = get(m, A2 + ".per_cell")
    twelve = get(m, A2 + ".compared_settings_of_the_ladder").split()
    rfb, rfl = get(m, FR + ".base_pu"), get(m, FR + ".low_pu")
    for tok, v in ((BASE_RF, rfb), (LOW_RF, rfl)):          # the tokens name the record's two resistances
        assert abs(float(tok[:-2].replace("p", ".")) - v) < 1e-12, (tok, v)

    def low_src(c):
        """a code's record of the lost buses per duration through the low resistance (exactly one source a code)"""
        s = [x for x in (lrf.get(c) if c in lrf else None, lrx.get(c),
                         nr[c][LOW_RF] if c in nr and LOW_RF in nr[c] else None) if x is not None]
        assert len(s) == 1, (c, "the low-resistance ladder: one source a code", len(s))
        return s[0]

    def per_cell(c, rf, p):
        """a cell's verdict in A2.per_cell (the twelve by their returned codes, the seven rows of Table III by word)"""
        x = pcell["%s_%04d_%02d" % (rf, p["dur_ms"], p["bus"])]
        assert x["twelve_lost"] + len(x["twelve_returned"]) == len(twelve) and set(x["twelve_returned"]) <= set(twelve)
        if c in twelve:
            return "R" if c in x["twelve_returned"] else "L"
        return {"RETURNS": "R", "LOST": "L"}[x[c]]
    # rule R145 (R17): the eleven other compared settings on the same two families, per run (verdict, rest, limiter at
    # the end, return time); the keys a code had run before are its rows of record (rows_of_record), counted once
    N17 = list(get(m, R17 + ".sets.codes"))
    Q17 = {"S": get(m, R17 + ".q1"), "T": get(m, R17 + ".q2")}
    buses = list(get(m, R16 + ".sets.r1.buses"))
    assert buses == sorted(buses) and buses == list(get(m, R16 + ".sets.c101_fault_buses")), "the ladder's buses"
    # the columns: every code of the paper's rows that the ladder holds, h out (its reason asserted held)
    compared = [r["code"] for r in laws[1:]]
    cols = list(PART_CODES) + [c for c in compared if c != "h"]
    assert "not steady" in get(m, "s60r.v6.p_nr.h_not_eligible_reason") and H_CUT in get(
        m, "s60r.v6.p_nr.h_not_eligible_reason")
    assert "h" not in e3c and "h" not in tp and "h" not in nr and "h" not in R1 and "h" not in R3
    # the rows: the three-phase ladder through the base resistance (0.3, 1 and 2 s), the same through the low one
    # (0.15, 0.3 and 1 s: Fig. 6's 78 ladder faults, Table III's order), through the base resistance at 4 and 5 s,
    # then the SLG ladder (1, 2 and 5 s)
    k3 = ["%02d_%04d_10TF" % (b, d) for d in SHORT_LAD_MS for b in buses]
    low_ms = sorted(int(d[1:5]) for d in low_src("v") if re.match(r"^d\d{4}ms$", d))
    kL = ["%02d_%04d_10TF_%s" % (b, d, LOW_RF) for d in low_ms for b in buses]
    assert sorted(pcell) == sorted(["%s_%04d_%02d" % (BASE_RF, d, b) for d in SHORT_LAD_MS for b in buses]
                                   + ["%s_%04d_%02d" % (LOW_RF, d, b) for d in low_ms for b in buses]), "A2's cells"
    assert get(m, R17 + ".ran.lad78.cells") == len(pcell) == len(k3) + len(kL), "the 78 ladder faults of up to 2 s"
    # the keys' words (three-phase, base load, base network) against the record's own tags of these runs
    for c in nr:
        for cid, x in get(m, "s60r.v6.p_nr.cells." + c).items():
            if cid.startswith(LOW_RF + "_"):
                assert x["tag"].endswith("%s_%s_10TF" % (cid[-2:], cid[len(LOW_RF) + 1:len(LOW_RF) + 5])), (c, cid)
    k4 = sorted(get(m, R15 + ".sets.lad26.keys_4s"), key=order)
    k5 = sorted(get(m, R15 + ".sets.lad26.keys_5s"), key=order)
    assert sorted(k4 + k5) == sorted(get(m, R16 + ".sets.r3.keys")), "R3's keys are the ladder's 26"
    assert [parse_key(k)["bus"] for k in k4] == buses == [parse_key(k)["bus"] for k in k5]
    ks = sorted(get(m, R16 + ".sets.r1.keys"), key=lambda k: (parse_key(k)["dur_ms"], parse_key(k)["bus"]))
    assert len(ks) == get(m, R16 + ".sets.r1.n") and all(parse_key(k)["type"] == "S" and k.endswith("_10SF")
                                                         for k in ks)
    byd = get(m, R16 + ".sets.r1.by_duration_ms")
    assert {parse_key(k)["dur_ms"] for k in ks} == {int(d) for d in byd}
    assert all(sum(parse_key(k)["dur_ms"] == int(d) for k in ks) == byd[d] for d in byd)
    keys = k3 + kL + k4 + k5 + ks
    assert len(set(keys)) == len(keys) and all(kept(k) for k in keys), "the ladder's keys break the set's rule"
    assert sorted(get(m, R17 + ".q1.keys")) == sorted(ks) and sorted(get(m, R17 + ".q2.keys")) == sorted(k4 + k5)
    assert not set(N17) & (set(PART_CODES) | {"k"}) and set(N17) <= {r["code"] for r in laws[1:]}, N17

    def by_buses(x, k):
        """a cell from a per-duration record of the lost buses (all 13 run, asserted)"""
        assert x["of"] == len(buses) and x["lost"] == len(x["buses"]), x
        if "returned" in x:
            assert x["returned"] == x["of"] - x["lost"], x
        return "L" if parse_key(k)["bus"] in x["buses"] else "R"

    def engaged(fam, c):
        """the keys whose return ends with a limiter engaged, per key where the record lists them"""
        x = fam[c]
        if "returned_limiter_engaged_keys" in x:
            ek = set(x["returned_limiter_engaged_keys"])
            assert len(ek) == x["returned_limiter_engaged"], (c, "engaged keys")
            return ek
        assert x["returned_limiter_engaged"] == 0, (c, "engaged without a key list")
        return set()

    # part 19 (worker NUM's N4, where the record holds it): the eight codes of Table III and [9] per run on the same two
    # families, in R17's form under R19.q1 and q2 (per_key with the same fields); read only in that form, else the
    # cards keep "at rest" from the counts (R16.r1 and r3), as before
    Q19 = {"S": opt(m, R19 + ".q1"), "T": opt(m, R19 + ".q2")}

    def has19(c, k):
        q = Q19[parse_key(k)["type"]]
        x = q.get(c) if isinstance(q, dict) else None
        return isinstance(x, dict) and isinstance(x.get("per_key"), dict) and k in x["per_key"] and all(
            f in x["per_key"][k] for f in ("verdict", "word", "REST", "SATEND", "limiter_engaged_at_end", "T_RET"))

    def run17(c, k, Q=None):
        """a run of rule R145 (R17.q1 or q2; or of R19 for the eight): its cell and its words (rest, return time),
        from the per-run leaves"""
        q = (Q or Q17)[parse_key(k)["type"]][c]
        x = q["per_key"][k]
        assert x.get("eligible", True) is True and k not in q.get("not_eligible_keys", []), (c, k)
        if x["verdict"] == "LOST":
            assert x["word"] == "LOST" and x["REST"] == "LOST" and x["limiter_engaged_at_end"] is False, (c, k, x)
            assert x["T_RET"] == "na" and k in q.get("lost_keys", [k]), (c, k, x)
            return "L", ""
        assert x["verdict"] == "RETURNS" and k not in q.get("lost_keys", []) and x["REST"] in ("AT REST",
                                                                                              "NOT AT REST"), x
        assert x["limiter_engaged_at_end"] == (x["SATEND"] != "0"), (c, k, x)
        # the words of a return: settled or not (the map-word rule), or, on a row of record of R19, re-read A's own
        # verdict with its return time
        assert x["word"] in ("RETURNS SETTLED", "RETURNS NOT SETTLED", "RETURNS (re-read A)"), (c, k, x)
        assert (x["T_RET"] == "na") == (x["word"] == "RETURNS NOT SETTLED"), (c, k, x)
        w = "E" if x["limiter_engaged_at_end"] else "R"
        rest = "at rest" if x["REST"] == "AT REST" else "not at rest"
        if x["T_RET"] == "na":
            return w, rest + ", not settled: no return time"
        assert float(x["T_RET"]) > 0, (c, k, x)
        return w, "%s, return time %s s after clearing" % (rest, x["T_RET"])

    def detail(c, k):
        """the words of one run beyond its cell: its rest and return time where the record holds them per run (R17);
        at rest where every return of the code on the family is at rest (R16.r1 and r3: returned_at_rest equal to
        returned, asserted); nothing on the ladder's faults of 0.3 to 2 s"""
        p = parse_key(k)
        if p["type"] != "S" and p["dur_ms"] not in (4000, 5000):
            return ""
        if c in N17:
            return run17(c, k)[1]
        fam = R1 if p["type"] == "S" else R3
        if has19(c, k):                            # the eight, per run (R19), asserted against R16's cell below
            w, words = run17(c, k, Q19)
            x = fam[c]
            assert w == ("L" if k in x["lost_keys"] else ("E" if k in engaged(fam, c) else "R")), (c, k, "R19/R16")
            return words
        if c not in fam or k in fam[c]["lost_keys"] or k in fam[c].get("not_eligible_keys", []):
            return ""
        x = fam[c]
        assert x["returned_at_rest"] == x["returned"] == x["of"] - x["lost"] and x["returned_not_at_rest"] == 0, c
        return "at rest"

    def cell(c, k):
        p = parse_key(k)
        d, dd = p["dur_ms"], "d%04dms" % p["dur_ms"]
        if p.get("rf") == LOW_RF:                  # through the low resistance: 0.15, 0.3 and 1 s
            w = by_buses(low_src(c)[dd], k)
            assert w == per_cell(c, LOW_RF, p), (c, k, "the low-resistance ladder against A2.per_cell")
            return w
        if p["type"] == "S":                       # R1: the SLG ladder, Table III's rows and [9]
            if c in N17:
                return run17(c, k)[0]
            if c not in R1:
                return "N"
            x = R1[c]
            if k in x["not_eligible_keys"]:
                return "N"
            if k in x["lost_keys"]:
                return "L"
            return "E" if k in engaged(R1, c) else "R"
        if d in (4000, 5000):                      # R3 and R15.lad26
            if c in N17:
                w = run17(c, k)[0]
                if c in e3c and k in e3c[c]:
                    assert WORD[e3c[c][k]] == ("L" if w == "L" else "R"), (c, k, "s60r.e3 against R17.q2")
                return w
            if c not in R3:
                return "N"
            w = "L" if k in R3[c]["lost_keys"] else ("E" if k in engaged(R3, c) else "R")
            if c in L26:
                assert ("L" if k in L26[c]["lost_keys"] else "R") == ("L" if w == "L" else "R"), (c, k, "lad26")
            if c in e3c and k in e3c[c]:
                assert WORD[e3c[c][k]] == ("L" if w == "L" else "R"), (c, k, "s60r.e3 against R16.r3")
            return w
        if c in e3c:                               # 0.3, 1 and 2 s
            w = WORD[e3c[c][k]]
            if c in tp:
                assert by_buses(tp[c][dd], k) == w, (c, k, "t_parts against s60r.e3")
        elif c in tp:
            w = by_buses(tp[c][dd], k)
        elif c in nr:
            w = by_buses(nr[c][BASE_RF][dd], k)
        else:
            return "N"
        assert w == per_cell(c, BASE_RF, p), (c, k, "the ladder of 0.3 to 2 s against A2.per_cell")
        return w
    rows = ["".join(cell(c, k) for c in cols) for k in keys]
    details = ["|".join(detail(c, k) for c in cols) for k in keys]
    n19 = 0                                        # the eight per run (R19): whole families only, their rests counted
    for t, ks_, fam in (("S", ks, R1), ("T", k4 + k5, R3)):
        for c in PART_CODES + ("k",):
            h = [has19(c, k) for k in ks_]
            if all(h):
                x = Q19[t][c]
                assert sorted(x["per_key"]) == sorted(ks_), (c, t, "R19 per_key")
                rest = [x["per_key"][k]["REST"] for k in ks_ if k not in fam[c]["lost_keys"]]
                assert rest.count("AT REST") == fam[c]["returned_at_rest"], (c, t, "R19 at rest")
                n19 += 1
            else:
                assert not any(h), (c, t, "R19 holds some runs of a family and not all")
    if has(m, R19) and not n19:
        print("make_app_data: %s holds no per-run record of the eight in the form read here: the cards keep "
              "'at rest' from the counts" % R19)

    def check17(c, col, ks_, t):
        """a code of rule R145 on one family (t: S the SLG faults, T those of 4 and 5 s): its cells against the record's
        counts in all and per duration, its lost and limited keys, its rests; its rows of record and its new rows"""
        x = Q17[t][c]
        assert sorted(x["per_key"]) == sorted(ks_), (c, t, "per_key")
        v = [col[k] for k in ks_]
        assert v.count("L") == x["lost"] and len(v) == x["of"] and "N" not in v, (c, t)
        assert v.count("R") + v.count("E") == x["returned"] and v.count("E") == x["returned_limiter_engaged"], (c, t)
        assert sorted(k for k in ks_ if col[k] == "L") == sorted(x["lost_keys"]), (c, t, "lost_keys")
        assert sorted(k for k in ks_ if col[k] == "E") == sorted(x["returned_limiter_engaged_keys"]), (c, t)
        rest = [x["per_key"][k]["REST"] for k in ks_ if col[k] != "L"]
        assert rest.count("AT REST") == x["returned_at_rest"], (c, t, "at rest")
        assert rest.count("NOT AT REST") == x["returned_not_at_rest"], (c, t, "not at rest")
        for d in sorted({parse_key(k)["dur_ms"] for k in ks_}):
            xd = x["d%04dms" % d]
            vd = [col[k] for k in ks_ if parse_key(k)["dur_ms"] == d]
            assert vd.count("L") == xd["lost"] and len(vd) == xd["of"], (c, t, d)
        rec = sorted(k for k in ks_ if x["per_key"][k]["new"] is False)
        assert rec == sorted(x["rows_of_record"]) and len(rec) == x["rows_of_record_n"], (c, t, "rows of record")
        assert all(x["per_key"][k]["row"] == x["rows_of_record"][k] for k in rec), (c, t, "rows of record")
        new_ = [x["per_key"][k]["row"] for k in ks_ if x["per_key"][k]["new"] is True]
        assert len(new_) == x["rows_new_n"] and sorted(new_) == sorted(x["new_tags"]), (c, t, "new rows")
    # the assertions per code: the 0.3 to 2 s ladder against its counts, R3 and R1 against R16 per duration and in all
    for j, c in enumerate(cols):
        col = {k: r[j] for k, r in zip(keys, rows)}

        def count(ks_, x, what):
            v = [col[k] for k in ks_]
            assert v.count("L") == x["lost"], (c, what, "lost")
            assert v.count("L") + v.count("R") + v.count("E") == x["of"], (c, what, "of")
            if "returned_limiter_engaged" in x:
                assert v.count("E") == x["returned_limiter_engaged"], (c, what, "engaged")
        for d in SHORT_LAD_MS:
            dd = "d%04dms" % d
            kd = [k for k in k3 if parse_key(k)["dur_ms"] == d]
            src = (e3l[c][dd] if c in e3l else tp[c][dd] if c in tp else nr[c]["0p01pu"][dd] if c in nr else None)
            assert src is not None, (c, dd, "a code of the ladder without its 0.3 to 2 s record")
            count(kd, src, dd)
            assert "E" not in [col[k] for k in kd]
        ls_ = low_src(c)                           # through the low resistance, per duration and in all
        assert sorted(d for d in ls_ if re.match(r"^d\d{4}ms$", d)) == ["d%04dms" % d for d in low_ms], c
        for d in low_ms:
            count([k for k in kL if parse_key(k)["dur_ms"] == d], ls_["d%04dms" % d], "%s %d" % (LOW_RF, d))
        vl = [col[k] for k in kL]
        assert "E" not in vl and "N" not in vl, (c, LOW_RF)
        if "lost_of_39" in ls_:
            assert vl.count("L") == ls_["lost_of_39"], (c, LOW_RF, "lost of 39")
        if "returned" in ls_:
            assert vl.count("R") == ls_["returned"], (c, LOW_RF, "returned")
        assert [col[k] for k in k3 + kL].count("L") == get(m, A2 + ".lost_of_78_by_setting")[c], (c, "of the 78")
        if c in R3:
            count(k4, R3[c]["d4000ms"], "R3 4 s")
            count(k5, R3[c]["d5000ms"], "R3 5 s")
            count(k4 + k5, R3[c], "R3")
            if c in L26:
                count(k4 + k5, L26[c], "lad26")
        elif c in N17:
            check17(c, col, k4 + k5, "T")
        else:
            assert {col[k] for k in k4 + k5} == {"N"}, (c, "not run at 4 and 5 s")
        if c in R1:
            for d in sorted({parse_key(k)["dur_ms"] for k in ks}):
                count([k for k in ks if parse_key(k)["dur_ms"] == d], R1[c]["d%04dms" % d], "R1 %d" % d)
            count(ks, R1[c], "R1")
        elif c in N17:
            check17(c, col, ks, "S")
        else:
            assert {col[k] for k in ks} == {"N"}, (c, "not run on the SLG ladder")
    for fam, nm in ((R1, "R1"), (R3, "R3")):     # the codes each family ran: Table III's seven rows and [9]
        assert {c for c in fam if isinstance(fam[c], dict) and "lost_keys" in fam[c]} == set(PART_CODES) | {"k"}, nm
    # every column ran every fault of the ladder: the record's statement (R17.ran), asserted on the cells
    assert get(m, R17 + ".ran.all_three_groups_ran_by_the_law_its_parts_and_the_twelve") is True
    assert get(m, R17 + ".ran.lad78.every_cell_every_code") is True
    assert set(cols) == set(PART_CODES) | {"k"} | set(N17) and not any("N" in r for r in rows), "a run is missing"
    assert sorted(get(m, R17 + ".ran.lad78.codes")) == sorted(cols), "the 78's codes are the ladder's columns"
    assert sorted(twelve) == sorted(set(cols) - set(PART_CODES)), "the twelve compared settings of the ladder"
    # every ladder key that is a common scenario: the same verdict as the grid's (the laws) and the parts' cells
    gk = {k: i for i, k in enumerate(grid_["keys"])}
    shared = 0
    for k, r in zip(keys, rows):
        if k not in gk:
            continue
        i = gk[k]
        for j, c in enumerate(cols):
            w = r[j].replace("E", "R")
            if w == "N":
                continue
            g = grid_["cells"][i][grid_["cols"].index(c)] if c in grid_["cols"] else grid_["ablation_cells"][c][i]
            if g != "N":
                assert g == w, (k, c, "the ladder against the grid", g, w)
                shared += 1
    # THE FIVE DECISIVE FAULTS of Section V-D, from the record's own keys (R17.d1: the cells of the 78 and the keys of
    # Q1 and Q2), asserted: the count read every ladder key, and the marks are exactly the ladder's faults on which
    # all twelve compared settings lose; on each the circular limiter alone loses (d1) and the law returns
    d1 = get(m, R17 + ".d1")
    marked = list(d1["q1"]["keys"]) + list(d1["q2"]["keys"])
    assert sorted(x["cell"] for x in d1["of_record_78"]["per_cell"]) == sorted(d1["of_record_78"]["cells"])
    for x in d1["of_record_78"]["per_cell"]:
        tok = x["cell"].split("_")[0]
        assert tok in (BASE_RF, LOW_RF) and x["type"] == "three-phase", x
        assert abs(x["resistance_pu"] - (rfl if tok == LOW_RF else rfb)) < 1e-12, x
        ms = round(1000 * x["duration_s"])
        assert x["cell"] == "%s_%04d_%02d" % (tok, ms, x["bus"]), x
        marked.append("%02d_%04d_10TF" % (x["bus"], ms) + ("_" + LOW_RF if tok == LOW_RF else ""))
    assert len(set(marked)) == len(marked) == d1["n"] and set(marked) <= set(keys), marked
    assert d1["keys_read"]["all"] == len(keys), ("Section V-D's count read every ladder key", len(keys))
    jt = [cols.index(c) for c in twelve]
    all12 = [k for k, r in zip(keys, rows) if all(r[j] == "L" for j in jt)]
    assert sorted(all12) == sorted(marked), ("the faults on which all twelve lose", all12)
    also = set(d1["q1"]["circular_limiter_alone_also_lost"]) | set(d1["q2"]["circular_limiter_alone_also_lost"])
    also |= {"%s_%s_10TF" % (c[-2:], c.split("_")[1]) + ("_" + LOW_RF if c.startswith(LOW_RF + "_") else "")
             for c in d1["of_record_78"]["circular_limiter_alone_also_lost"]}
    assert also == set(marked) and len(also) == d1["circular_limiter_alone_also_lost_n"], also
    assert d1["circular_limiter_alone_on_all"] is True
    for k in marked:
        r = rows[keys.index(k)]
        assert r[cols.index("v")] in "RE" and r[cols.index("n")] == "L", (k, r)

    def cls_of(k):
        p = parse_key(k)
        return "%s%04d" % (p["type"], p["dur_ms"]) + ("_" + p["rf"] if p.get("rf") else "")

    # the groups: by fault type, resistance and duration (Table III's order); each with the leaf of its resistance
    groups = []
    for k in keys:
        p = parse_key(k)
        cl = cls_of(k)
        if not groups or groups[-1]["cls"] != cl:
            low = p.get("rf") == LOW_RF
            groups.append({"cls": cl, "type": p["type"], "dur_ms": p["dur_ms"], "n": 0,
                           "rf_leaf": FR + (".low_pu" if low else ".base_pu"),
                           "engaged_read": p["type"] == "S" or (not low and p["dur_ms"] in (4000, 5000))})
        groups[-1]["n"] += 1
    assert len({g["cls"] for g in groups}) == len(groups), "a group split"
    hr = get(m, "s60r.v6.p_nr.h_not_eligible_reason")
    names = {r["code"]: r["name"] for r in laws + others}
    return {"cols": cols, "keys": keys, "cells": rows, "groups": groups,
            "cls": [cls_of(k) for k in keys],
            "durations_ms": sorted({parse_key(k)["dur_ms"] for k in keys}),
            "in_grid": [k in gk for k in keys], "checked_against_grid": shared, "detail": details,
            "marks": [k in marked for k in keys],
            "decisive": {"keys": [k for k in keys if k in marked], "n": d1["n"], "n_word": d1["n_word"],
                         "twelve": twelve, "limiter_alone_lost_on_all": d1["circular_limiter_alone_on_all"],
                         "src": "%s.d1 (of_record_78.cells and q1/q2.keys; keys_read.all = the ladder's %d keys); "
                                "asserted: exactly the ladder's faults on which all twelve compared settings "
                                "(%s.compared_settings_of_the_ladder) lose; the circular limiter alone loses on "
                                "each, the law returns" % (R17, len(keys), A2)},
            "detail_src": "per run, the columns joined by a bar: rest and return time after clearing from "
                          "%s.q1 and %s.q2 per_key (the eleven other compared settings) and, where the record holds "
                          "them, %s.q1 and %s.q2 per_key (the eight: %d families of code read); else at rest from "
                          "%s.r1 and %s.r3 (returned_at_rest equal to returned)" % (R17, R17, R19, R19, n19, R16, R16),
            "codes": {"R": "returns", "E": "returns, a limiter engaged at the end", "L": "loses synchronism",
                      "N": "not eligible"},
            "not_shown": {"code": "h", "name": names["h"], "reason": hr[:hr.index(H_CUT)],
                          "src": "s60r.v6.p_nr.h_not_eligible_reason"},
            "src": "s60r.e3.cells (words) and s60r.e3.ladder (counts); s60r.v6.t_parts.ladder.c and "
                   "s60r.v6.p_nr.ladder.<code>.0p01pu (lost buses per duration); %s.lad26 and %s.r3 (4 and 5 s); "
                   "%s.r1 (SLG); limited at the end: %s.r1 and %s.r3 returned_limiter_engaged_keys; the eleven "
                   "other compared settings on the SLG faults and the faults of 4 and 5 s: s60r.v6.r17.q1 and q2 "
                   "per_key; through the low resistance: %s, %s and s60r.v6.p_nr.ladder.<code>.0p001pu (lost buses "
                   "per duration); every cell of the 78 checked against %s.per_cell and every code's losses on them "
                   "against %s.lost_of_78_by_setting"
                   % (R15, R16, R16, R16, R16, LRF, LRX, A2, A2)}


def loadsteps(m, cols):
    """the six load steps without a fault of rule R142 R2 (R16.sets.r2.events: two sizes at buses 23, 29 and 25), one
    row an event, one column a code (the ladder's columns: the codes R2 ran, Table III's rows and the twelve compared
    settings eligible at base load in the base network). Cells from R16.r2.cells.<code>.<event>: R returns (at
    rest), E returns with a limiter engaged at the end, L loses synchronism; asserted against R16.r2.per_code.<code>
    (losses, returns, returns at rest, the limited ones, the events named). The rows grouped by the step's size, the
    smaller step first (Fig. 6's order), the buses ascending; the words of each row from R16.r2.events.<event>"""
    S2 = get(m, R16 + ".sets.r2")
    R2 = get(m, R16 + ".r2")
    ev = list(S2["events"])
    assert len(ev) == S2["n"] and sorted(R2["events"]) == sorted(ev) and sorted(R2["cells"]) == sorted(R2["per_code"])
    assert sorted(R2["per_code"]) == sorted(cols), ("the load steps' codes are the ladder's", sorted(R2["per_code"]))
    E = R2["events"]
    sizes = list(S2["sizes_pu"])
    assert sorted({E[e]["size_pu"] for e in ev}) == sorted(sizes) and sorted({E[e]["bus"] for e in ev}) == sorted(
        S2["buses"])
    # the smaller step first: the larger resistance in pu draws the smaller power (asserted on the law's row)
    by = R2["P_path_by_size"]
    sz = {by[g]["size_pu"]: g for g in by}
    assert sorted(sz) == sorted(sizes)
    small, large = sorted(sizes, reverse=True)
    assert by[sz[small]]["max_MW"] < by[sz[large]]["min_MW"], "the smaller step"
    ev = sorted(ev, key=lambda e: (-E[e]["size_pu"], E[e]["bus"]))
    rows, cells = [], []
    for e in ev:
        x = E[e]
        g = sz[x["size_pu"]]
        assert by[g]["min_MW"] <= x["P_path_MW"]["v"] <= by[g]["max_MW"]
        rows.append({"event": e, "bus": x["bus"], "group": g,
                     "name": "bus %d, %s MW" % (x["bus"], x["P_path_print"]),
                     "P_MW_print": x["P_path_print"], "src": "%s.r2.events.%s" % (R16, e)})
        r = ""
        for c in cols:
            ce = R2["cells"][c][e]
            if ce["verdict"] == "LOST":
                r += "L"
            else:
                assert ce["verdict"] == "RETURNS" and ce["at_rest"] is True, (c, e, ce)
                r += "E" if ce["engaged_at_end"] else "R"
        cells.append(r)
    totals = {}
    for j, c in enumerate(cols):
        pc = R2["per_code"][c]
        col = [r[j] for r in cells]
        assert pc["eligible_10F"] is True and pc["not_eligible_events"] == [] and pc["of"] == len(ev), c
        assert col.count("L") == pc["lost"] and col.count("R") + col.count("E") == pc["returned"], c
        assert pc["returned_at_rest"] == pc["returned"] and pc["returned_not_at_rest"] == 0, c
        assert pc["returned_not_settled"] == 0, c
        assert col.count("E") == pc["returned_limiter_engaged"], c
        assert sorted(e for e, w in zip(ev, col) if w == "L") == sorted(pc["lost_events"]), c
        assert sorted(e for e, w in zip(ev, col) if w == "E") == sorted(pc["returned_limiter_engaged_events"]), c
        totals[c] = {"returned": pc["returned"], "of": pc["of"], "lost": pc["lost"],
                     "engaged": pc["returned_limiter_engaged"], "engaged_print": pc["engaged_print"],
                     "src": "%s.r2.per_code.%s" % (R16, c)}
    groups = []
    for g, s, step in ((sz[small], small, "smaller"), (sz[large], large, "larger")):
        mw = get(m, "%s.r2.P_path_by_size_print.%s" % (R16, "0p%dpu" % round(10 * s)))
        groups.append({"cls": g, "step": step, "name": "the %s step, %s MW" % (step, mw),
                       "n": sum(r["group"] == g for r in rows), "MW_print": mw,
                       "src": "%s.r2.P_path_by_size.%s and P_path_by_size_print" % (R16, g)})
    assert all(gr["MW_print"] == "%s to %s" % (by[gr["cls"]]["min_print"], by[gr["cls"]]["max_print"]) for gr in groups)
    # the smaller step's test fixed before the runs (R17.vf): its buses are the smaller step's, it passed at each, and
    # on each the law's cell is a return; the words are the screen's, from the leaves
    vf = get(m, R17 + ".vf")
    assert abs(vf["size_pu"] - small) < 1e-12, (vf["size_pu"], small)
    assert sorted(vf["buses"]) == sorted(r["bus"] for r in rows if r["group"] == sz[small]), vf["buses"]
    assert vf["passed_at_all_three"] is True and all(vf["per_bus"][str(b)]["passed"] is True for b in vf["buses"])
    jv = cols.index("v")
    assert all(cells[i][jv] in "RE" for i, r in enumerate(rows) if r["group"] == sz[small]), "the law at the smaller step"
    return {"cols": cols, "events": ev, "rows": rows, "cells": cells, "groups": groups, "totals": totals,
            "set_print": S2["print"],
            "codes": {"R": "returns", "E": "returns, a limiter engaged at the end", "L": "loses synchronism"},
            "src": "%s.r2.cells.<code>.<event> (verdict, at rest, engaged at the end), asserted against "
                   "%s.r2.per_code.<code>; the rows from %s.r2.events and %s.sets.r2" % (R16, R16, R16, R16)}


# ------------------------------------------------------------------------------------------------------ Table IV
# Table IV of the paper (Section V-F, "Robustness: Losses With One Setting Varied"), as the paper binds it: the 18
# scenarios of
# R140.sets.s18; per row the counts of R140.s18.table.<setting>.<v|k> (v the Current Compass, k the law of [8] in the
# column beside it); the cap factor's first cell from R19.t4.cells.capf_0p7 (Table II's a/b form, the eligible only);
# the current limits from R15.lim.<v|k>.<limit>; the note's six other published laws from R15.lim_d2.<code>.<limit>.
# A cell group is joined by ", ", two groups of one row by "; " (the paper's row "Voltage filter; decay"); "-" where
# the row is not a setting of [8]. Every count is asserted against its leaf; main() asserts the paper's build equal.
R140 = "s60r.v6.r140"
T4 = R19 + ".t4.cells.capf_0p7"
LIM = ("1p1", "1p15", "1p2", "1p4")
ROB_ROWS = (("design", [["design"]], [["design"]]),
            ("floor", [["floor_0p3", "floor_0p4", "floor_0p6", "floor_0p7"]], None),
            ("gain", [["gain_10", "gain_40"]], None),
            ("capf", [["T4", "capf_0p9", "capf_1p0"]], None),
            ("ratio", [["ratio_2", "ratio_5"]], None),
            ("vfilt_decay", [["vfilt_2", "vfilt_10"], ["decay_5", "decay_20"]], None),
            ("lim", [["lim_" + x for x in LIM]], [["lim_" + x for x in LIM]]),
            ("pll", [["pll_3p2", "pll_9p0"]], [["pll_3p2", "pll_9p0"]]),
            ("droop", [["droop_0p5", "droop_2"]], [["droop_0p5", "droop_2"]]))


def robustness(m):
    """Table IV's cells and its 18 scenarios from the record, every count asserted against its leaf"""
    S = At(m, R140 + ".sets.s18")
    keys = list(S["keys"])
    ks = set(keys)
    assert len(keys) == S["n_keys"] == len(ks) and all(KEY_RE.match(k) and kept(k) for k in keys), "the 18"
    tab = At(m, R140 + ".s18.table")
    t4 = get(m, T4)
    assert t4["rows"] == len(keys) and t4["pass"] + t4["perturbed"] == t4["rows"], "the cap factor's rows"
    assert t4["pass_are_the_load_0p9_rows"] is True and t4["perturbed_are_the_base_load_rows"] is True
    assert t4["cap_below_every_base_load_dispatch"] is True
    assert t4["ab_print_table_ii_form"] == "%d/%d" % (t4["lost_among_pass"], t4["pass"]), "the a/b form"
    pk = set(t4["perturbed_keys"])
    assert pk <= ks and len(pk) == t4["perturbed"], "the perturbed keys are of the 18"
    assert all(parse_key(k)["load"] == "10" for k in pk) and all(parse_key(k)["load"] == "09" for k in ks - pk)
    lp = set(t4["lost_among_pass_keys"])
    assert lp <= ks - pk and len(lp) == t4["lost_among_pass"], "the losses among the eligible"
    cells = {}

    def put(cid, who, lost, eligible, rows, lost_keys, prt, path):
        assert rows == len(keys) and len(set(lost_keys)) == len(lost_keys) == lost and set(lost_keys) <= ks, (cid, who)
        assert prt == (str(lost) if eligible == rows else "%d/%d" % (lost, eligible)), (cid, who, prt)
        cells.setdefault(cid, {})[who] = {"print": prt, "lost": lost, "eligible": eligible, "of": rows,
                                          "lost_keys": sorted(lost_keys, key=order), "path": path}

    for cid, x in tab.items():
        for who, c in x.items():
            p = "%s.s18.table.%s.%s" % (R140, cid, who)
            if cid == "capf_0p7" and who == "v":
                continue                          # the paper prints R19's cell (below), not this one
            put(cid, who, c["lost"], c["eligible"], c["rows"], c["lost_keys"], c["cell_print"], p + ".cell_print")
    put("T4", "v", t4["lost_among_pass"], t4["pass"], t4["rows"], t4["lost_among_pass_keys"],
        t4["ab_print_table_ii_form"], T4 + ".ab_print_table_ii_form")
    for who in ("v", "k"):
        for x in LIM:
            c = get(m, "%s.lim.%s.%s" % (R15, who, x))
            assert c["E"] == c["of"] == len(keys) and c["cell_print"] == str(c["L"]), (who, x)
            if who == "v":
                assert abs(c["cap_factor"] * c["limit_pu"] - 1.0) < 1e-12, x
            put("lim_" + x, who, c["L"], c["E"], c["of"], c["lost_keys"], c["cell_print"],
                "%s.lim.%s.%s.cell_print" % (R15, who, x))
    rows = []
    def txt(groups, who):
        return "; ".join(", ".join(cells[c][who]["print"] for c in grp) for grp in groups)

    for rid, vg, kg in ROB_ROWS:
        rows.append({"row": rid, "v": txt(vg, "v"), "k": txt(kg, "k") if kg else "-",
                     "v_cells": [c for grp in vg for c in grp], "k_cells": [c for grp in kg for c in grp] if kg else []})
    lim6 = []
    for code, x in At(m, R15 + ".lim_d2").items():
        if not isinstance(x, (dict, At)) or "ref" not in x:
            continue
        pr, lk = [], []
        for l_ in LIM:
            c = x[l_]
            assert c["E"] == c["of"] == len(keys) and c["cell_print"] == str(c["L"]), (code, l_)
            assert len(set(c["lost_keys"])) == len(c["lost_keys"]) == c["L"] and set(c["lost_keys"]) <= ks, (code, l_)
            pr.append(c["cell_print"])
            lk.append(sorted(c["lost_keys"], key=order))
        lim6.append({"code": code, "ref": x["ref"], "prints": pr, "lost_keys": lk,
                     "path": "%s.lim_d2.%s.<limit>.cell_print" % (R15, code)})
    lim6.sort(key=lambda r: int(re.match(r"^\[(\d+)\]$", r["ref"]).group(1)))
    assert len(lim6) == 6, "the note's six other published laws"
    wr = get(m, R140 + ".s18.note.without_release_v_keys")
    assert len(wr) == get(m, R140 + ".s18.note.without_release_v") and set(wr) <= ks, "without the release"
    note = {"without_release_v": get(m, R140 + ".s18.note.without_release_v"),
            "without_release_v_keys": sorted(wr, key=order),
            "pll_fast_v_returns_unsettled": get(m, R140 + ".s18.note.pll_fast_v_returns_unsettled")}
    return {"keys": sorted(keys, key=order), "n": len(keys), "keys_src": R140 + ".sets.s18.keys",
            "rows": rows, "cells": cells, "lim6": lim6, "note": note,
            "capf_0p7": {"print": t4["ab_print_table_ii_form"], "cap_factor": t4["cap_factor"],
                         "eligible_keys": sorted(ks - pk, key=order),
                         "not_eligible_keys": sorted(pk, key=order), "src": T4},
            "src": "%s.sets.s18, %s.s18.table, %s, %s.lim, %s.lim_d2, %s.s18.note" % (R140, R140, T4, R15, R15, R140)}


def granted_check(m, g):
    """R4, the granted control of [13]: the law's own losses at its two settings (R16.r4.published and .selected)
    are the grid's counts of its two columns on the 101, every one explained by the granted reactance; with the
    fault-on reactance granted it returns on all 101 at both settings (R16.r4.MAd, .MAq)"""
    R4 = get(m, R16 + ".r4")
    assert R4["both_settings_return_on_all_101"] is True
    n = get(m, R15 + ".sets.c101.n_keys")
    for arm, x in (("published", R4["published"]), ("selected", R4["selected"])):
        c = x["code"]
        assert x["law_losses_on_101"] == g["totals"][c]["n_lost"], (arm, c, "the grid's count")
        assert x["explained"] == x["law_losses_on_101"] and x["granted_returns"] == x["of"] == n, (arm, c)
        assert R4[x["arm"]]["returns"] == R4[x["arm"]]["of"] == n and R4[x["arm"]]["lost"] == 0, (arm, c)
    assert R4["print"] == "%d of the %d" % (n, n)
    fam = [r for r in laws_table(m)[0] if r["code"] in (R4["published"]["code"], R4["selected"]["code"])]
    assert len(fam) == 2 and fam[0]["mode"] == fam[1]["mode"], "R4's two settings are one law's"




def series(m):
    """per-key lists for small charts: none in this build (the Overview's cards print the paper's own leaves, and
    the paper prints no per-run list behind them)"""
    return {}


def runs():
    """the run files (data/runs and its index): Fig. 7's traces (the rows its panels draw at bus 39, unit 10: the
    series of panels (a) to (d)), shipped as data under the runs' tags; the full mode writes them from the record's
    registered exports (RUN_FILES, before this step), the release mode reads them as shipped; the index (key, code,
    file, sha256, tag) is regenerated in either mode from the inputs' trace list and the files' own bytes"""
    out_dir = DATA / "runs"
    assert MODE == "full" or out_dir.resolve() != (SRC_DATA / "runs").resolve(), "the release mode never writes app/data"
    if MODE == "release":
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True)
    src = (SRC_DATA if MODE == "release" else DATA) / "runs"
    idx = []
    TRACES.clear()
    for x in RO.get("traces", []):
        f = src / x["file"]
        assert f.is_file(), ("a run file of the trace list is missing", x["file"])
        idx.append({"key": x["key"], "code": x["code"], "file": x["file"], "sha256": sha256(f), "tag": x["tag"]})
        TRACES[x["tag"]] = "runs/" + x["file"]
    write_json(out_dir / "index.json", {"schema": "cca-runs/2", "runs": idx,
                                        "series": RO.get("trace_series", {}),
                                        "src": "Fig. 7's traces: the rows its panels draw, under their tags"})
    return idx


# ------------------------------------------------------------------------------------------- the list of the runs
# app_runs.json: ONE ROW FOR EVERY ROW OF THE CAMPAIGN TABLE (artifacts/campaign/campaign_table_paper.tsv, a released
# file), in its order, with its 13 fields as they stand, the record's scenario key, the run's outcome in the paper's
# words, what the data hold for it beside the outcome, the sets in which it is the run the paper counts, the paper's
# places that count its scenario and its run file. An outcome is the record's: per key and code where the record holds
# the scenario's outcome (the grid, the ladder, the load steps, Table IV), per tag where the record holds the run's
# own (data/record/run_outcomes.json, written by the full mode: values and tags only); every count asserted against
# the paper's printed counts; where the record holds neither, the neutral word and the row's place
TABLE_COLS = ("tag", "set", "code", "law", "setting", "fault_bus", "fault_kind", "fault_ms", "fault_r_pu", "event",
              "load", "network", "args_sha256")
RUN_COLS = TABLE_COLS + ("key", "outcome", "detail", "counts_in", "place", "trace")
SETS = ("common scenarios", "shortened runs", "ladder 0.01 pu", "ladder 0.001 pu", "faults of 4 and 5 s",
        "single-phase ladder", "load steps", "Table IV", "reruns", "theory checks", "module search", "fault-free row")
NEUTRAL = "in the printed count"
OUTCOMES = (
    ("returned", "R", "the run returned to synchronism after the fault was cleared or the event ended (the paper: "
                      "returns)"),
    ("returned, a limiter engaged at the end", "E", "the run returned, with a current limiter still engaged at the "
                                                    "end of its record (Table III, ending with a limiter engaged)"),
    ("lost", "L", "the run lost synchronism (the Lost columns of Tables II and III, Fig. 6)"),
    ("not eligible", "N", "the law's fault-free run at this load and network state is not steady, so the paper does "
                          "not count this scenario for the law (Table II, a/b: of the b eligible)"),
    ("steady", "R", "a fault-free run that is steady (Section IV: a law is eligible on a scenario if its fault-free "
                    "run is steady)"),
    ("not steady", "L", "a fault-free run that is not steady"),
    ("identical", "R", "a rerun at a solver tolerance ten times tighter, identical to its first run (Section V-D)"),
    ("verdict unchanged", "R", "a rerun with both steps halved whose verdict is that of its first run (Section V-D)"),
    (NEUTRAL, "C", "the record holds the printed count of this run's family, not this run's own outcome: the row's "
                   "place names the number that counts it; where another run of the same law, setting and scenario "
                   "holds the count, the detail says so"))
LETTER = {"R": "returned", "E": "returned, a limiter engaged at the end", "L": "lost", "N": "not eligible"}
NET = {"base": "F", "line 17-18 out": "O1718", "unit 8 under GFL control": "U08", "line 1-39 out": "W"}
KIND = {"three-phase": "T", "SLG": "S"}
LOADK = {"1.0": "10", "0.9": "09"}
STEP = re.compile(r"^resistive load through (0\.\d+) pu at bus (\d+), on at \d+ s for \d+ s$")
# Table IV's settings as the campaign table prints them -> the record's cell ids (R140.s18.table, R19's cap factor cell
# T4, R15.lim); the law of [9] at its published setting is the table's design column for k
ROB_SET = {"design": "design", "published": "design", "cap factor 0.7": "T4", "cap factor 0.9": "capf_0p9",
           "cap factor 1": "capf_1p0", "release ratio 2": "ratio_2", "release ratio 5": "ratio_5",
           "voltage filter 2 ms": "vfilt_2", "voltage filter 10 ms": "vfilt_10", "decay 5 ms": "decay_5",
           "decay 20 ms": "decay_20", "PLL of the GFL units 3.2 Hz": "pll_3p2", "PLL of the GFL units 9.0 Hz": "pll_9p0",
           "droop slope 0.5 times design": "droop_0p5", "droop slope 2 times design": "droop_2"}
for _x, _y in (("0.3", "0p3"), ("0.4", "0p4"), ("0.6", "0p6"), ("0.7", "0p7")):
    ROB_SET["reactive-power floor %s pu" % _x] = "floor_" + _y
for _x, _y in (("10", "10"), ("40", "40")):
    ROB_SET["rotation gain %s rad/s per pu" % _x] = "gain_" + _y
for _x, _y in zip(("1.1", "1.15", "1.2", "1.4"), LIM):
    ROB_SET["current limit %s pu" % _x] = "lim_" + _y
    ROB_SET["current limit %s pu, cap factor 1/limit" % _x] = "lim_" + _y
S2 = R140 + ".stepb.s2"          # the reruns of Section V-D (T: tolerance ten times tighter; H: both steps halved)
S5 = R140 + ".stepb.s5"          # the ten SLG faults at bus 37 at every floor, gain and release constant (Table IV)
# the paper's places that count a set's runs: the record paths of the printed leaves that count them ({c} the code);
# the places are those of the printed leaves (the numbers view), in the paper's order
PLACE_PATHS = {
    "common scenarios": (R15 + r"\.c101\.(?:laws|parts)\.{c}\.", R15 + r"\.c101\.{c}\.", R16 + r"\.r4\.",
                         r"s60r\.v6\.p_rt\.rows\.{c}\."),
    "shortened runs": (r"s60r\.v6\.t_dur\.laws\.{c}\.",),
    "ladder 0.01 pu": (r"s60r\.v6\.t_parts\.ladder\.{c}\.", r"s60r\.v6\.p_nr\.ladder\.{c}\.", A2 + r"\.lost_of_78",
                       r"s60r\.v6\.p_na\.totals\.{c}\."),
    "ladder 0.001 pu": (LRF.replace(".", r"\.") + r"\.{c}\.", LRX.replace(".", r"\.") + r"\.{c}\.",
                        r"s60r\.v6\.p_nr\.ladder\.{c}\.", A2 + r"\.lost_of_78", r"s60r\.v6\.p_na\.totals\.{c}\."),
    "faults of 4 and 5 s": (R15 + r"\.lad26\.{c}\.", R16 + r"\.r3\.{c}\.", R17 + r"\.q2\."),
    "single-phase ladder": (R16 + r"\.r1\.{c}\.", R17 + r"\.q1\."),
    "load steps": (R16 + r"\.r2\.", R17 + r"\.vf\."),
    "Table IV": (R140 + r"\.s18\.", R15 + r"\.lim", R19 + r"\.t4\.", S5.replace(".", r"\.") + r"\."),
    "reruns": (S2.replace(".", r"\.") + r"\.",),
    "theory checks": (TESTS.replace(".", r"\.") + r"\.", R15 + r"\.pooled\."),
    "module search": (r"s60r\.v6\.t_set\.module_search\.",),
    "fault-free row": (r"chain\.map\.note", R15 + r"\.c101\.laws\.{c}\.of\b"),
}


def table_rows():
    """the campaign table's rows (dicts of its 13 fields, its order) and its sha256; its header asserted"""
    p = Path(TABLE[0])
    b = p.read_bytes()
    txt = b.decode("ascii")
    assert "\r" not in txt and txt.endswith("\n"), "the campaign table: ASCII with LF line ends"
    lines = txt[:-1].split("\n")
    assert tuple(lines[0].split("\t")) == TABLE_COLS, "the campaign table's header"
    rows = []
    for ln in lines[1:]:
        f = ln.split("\t")
        assert len(f) == len(TABLE_COLS) and all(f), ("a row of the campaign table", ln[:60])
        rows.append(dict(zip(TABLE_COLS, f)))
    assert len({r["tag"] for r in rows}) == len(rows), "the campaign table's tags are unique"
    assert all(r["set"].split(" + ")[0] in SETS and set(r["set"].split(" + ")) <= set(SETS) for r in rows)
    return rows, hashlib.sha256(b).hexdigest()


def row_key(r):
    """the record's scenario key of a row, from its columns 6 to 12: a fault <bus>_<ms>_<load><T|S><state> (with
    _0p001pu through the low fault resistance); a load step its event <bus>_<a|b>; no disturbance its state"""
    if r["event"] != "-":
        g = STEP.match(r["event"])
        assert g and r["fault_bus"] == "-" and r["fault_kind"] == "none", r["tag"]
        return "%s_%s" % (g.group(2), {"0.2": "a", "0.1": "b"}[g.group(1)])
    if r["fault_bus"] == "-":
        assert r["fault_kind"] == "none" and r["fault_ms"] == "-" and r["fault_r_pu"] == "-", r["tag"]
        return LOADK[r["load"]] + NET[r["network"]]
    k = "%02d_%04d_%s%s%s" % (int(r["fault_bus"]), int(r["fault_ms"]), LOADK[r["load"]], KIND[r["fault_kind"]],
                              NET[r["network"]])
    assert r["fault_r_pu"] in ("0.01", "0.001"), r["tag"]
    return k + ("_" + LOW_RF if r["fault_r_pu"] == "0.001" else "")


def run_places(printed_rows):
    """per set and code, the paper's places of the printed leaves that count the set's runs (PLACE_PATHS)"""
    def places(s, c):
        out = []
        for pat in PLACE_PATHS[s]:
            rx = re.compile(r"(?:^|\s|\()" + pat.replace("{c}", re.escape(c)))
            for x in printed_rows:
                if rx.search(x["path"]) and x["place"] not in out:
                    out.append(x["place"])
        return out
    return places


def runs_table(m, g, laws, others):
    """app_runs.json (see the block's head): every row of the campaign table with its outcome; every count of a set
    asserted against the record's (and so the paper's) printed counts; a difference stops the data step"""
    rows, tsha = table_rows()
    ro = RO
    names = {r["code"]: r["name"] for r in laws + others}
    keys = [row_key(r) for r in rows]
    n = len(rows)
    out = {c: [] for c in RUN_COLS}
    given = [[] for _ in range(n)]                 # per row: (set, word, words) of each set that gives one
    counts = [[] for _ in range(n)]
    scen = {}                                      # per scenario (set, code, key, setting): its outcome
    with_outcome = {s: 0 for s in SETS}
    note = {}
    # the scenario groups: one law, setting and scenario in one set (a scenario counted once per set)
    grp = {}
    for i, r in enumerate(rows):
        for s in r["set"].split(" + "):
            grp.setdefault((s, r["code"], keys[i], r["setting"]), []).append(i)

    def put(i, s, word, words=""):
        """an outcome of row i in set s; resolved over the row's sets at the end (final())"""
        assert word in [w for w, _c, _m in OUTCOMES], word
        given[i].append((s, word, words))

    def final(i):
        """the row's outcome: the first set's own word (returned and returned with a limiter engaged agree, the
        second the more precise); the neutral word only where no set gives the run's own; its words with it"""
        own = [(s, w, x) for s, w, x in given[i] if w != NEUTRAL]
        if not own:
            s, w, x = given[i][0]
            return w, x
        ws = {w for _s, w, _x in own}
        if ws == {"returned", "returned, a limiter engaged at the end"}:
            ws = {"returned, a limiter engaged at the end"}
        assert len(ws) == 1, (rows[i]["tag"], "two sets give the run two outcomes", own)
        w = ws.pop()
        x = next((x for _s, w_, x in own if w_ == w and x), "")
        return w, x

    def scenario(s, code, k, setting, word, words="", tag_of_record=None):
        """a scenario's outcome on its rows: one run (or runs of one argument string, one simulation) carries it,
        the row the record names counting (else the first); of several runs with other arguments, the row the
        record names counts and carries it, the others the neutral word; where the record names none, every row
        carries the neutral word and the scenario's outcome in its detail"""
        ix = grp.get((s, code, k, setting))
        assert ix, ("a scenario of the record without its row in the campaign table", s, code, k, setting)
        assert (s, code, k, setting) not in scen, ("a scenario given twice", s, code, k, setting)
        scen[(s, code, k, setting)] = word
        named = [i for i in ix if tag_of_record and rows[i]["tag"] == tag_of_record]
        assert len(named) <= 1
        if len(ix) == 1 or len({rows[i]["args_sha256"] for i in ix}) == 1:
            first = named[0] if named else ix[0]
            for i in ix:
                put(i, s, word, words if i == first else (
                    "the same arguments as %s, which the paper counts" % rows[first]["tag"]))
            counts[first].append(s)
            return
        if named:
            put(named[0], s, word, words)
            counts[named[0]].append(s)
            for i in ix:
                if i != named[0]:
                    put(i, s, NEUTRAL, "the paper counts this scenario once, by %s" % tag_of_record)
            return
        # the record names no run: the scenario's first run in the table's order carries its count (FIX_1)
        first = ix[0]
        put(first, s, word, (words + "; " if words else "") + "the scenario's outcome as the paper counts it; this "
                                                              "scenario has %d runs of this law and setting" % len(ix))
        counts[first].append(s)
        for i in ix[1:]:
            put(i, s, NEUTRAL, "the paper counts this scenario once, by %s" % rows[first]["tag"])

    # the law's 279 fault runs of Sections V-B and V-C (the 101, the shortened runs, the ladders through 0.01 pu, of 4
    # and 5 s, the SLG ladder, through 0.001 pu): all returned, all at rest, none with a limiter engaged (R20.f1)
    f1 = {f: get(m, "s60r.v6.r20.f1." + f) for f in ("total", "returned", "at_rest", "limiter_engaged_at_end", "lost")}
    assert f1["total"] == f1["returned"] == f1["at_rest"] and f1["limiter_engaged_at_end"] == f1["lost"] == 0, f1
    CLS_WORDS = {"d0300ms": "of 0.3 s", "d0500_1000ms": "of 0.5 and 1 s", "long_to5s": "of 2 to 5 s"}

    def end_state(code, k, w):
        """a run's word and its end state on the common scenarios: at rest where every return of the law (or part)
        in the scenario's class is at rest without a limiter engaged; a limiter engaged where every one ends so;
        else the record's counts of the class (Table III and Fig. 6 count them; the record does not list the runs)"""
        if w != "R":
            return LETTER[w], ""
        if code == "v":
            return "returned", "at rest"
        if code in arms:
            return "returned", ""
        if code in g["cols"]:
            q = class_of(k)
            x = {f: get(m, "%s.c101.laws.%s.%s.%s" % (R15, code, q, f)) for f in (
                "lost", "of", "returned_not_at_rest", "returned_limiter_engaged")}
            ret, nar, eng = x["of"] - x["lost"], x["returned_not_at_rest"], x["returned_limiter_engaged"]
            who, where = "this law's", "on the common scenarios %s (Fig. 6)" % CLS_WORDS[q]
        else:
            q = "SHORT" if parse_key(k)["dur_ms"] <= 1000 else "LONG"
            x = {f: get(m, "%s.c101.parts.%s.%s.%s" % (R15, code, q, f)) for f in (
                "returns", "returns_not_at_rest", "returns_limiter_engaged_at_end")}
            ret, nar, eng = x["returns"], x["returns_not_at_rest"], x["returns_limiter_engaged_at_end"]
            who, where = "this part's", "%s returns on the common scenarios (Table III)" % q.lower()
        if nar == 0 and eng == 0:
            return "returned", "at rest"
        if nar == 0 and eng == ret:
            return "returned, a limiter engaged at the end", "at rest"
        return "returned", ("of %s %d %s, %d end with a limiter engaged and %d not at rest; the record counts them, "
                            "it does not list which runs" % (who, ret, where, eng, nar))

    # (1) THE COMMON SCENARIOS: the grid's cells (the law and the compared settings), the parts' cells, the granted
    # arms of [13] (returned on all 101 at both settings: R16.r4, asserted by granted_check)
    gk = {k: i for i, k in enumerate(g["keys"])}
    R4 = get(m, R16 + ".r4")
    arms = {R4["published"]["arm"]: R4["published"]["code"], R4["selected"]["arm"]: R4["selected"]["code"]}
    comp = {x["key"]: x for x in g["compass"]}
    seen = set()
    for (s, code, k, setting), ix in grp.items():
        if s != "common scenarios":
            continue
        assert k in gk, ("a common-scenario row off the 101", rows[ix[0]]["tag"], k)
        i = gk[k]
        if code in g["cols"]:
            w = g["cells"][i][g["cols"].index(code)]
        elif code in g["ablation_cells"]:
            w = g["ablation_cells"][code][i]
        else:
            assert code in arms and R4[code]["returns"] == R4[code]["of"] == len(g["keys"]) and R4[code]["lost"] == 0
            w = "R"
        word, words = end_state(code, k, w)
        if code == "v":
            x = comp[k]
            if x["t_ret_s"] is not None:
                words += ", return time %.4f s after clearing" % x["t_ret_s"]
        tag = None
        if code in g["tags"]:
            tag = g["tags"][code][i] or None
        scenario(s, code, k, setting, word, words, tag)
        seen.add((code, k))
    for c in list(g["cols"]) + list(g["ablation_cells"]) + list(arms):
        for k in g["keys"]:              # a scenario without the law's run: only where the law is not eligible
            assert (c, k) in seen or c in g["cols"] and g["cells"][gk[k]][g["cols"].index(c)] == "N", (
                "a law or part without a run on a common scenario where it is eligible", c, k)
    note["common scenarios"] = ("per scenario and law from the record's outcomes of the 101 common scenarios (Table "
                                "II's Lost column and Table III's rows, asserted equal to their counts); a return's end "
                                "state (at rest, a limiter engaged at the end) per run where the record makes it one "
                                "for every return of the class, else the record's counts in the detail (Table III's "
                                "engaged columns, Fig. 6's columns not at rest and limited at end); Table III's "
                                "return-time medians of the parts are printed numbers of the record, the law's own "
                                "return time stands per run")
    # (2) THE LADDERS: the ladder's cells and their words (rest, return time) per scenario and code
    L = g["ladder"]
    lk = {k: i for i, k in enumerate(L["keys"])}
    tag17 = {}
    for t, q in (("S", R17 + ".q1"), ("T", R17 + ".q2")):
        for c in get(m, R17 + ".sets.codes"):
            for k, x in At(m, "%s.%s.per_key" % (q, c)).items():
                tag17[(c, k)] = x["row"]
    for c in get(m, "s60r.v6.p_nr.ladder"):
        for cid in _peek(m, "s60r.v6.p_nr.cells." + c):
            tk = get(m, "s60r.v6.p_nr.cells.%s.%s.tag" % (c, cid))
            tok, ms, bus = cid.split("_")
            tag17[(c, "%s_%s_10TF" % (bus, ms) + ("_" + LOW_RF if tok == LOW_RF else ""))] = tk
    lad = {"ladder 0.01 pu": lambda p: p["type"] == "T" and p.get("rf") is None and p["dur_ms"] in SHORT_LAD_MS,
           "ladder 0.001 pu": lambda p: p.get("rf") == LOW_RF,
           "faults of 4 and 5 s": lambda p: p["type"] == "T" and p.get("rf") is None and p["dur_ms"] in (4000, 5000),
           "single-phase ladder": lambda p: p["type"] == "S"}
    for s, belongs in lad.items():
        done = set()
        for (s_, code, k, setting), ix in grp.items():
            if s_ != s:
                continue
            assert k in lk and belongs(parse_key(k)), ("a ladder row off its family", s, rows[ix[0]]["tag"], k)
            i, j = lk[k], L["cols"].index(code)
            w = L["cells"][i][j]
            assert w in "REL", (s, code, k, w)
            words = L["detail"][i].split("|")[j]
            # the run of record: the ladder's own tag where the record names one, else on a common scenario the
            # grid's (the ladder's cell is asserted equal to the grid's there)
            tag = tag17.get((code, k)) or (g["tags"][code][gk[k]] if k in gk and code in g["tags"] else "") or None
            if w == "R" and not words and s in ("ladder 0.01 pu", "ladder 0.001 pu") and code in PART_CODES:
                words = ("at rest" if code == "v" else "Table III counts this part's returns on the ladder that end "
                         "with a limiter engaged; the record does not list which runs")
            scenario(s, code, k, setting, LETTER[w], words, tag)
            done.add((code, k))
        want = {(c, k) for k in L["keys"] if belongs(parse_key(k)) for c in L["cols"]}
        assert done == want, (s, "the ladder's cells and the campaign table's rows", len(done), len(want))
        note[s] = "per scenario and law from the record's outcomes of the ladder (Table III's counts, Fig. 6, asserted)"
    # (3) THE LOAD STEPS: per event and code
    LS = g["loadsteps"]
    done = set()
    for (s, code, k, setting), ix in grp.items():
        if s != "load steps":
            continue
        i, j = LS["events"].index(k), LS["cols"].index(code)
        scenario(s, code, k, setting, LETTER[LS["cells"][i][j]], "at rest" if LS["cells"][i][j] in "RE" else "")
        done.add((code, k))
    assert done == {(c, e) for e in LS["events"] for c in LS["cols"]}, "the load steps' cells and the table's rows"
    note["load steps"] = "per event and law from the record's outcomes of the six load steps (asserted)"
    # (4) TABLE IV: per varied setting, law and scenario on the 18 (the count cells' lost keys and the cap factor's
    # eligible keys); the ten SLG faults at bus 37 at the twelve floor, gain and release settings (S5: all return)
    rob = g["robust"]
    r18 = set(rob["keys"])
    lim6 = {x["code"]: x for x in rob["lim6"]}
    s5 = {f: get(m, "%s.%s" % (S5, f)) for f in ("all_ten_return_at_every_tested_value", "R", "rows",
                                                  "returns_limiter_engaged", "ten_keys", "settings_n")}
    s5_rows = 0
    assert s5["all_ten_return_at_every_tested_value"] is True and s5["R"] == s5["rows"] and s5["returns_limiter_engaged"] == 0
    s5_settings = ("floor_0p3", "floor_0p4", "floor_0p6", "floor_0p7", "gain_10", "gain_40", "ratio_2", "ratio_5",
                   "vfilt_2", "vfilt_10", "decay_5", "decay_20")
    assert len(s5_settings) == s5["settings_n"]
    rob_cells = set()
    for (s, code, k, setting), ix in grp.items():
        if s != "Table IV":
            continue
        cid = ROB_SET[setting]
        if k not in r18:
            assert k in s5["ten_keys"] and code == "v" and cid in s5_settings, ("a Table IV row", rows[ix[0]]["tag"])
            scenario(s, code, k, setting, "returned", "at rest")
            s5_rows += len(ix)
            continue
        if code in ("v", "k"):
            c = rob["cells"][cid][code]
            if cid == "T4":
                w = "not eligible" if k in rob["capf_0p7"]["not_eligible_keys"] else (
                    "lost" if k in c["lost_keys"] else "returned")
            else:
                assert c["eligible"] == c["of"], (cid, code)
                w = "lost" if k in c["lost_keys"] else "returned"
        else:
            x = lim6[code]
            w = "lost" if k in x["lost_keys"][LIM.index(cid[4:])] else "returned"
        scenario(s, code, k, setting, w)
        rob_cells.add((cid, code, k))
    for cid, who in rob["cells"].items():
        for code in who:
            assert all((cid, code, k) in rob_cells for k in r18), ("a Table IV cell without its rows", cid, code)
    for code in lim6:
        assert all(("lim_" + x, code, k) in rob_cells for x in LIM for k in r18), ("the note's limits", code)
    assert s5_rows == s5["rows"], ("the ten SLG faults' new rows", s5_rows, s5["rows"])
    note["Table IV"] = ("per varied setting, law and scenario from the record's count cells of Table IV and its note "
                        "(asserted); the ten SLG faults at bus 37 at the twelve floor, gain and release settings all "
                        "returned (Section V-F)")
    # (5) THE RERUNS of Section V-D: two at a tolerance ten times tighter, identical; nine with both steps halved,
    # every verdict unchanged, four still toggling
    T = {f: get(m, "%s.T.%s" % (S2, f)) for f in ("rows_rerun", "channels_compared")}
    H = {f: get(m, "%s.H.%s" % (S2, f)) for f in ("rows", "K", "K_rows", "all_nine_verdicts_unchanged")}
    assert H["all_nine_verdicts_unchanged"] is True
    tt = [i for i, r in enumerate(rows) if r["set"].split(" + ")[0] == "reruns"]
    nt = nh = 0
    for i in tt:
        r = rows[i]
        if r["setting"] == "rerun at a solver tolerance ten times tighter":
            assert r["tag"] in T["channels_compared"], r["tag"]
            put(i, "reruns", "identical")
            nt += 1
        else:
            assert r["setting"] == "rerun with both steps halved", r["tag"]
            put(i, "reruns", "verdict unchanged", "still toggles" if r["tag"] in H["K_rows"] else "")
            nh += 1
        counts[i].append("reruns")
    assert (nt, nh) == (T["rows_rerun"], H["rows"]) and len(H["K_rows"]) == H["K"], (nt, nh)
    note["reruns"] = "per run from the record of Section V-D's reruns (asserted: 2 and 9 rows, 4 still toggling)"
    # (6) THE SHORTENED RUNS, THE MODULE SEARCH, THE FAULT-FREE ROWS: per run under its tag (run_outcomes.json)
    for s in ("shortened runs", "module search", "fault-free row"):
        got = ro["sets"].get(s, {})
        once = {}
        for i, r in enumerate(rows):
            if s not in r["set"].split(" + "):
                continue
            x = got.get(r["tag"])
            if x is None:
                put(i, s, NEUTRAL)
                continue
            sk = (r["code"], keys[i], r["setting"])
            if x.get("counted", True) and sk in once:     # one run counts a scenario; another keeps its own reading
                put(i, s, x["outcome"], "another run of this scenario, %s, carries its count" % rows[once[sk]]["tag"])
                continue
            put(i, s, x["outcome"], x.get("detail", ""))
            if x.get("counted", True):
                counts[i].append(s)
                once[sk] = i
        assert set(got) <= {r["tag"] for r in rows if s in r["set"].split(" + ")}, (s, "a tag off the table")
        note[s] = ro["notes"][s]
    # (7) THE THEORY CHECKS: the record holds their counts (Section V-E), not each run's outcome
    for i, r in enumerate(rows):
        if r["set"].split(" + ")[0] == "theory checks":
            put(i, "theory checks", NEUTRAL)
    note["theory checks"] = "the record holds the counts of Section V-E's checks on these runs, not each run's outcome"
    # every row has an outcome
    miss = [rows[i]["tag"] for i in range(n) if not given[i]]
    assert not miss, ("rows without an outcome", miss[:10])
    fin = [final(i) for i in range(n)]
    outcome = [w for w, _x in fin]
    detail = [x for _w, x in fin]
    # the law's 279 fault runs (R20.f1): every counted run of the law in their six sets returned at rest
    sets279 = ("common scenarios", "shortened runs", "ladder 0.01 pu", "faults of 4 and 5 s", "single-phase ladder",
               "ladder 0.001 pu")
    v279 = [i for i, r in enumerate(rows) if r["code"] == "v" and set(counts[i]) & set(sets279)]
    assert len(v279) == f1["total"] and all(outcome[i] == "returned" for i in v279), ("the law's 279", len(v279))
    for i in v279:
        if "at rest" not in detail[i]:
            detail[i] = "at rest" + (", " + detail[i] if detail[i] else "")
    # Fig. 7's panel (e): the loss instants of the compared rows and the law's return times at buses 29, 38 and 39
    # (the record's per-run values, in the figure's print form)
    tix = {r["tag"]: i for i, r in enumerate(rows)}
    for b in get(m, "s60r.v6.p_dec3.buses"):
        for c in get(m, "s60r.v6.p_dec3.rows"):
            base = "s60r.v6.p_dec3.cells.%s.%s" % (b, c)
            i, vd = tix[get(m, base + ".tag")], get(m, base + ".verdict")
            if vd == "RETURNS":
                assert outcome[i] == "returned", (base, outcome[i])
                detail[i] = (detail[i] + ", " if detail[i] else "") + (
                    "return time %.2f s after clearing (Fig. 7)" % get(m, base + ".t_ret_s"))
            else:
                assert vd == "LOST" and outcome[i] == "lost", (base, outcome[i])
                li = get(m, base + ".loss_instant_s")
                detail[i] = ("lost %.2f s after clearing (Fig. 7)" % li) if isinstance(li, (int, float)) else (
                    "lost by the growing angle at the record's end (Fig. 7, *)")
    # the shortened runs' counts per code and duration: the printed leaves of Fig. 6
    for c in sorted({r["code"] for r in rows if r["set"].split(" + ")[0] == "shortened runs"}):
        for d in (100, 150):
            ix = [i for i, r in enumerate(rows) if r["set"].split(" + ")[0] == "shortened runs" and r["code"] == c
                  and int(r["fault_ms"]) == d]
            # the 16 codes of t_dur and the Fixed Quarter Turn's own record (Fig. 6's seventeenth row)
            x = get(m, ("s60r.v6.p_nr.cohort_u1.d%04dms" % d) if c == "u1" else (
                "s60r.v6.t_dur.laws.%s.d%04dms" % (c, d)))
            cnt = [i for i in ix if "shortened runs" in counts[i]]
            assert len(cnt) == x["of"], ("the shortened runs", c, d, len(cnt), x["of"])
            assert sum(outcome[i] == "lost" for i in cnt) == x["lost"], ("the shortened runs' losses", c, d)
            # the rest state of the returns (Fig. 6's column not at rest counts them): at rest per run where none of
            # the law's returns at this duration is not at rest, else the record's count in the detail
            ret, nar = x["of"] - x["lost"], x["returned_not_at_rest"]
            for i in cnt:
                if outcome[i] == "returned" and "at rest" not in detail[i]:
                    detail[i] = ("at rest" if nar == 0 else
                                 "of this law's %d returns at %d ms, %d not at rest; the record counts them, it does "
                                 "not list which runs" % (ret, d, nar))
    # the module search: 18 modules of six fault-free runs; none held the operating point in all six
    ms = {f: get(m, "s60r.v6.t_set.module_search." + f) for f in ("rows", "modules", "candidates_passing_all_six")}
    mi = [i for i, r in enumerate(rows) if r["set"].split(" + ")[0] == "module search"]
    assert len(mi) == ms["rows"] and len({rows[i]["setting"] for i in mi}) == ms["modules"]
    if all(outcome[i] in ("steady", "not steady") for i in mi):
        allsix = [st for st in {rows[i]["setting"] for i in mi}
                  if all(outcome[i] == "steady" for i in mi if rows[i]["setting"] == st)]
        assert len(allsix) == ms["candidates_passing_all_six"] == 0, ("the module search", allsix)
    # the fault-free rows' readings against the 101's eligibility: a law is eligible on a common scenario exactly where
    # its fault-free run at the scenario's load and network state (same setting) is steady (Section IV)
    ffr = {}
    for i, r in enumerate(rows):
        if "fault-free row" in r["set"].split(" + ") and outcome[i] in ("steady", "not steady"):
            ffr[(r["code"], r["setting"], keys[i])] = outcome[i]
    nff = 0
    for (s, code, k, setting), w in scen.items():
        p = parse_key(k) if s == "common scenarios" else None
        x = ffr.get((code, setting, p["load"] + p["state"])) if p else None
        if x is not None:
            assert (w != "not eligible") == (x == "steady"), ("eligibility against the fault-free run", code, k, w, x)
            nff += 1
    assert nff > 0
    # THE COUNTS, per set and code, over the scenarios the rows carry, against the record's printed counts: Table II's
    # Lost and its a/b (the 101), Table III's columns (the parts on the 101, the ladders, the faults of 4 and 5 s, the
    # SLG ladder, the load steps), Fig. 6's 78 ladder faults, the granted arms' 101 of the 101, Table IV's cells
    # COMPLETE AND UNIQUE (FIX_1): every scenario of every set counted by exactly one row whose counts_in names the
    # set and whose outcome is the scenario's; the counts below are taken from those rows
    cmap = {}
    for i in range(n):
        for s_ in counts[i]:
            ck = (s_, rows[i]["code"], keys[i], rows[i]["setting"])
            assert ck not in cmap, ("two rows count one scenario", ck, rows[cmap[ck]]["tag"], rows[i]["tag"])
            cmap[ck] = i
    miss_ = sorted(set(scen) - set(cmap))
    assert not miss_, ("a scenario of the record without its counted row", len(miss_), miss_[:4])
    for ck, w in scen.items():
        o = outcome[cmap[ck]]
        assert o == w or {o, w} == {"returned", "returned, a limiter engaged at the end"}, ("the counted row", ck, o, w)

    def tally(s, code, setting=None):
        ws = [outcome[i] for (s_, c_, _k, st), i in cmap.items() if s_ == s and c_ == code and
              (setting is None or st == setting)]
        return ws.count("lost"), len(ws) - ws.count("not eligible")
    nchk = 0
    for c in g["cols"]:
        lw = get(m, "%s.c101.laws.%s" % (R15, c))
        assert tally("common scenarios", c) == (lw["lost"], lw["of"]), ("Table II", c, tally("common scenarios", c))
        nchk += 1
    for c in g["ablation_cells"]:
        pr = get(m, "%s.c101.parts.%s" % (R15, c))
        assert tally("common scenarios", c) == (pr["lost"], pr["of"]), ("Table III, the 101", c)
        nchk += 1
    for arm in arms:
        assert tally("common scenarios", arm) == (R4[arm]["lost"], R4[arm]["of"]), ("the granted arm", arm)
        nchk += 1
    lost78 = get(m, A2 + ".lost_of_78_by_setting")
    R1, R3 = get(m, R16 + ".r1"), get(m, R16 + ".r3")
    for c in L["cols"]:
        assert tally("ladder 0.01 pu", c)[0] + tally("ladder 0.001 pu", c)[0] == lost78[c], ("the 78", c)
        f45 = R3[c] if c in R3 else get(m, "%s.q2.%s" % (R17, c))
        slg = R1[c] if c in R1 else get(m, "%s.q1.%s" % (R17, c))
        assert tally("faults of 4 and 5 s", c) == (f45["lost"], f45["of"]), ("4 and 5 s", c)
        assert tally("single-phase ladder", c) == (slg["lost"], slg["of"]), ("SLG", c)
        lsx = get(m, "%s.r2.per_code.%s" % (R16, c))
        assert tally("load steps", c) == (lsx["lost"], lsx["of"]), ("load steps", c)
        nchk += 4
    for setting in sorted({st for (s_, _c, _k, st) in scen if s_ == "Table IV"}):
        cid = ROB_SET[setting]
        for code in sorted({c_ for (s_, c_, _k, st) in scen if s_ == "Table IV" and st == setting}):
            ws = [outcome[i] for (s_, c_, k_, st), i in cmap.items() if s_ == "Table IV" and c_ == code
                  and st == setting and k_ in r18]
            if code in ("v", "k"):
                c = rob["cells"][cid][code]
                assert (ws.count("lost"), len(ws) - ws.count("not eligible")) == (c["lost"], c["eligible"]), (
                    "Table IV", setting, code)
            else:
                x = lim6[code]
                assert ws.count("lost") == len(x["lost_keys"][LIM.index(cid[4:])]), ("Table IV's note", setting, code)
            nchk += 1
    NCHK[0] = nchk
    for i, r in enumerate(rows):
        for s in r["set"].split(" + "):
            if outcome[i] != NEUTRAL:
                with_outcome[s] += 1
    # the columns; a row's places: those of the printed leaves that count its set's runs of its code, else those of
    # its set's (a printed count over the set's laws)
    places = ro["places"]
    set_places = {}
    for s, by in places.items():
        set_places[s] = []
        for c in by:
            for p_ in by[c]:
                if p_ not in set_places[s]:
                    set_places[s].append(p_)
    for i, r in enumerate(rows):
        for c in TABLE_COLS:
            out[c].append(r[c])
        out["key"].append(keys[i])
        out["outcome"].append(outcome[i])
        out["detail"].append(detail[i] or "-")
        cs = [s for s in r["set"].split(" + ") if s in counts[i]]
        out["counts_in"].append(" + ".join(cs) if cs else "-")
        pl = []
        for s in r["set"].split(" + "):
            for p_ in places.get(s, {}).get(r["code"]) or set_places.get(s, []):
                if p_ not in pl:
                    pl.append(p_)
        out["place"].append("; ".join(pl) if pl else "-")
        out["trace"].append(TRACES.get(r["tag"], "-"))
    used = [w for w, _c, _m in OUTCOMES if w in set(outcome)]
    sets_ = []
    for s in SETS:
        mem = [i for i, r in enumerate(rows) if s in r["set"].split(" + ")]
        held = [i for i in mem if rows[i]["set"].split(" + ")[0] == s]
        sc = [i for i in mem if s in counts[i]]       # the counted scenarios: one row each (asserted above)
        pl = []
        for c in places.get(s, {}):
            for p_ in places[s][c]:
                if p_ not in pl:
                    pl.append(p_)
        sets_.append({"name": s, "rows": len(mem), "held": len(held), "scenarios": len(sc),
                      "place": "; ".join(pl) if pl else "-", "with_outcome": with_outcome[s], "note": note[s]})
    laws_ = []
    for c in dict.fromkeys(["v"] + [x["code"] for x in laws[1:]] + [x["code"] for x in others]
                           + [r["code"] for r in rows]):
        nr_ = sum(r["code"] == c for r in rows)
        if nr_:
            lw = {r["law"] for r in rows if r["code"] == c}
            assert len(lw) == 1, c
            laws_.append({"code": c, "law": lw.pop(), "rows": nr_})
    doc = {"schema": "cca-runs/1", "n_rows": n,
           "table": {"file": "artifacts/campaign/campaign_table_paper.tsv", "sha256": tsha, "rows": n},
           "columns": list(RUN_COLS), "data": out,
           "outcomes": [{"word": w, "class": c, "meaning": mn} for w, c, mn in OUTCOMES if w in used],
           "sets": sets_, "laws": laws_,
           "join": "a cell of app_grid.json (its key and code; the ladder's, the load steps' and Table IV's with "
                   "its setting) joins the row with the same code, key and setting whose counts_in names the cell's "
                   "set; where the record does not name which of several runs of one scenario the count holds, the "
                   "rows of that scenario carry the neutral word and the scenario's outcome in their detail",
           "sources": [{"path": "artifacts/campaign/campaign_table_paper.tsv", "sha256": tsha},
                       {"path": "app/data/" + RELEASED}, {"path": "app/data/" + RUN_OUT}]}
    write_json(DATA / "app_runs.json", doc)
    return doc


TRACES = {}             # the run files of this build by tag (runs(): Fig. 7's traces)
RO = {}                 # data/record/run_outcomes.json, read once by number_part (either mode)
PAP = [None]            # the paper's texts of the full mode (the release mode reads app_paper.json)
NCHK = [0]              # the counts of the runs' list asserted against the record's printed counts


# THE PAPER's SETS (s60r20 map PAPER_SETS): the codes of the paper's laws, Table III's parts and [13]'s granted arms;
# the codes of the record that the paper does not hold are refused wherever a code is named
PAPER_CODES = ("v", "u1", "f", "z", "c", "e", "n", "h", "y", "k", "d", "q", "o", "l10", "l20", "l63", "l94", "l51",
               "l99", "l98", "MAd", "MAq", "x", "l96", "l97")   # x, l96, l97: [14]'s own modules (its module search)
KEY_LOWOPT = re.compile(r"(\d\d_\d{4}_\d\d[ST](?:F|W|O1718|U08))(_" + LOW_RF + r")?")


def paper_sets_check(m, root):
    """refuses (AssertionError) a number file that names a scenario key or a code outside the paper's sets: the keys
    of the 101 common scenarios, of the ladder (its 78 faults of up to 2 s through the two fault resistances, by the
    record's per-cell leaves; its 26 faults of 4 and 5 s; its 39 SLG faults) and of Table IV's 18 scenarios; the
    codes of PAPER_CODES (a dict's "code", a "cols" list)"""
    keys = set(get(m, R15 + ".sets.c101.keys")) | set(get(m, R15 + ".sets.lad26.keys")) | set(
        get(m, R16 + ".sets.r1.keys")) | set(get(m, R140 + ".sets.s18.keys"))
    for ck in sorted(_peek(m, A2 + ".per_cell")):
        g = re.match(r"^(0p01pu|0p001pu)_(\d{4})_(\d\d)$", ck)
        assert g, ck
        keys.add("%s_%s_10TF%s" % (g.group(3), g.group(2), "" if g.group(1) == BASE_RF else "_" + LOW_RF))
    # the campaign table's rows are the paper's runs: their keys (from the columns) belong to the paper's sets; a
    # run's tag and its arguments' fingerprint are names, not keys
    if TABLE[0] is not None:
        keys |= {row_key(r) for r in table_rows()[0] if r["fault_bus"] != "-"}
    bad = []
    for n, p in number_files(root).items():
        doc = json.loads(p.read_text(encoding="utf-8"))
        for path, v in _walk(doc):
            if n == "app_runs.json" and re.match(r"^/data/(?:tag|args_sha256)\[\d+\]$", path):
                continue
            if isinstance(v, str):
                for g in KEY_LOWOPT.finditer(v):
                    k = g.group(1) + (g.group(2) or "")
                    if k not in keys:
                        bad.append("%s %s: key %s" % (n, path, k))
        def codes(o, path=""):
            if isinstance(o, dict):
                if isinstance(o.get("code"), str) and o["code"] not in PAPER_CODES:
                    bad.append("%s %s: code %s" % (n, path, o["code"]))
                if isinstance(o.get("cols"), list):
                    bad.extend("%s %s/cols: code %s" % (n, path, c) for c in o["cols"] if c not in PAPER_CODES)
                for k_, v_ in o.items():
                    codes(v_, path + "/" + k_)
            elif isinstance(o, list):
                for i_, v_ in enumerate(o):
                    codes(v_, "%s[%d]" % (path, i_))
        codes(doc)
    assert not bad, "make_app_data: the paper's sets' check FAILED:\n  " + "\n  ".join(sorted(set(bad))[:40])
    return len(keys)









# the home folders of any machine (an account's folder under home, or under a drive's Users), for check_set; the
# patterns are built so that this file holds no such path itself
_HOME = "/" + "home" + "/"
NUMBER = r"\d+(?:\.\d+)?"
SEP = r"(?:\s*,\s*(?:and\s+|or\s+)?|\s+and\s+|\s+or\s+|\s+to\s+|\s*-\s*)"
DUR_PHRASE = re.compile(r"(?<![\w.])(" + NUMBER + r"(?:" + SEP + NUMBER + r")*)\s*(s|ms|sec|seconds?)\b")
DROOP_WORDS = re.compile(r"droop|slope", re.I)
# the slope's multiple that the paper's set took out (the author's word R140), in words or beside the droop (the
# words are built, not spelled, so that this file names none of them); the droop scale that gives it; the robustness
# rows' tags and keys at it (the record's value d3: a tag of two to four capitals, d3 and a law's code; a key d3,
# an underscore and a code)
_M4 = "fo" + "ur"
DROOP_FOUR = re.compile(_M4 + r"\s*times|\b4\s*times|" + _M4 + r"fold|\b4\s*x\b|\bx\s*4\b|droop[\s_-]*(?:x\s*)?4(?:p0|\.0)?\b",
                        re.I)
DROOP_SCALE = re.compile(r"droop\s*scale\W{0,4}0?\.25(?!\d)", re.I)
ROB_D3 = re.compile(r"(?<![A-Za-z0-9])(?:[A-Z]{2,4}d3[a-z]|d3_[a-z])")
HOME_ANY = re.compile(r"(?:/lustre)?" + _HOME + r"[^/\"\\\s~]+/|[A-Za-z]:(?:\\\\|\\|/)Users(?:\\\\|\\|/)")


def _walk(o, path=""):
    """every (path, key-or-value) of a decoded JSON document: dict keys and leaf values"""
    if isinstance(o, dict):
        for k, v in o.items():
            yield path + "/" + k, k
            yield from _walk(v, path + "/" + k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from _walk(v, "%s[%d]" % (path, i))
    else:
        yield path, o


PAPER_FILES = ("app_paper.json", "app_text.json")    # the files read from the paper's sources (--part paper)


def check_set(root, part="all"):
    """refuses (AssertionError) if any file under root/data (of the part named) holds a scenario key of a fault
    longer than MAX_MS, a duration above it (a dur_ms/durations_ms number, or a duration in words outside "after
    clearing"), a droop slope outside the set (DROOP_FOUR beside the droop's words, DROOP_SCALE, ROB_D3, a droop
    number at the multiple or a droop scale at its inverse) or a home folder (any account's); returns the number of
    strings and numbers read"""
    bad, n = [], 0
    for p in sorted((root / "data").rglob("*.json")):
        if part == "record" and p.name in PAPER_FILES or part == "paper" and p.name not in PAPER_FILES:
            continue
        doc = json.loads(p.read_text(encoding="utf-8"))
        rel = p.relative_to(root).as_posix()
        for path, v in _walk(doc):
            n += 1
            if isinstance(v, bool) or v is None:
                continue
            if isinstance(v, (int, float)):
                low = path.lower()
                if (low.endswith("/dur_ms") or "/durations_ms[" in low) and v > MAX_MS:
                    bad.append("%s %s = %s" % (rel, path, v))
                if "droop" in low and (abs(v - 4) < 1e-12 or "scale" in low and abs(v - 0.25) < 1e-12):
                    bad.append("%s %s = %s (droop)" % (rel, path, v))
                continue
            s = str(v)
            for g in KEY_ANY.finditer(s):
                if int(g.group(2)) > MAX_MS:
                    bad.append("%s %s: key %s" % (rel, path, g.group(0)))
            for txt in (s, s.replace("_", " ")):      # every file, the trace exports too
                if DROOP_WORDS.search(txt) and DROOP_FOUR.search(txt) or DROOP_SCALE.search(txt):
                    bad.append("%s %s: droop '%s'" % (rel, path, txt[:80]))
            if ROB_D3.search(s):
                bad.append("%s %s: a robustness row at a droop slope outside the paper's set '%s'" % (rel, path, s[:80]))
            if HOME_ANY.search(s):
                bad.append("%s %s: a home folder" % (rel, path))
            if rel.startswith("data/runs/"):
                continue                         # the trace exports: durations in words not read (the exporter's)
            for txt in (s, s.replace("_", " ")):
                for g in DUR_PHRASE.finditer(txt):
                    nums = [float(x) for x in re.findall(NUMBER, g.group(1))]
                    lim = MAX_MS if g.group(2) == "ms" else MAX_MS / 1000.0
                    # not a fault: a time after clearing, or the release's time-out that Table I prints with its
                    # own words ("never reached")
                    # nor a run's record length ("rows 8s record", "record 8s", the paper's record lengths of
                    # Section IV), nor a switching instant of a load step ("on at 3 s and off at 8 s"), nor the
                    # inertia constant of [14]'s module search ("inertia constant 10 s")
                    if any(x > lim for x in nums) and not re.match(r"\s*(?:after clearing|,\s*never reached|records?\b)",
                                                                   txt[g.end():]) and not re.search(
                            r"(?:\brecords?(?: of)?|\b(?:on|off) at|\binertia constant)\s*$", txt[:g.start()]):
                        bad.append("%s %s: '%s'" % (rel, path, txt[max(0, g.start() - 30):g.end() + 10]))
    assert not bad, "make_app_data: the set's check FAILED:\n  " + "\n  ".join(sorted(set(bad))[:40])
    return n


def minimal_paths(paths):
    """the paths none of whose ancestors is also listed (a listed path stands for its whole subtree), sorted"""
    ps = sorted(set(paths))
    keep = set(ps)
    return [p for p in ps if not any(".".join(p.split(".")[:i]) in keep for i in range(1, p.count(".") + 1))]





ROMAN = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")
_ID_DOT = re.compile(r"(?<=[A-Za-z_\d])\.(?=[A-Za-z_])")


def neutral_name(path):
    """a short neutral name of a printed leaf made from its own path: the record's prefixes s60r.v6. and s60r. taken
    off, the dots between names written as ' / '"""
    s = re.sub(r"\bs60r\.v6\.", "", str(path))
    s = re.sub(r"\bs60r\.", "", s)
    return _ID_DOT.sub(" / ", s)


def printed_view(printed, pap):
    """the numbers view (app_printed.json): every printed number of the paper at the place where the paper prints it
    (the paper's place names: Abstract, Section I to VI, Appendix, Table I to IV, Fig. n, caption), with a neutral name
    and its print form; the places from the inputs file (written by the full mode, which asserts each row's print form
    in the text of its place); the count from the rows"""
    pl = INP["printed_places"]
    assert len(pl) == len(printed), "the inputs' places and the printed leaves"
    order = INP["place_order"]
    rows = [{"place": p, "name": neutral_name(x["path"]), "printed": x["printed"], "path": x["path"]}
            for x, p in zip(printed, pl) if p is not None]
    po = [p for p in order if any(r["place"] == p for r in rows)]
    rows.sort(key=lambda r: po.index(r["place"]))      # a stable sort: the paper's order inside a place
    return {"schema": "cca-printed/2", "n": len(rows), "places": po, "rows": rows,
            "src": "the released record's %s: the paper's printed numbers, each at the place where the paper prints "
                   "it" % PRINTED_KEY}


def printed_view_by_builder(printed, pap):
    """the numbers view placed by the builder that recorded each leaf (kept for reference; not written)"""
    secs = {x["module"]: x for x in pap["sections"]}
    order = [x["module"] for x in pap["sections"]]
    figs = {}
    for f in pap["figures"]:
        figs.setdefault(f["section"], []).append(f)
    tabs = {}
    for t in pap["tables"]:
        tabs.setdefault(t["section"], []).append(t)

    def sec_name(mod):
        n = secs[mod]["number"]
        return "Appendix" if n == "Appendix" else "Section " + n

    def holds(text, s):
        return re.search(r"(?<![\w.])" + re.escape(s) + r"(?![\w])", text) is not None
    rows, places = [], []
    for x in printed:
        w = x["where"]
        if w == "abstract":
            place, rank = "Abstract", (0, 0, 0)
        else:
            mod, kind = w.rsplit(".", 1)
            assert mod in secs, w
            si = order.index(mod)
            if kind == "section":
                place, rank = sec_name(mod), (1, si, 0)
            elif kind == "figures":
                c = [f for f in figs.get(mod, []) if holds(f["caption"], x["printed"])]
                place = ("Fig. %s, caption" % c[0]["number"]) if len(c) == 1 else (
                    "Figures of %s, captions" % sec_name(mod))
                rank = (2, int(c[0]["number"]) if len(c) == 1 else 100 + si, 0)
            else:
                assert kind == "tables", w
                c = [t for t in tabs.get(mod, []) if any(holds(" | ".join(r["c"]), x["printed"]) for r in t["cells"])
                     or any(holds(n_, x["printed"]) for n_ in t["notes"]) or holds(t["title"] or "", x["printed"])]
                place = ("Table %s" % c[0]["number"]) if len(c) == 1 else ("Tables of %s" % sec_name(mod))
                rank = (3, ROMAN.index(c[0]["number"]) if len(c) == 1 and c[0]["number"] in ROMAN else 100 + si, 0)
        assert x["printed"].strip(), ("a printed leaf without its print form", x["path"])
        rows.append({"place": place, "name": neutral_name(x["path"]), "printed": x["printed"], "path": x["path"],
                     "rank": list(rank)})
        if place not in [p_[0] for p_ in places]:
            places.append((place, rank))
    places.sort(key=lambda p_: p_[1])
    po = [p_[0] for p_ in places]
    rows.sort(key=lambda r: po.index(r["place"]))      # a stable sort: the paper's order inside a place
    for r in rows:
        del r["rank"]
    return {"schema": "cca-printed/1", "n": len(rows), "places": po, "rows": rows,
            "src": "the released record's %s: the paper's printed leaves in the order its build makes them" % PRINTED_KEY}


def number_files(root):
    """the number files of a data folder, by their names under data (the run files are shipped data, not number
    files: their index is one)"""
    out = {}
    for n in NUMBER_FILES:
        p = root / n
        if p.is_file():
            out[n] = p
    return out



def configure(into, src="", table=""):
    """the folders: DIR/data written, the data folder read (app/data unless given); the campaign table read (the
    repository's artifacts/campaign/campaign_table_paper.tsv unless given)"""
    global OUT, DATA, SRC_DATA
    OUT = Path(into).resolve()
    DATA = OUT / "data"
    SRC_DATA = Path(src).resolve() if src else APP / "data"
    TABLE[0] = Path(table).resolve() if table else REPO / "artifacts" / "campaign" / "campaign_table_paper.tsv"


def record_block(m):
    """the released record that ships: its file, sha256 and the builder's stamp, and its newest group (the newest
    group of the record whose leaves it holds, the paper's printed leaves among them) with the first word of that
    group's state (the inputs file's record entry, written by the full mode)"""
    rf = (SRC_DATA if MODE == "release" else DATA) / RELEASED     # the record of this application: the released one
    b = rf.read_bytes() if rf.is_file() else b""
    h = hashlib.sha256(b).hexdigest()
    return {"round": get(m, "s60r._stamp.round"), "date": get(m, "s60r._stamp.date"),
            "files": [{"file": "app/data/" + RELEASED, "bytes": len(b), "sha256": h}], "sha256_8": h[:8],
            "group": INP["record"]["group"], "group_state": INP["record"]["state"]}


def number_part(m):
    """the number files from the record (either mode): app_numbers.json, app_laws.json, app_grid.json (with the
    ladder, the load steps and Table IV), runs/index.json; every one checked against the paper's sets"""
    for grp_ in (R15, R16, R17):
        if not has(m, grp_):
            sys.exit("make_app_data: the record holds no group %s; nothing written" % grp_)
    miss = required(m)
    if miss:
        sys.exit("make_app_data: the record lacks %d leaves this step needs; nothing written:\n  %s"
                 % (len(miss), "\n  ".join(miss[:60])))
    DATA.mkdir(parents=True, exist_ok=True)
    RO.clear()
    RO.update(json.loads((SRC_DATA if MODE == "release" else DATA).joinpath(RUN_OUT).read_text(encoding="ascii")))
    record = record_block(m)
    # every shown figure's pin, a leaf of the record (so of the released record), equal to its shipped image's sha256
    pap = PAP[0] if PAP[0] is not None else json.loads((SRC_DATA / "app_paper.json").read_text(encoding="ascii"))
    for f in pap["figures"]:
        if f.get("pin"):
            assert get(m, f["pin"]) == f["sha256"], ("a figure's pin and its shipped file", f["key"])
    laws, others, law_src = laws_table(m)
    cols16 = list(PART_CODES) + [r["code"] for r in laws[1:] if r["code"] != "h"]
    paths = list(dict.fromkeys(LEAVES + LEAVES16 + counts16(m, cols16) + leaves17(m) + counts17(m)
                               + LEAVES_LAD + ["%s.lost_of_78_by_setting.%s" % (A2, c) for c in cols16]))
    leaves = [{"path": p, "value": get(m, p)} for p in paths]
    med = opt(m, TS1[1])
    if isinstance(med, (int, float)) and not isinstance(med, bool):
        leaves += [{"path": p, "value": get(m, p)} for p in TS1]   # the circle's test: its count and median
    g = grid(m, laws)
    granted_check(m, g)
    write_json(DATA / "app_numbers.json", {"schema": "cca-numbers/1", "record": record, "leaves": leaves,
                                           "series": series(m), "constants": constants(m)})
    write_json(DATA / "app_laws.json", {"schema": "cca-laws/1", "laws": laws, "others": others, "sources": law_src})
    g["ladder"] = ladder(m, laws, others, g)
    assert g["ladder"]["cols"] == cols16
    g["loadsteps"] = loadsteps(m, cols16)
    g["robust"] = rob = robustness(m)            # Table IV and its 18 scenarios
    write_json(DATA / "app_grid.json", dict(schema="cca-grid/3", **g))
    idx = runs()
    rt = runs_table(m, g, laws, others)          # the list of the paper's runs (the campaign table's rows)
    said = ["%d leaves; grid %d x %d; ladder %d x %d (%d cells checked against the grid); load steps %d x %d; runs %d"
            % (len(leaves), len(g["keys"]), len(g["cols"]), len(g["ladder"]["keys"]), len(g["ladder"]["cols"]),
               g["ladder"]["checked_against_grid"], len(g["loadsteps"]["events"]), len(g["loadsteps"]["cols"]),
               len(idx))]
    said.append("the paper's runs: %d rows of the campaign table, %d counts asserted equal to the record's, %d with "
                "an outcome per run (%s)"
                % (rt["n_rows"], NCHK[0], sum(w != NEUTRAL for w in rt["data"]["outcome"]),
                   ", ".join("%s %d of %d" % (x["name"], x["with_outcome"], x["rows"]) for x in rt["sets"])))
    said.append("the paper's sets: every key and code of the number files among %d allowed keys"
                % paper_sets_check(m, DATA))
    return record, rob, said


def release_compare(record, said):
    """every number file regenerated into DIR/data compared with the read data folder's MANIFEST.json (sha256),
    written to DIR/data/REGEN.json and printed, one line a file; the files the release mode does not regenerate (the
    released record, the inputs file, the paper's texts) are named as shipped"""
    man = json.loads((SRC_DATA / "MANIFEST.json").read_text(encoding="ascii"))
    want = {f["file"]: f["sha256"] for f in man["files"]}
    got = number_files(DATA)
    rows = []
    for n, p in sorted(got.items()):
        h = sha256(p)
        rows.append({"file": n, "sha256": h, "manifest_sha256": want.get(n), "equal": want.get(n) == h})
    shipped = sorted(f for f in want if f not in got)
    nchk = check_set(OUT, "record")
    write_json(DATA / "REGEN.json", {"schema": "cca-regen/1", "mode": "release", "files": rows, "shipped": shipped,
                                     "record": record})
    for r in rows:
        print("  %-28s %s" % (r["file"], "equal" if r["equal"] else "DIFFERENT"))
    print("make_app_data (release mode): %d of %d number files equal to MANIFEST.json; %d files shipped as data, not "
          "regenerated; %s; the set's check passed on %d items" % (sum(r["equal"] for r in rows), len(rows),
                                                                    len(shipped), "; ".join(said), nchk))
    return rows


def main_release(into, src="", table=""):
    """THE RELEASE MODE: the released record, the inputs file, the run outcomes and app_paper.json of the data folder
    read, and the campaign table; the number files written into DIR/data and compared"""
    configure(into, src, table)
    if DATA.resolve() == SRC_DATA.resolve():
        sys.exit("make_app_data: the release mode writes a check copy (--into DIR), never the data folder it reads")
    rel = json.loads((SRC_DATA / RELEASED).read_text(encoding="ascii"))
    printed = rel.pop(PRINTED_KEY)
    _ROOT[0] = rel
    INP.clear()
    INP.update(json.loads((SRC_DATA / INPUTS).read_text(encoding="ascii")))
    record, _rob, said = number_part(rel)
    pap = json.loads((SRC_DATA / "app_paper.json").read_text(encoding="ascii"))
    write_json(DATA / "app_printed.json", printed_view(printed, pap))
    return release_compare(record, said)


if __name__ == "__main__":
    _ap = argparse.ArgumentParser(description="Regenerate the application's number files from the released files "
                                              "into a check folder and compare them with app/data/MANIFEST.json.")
    _ap.add_argument("--into", required=True, help="write DIR/data (a check copy)")
    _ap.add_argument("--from", dest="src", default="", help="the data folder read (default app/data)")
    _ap.add_argument("--table", default="", help="the campaign table read (default "
                                                 "artifacts/campaign/campaign_table_paper.tsv of the repository)")
    _a = _ap.parse_args()
    main_release(_a.into, _a.src, _a.table)

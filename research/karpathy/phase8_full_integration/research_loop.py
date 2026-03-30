#!/usr/bin/env python3
"""
Karpathy Automated Research Loop
==================================
Phase 8 Full Integration - Smoke & Honey

The Karpathy method: start with the smallest unit, get it right, then expand.
When integration breaks, the bug is in the interaction between the newest
addition and everything before it. Never fix two things at once.

This loop:
  1. Runs Phase 8 full integration (all 8 subsystems together)
  2. Identifies the EARLIEST phase causing failures
  3. Dives into that phase -- sends the AI the full source code, science
     context, the Phase 8 failure data, and what's been tried before
  4. The AI analyzes the math/science and proposes code changes
  5. The changes are applied, the phase's own tests are validated
  6. Phase 8 is re-run to measure integration improvement
  7. If the phase is now contributing correctly, move to the next problem
  8. If not, iterate on the same phase with updated context
  9. Continues until all 15 integration tests pass or Ctrl+C

The AI doesn't just tweak constants -- it sees the full formulas, understands
the science, and can restructure logic when the math is wrong.

Usage:
  python research_loop.py                  # Run the automated loop
  python research_loop.py --status         # Show current test status
  python research_loop.py --model NAME     # Use a different Ollama model
  python research_loop.py --max-iters N    # Cap iterations (default 50)
  python research_loop.py --dry-run        # Show AI suggestions, don't apply
"""

import sys
import os
import json
import time
import re
import shutil
import subprocess
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "qwen2.5-coder:7b"
MAX_ITERATIONS = 50
MAX_PHASE_ATTEMPTS = 8  # max rounds on one phase before moving on

KARPATHY_ROOT = Path(__file__).parent.parent
PHASE8_DIR = Path(__file__).parent
BACKUP_DIR = PHASE8_DIR / "backups"
LOG_FILE = PHASE8_DIR / "research_log.txt"
STATE_FILE = PHASE8_DIR / "loop_state.json"

# Phase info: number -> (directory name, script name, description)
PHASE_INFO = {
    1: ("phase1_brood_biology",    "brood_sim.py",           "Brood cell state transitions"),
    2: ("phase2_population",       "population_sim.py",      "Population dynamics + lifecycle"),
    3: ("phase3_foraging_honey",   "foraging_sim.py",        "Foraging + honey economy"),
    4: ("phase4_queen_comb",       "queen_comb_sim.py",      "Queen behavior + comb mechanics"),
    5: ("phase5_disease_pests",    "disease_sim.py",         "Varroa + disease dynamics"),
    6: ("phase6_environment",      "environment_sim.py",     "Weather + flowers + forage"),
    7: ("phase7_colony_behavior",  "colony_behavior_sim.py", "Congestion + health scoring"),
}

PHASE_SCRIPTS = {}
for num, (dirname, script, desc) in PHASE_INFO.items():
    PHASE_SCRIPTS[num] = KARPATHY_ROOT / dirname / script


# ---------------------------------------------------------------------------
# Add all phases to Python path
# ---------------------------------------------------------------------------
for i in range(1, 8):
    phase_dirs = list(KARPATHY_ROOT.glob(f"phase{i}_*"))
    if phase_dirs:
        sys.path.insert(0, str(phase_dirs[0]))
sys.path.insert(0, str(PHASE8_DIR))


# ---------------------------------------------------------------------------
# Simulation Runner
# ---------------------------------------------------------------------------
def run_phase8_sim() -> Dict:
    """Run the full 365-day integration sim. Returns structured results."""
    # Force reimport to pick up any changes
    for mod_name in list(sys.modules.keys()):
        if mod_name in ('full_sim', 'brood_sim', 'population_sim', 'foraging_sim',
                        'queen_comb_sim', 'disease_sim', 'environment_sim',
                        'colony_behavior_sim'):
            del sys.modules[mod_name]

    from full_sim import FullColonySim, SeasonRank, YEAR_LENGTH, MONTH_LENGTH
    from population_sim import MONTH_NAMES

    hive_a = FullColonySim(name="Hive-A", seed=1701)
    hive_b = FullColonySim(name="Hive-B", seed=2048)

    rows_a, rows_b = [], []
    peak_a = peak_b = 0
    winter_min_a = winter_min_b = 999999
    w_honey_start_a = w_honey_start_b = None
    w_honey_end_a = w_honey_end_b = None
    varroa_double_a = -1
    max_forage = 0.0

    for d in range(1, 366):
        sa = hive_a.tick()
        sb = hive_b.tick()
        rows_a.append(sa)
        rows_b.append(sb)
        if d == 112: hive_a.harvest(35.0); hive_b.harvest(35.0)
        if d == 140: hive_a.harvest(25.0); hive_b.harvest(25.0)
        peak_a = max(peak_a, sa["total_adults"])
        peak_b = max(peak_b, sb["total_adults"])
        max_forage = max(max_forage, sa["forage_level"])
        if sa["winter"]:
            winter_min_a = min(winter_min_a, sa["total_adults"])
            winter_min_b = min(winter_min_b, sb["total_adults"])
            if w_honey_start_a is None:
                w_honey_start_a = sa["honey_stores"]
                w_honey_start_b = sb["honey_stores"]
            w_honey_end_a = sa["honey_stores"]
            w_honey_end_b = sb["honey_stores"]
        if varroa_double_a < 0 and hive_a.varroa.mite_count >= 100:
            varroa_double_a = d

    if winter_min_a == 999999: winter_min_a = 0
    if winter_min_b == 999999: winter_min_b = 0

    harvest_a = sum(hive_a.harvest_events)
    harvest_b = sum(hive_b.harvest_events)
    wc_a = max(0, (w_honey_start_a or 0) - (w_honey_end_a or 0))
    wc_b = max(0, (w_honey_start_b or 0) - (w_honey_end_b or 0))
    end_a = rows_a[-1]["honey_stores"]
    end_b = rows_b[-1]["honey_stores"]
    div = abs(end_a - end_b) / max(0.01, (end_a + end_b) / 2) * 100
    peak_day = max(range(365), key=lambda i: rows_a[i]["total_adults"])
    peak_month = rows_a[peak_day]["month"]
    sh = [r["health_score"] for r in rows_a if r["month"] in ("Wide-Clover", "High-Sun")]
    avg_sh = sum(sh) / len(sh) if sh else 0
    impossible = any(r["total_adults"] < 0 or r["honey_stores"] < -0.001
                     or r["egg_count"] < 0 for r in rows_a + rows_b)

    tests = []
    def chk(name, val, lo, hi, phase):
        ok = lo <= val <= hi
        tests.append({"name": name, "value": round(val, 2), "lo": lo, "hi": hi,
                       "passed": ok, "phase": phase,
                       "gap": round(lo - val, 2) if val < lo else (round(val - hi, 2) if val > hi else 0)})

    chk("peak_adults_A", peak_a, 40000, 65000, 2)
    chk("peak_adults_B", peak_b, 40000, 65000, 2)
    chk("winter_min_A", winter_min_a, 8000, 28000, 2)
    chk("winter_min_B", winter_min_b, 8000, 28000, 2)
    chk("annual_honey_A", hive_a.total_honey_produced, 150, 450, 3)
    chk("annual_honey_B", hive_b.total_honey_produced, 150, 450, 3)
    chk("harvest_A", harvest_a, 40, 120, 3)
    chk("harvest_B", harvest_b, 40, 120, 3)
    chk("winter_consume_A", wc_a, 20, 45, 3)
    chk("winter_consume_B", wc_b, 20, 45, 3)
    if varroa_double_a > 0:
        chk("varroa_doubling", varroa_double_a, 40, 70, 5)
    chk("divergence_pct", div, 8, 30, 8)
    tests.append({"name": "peak_in_summer", "value": peak_month,
                  "target": ["Greening", "Wide-Clover", "High-Sun"],
                  "passed": peak_month in ("Greening", "Wide-Clover", "High-Sun"), "phase": 2})
    tests.append({"name": "no_impossible_states", "value": "clean" if not impossible else "bad",
                  "passed": not impossible, "phase": 0})
    chk("summer_health", avg_sh, 50, 100, 7)

    monthly = []
    for m in range(8):
        mr = [r for r in rows_a if r["month"] == MONTH_NAMES[m]]
        if mr:
            monthly.append({
                "month": MONTH_NAMES[m],
                "adults": round(sum(r["total_adults"] for r in mr) / len(mr)),
                "forage": round(sum(r["forage_level"] for r in mr) / len(mr), 3),
                "lays": round(sum(r["queen_lays"] for r in mr) / len(mr)),
                "honey_in": round(sum(r["honey_gain"] for r in mr) / len(mr), 4),
                "consume": round(sum(r["consumption"] for r in mr) / len(mr), 4),
                "stores": mr[-1]["honey_stores"],
                "health": round(sum(r["health_score"] for r in mr) / len(mr), 1),
            })

    return {"passed": sum(1 for t in tests if t["passed"]), "total": len(tests),
            "all_pass": all(t["passed"] for t in tests),
            "tests": tests, "monthly": monthly, "peak_forage": round(max_forage, 4)}


def get_earliest_failing_phase(results: Dict) -> Optional[int]:
    """Find the earliest phase number with failing tests."""
    failing_phases = set()
    for t in results["tests"]:
        if not t["passed"]:
            p = t.get("phase", 0)
            if isinstance(p, int) and p > 0:
                failing_phases.add(p)
    return min(failing_phases) if failing_phases else None


def get_phase_failures(results: Dict, phase_num: int) -> List[Dict]:
    """Get all failing tests attributed to a specific phase."""
    return [t for t in results["tests"] if not t["passed"] and t.get("phase") == phase_num]


# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
def check_ollama() -> bool:
    try:
        req = urllib.request.Request("http://localhost:11434/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def query_ollama(prompt: str, model: str = DEFAULT_MODEL) -> str:
    payload = json.dumps({
        "model": model, "prompt": prompt, "stream": False,
        "options": {"temperature": 0.3, "num_predict": 3000}
    }).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL, data=payload,
                                headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return json.loads(resp.read().decode("utf-8")).get("response", "")
    except Exception as e:
        return f"OLLAMA_ERROR: {e}"


# ---------------------------------------------------------------------------
# Context & Prompt Building
# ---------------------------------------------------------------------------
def load_context() -> str:
    ctx_path = PHASE8_DIR / "CONTEXT.md"
    return ctx_path.read_text(encoding="utf-8") if ctx_path.exists() else ""


def load_phase_code(phase_num: int) -> str:
    """Load the FULL source code of a phase script."""
    script = PHASE_SCRIPTS.get(phase_num)
    if script and script.exists():
        return script.read_text(encoding="utf-8")
    return ""


def build_research_prompt(phase_num: int, results: Dict, phase_code: str,
                          attempt: int, phase_history: List[str]) -> str:
    """Build a comprehensive research prompt for deep phase analysis."""

    phase_info = PHASE_INFO[phase_num]
    phase_failures = get_phase_failures(results, phase_num)

    # Build failure summary
    fail_text = ""
    for t in phase_failures:
        if "lo" in t:
            fail_text += f"  {t['name']}: got {t['value']}, need {t['lo']}-{t['hi']} (gap: {t['gap']})\n"
        else:
            fail_text += f"  {t['name']}: got {t['value']}, expected {t.get('target', '?')}\n"

    # Monthly data for diagnosis
    monthly_text = "Month          Adults   Forage   Lays  HoneyIn  Consume  Stores  Health\n"
    for m in results["monthly"]:
        monthly_text += (f"{m['month']:<14} {m['adults']:>7,}  {m['forage']:>7.3f}  "
                         f"{m['lays']:>5}  {m['honey_in']:>7.4f}  {m['consume']:>7.4f}  "
                         f"{m['stores']:>6.1f}  {m['health']:>6.1f}\n")

    # History of what we tried on this phase
    hist_text = ""
    if phase_history:
        hist_text = "\nPREVIOUS ATTEMPTS ON THIS PHASE (do NOT repeat these exact changes):\n"
        for h in phase_history:
            hist_text += f"  - {h}\n"

    prompt = f"""You are a bee biology researcher tuning a simulation for accuracy.

PHASE {phase_num}: {phase_info[2]}
Script: {phase_info[1]}
Attempt {attempt} on this phase.

INTEGRATION TEST FAILURES caused by Phase {phase_num}:
{fail_text}
FULL SIMULATION MONTHLY DATA:
{monthly_text}
Score: {results['passed']}/{results['total']} tests passing
{hist_text}
HERE IS THE FULL SOURCE CODE OF {phase_info[1]}:
```python
{phase_code}
```

TASK: Analyze why the above code produces values that fail the integration tests.
Look at the formulas, constants, and logic. Consider the real-world bee biology.
Propose a code change that fixes the root cause.

RULES:
- You can change constants, formulas, or function logic
- Do NOT change NECTAR_TO_HONEY (0.20, science-locked 5:1 ratio)
- Do NOT change brood timing (EGG=3, LARVA=6, CAPPED=12 days)
- Keep changes biologically reasonable
- Explain your reasoning about the bee science
- Make ONE focused change (Karpathy method -- one thing at a time)

Respond in EXACTLY this format:

ANALYSIS: (2-3 sentences explaining the root cause)
FILE: {phase_info[1]}
FIND:
```
(exact lines to replace, copy-pasted from the code above)
```
REPLACE:
```
(the new code to put in its place)
```
EXPECTED_EFFECT: (what this should change in the test results)
"""
    return prompt


# ---------------------------------------------------------------------------
# Code Modification
# ---------------------------------------------------------------------------
def parse_research_response(response: str) -> Optional[Dict]:
    """Parse the AI's research response into an actionable edit."""
    result = {}

    # Extract ANALYSIS
    analysis_match = re.search(r'ANALYSIS:\s*(.+?)(?=\nFILE:)', response, re.DOTALL)
    if analysis_match:
        result["analysis"] = analysis_match.group(1).strip()

    # Extract FILE
    file_match = re.search(r'FILE:\s*(\S+)', response)
    if file_match:
        result["file"] = file_match.group(1).strip()

    # Extract FIND block
    find_match = re.search(r'FIND:\s*```\w*\n(.*?)```', response, re.DOTALL)
    if find_match:
        result["find"] = find_match.group(1).strip()

    # Extract REPLACE block
    replace_match = re.search(r'REPLACE:\s*```\w*\n(.*?)```', response, re.DOTALL)
    if replace_match:
        result["replace"] = replace_match.group(1).strip()

    # Extract EXPECTED_EFFECT
    effect_match = re.search(r'EXPECTED_EFFECT:\s*(.+)', response, re.DOTALL)
    if effect_match:
        result["expected"] = effect_match.group(1).strip()

    if "find" in result and "replace" in result:
        return result
    return None


def backup_file(filepath: Path, iteration: int) -> Path:
    BACKUP_DIR.mkdir(exist_ok=True)
    backup = BACKUP_DIR / f"{filepath.name}.iter{iteration}.bak"
    shutil.copy2(filepath, backup)
    return backup


def apply_multiline_edit(filepath: Path, find_text: str, replace_text: str) -> bool:
    """Apply a multi-line find/replace edit to a file."""
    content = filepath.read_text(encoding="utf-8")

    # Try exact match
    if find_text in content:
        new_content = content.replace(find_text, replace_text, 1)
        filepath.write_text(new_content, encoding="utf-8")
        return True

    # Try with normalized whitespace (strip trailing spaces per line)
    find_normalized = "\n".join(line.rstrip() for line in find_text.split("\n"))
    content_normalized = "\n".join(line.rstrip() for line in content.split("\n"))
    if find_normalized in content_normalized:
        new_content = content_normalized.replace(find_normalized, replace_text, 1)
        filepath.write_text(new_content, encoding="utf-8")
        return True

    # Try matching by stripping all leading whitespace (indent-agnostic)
    find_lines = [l.strip() for l in find_text.strip().split("\n") if l.strip()]
    content_lines = content.split("\n")
    for start_i in range(len(content_lines)):
        match = True
        matched_end = start_i
        fi = 0
        for ci in range(start_i, min(start_i + len(find_lines) * 2, len(content_lines))):
            if fi >= len(find_lines):
                break
            if content_lines[ci].strip() == find_lines[fi]:
                fi += 1
                matched_end = ci + 1
            elif content_lines[ci].strip() == "":
                continue  # skip blank lines
            else:
                match = False
                break
        if match and fi == len(find_lines):
            # Found it -- replace those lines
            # Detect indentation from first matched line
            indent = len(content_lines[start_i]) - len(content_lines[start_i].lstrip())
            indent_str = " " * indent
            replace_lines = replace_text.split("\n")
            # Apply indentation to replacement
            indented_replace = []
            for rl in replace_lines:
                if rl.strip():
                    indented_replace.append(indent_str + rl.lstrip())
                else:
                    indented_replace.append("")
            content_lines[start_i:matched_end] = indented_replace
            filepath.write_text("\n".join(content_lines), encoding="utf-8")
            return True

    return False


def revert_file(filepath: Path, backup: Path):
    shutil.copy2(backup, filepath)


def run_phase_tests(phase_num: int) -> Tuple[bool, str]:
    """Run a phase's own test suite."""
    script = PHASE_SCRIPTS.get(phase_num)
    if not script or not script.exists():
        return False, f"Phase {phase_num} script not found"
    try:
        r = subprocess.run([sys.executable, str(script)], capture_output=True,
                           text=True, timeout=60, cwd=str(script.parent))
        return r.returncode == 0, (r.stdout + r.stderr)[:2000]
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"
    except Exception as e:
        return False, str(e)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
def log(iteration: int, phase: int, message: str, edit: Optional[Dict] = None):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n[Iter {iteration} | Phase {phase} | {time.strftime('%H:%M:%S')}] {message}\n")
        if edit:
            f.write(f"  Analysis: {edit.get('analysis', '')[:200]}\n")
            f.write(f"  Find: {edit.get('find', '')[:100]}...\n")
            f.write(f"  Replace: {edit.get('replace', '')[:100]}...\n")


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------
def print_bar(passed: int, total: int):
    w = 30
    filled = int(w * passed / max(1, total))
    bar = "#" * filled + "-" * (w - filled)
    return f"[{bar}] {passed}/{total}"


def show_status():
    """Show current test results without looping."""
    print("\n  Running full simulation...", end=" ", flush=True)
    r = run_phase8_sim()
    print("done\n")
    print(f"  {print_bar(r['passed'], r['total'])}\n")
    for t in r["tests"]:
        s = "PASS" if t["passed"] else "FAIL"
        if "lo" in t:
            print(f"  [{s}] {t['name']}: {t['value']} (target {t['lo']}-{t['hi']})")
        else:
            print(f"  [{s}] {t['name']}: {t.get('value', '?')}")
    print(f"\n  Monthly:")
    for m in r["monthly"]:
        print(f"    {m['month']:<14} pop={m['adults']:>7,} forage={m['forage']:.3f} "
              f"lays={m['lays']:>5} honey={m['stores']:.1f}")


# ---------------------------------------------------------------------------
# Main Research Loop
# ---------------------------------------------------------------------------
def run_loop(model: str = DEFAULT_MODEL, max_iters: int = MAX_ITERATIONS,
             dry_run: bool = False):

    print("\n" + "=" * 70)
    print("  KARPATHY AUTOMATED RESEARCH LOOP")
    print("  Smoke & Honey Beekeeping Simulation")
    print(f"  Model: {model}")
    print("  Press Ctrl+C to stop")
    print("=" * 70)

    # Check Ollama
    print("\n  Checking Ollama...", end=" ", flush=True)
    if not check_ollama():
        print("NOT RUNNING")
        print("\n  Start Ollama first:")
        print("    ollama serve")
        print(f"    ollama pull {model}")
        return 1
    print("connected")

    # Load base context
    context = load_context()
    print(f"  CONTEXT.md loaded ({len(context)} chars)")

    best_score = 0
    phase_history = {}  # {phase_num: [list of attempt descriptions]}

    # Initialize log
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*70}\nNEW SESSION {time.strftime('%Y-%m-%d %H:%M:%S')} | model={model}\n{'='*70}\n")

    for iteration in range(1, max_iters + 1):
        try:
            # === STEP 1: Run Phase 8 ===
            print(f"\n{'='*70}")
            print(f"  ITERATION {iteration}")
            print(f"{'='*70}")
            print("  Running Phase 8 integration...", end=" ", flush=True)
            results = run_phase8_sim()
            print(f"{print_bar(results['passed'], results['total'])}")

            if results["passed"] > best_score:
                best_score = results["passed"]
                print(f"  *** NEW BEST: {best_score}/{results['total']} ***")

            if results["all_pass"]:
                print("\n" + "=" * 70)
                print("  ALL 15 TESTS PASSING!")
                print("  Simulation is fully calibrated.")
                print("  Ready for GDScript porting.")
                print("=" * 70)
                log(iteration, 0, "ALL PASS -- COMPLETE")
                return 0

            # === STEP 2: Identify earliest failing phase ===
            target_phase = get_earliest_failing_phase(results)
            if target_phase is None:
                print("  No failing phases identified (only non-phase failures remain)")
                break

            phase_fails = get_phase_failures(results, target_phase)
            info = PHASE_INFO[target_phase]
            print(f"\n  Target: Phase {target_phase} ({info[2]})")
            print(f"  Failures: {len(phase_fails)}")
            for f in phase_fails:
                if "lo" in f:
                    print(f"    {f['name']}: {f['value']} (need {f['lo']}-{f['hi']}, gap={f['gap']})")
                else:
                    print(f"    {f['name']}: {f['value']}")

            # Track attempts per phase
            if target_phase not in phase_history:
                phase_history[target_phase] = []

            if len(phase_history[target_phase]) >= MAX_PHASE_ATTEMPTS:
                print(f"\n  Hit {MAX_PHASE_ATTEMPTS} attempts on Phase {target_phase}.")
                print(f"  Skipping to next failing phase...")
                # Temporarily exclude this phase and find next
                remaining = [t for t in results["tests"]
                             if not t["passed"] and t.get("phase", 0) != target_phase
                             and isinstance(t.get("phase"), int) and t["phase"] > 0]
                if remaining:
                    target_phase = min(t["phase"] for t in remaining)
                    phase_history.setdefault(target_phase, [])
                    info = PHASE_INFO.get(target_phase, ("?", "?", "?"))
                    print(f"  Switching to Phase {target_phase} ({info[2]})")
                else:
                    print("  No more phases to try. Stopping.")
                    break

            attempt = len(phase_history[target_phase]) + 1

            # === STEP 3: Load full phase source code ===
            phase_code = load_phase_code(target_phase)
            if not phase_code:
                print(f"  ERROR: Cannot read Phase {target_phase} source")
                continue

            # === STEP 4: Ask AI to research and propose a fix ===
            print(f"\n  Sending to {model} for analysis (attempt {attempt})...", end=" ", flush=True)
            prompt = build_research_prompt(
                target_phase, results, phase_code,
                attempt, phase_history.get(target_phase, [])
            )
            # Prepend the system context
            full_prompt = context + "\n\n---\nCURRENT RESEARCH TASK:\n---\n\n" + prompt

            ai_response = query_ollama(full_prompt, model)
            if ai_response.startswith("OLLAMA_ERROR:"):
                print(f"\n  {ai_response}")
                log(iteration, target_phase, ai_response)
                time.sleep(5)
                continue
            print("done")

            # === STEP 5: Parse the response ===
            edit = parse_research_response(ai_response)
            if not edit:
                print("  Could not parse AI response:")
                preview = ai_response[:400].replace("\n", "\n    ")
                print(f"    {preview}")
                phase_history[target_phase].append(f"Attempt {attempt}: unparseable response")
                log(iteration, target_phase, "Unparseable response")
                continue

            print(f"\n  AI Analysis: {edit.get('analysis', '(none)')[:120]}")
            print(f"  Change in: {edit.get('file', '?')}")
            find_preview = edit.get('find', '')[:80].replace('\n', ' | ')
            replace_preview = edit.get('replace', '')[:80].replace('\n', ' | ')
            print(f"  Find:    {find_preview}...")
            print(f"  Replace: {replace_preview}...")
            if edit.get("expected"):
                print(f"  Expects: {edit['expected'][:120]}")

            if dry_run:
                print("  (dry run -- not applying)")
                phase_history[target_phase].append(
                    f"Attempt {attempt}: [dry run] {edit.get('analysis', '')[:100]}")
                log(iteration, target_phase, "DRY RUN", edit)
                continue

            # === STEP 6: Backup and apply ===
            script_path = PHASE_SCRIPTS[target_phase]
            backup = backup_file(script_path, iteration)

            if not apply_multiline_edit(script_path, edit["find"], edit["replace"]):
                print("  FAILED: Could not find the target text in the file.")
                print("  The AI may have produced slightly wrong code to match.")
                revert_file(script_path, backup)
                phase_history[target_phase].append(
                    f"Attempt {attempt}: find/replace failed -- {edit.get('analysis', '')[:80]}")
                log(iteration, target_phase, "Edit failed - text not found", edit)
                continue

            print("  Edit applied.")

            # === STEP 7: Validate the phase's own tests ===
            print(f"  Running Phase {target_phase} tests...", end=" ", flush=True)
            phase_ok, phase_output = run_phase_tests(target_phase)

            if not phase_ok:
                print("BROKE -- reverting")
                revert_file(script_path, backup)
                phase_history[target_phase].append(
                    f"Attempt {attempt}: broke Phase {target_phase} tests -- "
                    f"{edit.get('analysis', '')[:60]}")
                log(iteration, target_phase, f"Phase tests broke, reverted", edit)
                continue

            print("still passing")

            # === STEP 8: Re-run Phase 8 to check improvement ===
            print("  Re-checking Phase 8 integration...", end=" ", flush=True)
            new_results = run_phase8_sim()
            print(f"{print_bar(new_results['passed'], new_results['total'])}")

            improved = new_results["passed"] > results["passed"]
            same = new_results["passed"] == results["passed"]
            worse = new_results["passed"] < results["passed"]

            if worse:
                print(f"  REGRESSION ({results['passed']} -> {new_results['passed']}) -- reverting")
                revert_file(script_path, backup)
                phase_history[target_phase].append(
                    f"Attempt {attempt}: regressed {results['passed']}->{new_results['passed']}, "
                    f"reverted -- {edit.get('analysis', '')[:60]}")
                log(iteration, target_phase, f"Regressed, reverted", edit)
            elif improved:
                print(f"  IMPROVED! ({results['passed']} -> {new_results['passed']})")
                phase_history[target_phase].append(
                    f"Attempt {attempt}: KEPT -- improved {results['passed']}->{new_results['passed']} -- "
                    f"{edit.get('analysis', '')[:60]}")
                log(iteration, target_phase, f"Improved {results['passed']}->{new_results['passed']}", edit)
            else:
                # Same score -- keep it if it moved numbers in the right direction
                print(f"  Same score, keeping change (may help downstream)")
                phase_history[target_phase].append(
                    f"Attempt {attempt}: kept (no score change) -- {edit.get('analysis', '')[:60]}")
                log(iteration, target_phase, "Same score, kept", edit)

            time.sleep(1)

        except KeyboardInterrupt:
            print(f"\n\n  Stopped by Ctrl+C")
            print(f"  Best score: {best_score}")
            print(f"  Log: {LOG_FILE}")
            print(f"  Backups: {BACKUP_DIR}/")
            return 0

    print(f"\n  Done. Best score: {best_score}/{results.get('total', '?')}")
    return 0 if results.get("all_pass") else 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    import argparse
    p = argparse.ArgumentParser(description="Karpathy Automated Research Loop")
    p.add_argument("--model", default=DEFAULT_MODEL, help=f"Ollama model (default: {DEFAULT_MODEL})")
    p.add_argument("--max-iters", type=int, default=MAX_ITERATIONS, help="Max iterations")
    p.add_argument("--dry-run", action="store_true", help="Show suggestions only")
    p.add_argument("--status", action="store_true", help="Show current test status")
    args = p.parse_args()

    if args.status:
        show_status()
        return 0

    return run_loop(model=args.model, max_iters=args.max_iters, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())

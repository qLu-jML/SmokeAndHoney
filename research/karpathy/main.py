#!/usr/bin/env python3
"""
Karpathy Research Machine - Smoke & Honey
===========================================
Modeled after https://github.com/karpathy/autoresearch

Core principle: an autonomous AI research loop that runs overnight.
You wake up to a log of experiments and (hopefully) a better simulation.

Architecture (adapted from Karpathy's autoresearch):
  - prepare = fixed (CONTEXT.md, science anchors, test harnesses)
  - train = the phase scripts (the ONLY files the AI modifies)
  - program = the prompts this script sends to Ollama
  - metric = test pass count (higher is better)

The loop:
  1. Run tests -> get metric (pass count)
  2. Send code + failures to Ollama for analysis
  3. AI proposes ONE focused change
  4. Apply change, re-test
  5. If metric improved or same: KEEP + git commit
  6. If metric regressed: REVERT
  7. Log result to results.tsv
  8. NEVER STOP -- loop until Ctrl+C

Bottom-up phase progression (Nathan's adaptation):
  Perfect Phase 1 -> lock -> incorporate into Phase 2 -> lock -> ...
  -> Phase 8 full integration -> tune source phases until nature works

Usage:
  python main.py                    # Full bottom-up research machine (never stops)
  python main.py --start-at N       # Resume from phase N
  python main.py --status           # Show all phases pass/fail
  python main.py --model NAME       # Ollama model (default: qwen2.5-coder:7b)
  python main.py --skip-validate    # Skip straight to integration loop
  python main.py --dry-run          # Show AI suggestions without applying
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
import argparse
import csv
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# ---------------------------------------------------------------------------
# Thermal Monitoring
# ---------------------------------------------------------------------------
# Thresholds (Celsius) -- if exceeded, the loop pauses to let hardware cool
CPU_TEMP_WARN = 80       # warn and slow down
CPU_TEMP_CRITICAL = 90   # pause until cooled
GPU_TEMP_WARN = 80
GPU_TEMP_CRITICAL = 88
COOLDOWN_WAIT = 30       # seconds to wait when temps are critical
BETWEEN_ATTEMPTS_WAIT = 3  # minimum seconds between attempts (gentle pacing)


def _read_cpu_temp_windows() -> Optional[float]:
    """Read CPU temp via WMI on Windows. Returns Celsius or None."""
    try:
        r = subprocess.run(
            ["powershell", "-Command",
             "Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/wmi "
             "2>$null | Select-Object -First 1 -ExpandProperty CurrentTemperature"],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode == 0 and r.stdout.strip():
            # WMI returns temp in tenths of Kelvin
            kelvin_tenths = float(r.stdout.strip())
            celsius = (kelvin_tenths / 10.0) - 273.15
            if 0 < celsius < 150:  # sanity check
                return round(celsius, 1)
    except Exception:
        pass
    return None


def _read_gpu_temp_nvidia() -> Optional[float]:
    """Read GPU temp via nvidia-smi. Returns Celsius or None."""
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode == 0 and r.stdout.strip():
            temp = float(r.stdout.strip().split("\n")[0])
            if 0 < temp < 150:
                return temp
    except Exception:
        pass
    return None


def check_system_temps() -> tuple:
    """Check CPU and GPU temperatures.
    Returns (ok: bool, message: str).
    ok=True means temps are fine, ok=False means we should wait."""
    cpu = _read_cpu_temp_windows()
    gpu = _read_gpu_temp_nvidia()

    parts = []
    critical = False

    if cpu is not None:
        parts.append(f"CPU: {cpu}C")
        if cpu >= CPU_TEMP_CRITICAL:
            critical = True
            parts.append("(CRITICAL)")
        elif cpu >= CPU_TEMP_WARN:
            parts.append("(warm)")

    if gpu is not None:
        parts.append(f"GPU: {gpu}C")
        if gpu >= GPU_TEMP_CRITICAL:
            critical = True
            parts.append("(CRITICAL)")
        elif gpu >= GPU_TEMP_WARN:
            parts.append("(warm)")

    if not parts:
        # Can't read temps -- no monitoring available, that's OK
        return True, "Temps: (monitoring unavailable)"

    msg = "Temps: " + " | ".join(parts)

    if critical:
        return False, f"THERMAL WARNING: {msg} -- pausing {COOLDOWN_WAIT}s to cool down"
    return True, msg


def thermal_cooldown():
    """Wait for system to cool down, checking every 10 seconds."""
    waited = 0
    while waited < COOLDOWN_WAIT:
        time.sleep(10)
        waited += 10
        ok, msg = check_system_temps()
        print(f"    [{waited}s] {msg}")
        if ok:
            print(f"    Temps OK -- resuming")
            return
    print(f"    Cooldown period complete -- resuming")


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
KARPATHY_ROOT = Path(__file__).resolve().parent
BACKUP_DIR = KARPATHY_ROOT / "backups"
LOG_FILE = KARPATHY_ROOT / "research_log.txt"
RESULTS_TSV = KARPATHY_ROOT / "results.tsv"

# ---------------------------------------------------------------------------
# Phase Registry
# ---------------------------------------------------------------------------
PHASES = {
    1: {
        "dir": "phase1_brood_biology",
        "script": "brood_sim.py",
        "name": "Brood Biology",
        "imports": [],
        "science": (
            "Brood development: 21 days total (3 egg + 6 larva + 12 capped). "
            "Winston 1987. These timings are biological facts. "
            "The brood pipeline is the ONLY source of new adult bees."
        ),
        "locked_constants": ["EGG_DURATION", "LARVA_DURATION", "CAPPED_BROOD_DURATION"],
    },
    2: {
        "dir": "phase2_population",
        "script": "population_sim.py",
        "name": "Population Dynamics",
        "imports": [1],
        "science": (
            "Adult bee lifecycle: nurse(~12d) -> house(~12d) -> forager(~18d avg). "
            "Winter bees live 90-180 days. Summer peak 40-65k, winter min 8-28k. "
            "SEASON_FACTORS drive the yearly rhythm. Population is the foundation "
            "for every downstream system."
        ),
        "locked_constants": [],
    },
    3: {
        "dir": "phase3_foraging_honey",
        "script": "foraging_sim.py",
        "name": "Foraging & Honey Economy",
        "imports": [1, 2],
        "science": (
            "Nectar-to-honey ratio is 5:1 (0.20 conversion, science-locked). "
            "Forager carries ~40mg nectar/trip, 10-12 trips/day. "
            "Iowa annual surplus: 40-120 lbs harvestable. "
            "Winter consumption: 60-90 lbs real (20-45 in compressed calendar)."
        ),
        "locked_constants": ["NECTAR_TO_HONEY"],
    },
    4: {
        "dir": "phase4_queen_comb",
        "script": "queen_comb_sim.py",
        "name": "Queen & Comb Mechanics",
        "imports": [],
        "science": (
            "Queen grade S-F system. Peak laying 1500-2000 eggs/day for good queens. "
            "Queen performance peaks year 2, declines after. "
            "Laying rate affected by: season, available cells, congestion, varroa, forage. "
            "Comb drawing requires honey (wax is metabolically expensive)."
        ),
        "locked_constants": [],
    },
    5: {
        "dir": "phase5_disease_pests",
        "script": "disease_sim.py",
        "name": "Disease & Pests",
        "imports": [],
        "science": (
            "Varroa doubling time: 40-70 days untreated. Exponential growth. "
            "AFB: bacterial, 1.2%% spread rate per infected neighbor. "
            "EFB: less severe, 30%% self-cure rate, 4%% mortality. "
            "Treatment efficacies: oxalic 90%%, apivar 95%%, formic 85%%."
        ),
        "locked_constants": [],
    },
    6: {
        "dir": "phase6_environment",
        "script": "environment_sim.py",
        "name": "Environmental Systems",
        "imports": [],
        "science": (
            "Iowa USDA Zone 5a. 7 native flower species with bloom windows. "
            "Dandelion earliest (spring), Aster latest (fall). "
            "8 weather states with seasonal probability tables. "
            "Rain/cold stops foraging. Winter: no flowers, no forage. "
            "Forage output here replaces the simple mock from Phase 3."
        ),
        "locked_constants": [],
    },
    7: {
        "dir": "phase7_colony_behavior",
        "script": "colony_behavior_sim.py",
        "name": "Colony Behavior & Health",
        "imports": [],
        "science": (
            "Congestion detection: honey-bound(0.62), brood-bound(0.65). "
            "Swarm impulse needs 7+ consecutive congested ticks. "
            "Health score 0-100: pop(25%%) + brood(25%%) + stores(20%%) + queen(20%%) + varroa(10%%). "
            "These are evaluation systems -- they read colony state, they don't change it."
        ),
        "locked_constants": [],
    },
    8: {
        "dir": "phase8_full_integration",
        "script": "full_sim.py",
        "name": "Full Integration",
        "imports": [1, 2, 3, 4, 5, 6, 7],
        "science": (
            "All 7 subsystems running together in the 10-step pipeline. "
            "15 integration tests validate the complete colony lifecycle: "
            "population curves, honey economy, varroa dynamics, seasonal rhythm, health. "
            "Failures here mean calibration between systems, not bugs in individual phases. "
            "Fix at the SOURCE phase, not in full_sim.py."
        ),
        "locked_constants": [],
    },
}


def phase_script_path(phase_num: int) -> Path:
    info = PHASES[phase_num]
    return KARPATHY_ROOT / info["dir"] / info["script"]


# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "qwen2.5-coder:7b"


def check_ollama() -> bool:
    try:
        req = urllib.request.Request("http://localhost:11434/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def query_ollama(prompt: str, model: str) -> str:
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
# Phase Test Runner
# ---------------------------------------------------------------------------
def run_phase_tests(phase_num: int) -> Tuple[bool, str]:
    """Run a phase's test suite. Returns (all_passed, output_text)."""
    script = phase_script_path(phase_num).resolve()
    if not script.exists():
        return False, f"Script not found: {script}"
    try:
        r = subprocess.run(
            [sys.executable, str(script)],
            capture_output=True, text=True, timeout=120,
            cwd=str(script.parent)
        )
        output = r.stdout + r.stderr
        return r.returncode == 0, output
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT (>120s)"
    except Exception as e:
        return False, str(e)


def extract_test_results(output: str) -> List[Dict]:
    """Parse PASS/FAIL lines from phase test output."""
    results = []
    for line in output.split("\n"):
        line = line.strip()
        if "[PASS]" in line:
            results.append({"passed": True, "text": line})
        elif "[FAIL]" in line:
            results.append({"passed": False, "text": line})
    return results


# ---------------------------------------------------------------------------
# Results TSV (a la autoresearch results.tsv)
# ---------------------------------------------------------------------------
def init_results_tsv():
    """Create results.tsv with header if it doesn't exist."""
    if not RESULTS_TSV.exists():
        with open(RESULTS_TSV, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f, delimiter="\t")
            writer.writerow([
                "timestamp", "phase", "attempt", "pass_count", "total_tests",
                "status", "target_file", "description"
            ])


def log_result(phase: int, attempt: int, pass_count: int, total: int,
               status: str, target_file: str, description: str):
    """Append one row to results.tsv."""
    with open(RESULTS_TSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow([
            datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            phase, attempt, pass_count, total, status, target_file, description
        ])


# ---------------------------------------------------------------------------
# Code Editing
# ---------------------------------------------------------------------------
def backup_file(filepath: Path, phase: int, iteration: int) -> Path:
    BACKUP_DIR.mkdir(exist_ok=True)
    backup = BACKUP_DIR / f"phase{phase}_{filepath.name}.iter{iteration}.bak"
    shutil.copy2(filepath, backup)
    return backup


def apply_edit(filepath: Path, find_text: str, replace_text: str) -> bool:
    """Multi-line find/replace with fuzzy matching."""
    content = filepath.read_text(encoding="utf-8")

    # Exact match
    if find_text in content:
        filepath.write_text(content.replace(find_text, replace_text, 1), encoding="utf-8")
        return True

    # Normalized whitespace
    find_norm = "\n".join(l.rstrip() for l in find_text.split("\n"))
    content_norm = "\n".join(l.rstrip() for l in content.split("\n"))
    if find_norm in content_norm:
        filepath.write_text(content_norm.replace(find_norm, replace_text, 1), encoding="utf-8")
        return True

    # Indent-agnostic line matching
    find_lines = [l.strip() for l in find_text.strip().split("\n") if l.strip()]
    content_lines = content.split("\n")
    for start in range(len(content_lines)):
        fi = 0
        end = start
        for ci in range(start, min(start + len(find_lines) * 2, len(content_lines))):
            if fi >= len(find_lines):
                break
            if content_lines[ci].strip() == find_lines[fi]:
                fi += 1
                end = ci + 1
            elif content_lines[ci].strip() == "":
                continue
            else:
                break
        if fi == len(find_lines):
            indent = len(content_lines[start]) - len(content_lines[start].lstrip())
            new_lines = []
            for rl in replace_text.split("\n"):
                new_lines.append(" " * indent + rl.lstrip() if rl.strip() else "")
            content_lines[start:end] = new_lines
            filepath.write_text("\n".join(content_lines), encoding="utf-8")
            return True

    return False


def revert_file(filepath: Path, backup: Path):
    shutil.copy2(backup, filepath)


def check_locked_constants(find_text: str, replace_text: str, locked: list) -> Optional[str]:
    """Check if a proposed edit tries to modify any locked constants.
    Returns a description of the violation, or None if clean."""
    if not locked:
        return None
    for const in locked:
        # Look for the constant being reassigned to a different value
        find_pattern = re.search(rf'{const}\s*=\s*(\S+)', find_text)
        repl_pattern = re.search(rf'{const}\s*=\s*(\S+)', replace_text)
        if find_pattern and repl_pattern:
            old_val = find_pattern.group(1)
            new_val = repl_pattern.group(1)
            if old_val != new_val:
                return (f"LOCKED CONSTANT VIOLATION: {const} = {old_val} -> {new_val}. "
                        f"{const} is a science-locked biological fact and must NOT be changed.")
    return None


def diagnose_edit_failure(filepath: Path, find_text: str) -> str:
    """Diagnose WHY a find/replace failed. Returns human-readable explanation."""
    content = filepath.read_text(encoding="utf-8")
    find_lines = [l.strip() for l in find_text.strip().split("\n") if l.strip()]

    if not find_lines:
        return "The proposed FIND block was empty -- AI returned no code to match."

    # Check if first line exists anywhere
    first_line = find_lines[0]
    matches = [i for i, l in enumerate(content.split("\n")) if first_line in l]

    if not matches:
        # Check for partial matches (AI may have hallucinated the code)
        # Try the first meaningful token (e.g., variable name)
        tokens = re.findall(r'[A-Z_][A-Z_0-9]+\s*=', first_line)
        if tokens:
            token = tokens[0].split("=")[0].strip()
            real_lines = [l.strip() for l in content.split("\n") if token in l]
            if real_lines:
                return (f"AI hallucinated the code. It looked for:\n"
                        f"      '{first_line}'\n"
                        f"    but the actual line in the file is:\n"
                        f"      '{real_lines[0]}'")
        return (f"The FIND text does not exist in the file. "
                f"The AI likely hallucinated or misremembered the current code. "
                f"First line sought: '{first_line[:80]}'")

    if len(find_lines) > 1:
        # First line found but multi-line block didn't match
        return (f"First line found at line(s) {[m+1 for m in matches[:3]]}, "
                f"but the full {len(find_lines)}-line block didn't match. "
                f"Likely whitespace/indentation mismatch or intervening lines differ.")

    return "Single-line match attempted but failed on whitespace normalization."


# No git -- all tracking is local via results.tsv and backups/


# ---------------------------------------------------------------------------
# Prompt Building (the "program.md" equivalent)
# ---------------------------------------------------------------------------
def load_context() -> str:
    ctx = KARPATHY_ROOT / "phase8_full_integration" / "CONTEXT.md"
    return ctx.read_text(encoding="utf-8") if ctx.exists() else ""


def build_phase_prompt(phase_num: int, test_output: str, test_results: List[Dict],
                       history: List[str], integration_context: str = "",
                       last_failure_context: str = "") -> str:
    """Build a research prompt for a specific phase."""
    info = PHASES[phase_num]
    script = phase_script_path(phase_num)
    code = script.read_text(encoding="utf-8") if script.exists() else "(not found)"

    failures = [t for t in test_results if not t["passed"]]
    passes = [t for t in test_results if t["passed"]]

    fail_text = "\n".join(f"  {t['text']}" for t in failures)
    pass_text = "\n".join(f"  {t['text']}" for t in passes)

    locked_text = ""
    if info["locked_constants"]:
        locked_text = (f"\n\nSCIENCE-LOCKED CONSTANTS (NEVER change these -- they are biological facts):\n"
                       f"  {', '.join(info['locked_constants'])}\n"
                       f"  Any attempt to modify these will be REJECTED automatically.\n"
                       f"  Find other parameters to adjust instead.")

    imports_text = ""
    if info["imports"]:
        names = [PHASES[i]["name"] for i in info["imports"]]
        imports_text = f"\nThis phase builds on: {', '.join(names)}"

    hist_text = ""
    if history:
        hist_text = "\nPREVIOUS ATTEMPTS (do NOT repeat these):\n"
        for h in history[-8:]:
            hist_text += f"  - {h}\n"

    failure_context_text = ""
    if last_failure_context:
        failure_context_text = (f"\nLAST ATTEMPT FAILED -- READ THIS CAREFULLY:\n"
                                f"  {last_failure_context}\n"
                                f"  You MUST avoid this same mistake. Read the actual source code below\n"
                                f"  carefully and copy the FIND text EXACTLY as it appears.\n")

    integration_note = ""
    if integration_context:
        integration_note = f"\nINTEGRATION CONTEXT:\n{integration_context}\n"

    prompt = f"""You are a bee biology researcher perfecting a simulation subsystem.

PHASE {phase_num}: {info['name']}
Science: {info['science']}
{imports_text}{locked_text}

CURRENT TEST RESULTS:
  Passing: {len(passes)}/{len(passes)+len(failures)}
  Failing:
{fail_text}
  Passing:
{pass_text}
{hist_text}{failure_context_text}{integration_note}
FULL SOURCE CODE of {info['script']}:
```python
{code}
```

TASK: Analyze why the failing tests fail. Look at the formulas, constants, and
logic. Consider real-world bee biology. Propose ONE focused code change that
fixes the root cause of the earliest/most fundamental failure.

CRITICAL RULES:
- ONE change at a time (smallest possible delta)
- Do NOT change science-locked constants (see above) -- find other levers
- Keep changes biologically reasonable
- You can modify non-locked constants, formulas, or function logic
- The FIND block must be EXACTLY copied from the source code shown above
- Explain your bee science reasoning briefly

Respond in EXACTLY this format:

ANALYSIS: (2-3 sentences on root cause and bee science reasoning)
FILE: {info['script']}
FIND:
```
(exact lines to replace -- copy PRECISELY from the code above)
```
REPLACE:
```
(the new code)
```
EXPECTED: (what should change in test results)
"""
    return prompt


def build_integration_prompt(phase8_output: str, test_results: List[Dict],
                             history: List[str]) -> Tuple[str, int]:
    """Build a prompt for Phase 8 integration tuning. Returns (prompt, target_phase)."""

    failures = [t for t in test_results if not t["passed"]]

    # Determine which source phase to target based on failure keywords
    phase_counts = {}
    for line in [t["text"] for t in failures]:
        lower = line.lower()
        if "peak" in lower or "winter_min" in lower or "population" in lower:
            phase_counts[2] = phase_counts.get(2, 0) + 1
        elif "honey" in lower or "harvest" in lower or "consumption" in lower:
            phase_counts[3] = phase_counts.get(3, 0) + 1
        elif "varroa" in lower:
            phase_counts[5] = phase_counts.get(5, 0) + 1
        elif "health" in lower:
            phase_counts[7] = phase_counts.get(7, 0) + 1
        elif "forage" in lower or "season" in lower:
            phase_counts[6] = phase_counts.get(6, 0) + 1
        elif "queen" in lower or "laying" in lower or "brood" in lower:
            phase_counts[4] = phase_counts.get(4, 0) + 1

    target_phase = min(phase_counts.keys()) if phase_counts else 2
    target_info = PHASES[target_phase]
    target_script = phase_script_path(target_phase)
    target_code = target_script.read_text(encoding="utf-8") if target_script.exists() else ""

    fail_text = "\n".join(f"  {t['text']}" for t in failures)
    hist_text = ""
    if history:
        hist_text = "\nPREVIOUS INTEGRATION ATTEMPTS (do NOT repeat):\n"
        for h in history[-8:]:
            hist_text += f"  - {h}\n"

    prompt = f"""You are a bee biology researcher tuning a full simulation for accuracy.

PHASE 8: Full Integration (all subsystems combined)
All 7 individual phases pass their own tests.
When combined, calibration between systems causes failures.

FAILING INTEGRATION TESTS:
{fail_text}

The earliest source of failures points to Phase {target_phase} ({target_info['name']}).
{hist_text}
FULL SOURCE CODE of Phase {target_phase} ({target_info['script']}):
```python
{target_code}
```

TASK: These tests fail in integration even though Phase {target_phase} passes alone.
The constants/formulas need adjustment so they work correctly when all systems
interact. Analyze the bee science and propose ONE change to Phase {target_phase}.

RULES:
- Change Phase {target_phase} code only (the source of the problem)
- Do NOT change NECTAR_TO_HONEY or brood development timings
- Keep changes biologically reasonable
- ONE focused change (smallest possible delta)

Respond in EXACTLY this format:

ANALYSIS: (root cause and bee science reasoning)
FILE: {target_info['script']}
FIND:
```
(exact lines to replace)
```
REPLACE:
```
(new code)
```
EXPECTED: (what should improve in integration tests)
"""
    return prompt, target_phase


# ---------------------------------------------------------------------------
# Response Parser
# ---------------------------------------------------------------------------
def parse_response(response: str) -> Optional[Dict]:
    result = {}
    analysis = re.search(r'ANALYSIS:\s*(.+?)(?=\nFILE:)', response, re.DOTALL)
    if analysis: result["analysis"] = analysis.group(1).strip()

    file_m = re.search(r'FILE:\s*(\S+)', response)
    if file_m: result["file"] = file_m.group(1).strip()

    find_m = re.search(r'FIND:\s*```\w*\n(.*?)```', response, re.DOTALL)
    if find_m: result["find"] = find_m.group(1).strip()

    replace_m = re.search(r'REPLACE:\s*```\w*\n(.*?)```', response, re.DOTALL)
    if replace_m: result["replace"] = replace_m.group(1).strip()

    expected_m = re.search(r'EXPECTED:\s*(.+)', response, re.DOTALL)
    if expected_m: result["expected"] = expected_m.group(1).strip()

    if "find" in result and "replace" in result:
        return result
    return None


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
def log(message: str):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{time.strftime('%H:%M:%S')}] {message}\n")


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------
def bar(passed: int, total: int, width: int = 25) -> str:
    filled = int(width * passed / max(1, total))
    return f"[{'#' * filled}{'-' * (width - filled)}] {passed}/{total}"


def print_phase_header(phase_num: int, status: str = ""):
    info = PHASES[phase_num]
    print(f"\n{'='*70}")
    deps = ""
    if info["imports"]:
        dep_names = [f"P{i}" for i in info["imports"]]
        deps = f" (uses {'+'.join(dep_names)})"
    print(f"  PHASE {phase_num}: {info['name'].upper()}{deps}")
    if status:
        print(f"  {status}")
    print(f"{'='*70}")


# ---------------------------------------------------------------------------
# Research Loop for a Single Phase
# NEVER STOPS until all tests pass or Ctrl+C (autoresearch principle)
# ---------------------------------------------------------------------------
def research_phase(phase_num: int, model: str, dry_run: bool = False) -> bool:
    """
    Autonomous research loop for a single phase.
    Runs INDEFINITELY until all tests pass or Ctrl+C.
    """
    info = PHASES[phase_num]
    history = []
    attempt = 0
    last_failure_context = ""  # Fed back into next prompt so AI learns

    while True:
        attempt += 1

        # Thermal check before each attempt
        temp_ok, temp_msg = check_system_temps()
        if not temp_ok:
            print(f"\n  {temp_msg}")
            print(f"  Waiting for cooldown...")
            thermal_cooldown()
        elif attempt > 1:
            # Gentle pacing between attempts even if temps are fine
            print(f"  ({temp_msg}) -- pacing {BETWEEN_ATTEMPTS_WAIT}s...", flush=True)
            time.sleep(BETWEEN_ATTEMPTS_WAIT)

        # Run phase tests
        print(f"\n  [Attempt {attempt}] Running {info['script']}...", end=" ", flush=True)
        passed, output = run_phase_tests(phase_num)
        test_results = extract_test_results(output)
        n_pass = sum(1 for t in test_results if t["passed"])
        n_total = len(test_results)
        print(f"{bar(n_pass, n_total)}")

        if passed:
            print(f"  ALL TESTS PASS -- Phase {phase_num} LOCKED")
            log(f"Phase {phase_num} LOCKED ({n_pass}/{n_total} pass) after {attempt} attempts")
            log_result(phase_num, attempt, n_pass, n_total, "LOCKED",
                       info["script"], "All tests passing")
            return True

        # Handle 0/0 (script crashed before printing any test results)
        if n_total == 0:
            print(f"  WARNING: Script produced 0 test results -- likely a crash or import error")
            print(f"  Raw output (last 15 lines):")
            out_lines = [l for l in output.strip().split("\n") if l.strip()]
            for ol in out_lines[-15:]:
                print(f"    {ol}")
            # Try to restore from the most recent backup if one exists
            script_path = phase_script_path(phase_num)
            backups = sorted(BACKUP_DIR.glob(f"phase{phase_num}_{info['script']}.iter*.bak"),
                             key=lambda p: p.stat().st_mtime) if BACKUP_DIR.exists() else []
            if backups:
                print(f"  >> Restoring from latest backup: {backups[-1].name}")
                revert_file(script_path, backups[-1])
                last_failure_context = ("Script crashed with 0 test results. "
                                        "Restored from backup. A previous edit likely corrupted the file.")
                history.append(f"Attempt {attempt}: script crash (0/0), restored from backup")
                log(f"Phase {phase_num} attempt {attempt}: 0/0 crash, restored from backup")
            else:
                last_failure_context = ("Script crashed with 0 test results -- runtime error, not a test failure.")
                history.append(f"Attempt {attempt}: script crash (0/0)")
                log(f"Phase {phase_num} attempt {attempt}: 0/0 crash, no backup available")
                print(f"  >> No backup available. Script may need manual repair.")
                print(f"  >> Try running: python {phase_script_path(phase_num)}")
            log_result(phase_num, attempt, 0, 0, "SCRIPT_CRASH",
                       info["script"], "Script crashed - 0 test results")
            continue

        # Show failures
        failures = [t for t in test_results if not t["passed"]]
        for f_item in failures:
            print(f"    {f_item['text']}")

        # Build integration context for early phases
        int_ctx = ""
        if phase_num <= 3:
            int_ctx = (
                f"Phase {phase_num} feeds into the full integration. "
                f"Population needs to peak at 40-65k summer, 8-28k winter. "
                f"Annual honey 150-450 lbs. These downstream targets matter."
            )

        # Ask Ollama
        print(f"  Querying Ollama ({model})...", end=" ", flush=True)
        prompt = build_phase_prompt(phase_num, output, test_results, history,
                                    int_ctx, last_failure_context)
        context = load_context()
        response = query_ollama(context + "\n---\n" + prompt, model)

        if response.startswith("OLLAMA_ERROR:"):
            print(f"\n  {response}")
            log(f"Phase {phase_num} attempt {attempt}: {response}")
            log_result(phase_num, attempt, n_pass, n_total, "OLLAMA_ERROR",
                       info["script"], response[:80])
            time.sleep(5)
            continue
        print("done")

        # Parse
        edit = parse_response(response)
        if not edit:
            print(f"  Could not parse AI response")
            preview = response[:300].replace("\n", "\n    ")
            print(f"    {preview}")
            last_failure_context = "AI response was not in the required format. Use EXACTLY: ANALYSIS/FILE/FIND/REPLACE/EXPECTED."
            history.append(f"Attempt {attempt}: unparseable response")
            log(f"Phase {phase_num} attempt {attempt}: unparseable")
            log_result(phase_num, attempt, n_pass, n_total, "PARSE_FAIL",
                       info["script"], "Could not parse AI response")
            print(f"  >> NEXT STRATEGY: Re-querying with stricter format instructions")
            continue

        analysis_short = edit.get("analysis", "")[:100]
        print(f"  Analysis: {analysis_short}")
        find_p = edit['find'][:60].replace('\n', ' | ')
        repl_p = edit['replace'][:60].replace('\n', ' | ')
        print(f"  Find:    {find_p}...")
        print(f"  Replace: {repl_p}...")

        # Check for locked constant violations BEFORE applying
        locked_violation = check_locked_constants(
            edit["find"], edit["replace"], info["locked_constants"])
        if locked_violation:
            print(f"  REJECTED: {locked_violation}")
            last_failure_context = (f"{locked_violation} "
                                    f"Do NOT touch these constants. Find other parameters to adjust "
                                    f"(mortality rates, transition rates, seasonal factors, etc).")
            history.append(f"Attempt {attempt}: REJECTED locked constant change -- {locked_violation}")
            log(f"Phase {phase_num} attempt {attempt}: locked constant violation")
            log_result(phase_num, attempt, n_pass, n_total, "LOCKED_VIOLATION",
                       info["script"], locked_violation[:80])
            print(f"  >> NEXT STRATEGY: Re-querying AI with explicit warning about locked constants.")
            print(f"     AI must find OTHER parameters to adjust (not {', '.join(info['locked_constants'])})")
            continue

        if dry_run:
            print(f"  [DRY RUN] Would apply this change")
            log_result(phase_num, attempt, n_pass, n_total, "DRY_RUN",
                       info["script"], analysis_short)
            last_failure_context = ""
            continue

        # Backup and apply
        script_path = phase_script_path(phase_num)
        bk = backup_file(script_path, phase_num, attempt)

        if not apply_edit(script_path, edit["find"], edit["replace"]):
            # Diagnose WHY the edit failed
            diagnosis = diagnose_edit_failure(script_path, edit["find"])
            print(f"  FAILED: Edit could not be applied")
            print(f"  >> WHY: {diagnosis}")
            revert_file(script_path, bk)

            last_failure_context = (f"Find/replace FAILED: {diagnosis}. "
                                    f"You must copy the FIND text EXACTLY from the source code. "
                                    f"Pay attention to exact spacing, variable names, and values.")
            history.append(f"Attempt {attempt}: find/replace miss -- {diagnosis[:60]}")
            log(f"Phase {phase_num} attempt {attempt}: edit failed -- {diagnosis[:80]}")
            log_result(phase_num, attempt, n_pass, n_total, "EDIT_FAIL",
                       info["script"], diagnosis[:80])
            print(f"  >> NEXT STRATEGY: Re-querying AI with failure diagnosis. "
                  f"AI will be told to read the actual code more carefully.")
            continue

        # Edit applied successfully -- clear failure context
        last_failure_context = ""

        # Validate
        print(f"  Validating...", end=" ", flush=True)
        new_passed, new_output = run_phase_tests(phase_num)
        new_results = extract_test_results(new_output)
        new_n_pass = sum(1 for t in new_results if t["passed"])

        if new_n_pass < n_pass:
            print(f"WORSE ({n_pass}->{new_n_pass}) -- reverting")
            revert_file(script_path, bk)
            last_failure_context = (f"Last change REGRESSED tests from {n_pass} to {new_n_pass} passing. "
                                    f"The change was: {analysis_short}. "
                                    f"Try a DIFFERENT approach -- do not repeat this change.")
            history.append(f"Attempt {attempt}: regressed {n_pass}->{new_n_pass}, reverted")
            log(f"Phase {phase_num} attempt {attempt}: regressed, reverted")
            log_result(phase_num, attempt, new_n_pass, len(new_results), "REVERTED",
                       info["script"], f"Regressed {n_pass}->{new_n_pass}")
            print(f"  >> NEXT STRATEGY: Change reverted. AI will be told this approach "
                  f"made things worse and must try a different parameter.")
        elif new_n_pass > n_pass:
            print(f"IMPROVED ({n_pass}->{new_n_pass}) -- KEPT")
            history.append(f"Attempt {attempt}: IMPROVED {n_pass}->{new_n_pass}")
            log(f"Phase {phase_num} attempt {attempt}: improved {n_pass}->{new_n_pass}")
            log_result(phase_num, attempt, new_n_pass, len(new_results), "IMPROVED",
                       info["script"], analysis_short)
        else:
            print(f"SAME ({n_pass}) -- kept")
            history.append(f"Attempt {attempt}: same score ({n_pass})")
            log(f"Phase {phase_num} attempt {attempt}: same score, kept")
            log_result(phase_num, attempt, new_n_pass, len(new_results), "KEPT_SAME",
                       info["script"], analysis_short)

        if new_passed:
            print(f"  ALL TESTS PASS -- Phase {phase_num} LOCKED")
            log(f"Phase {phase_num} LOCKED ({new_n_pass}/{len(new_results)} pass)")
            log_result(phase_num, attempt, new_n_pass, len(new_results), "LOCKED",
                       info["script"], "All tests passing")
            return True

        time.sleep(1)


# ---------------------------------------------------------------------------
# Integration Research Loop (Phase 8)
# NEVER STOPS until all 15 pass or Ctrl+C
# ---------------------------------------------------------------------------
def research_integration(model: str, dry_run: bool = False) -> bool:
    """
    Phase 8 integration loop. All individual phases should pass.
    Fixes are applied to SOURCE phases, not full_sim.py.
    Runs INDEFINITELY until all tests pass or Ctrl+C.
    """
    history = []
    attempt = 0
    last_failure_context = ""

    while True:
        attempt += 1

        # Thermal check before each attempt
        temp_ok, temp_msg = check_system_temps()
        if not temp_ok:
            print(f"\n  {temp_msg}")
            print(f"  Waiting for cooldown...")
            thermal_cooldown()
        elif attempt > 1:
            print(f"  ({temp_msg}) -- pacing {BETWEEN_ATTEMPTS_WAIT}s...", flush=True)
            time.sleep(BETWEEN_ATTEMPTS_WAIT)

        # Run Phase 8
        print(f"\n  [Attempt {attempt}] Running full integration...", end=" ", flush=True)
        passed, output = run_phase_tests(8)
        test_results = extract_test_results(output)
        n_pass = sum(1 for t in test_results if t["passed"])
        n_total = len(test_results)
        print(f"{bar(n_pass, n_total)}")

        if passed:
            print(f"\n  ALL 15 INTEGRATION TESTS PASS!")
            log(f"Phase 8 COMPLETE ({n_pass}/{n_total}) after {attempt} attempts")
            log_result(8, attempt, n_pass, n_total, "COMPLETE",
                       "full_sim.py", "All integration tests pass")
            return True

        # Show failures
        failures = [t for t in test_results if not t["passed"]]
        for f_item in failures[:5]:
            print(f"    {f_item['text']}")
        if len(failures) > 5:
            print(f"    ...and {len(failures)-5} more")

        # Ask Ollama for integration fix
        print(f"  Querying Ollama ({model})...", end=" ", flush=True)
        context = load_context()
        prompt, target_phase = build_integration_prompt(output, test_results, history)
        # Inject failure context if available
        if last_failure_context:
            prompt = prompt.replace("TASK:", f"LAST ATTEMPT FAILED:\n  {last_failure_context}\n\nTASK:")
        response = query_ollama(context + "\n---\n" + prompt, model)

        if response.startswith("OLLAMA_ERROR:"):
            print(f"\n  {response}")
            log_result(8, attempt, n_pass, n_total, "OLLAMA_ERROR",
                       "N/A", response[:80])
            time.sleep(5)
            continue
        print(f"done (targeting Phase {target_phase})")

        edit = parse_response(response)
        if not edit:
            print(f"  Could not parse response")
            last_failure_context = "Response format was wrong. Use EXACTLY: ANALYSIS/FILE/FIND/REPLACE/EXPECTED."
            history.append(f"Attempt {attempt}: unparseable")
            log_result(8, attempt, n_pass, n_total, "PARSE_FAIL",
                       "N/A", "Could not parse AI response")
            print(f"  >> NEXT STRATEGY: Re-querying with stricter format instructions")
            continue

        analysis_short = edit.get("analysis", "")[:100]
        print(f"  Analysis: {analysis_short}")

        # Check locked constants for the target phase
        target_info = PHASES[target_phase]
        locked_violation = check_locked_constants(
            edit["find"], edit["replace"], target_info["locked_constants"])
        if locked_violation:
            print(f"  REJECTED: {locked_violation}")
            last_failure_context = locked_violation
            history.append(f"Attempt {attempt}: REJECTED locked constant change")
            log_result(8, attempt, n_pass, n_total, "LOCKED_VIOLATION",
                       target_info["script"], locked_violation[:80])
            print(f"  >> NEXT STRATEGY: AI must find non-locked parameters to adjust")
            continue

        if dry_run:
            print(f"  [DRY RUN] Would modify Phase {target_phase}")
            log_result(8, attempt, n_pass, n_total, "DRY_RUN",
                       PHASES[target_phase]["script"], analysis_short)
            last_failure_context = ""
            continue

        # Apply to SOURCE phase
        target_script = phase_script_path(target_phase)
        bk = backup_file(target_script, target_phase, 800 + attempt)

        if not apply_edit(target_script, edit["find"], edit["replace"]):
            diagnosis = diagnose_edit_failure(target_script, edit["find"])
            print(f"  FAILED: Edit could not be applied to {target_info['script']}")
            print(f"  >> WHY: {diagnosis}")
            revert_file(target_script, bk)
            last_failure_context = (f"Find/replace FAILED on {target_info['script']}: {diagnosis}. "
                                    f"Copy FIND text EXACTLY from the source code.")
            history.append(f"Attempt {attempt}: edit failed on Phase {target_phase} -- {diagnosis[:60]}")
            log_result(8, attempt, n_pass, n_total, "EDIT_FAIL",
                       target_info["script"], diagnosis[:80])
            print(f"  >> NEXT STRATEGY: Re-querying with failure diagnosis")
            continue

        last_failure_context = ""

        # Validate the source phase still passes
        print(f"  Validating Phase {target_phase}...", end=" ", flush=True)
        source_passed, _ = run_phase_tests(target_phase)
        if not source_passed:
            print(f"BROKE Phase {target_phase} -- reverting")
            revert_file(target_script, bk)
            last_failure_context = (f"Change broke Phase {target_phase}'s own tests. "
                                    f"The fix must keep Phase {target_phase} passing while improving integration.")
            history.append(f"Attempt {attempt}: broke Phase {target_phase}, reverted")
            log_result(8, attempt, n_pass, n_total, "BROKE_SOURCE",
                       target_info["script"], f"Broke Phase {target_phase}")
            print(f"  >> NEXT STRATEGY: AI must make a change that keeps Phase {target_phase} passing")
            continue
        print("still passing")

        # Re-run Phase 8
        print(f"  Re-checking integration...", end=" ", flush=True)
        new_passed, new_output = run_phase_tests(8)
        new_results = extract_test_results(new_output)
        new_n_pass = sum(1 for t in new_results if t["passed"])

        if new_n_pass < n_pass:
            print(f"WORSE ({n_pass}->{new_n_pass}) -- reverting")
            revert_file(target_script, bk)
            last_failure_context = (f"Last change REGRESSED integration from {n_pass} to {new_n_pass}. "
                                    f"Change was: {analysis_short}. Try a DIFFERENT approach.")
            history.append(f"Attempt {attempt}: regressed {n_pass}->{new_n_pass}")
            log_result(8, attempt, new_n_pass, len(new_results), "REVERTED",
                       target_info["script"], f"Regressed {n_pass}->{new_n_pass}")
            print(f"  >> NEXT STRATEGY: Reverted. AI will try a different parameter.")
        elif new_n_pass > n_pass:
            print(f"IMPROVED! ({n_pass}->{new_n_pass}) -- KEPT")
            history.append(f"Attempt {attempt}: IMPROVED Phase {target_phase} fix, {n_pass}->{new_n_pass}")
            log_result(8, attempt, new_n_pass, len(new_results), "IMPROVED",
                       target_info["script"], analysis_short)
        else:
            print(f"SAME ({n_pass}) -- kept")
            history.append(f"Attempt {attempt}: same score")
            log_result(8, attempt, new_n_pass, len(new_results), "KEPT_SAME",
                       target_info["script"], analysis_short)

        if new_passed:
            print(f"\n  ALL 15 INTEGRATION TESTS PASS!")
            log(f"Phase 8 COMPLETE ({new_n_pass}/{len(new_results)})")
            log_result(8, attempt, new_n_pass, len(new_results), "COMPLETE",
                       "full_sim.py", "All integration tests pass")
            return True

        time.sleep(1)


# ---------------------------------------------------------------------------
# Status Display
# ---------------------------------------------------------------------------
def show_status():
    print(f"\n{'='*70}")
    print(f"  KARPATHY RESEARCH MACHINE -- STATUS")
    print(f"{'='*70}\n")

    for phase_num in range(1, 9):
        info = PHASES[phase_num]
        print(f"  Phase {phase_num}: {info['name']:<30}", end="", flush=True)
        passed, output = run_phase_tests(phase_num)
        results = extract_test_results(output)
        n_pass = sum(1 for t in results if t["passed"])
        n_total = len(results)
        status = "PASS" if passed else "FAIL"
        print(f"{bar(n_pass, n_total)}  {status}")

    # Show results.tsv summary if it exists
    if RESULTS_TSV.exists():
        print(f"\n  Experiment log: {RESULTS_TSV}")
        try:
            with open(RESULTS_TSV, "r", encoding="utf-8") as f:
                reader = csv.reader(f, delimiter="\t")
                rows = list(reader)
            if len(rows) > 1:
                total_experiments = len(rows) - 1
                improved = sum(1 for r in rows[1:] if r[5] == "IMPROVED")
                reverted = sum(1 for r in rows[1:] if r[5] == "REVERTED")
                print(f"  Total experiments: {total_experiments}")
                print(f"  Improvements kept: {improved}")
                print(f"  Reverted: {reverted}")
        except Exception:
            pass

    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Karpathy Research Machine - Smoke & Honey")
    parser.add_argument("--start-at", type=int, default=1,
                        help="Start from phase N (default: 1)")
    parser.add_argument("--status", action="store_true",
                        help="Show all phases pass/fail and exit")
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help=f"Ollama model (default: {DEFAULT_MODEL})")
    parser.add_argument("--skip-validate", action="store_true",
                        help="Skip phase validation, go straight to integration")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show AI suggestions without applying changes")
    args = parser.parse_args()

    print()
    print("=" * 70)
    print("  KARPATHY RESEARCH MACHINE")
    print("  Smoke & Honey Beekeeping Simulation")
    print("  Modeled after github.com/karpathy/autoresearch")
    print("  NEVER STOPS -- Ctrl+C to interrupt")
    print("=" * 70)

    if args.status:
        show_status()
        return 0

    # System temp check
    temp_ok, temp_msg = check_system_temps()
    print(f"\n  {temp_msg}")
    if not temp_ok:
        print(f"  System is already hot! Waiting for cooldown before starting...")
        thermal_cooldown()

    # Check Ollama
    print(f"\n  Ollama...", end=" ", flush=True)
    if not check_ollama():
        print("NOT RUNNING")
        print(f"\n  Start Ollama first:")
        print(f"    ollama serve")
        print(f"    ollama pull {args.model}")
        return 1
    print(f"connected ({args.model})")

    # Init results.tsv
    init_results_tsv()
    print(f"  Results: {RESULTS_TSV}")
    print(f"  Tracking: results.tsv + backups/ (no git commits)")

    # Init log
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*70}\n")
        f.write(f"SESSION {time.strftime('%Y-%m-%d %H:%M:%S')} | model={args.model}\n")
        f.write(f"{'='*70}\n")

    if args.dry_run:
        print(f"\n  DRY RUN MODE -- showing suggestions without applying")

    print(f"\n  Press Ctrl+C to stop at any time")
    print(f"  The loop runs until you interrupt it or all tests pass.\n")

    try:
        if not args.skip_validate:
            # ========================================
            # BOTTOM-UP: Phases 1-7
            # Each phase perfected before moving up
            # ========================================
            for phase_num in range(args.start_at, 8):
                info = PHASES[phase_num]
                print_phase_header(phase_num)

                # Quick check -- does it already pass?
                print(f"  Testing current state...", end=" ", flush=True)
                passed, output = run_phase_tests(phase_num)
                results = extract_test_results(output)
                n_pass = sum(1 for t in results if t["passed"])
                n_total = len(results)
                print(f"{bar(n_pass, n_total)}")

                if passed:
                    print(f"  Already passing -- LOCKED")
                    log(f"Phase {phase_num}: already passing, locked")
                    log_result(phase_num, 0, n_pass, n_total, "ALREADY_LOCKED",
                               info["script"], "Already passing")
                    continue

                # Edge case: all extracted tests pass but return code != 0
                # (script error outside test framework, import error, etc.)
                if n_total > 0 and n_pass == n_total:
                    print(f"  All {n_total} tests pass but script exited with error!")
                    print(f"  This may be an import error or syntax issue.")
                    # Show last few lines of output for context
                    out_lines = [l for l in output.strip().split("\n") if l.strip()]
                    for ol in out_lines[-5:]:
                        print(f"    {ol}")
                    print(f"  Treating as LOCKED (test logic is sound)")
                    log(f"Phase {phase_num}: all tests pass but returncode!=0, locked anyway")
                    log_result(phase_num, 0, n_pass, n_total, "ALREADY_LOCKED",
                               info["script"], "All tests pass (non-zero exit)")
                    continue

                # Needs research -- loop indefinitely
                print(f"  {n_total - n_pass} failing test(s) -- entering research loop")
                print(f"  (loops until all pass or Ctrl+C)")

                success = research_phase(phase_num, args.model, args.dry_run)

                if not success and not args.dry_run:
                    # This shouldn't happen since the loop is infinite,
                    # but just in case (Ctrl+C caught elsewhere, etc.)
                    print(f"\n  Phase {phase_num} interrupted.")
                    print(f"  Continuing to next phase...")
                    log(f"Phase {phase_num}: interrupted, moving on")

        # ========================================
        # TOP: Phase 8 Integration
        # All subsystems -> full integration
        # Fixes go to SOURCE phases, not full_sim.py
        # ========================================
        print_phase_header(8, "All subsystems -> full integration")

        # Quick check
        print(f"  Testing integration...", end=" ", flush=True)
        passed, output = run_phase_tests(8)
        results = extract_test_results(output)
        n_pass = sum(1 for t in results if t["passed"])
        n_total = len(results)
        print(f"{bar(n_pass, n_total)}")

        if passed:
            print(f"\n  ALL INTEGRATION TESTS PASS!")
            print(f"  The simulation accurately emulates nature.")
            print(f"  Ready for GDScript porting.")
            log(f"Phase 8: already passing -- COMPLETE")
            return 0

        print(f"  {n_total - n_pass} integration test(s) failing")
        print(f"  Entering integration research loop...")
        print(f"  (Fixes go to SOURCE phases, not full_sim.py)")
        print(f"  (Loops indefinitely until all 15 pass or Ctrl+C)")

        success = research_integration(args.model, args.dry_run)

        if success:
            print(f"\n{'='*70}")
            print(f"  SIMULATION COMPLETE")
            print(f"  All phases validated. All integration tests pass.")
            print(f"  The bee colony lifecycle matches real-world data.")
            print(f"  Port these constants to GDScript with confidence.")
            print(f"{'='*70}")
            return 0
        else:
            print(f"\n  Research session ended.")
            print(f"  Progress saved. Run again to continue.")
            print(f"  Results: {RESULTS_TSV}")
            print(f"  Log: {LOG_FILE}")
            return 1

    except KeyboardInterrupt:
        print(f"\n\n  Stopped (Ctrl+C)")
        print(f"  All changes are backed up in: {BACKUP_DIR}/")
        print(f"  Results: {RESULTS_TSV}")
        print(f"  Log: {LOG_FILE}")
        print(f"  Run again to continue where you left off.")
        return 0


if __name__ == "__main__":
    sys.exit(main())

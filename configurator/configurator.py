#!/usr/bin/env python3
#################################################################################################################################
##   _______   _                      __     __             _
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/                            ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/
##           /_/                                    /___/                                              chipmunklogic.com
#################################################################################################################################
# File Name        : configurator.py
# Module Name      : PQR5 Interactive Configurator
# Author           : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic (TM), https://chipmunklogic.com
#
# Description      : Menu-driven, interactive configurator for the Pequeno RISC-V (PQR5) database. Helps configure the
#                     macros in src/include/*.svh and the Makefile of CoreMark & Dhrystone benchmarks, without the user
#                     having to hand-edit multiple files for every run (example programs/regressions/synthesis/
#                     CoreMark/Dhrystone). Note: linker.ld IRAM/DRAM LENGTH is kept in sync automatically whenever the
#                     Benchmark flow sets IRAM/DRAM size; it is otherwise never touched by this tool.
#
# Usage            : ./configurator.sh -- interactive main menu (run from the repo root)
#
# Copyright        : Open-source license, see LICENSE.
#################################################################################################################################

import argparse
import difflib
import os
import re
import sys
from pathlib import Path

try:
    import termios
    import tty
    import select
    _POSIX_TTY = True
except ImportError:
    _POSIX_TTY = False

try:
    import msvcrt
    _WINDOWS_TTY = True
except ImportError:
    _WINDOWS_TTY = False

# =================================================================================================================================
# Paths
# =================================================================================================================================
SCRIPT_DIR  = Path(__file__).resolve().parent
REPO_ROOT   = SCRIPT_DIR.parent

CORE_SVH    = REPO_ROOT / "src" / "include" / "pqr5_core_macros.svh"
SUBSYS_SVH  = REPO_ROOT / "src" / "include" / "pqr5_subsystem_macros.svh"
CMK_MAKE    = REPO_ROOT / "coremark" / "Makefile"
CMK_LINKER  = REPO_ROOT / "coremark" / "linker.ld"
DHRY_MAKE   = REPO_ROOT / "dhrystone" / "Makefile"
DHRY_LINKER = REPO_ROOT / "dhrystone" / "linker.ld"
RVTEST_DIR  = REPO_ROOT / "riscv_tests"
RVTESTS     = ["median", "memcpy", "multiply", "qsort", "rsort", "towers"]

BUILD_NOTES = REPO_ROOT / "build_notes.txt"


class SkipRemaining(Exception):
    """Raised when the user presses 's' to skip all remaining questions in the current flow and
    jump straight to the summary/review step, keeping the current/default values for the rest."""
    pass


class QuitConfigurator(Exception):
    """Raised when the user types/presses 'q' at ANY prompt, anywhere in the tool -- unlike 's' (skip
    to summary), this unwinds all the way out to main() immediately, applying nothing further. This
    is the only way out that doesn't require finishing (or Ctrl+C-ing) whatever flow you're in."""
    pass

# =================================================================================================================================
# Colors
# =================================================================================================================================
class C:
    ENABLED = sys.stdout.isatty()
    RESET   = "\033[0m"   if ENABLED else ""
    BOLD    = "\033[1m"   if ENABLED else ""
    DIM     = "\033[2m"   if ENABLED else ""
    RED     = "\033[91m"  if ENABLED else ""
    GREEN   = "\033[92m"  if ENABLED else ""
    YELLOW  = "\033[93m"  if ENABLED else ""
    BLUE    = "\033[94m"  if ENABLED else ""
    MAGENTA = "\033[95m"  if ENABLED else ""
    CYAN    = "\033[96m"  if ENABLED else ""
    WHITE   = "\033[97m"  if ENABLED else ""
    ORANGE  = "\033[38;5;208m" if ENABLED else ""
    GREY    = "\033[38;5;245m" if ENABLED else ""
    ARROW   = "\033[38;5;46m"  if ENABLED else ""   # bright spring-green accent for the selector arrow


def c(text, *codes):
    return "".join(codes) + text + C.RESET


def hr(char="-", width=110, color=C.GREY):
    print(c(char * width, color))


def clear_screen():
    if C.ENABLED:
        print("\033[2J\033[H", end="")


def title():
    print()
    hr("=", color=C.CYAN)
    print(c("  PEQUENO R5 (PQR5)  ", C.BOLD, C.CYAN) + c("Configurator", C.BOLD, C.WHITE))
    print(c("  chipmunklogic.com", C.DIM, C.GREY))
    hr("=", color=C.CYAN)


def header(title_text):
    print()
    hr("=")
    print(c(f"  {title_text}", C.BOLD, C.CYAN))
    hr("=")


# =================================================================================================================================
# File I/O helpers
# =================================================================================================================================
def read_lines(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Expected file not found: {path}")
    return path.read_text().splitlines()


def write_lines(path: Path, lines):
    path.write_text("\n".join(lines) + "\n")


def unified_diff(old_lines, new_lines, old_label, new_label):
    return list(difflib.unified_diff(old_lines, new_lines, fromfile=old_label, tofile=new_label, lineterm=""))


def print_diff(diff_lines):
    if not diff_lines:
        print(c("  (no differences)", C.DIM))
        return
    for line in diff_lines:
        if line.startswith("+") and not line.startswith("+++"):
            print(c(line, C.GREEN))
        elif line.startswith("-") and not line.startswith("---"):
            print(c(line, C.RED))
        elif line.startswith("@@"):
            print(c(line, C.CYAN))
        else:
            print(c(line, C.GREY))


# =================================================================================================================================
# SVH macro helpers  (feature toggles are commented-out `//`define NAME`` when disabled, no leading whitespace in this codebase)
# =================================================================================================================================
def _toggle_pattern(name):
    return re.compile(r'^(//)?(`define\s+' + re.escape(name) + r'\b.*)$')


def svh_toggle_get(lines, name):
    pat = _toggle_pattern(name)
    for line in lines:
        m = pat.match(line)
        if m:
            return m.group(1) is None
    raise KeyError(f"Macro `{name} not found")


def svh_toggle_set(lines, name, enable: bool):
    pat = _toggle_pattern(name)
    for i, line in enumerate(lines):
        m = pat.match(line)
        if m:
            body = m.group(2)
            lines[i] = body if enable else "//" + body
            return
    raise KeyError(f"Macro `{name} not found")


def _value_pattern(name):
    return re.compile(r'^(`define\s+' + re.escape(name) + r'\s+)(\S+)(.*)$')


def svh_value_get(lines, name):
    pat = _value_pattern(name)
    for line in lines:
        m = pat.match(line)
        if m:
            return m.group(2)
    raise KeyError(f"Macro `{name} not found")


def svh_value_set(lines, name, value):
    pat = _value_pattern(name)
    for i, line in enumerate(lines):
        m = pat.match(line)
        if m:
            lines[i] = m.group(1) + value + m.group(3)
            return
    raise KeyError(f"Macro `{name} not found")


# =================================================================================================================================
# Makefile "KEY = value" helpers
# =================================================================================================================================
def _makefile_pattern(key):
    return re.compile(r'^(' + re.escape(key) + r'\s*=\s*)(\S+)(.*)$')


def makefile_value_get(lines, key):
    pat = _makefile_pattern(key)
    for line in lines:
        m = pat.match(line)
        if m:
            return m.group(2)
    raise KeyError(f"Makefile key {key} not found")


def makefile_value_set(lines, key, value):
    pat = _makefile_pattern(key)
    for i, line in enumerate(lines):
        m = pat.match(line)
        if m:
            lines[i] = m.group(1) + value + m.group(3)
            return
    raise KeyError(f"Makefile key {key} not found")


# =================================================================================================================================
# linker.ld MEMORY region LENGTH helpers
# =================================================================================================================================
def _linker_pattern(region):
    tag = "rx" if region == "IRAM" else "rw"
    return re.compile(r'^(\s*' + region + r'\s*\(' + tag + r'\)\s*:\s*ORIGIN\s*=\s*\S+,\s*LENGTH\s*=\s*)(\S+)(.*)$')


def linker_length_get(lines, region):
    pat = _linker_pattern(region)
    for line in lines:
        m = pat.match(line)
        if m:
            return m.group(2)
    raise KeyError(f"Region {region} not found in linker.ld")


def linker_length_set(lines, region, size_kb):
    """Writes LENGTH as a 'NNK' token (same KB unit already used throughout linker.ld), so the value
    stays directly comparable to the KB the user was asked for -- no lossy bytes<->K back-conversion."""
    pat = _linker_pattern(region)
    for i, line in enumerate(lines):
        m = pat.match(line)
        if m:
            lines[i] = m.group(1) + f"{size_kb}K" + m.group(3)
            return
    raise KeyError(f"Region {region} not found in linker.ld")


# =================================================================================================================================
# Size helpers (KB <-> bytes, "32K" style linker.ld tokens)
# =================================================================================================================================
def parse_kb(text):
    m = re.match(r'^\s*(\d+)\s*[kK]?\s*$', text)
    if not m:
        raise ValueError(f"'{text}' is not a valid size (expected e.g. 32 or 32K)")
    return int(m.group(1))


def kb_to_bytes(kb):
    return kb * 1024


def bytes_to_kb(size_bytes):
    return size_bytes // 1024


# =================================================================================================================================
# Raw keyboard input (for the arrow-key menu) — POSIX (termios) and Windows (msvcrt)
# =================================================================================================================================
class _RawInput:
    def __enter__(self):
        if _POSIX_TTY:
            self.fd = sys.stdin.fileno()
            self.old_settings = termios.tcgetattr(self.fd)
            tty.setcbreak(self.fd)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if _POSIX_TTY:
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old_settings)

    def getkey(self):
        if _WINDOWS_TTY:
            ch = msvcrt.getch()
            if ch in (b"\x00", b"\xe0"):
                ch2 = msvcrt.getch()
                return {b"H": "UP", b"P": "DOWN"}.get(ch2)
            if ch in (b"\r", b"\n"):
                return "ENTER"
            if ch == b"\x03":
                raise KeyboardInterrupt
            if ch in (b"q", b"Q"):
                return "QUIT"
            if ch in (b"s", b"S"):
                return "SKIP"
            return None
        elif _POSIX_TTY:
            # Read straight off the raw fd with os.read(), never sys.stdin.read(): the latter is a
            # buffered TextIOWrapper that can silently slurp an entire escape sequence into its
            # internal buffer on the first read, after which select() on the (now-empty-at-the-OS-
            # level) fd sees "nothing ready" and stalls out the full timeout before giving up on
            # what looked like a dropped/slow arrow key.
            ch = os.read(self.fd, 1).decode(errors="ignore")
            if ch == "\x1b":
                # Only a genuine arrow-key escape sequence (ESC [ A/B) does anything; a lone ESC
                # (e.g. slow SSH link splitting the sequence) is just ignored rather than quitting,
                # so 'q' remains the one unambiguous way to cancel/quit.
                if select.select([self.fd], [], [], 0.15)[0]:
                    ch2 = os.read(self.fd, 1).decode(errors="ignore")
                    if ch2 == "[" and select.select([self.fd], [], [], 0.15)[0]:
                        ch3 = os.read(self.fd, 1).decode(errors="ignore")
                        return {"A": "UP", "B": "DOWN"}.get(ch3)
                return None
            if ch in ("\r", "\n"):
                return "ENTER"
            if ch == "\x03":
                raise KeyboardInterrupt
            if ch in ("q", "Q"):
                return "QUIT"
            if ch in ("s", "S"):
                return "SKIP"
            return None
        return None


def _interactive_tty():
    return (_POSIX_TTY or _WINDOWS_TTY) and sys.stdin.isatty() and sys.stdout.isatty()


def arrow_select(question, options, default_index=0, hints=None, allow_skip=False):
    """Modern arrow-key driven menu. Falls back to a numbered prompt when not attached to a real
    terminal (e.g. piped input during scripted/automated use), so the tool stays scriptable."""
    if not _interactive_tty():
        return _numbered_choice(question, options, default_index, allow_skip=allow_skip)

    idx = default_index
    skip_hint = "    s skip rest" if allow_skip else ""
    n_lines = len(options) + 2  # question line + options + hint line

    def render():
        lines = [c(question, C.CYAN, C.BOLD)]
        for i, opt in enumerate(options):
            hint = f"  {c(hints[i], C.DIM)}" if hints and hints[i] else ""
            if i == idx:
                lines.append(c("  ❯ ", C.BOLD, C.ARROW) + c(opt, C.BOLD, C.WHITE) + hint)
            else:
                lines.append("    " + c(opt, C.GREY) + hint)
        lines.append(c(f"  ↑/↓ move    Enter select    q quit{skip_hint}", C.DIM))
        return lines

    print(c("\033[?25l", ""), end="")  # hide cursor
    try:
        with _RawInput() as ri:
            lines = render()
            print("\n".join(lines))
            while True:
                key = ri.getkey()
                if key == "UP":
                    idx = (idx - 1) % len(options)
                elif key == "DOWN":
                    idx = (idx + 1) % len(options)
                elif key == "ENTER":
                    break
                elif key == "QUIT":
                    raise QuitConfigurator()
                elif key == "SKIP" and allow_skip:
                    raise SkipRemaining()
                else:
                    continue
                print(f"\033[{n_lines}A", end="")
                lines = render()
                for ln in lines:
                    print("\033[2K" + ln)
    finally:
        print("\033[?25h", end="")  # show cursor
    return idx


def _numbered_choice(question, options, default_index=0, allow_skip=False):
    print(c(question, C.CYAN, C.BOLD))
    for i, opt in enumerate(options, 1):
        marker = c(" (default)", C.DIM) if (i - 1) == default_index else ""
        print(f"    {i}) {opt}{marker}")
    skip_hint = ", 's' to skip rest" if allow_skip else ""
    print(c(f"  (Enter a number, or 'q' to quit{skip_hint})", C.DIM))
    while True:
        ans = input(c("  Choice: ", C.DIM)).strip()
        if ans.lower() in ("q", "quit"):
            raise QuitConfigurator()
        if allow_skip and ans.lower() in ("s", "skip"):
            raise SkipRemaining()
        if ans == "":
            return default_index
        if ans.isdigit() and 1 <= int(ans) <= len(options):
            return int(ans) - 1
        print(c("  Please enter a valid option number.", C.YELLOW))


# =================================================================================================================================
# Prompt helpers
# =================================================================================================================================
def ask_yes_no(question, default: bool, allow_skip=False):
    suffix = c(" [Y/n/q]: ", C.DIM) if default else c(" [y/N/q]: ", C.DIM)
    while True:
        ans = input(c(question, C.CYAN, C.BOLD) + suffix).strip().lower()
        if ans in ("q", "quit"):
            raise QuitConfigurator()
        if allow_skip and ans in ("s", "skip"):
            raise SkipRemaining()
        if ans == "":
            return default
        if ans in ("y", "yes"):
            return True
        if ans in ("n", "no"):
            return False
        print(c("  Please answer y or n (or 'q' to quit).", C.YELLOW))


def ask_value(question, default, validator=None, allow_skip=False):
    while True:
        ans = input(c(question, C.CYAN, C.BOLD) + c(f" [default: {default}]: ", C.DIM)).strip()
        if ans.lower() in ("q", "quit"):
            raise QuitConfigurator()
        if allow_skip and ans.lower() in ("s", "skip"):
            raise SkipRemaining()
        if ans == "":
            ans = str(default)
        if validator:
            ok, msg = validator(ans)
            if not ok:
                print(c(f"  {msg}", C.YELLOW))
                continue
        return ans


def ask_choice(question, options, default_index=0, hints=None, allow_skip=False):
    return arrow_select(question, options, default_index=default_index, hints=hints, allow_skip=allow_skip)


def ask_size_kb(question, default_kb, min_kb, subject, allow_skip=False, max_kb=64):
    while True:
        raw = input(
            c(question, C.CYAN, C.BOLD) +
            c(f" [default: {default_kb}K, min. recommended: {min_kb}K, max: {max_kb}K]: ", C.DIM)
        ).strip()
        if raw.lower() in ("q", "quit"):
            raise QuitConfigurator()
        if allow_skip and raw.lower() in ("s", "skip"):
            raise SkipRemaining()
        val = raw if raw else str(default_kb)
        try:
            kb = parse_kb(val)
        except ValueError as e:
            print(c(f"  {e}", C.YELLOW))
            continue
        if kb > max_kb:
            print(c(f"  ERROR: {kb}K is currently not supported by the Subsystem. Max supported is {max_kb}K.", C.RED, C.BOLD))
            continue
        if kb < min_kb:
            print(c(f"  NOTE: {subject} requires a minimum of {min_kb}K. {kb}K is below that and the "
                     f"build/run may fail or misbehave.", C.YELLOW, C.BOLD))
            if not ask_yes_no("  Proceed with this smaller size anyway?", default=False):
                continue
        return kb


def pause():
    ans = input(c("\nPress ENTER to continue...", C.DIM)).strip().lower()
    if ans in ("q", "quit"):
        raise QuitConfigurator()


# =================================================================================================================================
# Review & apply — always show a diff and get one final explicit confirmation before touching any live file
# =================================================================================================================================
def review_and_apply_all(changes, title="Proposed changes"):
    """changes: list of dicts {label, path, old_lines, new_lines}"""
    real_changes = [ch for ch in changes if ch["old_lines"] != ch["new_lines"]]
    header(title)
    if not real_changes:
        print(c("No changes to apply — configuration already matches what you selected.", C.GREEN))
        return True  # Files already reflect the chosen config, so it's still safe/correct to run the build.

    for ch in real_changes:
        print()
        print(c(f"--- {ch['label']} ({ch['path']}) ---", C.BOLD, C.MAGENTA))
        print_diff(unified_diff(ch["old_lines"], ch["new_lines"], "current", "new"))

    print()
    if ask_yes_no(f"Apply all {len(real_changes)} file change(s) above?", default=True):
        for ch in real_changes:
            write_lines(ch["path"], ch["new_lines"])
        print(c(f"\nApplied changes to {len(real_changes)} file(s).", C.GREEN, C.BOLD))
        return True
    else:
        print(c("\nDiscarded. No files were modified.", C.YELLOW))
        return False


# =================================================================================================================================
# Feature summary table — reused by "View Current Configuration Summary" and by the pre-apply
# review step of both configuration flows, so the user always sees the same feature-oriented view.
# =================================================================================================================================
def print_row(label, value, macro=None):
    suffix = c(f"   [{macro}]", C.DIM) if macro else ""
    print(f"  {label:<32}: {c(str(value), C.CYAN, C.BOLD)}{suffix}")


def print_core_subsys_rows(core, subsys):
    print(c("\nCore:", C.BOLD))
    print_row("Reset vector", svh_value_get(core, "PC_INIT"), "PC_INIT")
    print_row("Register File on Block RAM", "Enabled" if svh_toggle_get(core, "RF_ON_BRAM") else "Disabled", "RF_ON_BRAM")
    print_row("Branch Predictor", "Dynamic (GShare)" if svh_toggle_get(core, "BPREDICT_DYN") else "Static (backward-taken)", "BPREDICT_DYN")
    print_row("Return Address Stack (RAS)", "Enabled" if svh_toggle_get(core, "RAS") else "Disabled", "RAS")
    if svh_toggle_get(core, "MULTDIV"):
        mult_type = "DSP x32 multiplier" if svh_value_get(core, "EN_FPGA_DSP_MULT") == "1" else "Radix-4 Booth multiplier"
        print_row("Hardware Multiplier/Divider", f"Enabled ({mult_type})", "MULTDIV")
    else:
        print_row("Hardware Multiplier/Divider", "Disabled", "MULTDIV")
    print_row("Test Ports", "Enabled" if svh_toggle_get(core, "TEST_PORTS") else "Disabled", "TEST_PORTS")
    print_row("Synthesis build (Core)", "Yes" if svh_toggle_get(core, "CORE_SYNTH") else "No", "CORE_SYNTH")
    print_row("Debug interfaces (Core)", "Enabled" if svh_toggle_get(core, "DBG") else "Disabled", "DBG")
    print_row("Exit sim on END instruction", "Enabled" if svh_toggle_get(core, "SIMEXIT_INSTR_END") else "Disabled", "SIMEXIT_INSTR_END")
    print_row("Register File dump", "Yes" if svh_value_get(core, "REGFILE_DUMP") == "1" else "No", "REGFILE_DUMP")

    print(c("\nSubsystem:", C.BOLD))
    print_row("Loader (UART programming)", "Enabled" if svh_toggle_get(subsys, "EN_LOADER") else "Disabled", "EN_LOADER")
    print_row("Benchmark support", "Enabled" if svh_toggle_get(subsys, "BENCHMARK") else "Disabled", "BENCHMARK")
    print_row("Clock speed", f"{svh_value_get(subsys, 'FCLK')} MHz", "FCLK")
    print_row("IRAM size", f"{svh_value_get(subsys, 'IRAM_SIZE')} bytes", "IRAM_SIZE")
    print_row("DRAM size", f"{svh_value_get(subsys, 'DRAM_SIZE')} bytes", "DRAM_SIZE")
    print_row("Synthesis build (Subsystem)", "Yes" if svh_toggle_get(subsys, "SUBSYS_SYNTH") else "No", "SUBSYS_SYNTH")
    print_row("Simulation TB clock/reset", "Enabled" if svh_toggle_get(subsys, "SUBSYS_DBG") else "Disabled", "SUBSYS_DBG")
    print_row("Simulation cycle limit", "Enabled" if svh_toggle_get(subsys, "SIMLIMIT") else "Disabled", "SIMLIMIT")
    print_row("Memory debug/dump ports", "Enabled" if svh_toggle_get(subsys, "MEM_DBG") else "Disabled", "MEM_DBG")
    print_row("DMEM latency model", "Zero-latency" if svh_value_get(subsys, "DMEM_IS_ZERO_LAT") == "1" else "Non-zero latency", "DMEM_IS_ZERO_LAT")
    print_row("Debug UART", "Enabled" if svh_toggle_get(subsys, "DBGUART") else "Disabled", "DBGUART")
    print_row("Debug UART baud rate", svh_value_get(subsys, "DBGUART_BRATE"), "DBGUART_BRATE")


# =================================================================================================================================
# CoreMark / Dhrystone benchmark configuration
# =================================================================================================================================
BENCH_PROFILES = {
    "coremark": {
        "name": "CoreMark",
        "makefile": CMK_MAKE,
        "linker": CMK_LINKER,
        "min_iram_kb": 32,
        "min_dram_kb": 8,
        "default_iterations": 400,
    },
    "dhrystone": {
        "name": "Dhrystone",
        "makefile": DHRY_MAKE,
        "linker": DHRY_LINKER,
        "min_iram_kb": 32,
        "min_dram_kb": 32,
        "default_iterations": 500,
    },
}


def configure_benchmark():
    header("CoreMark / Dhrystone Benchmark Configuration")
    print("Reference: see 'Building CoreMark(R) CPU Benchmark' / 'Building Dhrystone CPU Benchmark'")
    print(f"sections of {c(str(BUILD_NOTES), C.CYAN)} for full details.")
    print(c("Note: linker.ld's IRAM/DRAM LENGTH will be kept in sync with the sizes chosen below.", C.YELLOW))
    print(c("Tip: type 's' at any prompt below to skip the remaining questions and jump to the summary.", C.DIM))
    print(c("Tip: type 'q' at any prompt (below or later) to quit immediately, with nothing further changed.\n", C.DIM))

    idx = ask_choice("Which benchmark do you want to configure?", ["CoreMark", "Dhrystone", "Back to main menu"], default_index=0)
    if idx == 2:
        return
    profile = BENCH_PROFILES["coremark" if idx == 0 else "dhrystone"]
    name = profile["name"]

    make_lines_orig = read_lines(profile["makefile"])
    core_lines_orig = read_lines(CORE_SVH)
    subsys_lines_orig = read_lines(SUBSYS_SVH)
    linker_lines_orig = read_lines(profile["linker"])

    make_lines = list(make_lines_orig)
    core_lines = list(core_lines_orig)
    subsys_lines = list(subsys_lines_orig)
    linker_lines = list(linker_lines_orig)

    print()
    print(c(f"NOTE: {name} requires IRAM >= {profile['min_iram_kb']}K and DRAM >= {profile['min_dram_kb']}K.", C.YELLOW, C.BOLD))
    print(c("      You will be warned if you try to go below these minimums.\n", C.YELLOW))

    # Pre-seed every answer with its current/sensible-default value, so anything the user skips
    # past simply keeps that value untouched. (Macros driven via guided_toggle/guided_value below
    # -- BPREDICT_DYN, RAS, MULTDIV, EN_FPGA_DSP_MULT, MULT_PIPE_STAGES -- fetch their own current
    # value and write straight to core_lines, so they don't need pre-seeding here.)
    iram_kb = max(bytes_to_kb(int(svh_value_get(subsys_lines, "IRAM_SIZE"))), profile["min_iram_kb"])
    dram_kb = max(bytes_to_kb(int(svh_value_get(subsys_lines, "DRAM_SIZE"))), profile["min_dram_kb"])
    iterations = makefile_value_get(make_lines, "ITERATIONS")
    cur_clocks = makefile_value_get(make_lines, "CLOCKS_PER_SEC")
    mhz = int(cur_clocks) // 1_000_000 if cur_clocks.isdigit() else 12
    baud = svh_value_get(subsys_lines, "DBGUART_BRATE")
    debug_needed = True
    synth_needed = svh_toggle_get(core_lines, "CORE_SYNTH")

    try:
        # --- IRAM/DRAM Interface configuration ------------------------------------------------------------------------------
        print()
        print(c("IRAM/DRAM Interface configuration:", C.BOLD, C.CYAN))
        iram_kb = ask_size_kb(f"IRAM size for {name} (KB)?", iram_kb, profile["min_iram_kb"], name, allow_skip=True)
        dram_kb = ask_size_kb(f"DRAM size for {name} (KB)?", dram_kb, profile["min_dram_kb"], name, allow_skip=True)

        # --- {name} configuration --------------------------------------------------------------------------------------------
        print()
        print(c(f"{name} configuration:", C.BOLD, C.CYAN))
        iterations = ask_value(f"Number of {name} iterations/runs?", iterations,
                                validator=lambda s: (s.isdigit() and int(s) > 0, "Must be a positive integer"),
                                allow_skip=True)

        mhz = ask_value("Target system clock speed, in MHz?", mhz,
                         validator=lambda s: (s.isdigit() and int(s) > 0, "Must be a positive integer"),
                         allow_skip=True)

        new_baud = ask_value("Debug UART baud rate (for printing to the serial terminal)?", baud,
                              validator=lambda s: (s.isdigit(), "Must be an integer baud rate"), allow_skip=True)
        if int(new_baud) * 16 >= int(mhz) * 1_000_000:
            print(c(f"  WARNING: {new_baud} baud is not comfortably slower than 1/16 of FCLK ({mhz}MHz)."
                     " The Debug UART may not work reliably.", C.YELLOW))
            if ask_yes_no("  Keep this baud rate anyway?", default=False):
                baud = new_baud
        else:
            baud = new_baud

        # --- CPU configuration -----------------------------------------------------------------------------------------------
        print()
        print(c("CPU configuration:", C.BOLD, C.CYAN))
        # Reuses the same guided_toggle/guided_bool_value/guided_value helpers as the Full Custom flow,
        # so the "[MACRO]  (currently ...)" header above each question is shown consistently in both flows.
        guided_toggle(core_lines, "BPREDICT_DYN", "Enable Dynamic (GShare) Branch Predictor?",
                      note="Static = backward-always-taken heuristic (lighter). Dynamic = GShare, better prediction accuracy on real codes.")
        guided_toggle(core_lines, "RAS", "Enable the Return Address Stack (RAS) predictor?",
                      note="Predicts function-return branches; needs a small depth-N stack of PCs.")
        muldiv = guided_toggle(core_lines, "MULTDIV", "Enable the Hardware Multiplier/Divider (RISC-V M-extension)?",
                                note="Without HW multipliers/dividers, GCC must rely on mul/div/rem SW routines.")
        if muldiv:
            dsp_mult = guided_bool_choice(core_lines, "EN_FPGA_DSP_MULT",
                                           "Which HW multiplier should be used?",
                                           ("FPGA DSP-based x32 multiplier", "Radix-4 Booth multiplier"),
                                           note="DSP-based uses dedicated FPGA DSP slices.")
            if dsp_mult:
                guided_value(core_lines, "MULT_PIPE_STAGES", "Number of DSP multiplier pipeline stages (>= 2)?",
                             note="Tune the pipeline stages according to the target operating frequency.",
                             validator=lambda s: (s.isdigit() and int(s) >= 2, "Must be an integer >= 2"))

        print()
        print(c("[SYNTH Macros]", C.BOLD, C.MAGENTA) + c(f"  (currently {'ENABLED' if synth_needed else 'disabled'})", C.DIM))
        print(c("  Enables CORE_SYNTH/SUBSYS_SYNTH to target Synthesis and Simulation-only features are removed", C.GREY))
        synth_needed = ask_yes_no("Is a Synthesis-ready core (on-board FPGA/ASIC build) required, instead of a simulation build?",
                                   default=synth_needed, allow_skip=True)

        if not synth_needed:
            print()
            print(c("[DBG Macros]", C.BOLD, C.MAGENTA) + c(f"  (currently {'ENABLED' if svh_toggle_get(core_lines, 'DBG') else 'disabled'})", C.DIM))
            print(c("  Enables DBG/SUBSYS_DBG/MEM_DBG (For Simulation purpose only)", C.GREY))
            debug_needed = ask_yes_no("Enable Debug interfaces in the CPU/Subsystem (for Simulation only)?", default=True, allow_skip=True)
        else:
            print(c("\n  (Skipping Debug interfaces prompt — Synth macros disable simulation-only debug macros.)", C.DIM))
    except SkipRemaining:
        print(c("\n(Skipping remaining questions — keeping current/default values for anything not yet asked.)", C.DIM))

    mhz = int(mhz)

    # --- Apply everything to the in-memory file contents ------------------------------------------------------------------
    makefile_value_set(make_lines, "ITERATIONS", iterations)
    makefile_value_set(make_lines, "CLOCKS_PER_SEC", str(mhz * 1_000_000))

    # BPREDICT_DYN, RAS, MULTDIV, EN_FPGA_DSP_MULT, MULT_PIPE_STAGES were already written straight
    # into core_lines by the guided_toggle/guided_bool_value/guided_value calls above.

    if not svh_toggle_get(subsys_lines, "BENCHMARK"):
        svh_toggle_set(subsys_lines, "BENCHMARK", True)
        print(c("  -> BENCHMARK macro will be enabled (required to build/run CoreMark/Dhrystone).", C.CYAN))

    svh_value_set(subsys_lines, "FCLK", str(mhz))
    svh_value_set(subsys_lines, "IRAM_SIZE", str(kb_to_bytes(iram_kb)))
    svh_value_set(subsys_lines, "DRAM_SIZE", str(kb_to_bytes(dram_kb)))
    linker_length_set(linker_lines, "IRAM", iram_kb)
    linker_length_set(linker_lines, "DRAM", dram_kb)

    if not svh_toggle_get(subsys_lines, "DBGUART"):
        svh_toggle_set(subsys_lines, "DBGUART", True)
        print(c("  -> DBGUART will be enabled (benchmark report is printed over the Debug UART).", C.CYAN))
    svh_value_set(subsys_lines, "DBGUART_BRATE", baud)

    svh_value_set(core_lines, "PC_INIT", "32'h0000_0000")

    # Debug macros are only ever touched when NOT building for synthesis; a synthesis build leaves
    # DBG/SUBSYS_DBG/MEM_DBG/REGFILE_DUMP/IMEM_DUMP/DMEM_DUMP exactly as they were, matching the
    # Full Custom flow's behavior. DBG/SUBSYS_DBG/MEM_DBG toggle together either way; the *_DUMP
    # value macros are only ever explicitly enabled (never explicitly disabled) when debug is on.
    if not synth_needed:
        svh_toggle_set(core_lines, "DBG", debug_needed)
        svh_toggle_set(subsys_lines, "SUBSYS_DBG", debug_needed)
        svh_toggle_set(subsys_lines, "MEM_DBG", debug_needed)
        if debug_needed:
            svh_value_set(core_lines, "REGFILE_DUMP", "1")
            svh_value_set(subsys_lines, "IMEM_DUMP", "1")
            svh_value_set(subsys_lines, "DMEM_DUMP", "1")

    svh_toggle_set(core_lines, "CORE_SYNTH", synth_needed)
    svh_toggle_set(subsys_lines, "SUBSYS_SYNTH", synth_needed)

    # --- Feature summary, then a single gate before the detailed file diff/apply step ---------------------------------------
    header(f"{name} Configuration Summary")
    print(c(f"\n{name} Benchmark:", C.BOLD))
    print_row("Iterations", iterations, "ITERATIONS")
    print_row("Clock speed", f"{mhz} MHz", "CLOCKS_PER_SEC / FCLK")
    print_row("IRAM size", f"{iram_kb}K", "IRAM_SIZE")
    print_row("DRAM size", f"{dram_kb}K", "DRAM_SIZE")
    print_core_subsys_rows(core_lines, subsys_lines)
    input(c("\nPress ENTER to review the exact file changes and confirm...", C.DIM))

    changes = [
        {"label": f"{name} Makefile", "path": profile["makefile"], "old_lines": make_lines_orig, "new_lines": make_lines},
        {"label": "Core Macros", "path": CORE_SVH, "old_lines": core_lines_orig, "new_lines": core_lines},
        {"label": "Subsystem Macros", "path": SUBSYS_SVH, "old_lines": subsys_lines_orig, "new_lines": subsys_lines},
        {"label": f"{name} linker.ld", "path": profile["linker"], "old_lines": linker_lines_orig, "new_lines": linker_lines},
    ]
    applied = review_and_apply_all(changes, title=f"{name} Configuration — review before applying")
    if applied:
        print(f"\nPlease run  {c('make ' + ('coremark' if idx == 0 else 'dhryst') + f' ISZ={kb_to_bytes(iram_kb)} DSZ={kb_to_bytes(dram_kb)}', C.CYAN, C.BOLD)}")
        if svh_toggle_get(core_lines, "MULTDIV"):
            print(c(f"  Add ARCH=rv32im to also compile {name} with native HW mul/div (M-extension) instructions.", C.YELLOW))
        print(c(f"Refer to {BUILD_NOTES} for more details.", C.DIM))


# =================================================================================================================================
# RISC-V Standard Test Program configuration
# =================================================================================================================================
def configure_rvtest():
    header("RISC-V Standard Test Program Configuration")
    print("Reference: see 'Building RISC-V Test Programs' section of")
    print(f"{c(str(BUILD_NOTES), C.CYAN)} for full details.")
    print(c("Note: linker.ld's IRAM/DRAM LENGTH will be kept in sync with the sizes chosen below.", C.YELLOW))
    print(c("Tip: type 's' at any prompt below to skip the remaining questions and jump to the summary.", C.DIM))
    print(c("Tip: type 'q' at any prompt (below or later) to quit immediately, with nothing further changed.\n", C.DIM))

    pgm_options = RVTESTS + ["Back to main menu"]
    idx = ask_choice("Which RISC-V test program do you want to configure?", pgm_options, default_index=0)
    if idx == len(RVTESTS):
        return
    pgm = RVTESTS[idx]
    name = pgm
    makefile_path = RVTEST_DIR / pgm / "Makefile"
    linker_path = RVTEST_DIR / pgm / "linker.ld"
    min_iram_kb, min_dram_kb = 16, 16

    make_lines_orig = read_lines(makefile_path)
    core_lines_orig = read_lines(CORE_SVH)
    subsys_lines_orig = read_lines(SUBSYS_SVH)
    linker_lines_orig = read_lines(linker_path)

    make_lines = list(make_lines_orig)
    core_lines = list(core_lines_orig)
    subsys_lines = list(subsys_lines_orig)
    linker_lines = list(linker_lines_orig)

    print()
    print(c(f"NOTE: {name} requires IRAM >= {min_iram_kb}K and DRAM >= {min_dram_kb}K.", C.YELLOW, C.BOLD))
    print(c("      You will be warned if you try to go below these minimums.\n", C.YELLOW))

    # Pre-seed every answer with its current/sensible-default value, so anything the user skips
    # past simply keeps that value untouched. (Macros driven via guided_toggle/guided_bool_choice/
    # guided_value below fetch their own current value and write straight to core_lines.)
    iram_kb = max(bytes_to_kb(int(svh_value_get(subsys_lines, "IRAM_SIZE"))), min_iram_kb)
    dram_kb = max(bytes_to_kb(int(svh_value_get(subsys_lines, "DRAM_SIZE"))), min_dram_kb)
    cur_mhz = makefile_value_get(make_lines, "CLOCK_SPEED_MHZ")
    mhz = int(cur_mhz) if cur_mhz.isdigit() else 12
    baud = svh_value_get(subsys_lines, "DBGUART_BRATE")
    debug_needed = True
    synth_needed = svh_toggle_get(core_lines, "CORE_SYNTH")

    try:
        # --- IRAM/DRAM Interface configuration ------------------------------------------------------------------------------
        print()
        print(c("IRAM/DRAM Interface configuration:", C.BOLD, C.CYAN))
        iram_kb = ask_size_kb(f"IRAM size for {name} (KB)?", iram_kb, min_iram_kb, name, allow_skip=True)
        dram_kb = ask_size_kb(f"DRAM size for {name} (KB)?", dram_kb, min_dram_kb, name, allow_skip=True)

        # --- {name} configuration --------------------------------------------------------------------------------------------
        print()
        print(c(f"{name} configuration:", C.BOLD, C.CYAN))
        mhz = ask_value("Target system clock speed, in MHz?", mhz,
                         validator=lambda s: (s.isdigit() and int(s) > 0, "Must be a positive integer"),
                         allow_skip=True)

        new_baud = ask_value("Debug UART baud rate (for printing to the serial terminal)?", baud,
                              validator=lambda s: (s.isdigit(), "Must be an integer baud rate"), allow_skip=True)
        if int(new_baud) * 16 >= int(mhz) * 1_000_000:
            print(c(f"  WARNING: {new_baud} baud is not comfortably slower than 1/16 of FCLK ({mhz}MHz)."
                     " The Debug UART may not work reliably.", C.YELLOW))
            if ask_yes_no("  Keep this baud rate anyway?", default=False):
                baud = new_baud
        else:
            baud = new_baud

        # --- CPU configuration -----------------------------------------------------------------------------------------------
        print()
        print(c("CPU configuration:", C.BOLD, C.CYAN))
        guided_toggle(core_lines, "BPREDICT_DYN", "Enable Dynamic (GShare) Branch Predictor?",
                      note="Static = backward-always-taken heuristic (lighter). Dynamic = GShare, better prediction accuracy on real codes.")
        guided_toggle(core_lines, "RAS", "Enable the Return Address Stack (RAS) predictor?",
                      note="Predicts function-return branches; needs a small depth-N stack of PCs.")
        muldiv = guided_toggle(core_lines, "MULTDIV", "Enable the Hardware Multiplier/Divider (RISC-V M-extension)?",
                                note="Without HW multipliers/dividers, GCC must rely on mul/div/rem SW routines.")
        if muldiv:
            dsp_mult = guided_bool_choice(core_lines, "EN_FPGA_DSP_MULT",
                                           "Which HW multiplier should be used?",
                                           ("FPGA DSP-based x32 multiplier", "Radix-4 Booth multiplier"),
                                           note="DSP-based uses dedicated FPGA DSP slices.")
            if dsp_mult:
                guided_value(core_lines, "MULT_PIPE_STAGES", "Number of DSP multiplier pipeline stages (>= 2)?",
                             note="Tune the pipeline stages according to the target operating frequency.",
                             validator=lambda s: (s.isdigit() and int(s) >= 2, "Must be an integer >= 2"))

        print()
        print(c("[SYNTH Macros]", C.BOLD, C.MAGENTA) + c(f"  (currently {'ENABLED' if synth_needed else 'disabled'})", C.DIM))
        print(c("  Enables CORE_SYNTH/SUBSYS_SYNTH to target Synthesis and Simulation-only features are removed", C.GREY))
        synth_needed = ask_yes_no("Is a Synthesis-ready core (on-board FPGA/ASIC build) required, instead of a simulation build?",
                                   default=synth_needed, allow_skip=True)

        if not synth_needed:
            print()
            print(c("[DBG Macros]", C.BOLD, C.MAGENTA) + c(f"  (currently {'ENABLED' if svh_toggle_get(core_lines, 'DBG') else 'disabled'})", C.DIM))
            print(c("  Enables DBG/SUBSYS_DBG/MEM_DBG (For Simulation purpose only)", C.GREY))
            debug_needed = ask_yes_no("Enable Debug interfaces in the CPU/Subsystem (for Simulation only)?", default=True, allow_skip=True)
        else:
            print(c("\n  (Skipping Debug interfaces prompt — Synth macros disable simulation-only debug macros.)", C.DIM))
    except SkipRemaining:
        print(c("\n(Skipping remaining questions — keeping current/default values for anything not yet asked.)", C.DIM))

    mhz = int(mhz)

    # --- Apply everything to the in-memory file contents ------------------------------------------------------------------
    # ITERATIONS is not written here -- it's not supported/used by these test programs' C source.
    makefile_value_set(make_lines, "CLOCK_SPEED_MHZ", str(mhz))

    # BPREDICT_DYN, RAS, MULTDIV, EN_FPGA_DSP_MULT, MULT_PIPE_STAGES were already written straight
    # into core_lines by the guided_toggle/guided_bool_choice/guided_value calls above.

    if not svh_toggle_get(subsys_lines, "BENCHMARK"):
        svh_toggle_set(subsys_lines, "BENCHMARK", True)
        print(c("  -> BENCHMARK macro will be enabled (required to build/run RISC-V test programs).", C.CYAN))

    svh_value_set(subsys_lines, "FCLK", str(mhz))
    svh_value_set(subsys_lines, "IRAM_SIZE", str(kb_to_bytes(iram_kb)))
    svh_value_set(subsys_lines, "DRAM_SIZE", str(kb_to_bytes(dram_kb)))
    linker_length_set(linker_lines, "IRAM", iram_kb)
    linker_length_set(linker_lines, "DRAM", dram_kb)

    if not svh_toggle_get(subsys_lines, "DBGUART"):
        svh_toggle_set(subsys_lines, "DBGUART", True)
        print(c("  -> DBGUART will be enabled (test result is printed over the Debug UART).", C.CYAN))
    svh_value_set(subsys_lines, "DBGUART_BRATE", baud)

    svh_value_set(core_lines, "PC_INIT", "32'h0000_0000")

    # Debug macros are only ever touched when NOT building for synthesis; a synthesis build leaves
    # DBG/SUBSYS_DBG/MEM_DBG/REGFILE_DUMP/IMEM_DUMP/DMEM_DUMP exactly as they were, matching the
    # benchmark and Full Custom flows' behavior.
    if not synth_needed:
        svh_toggle_set(core_lines, "DBG", debug_needed)
        svh_toggle_set(subsys_lines, "SUBSYS_DBG", debug_needed)
        svh_toggle_set(subsys_lines, "MEM_DBG", debug_needed)
        if debug_needed:
            svh_value_set(core_lines, "REGFILE_DUMP", "1")
            svh_value_set(subsys_lines, "IMEM_DUMP", "1")
            svh_value_set(subsys_lines, "DMEM_DUMP", "1")

    svh_toggle_set(core_lines, "CORE_SYNTH", synth_needed)
    svh_toggle_set(subsys_lines, "SUBSYS_SYNTH", synth_needed)

    # --- Feature summary, then a single gate before the detailed file diff/apply step ---------------------------------------
    header(f"{name} Configuration Summary")
    print(c(f"\n{name} Test Program:", C.BOLD))
    print_row("Clock speed", f"{mhz} MHz", "CLOCK_SPEED_MHZ / FCLK")
    print_row("IRAM size", f"{iram_kb}K", "IRAM_SIZE")
    print_row("DRAM size", f"{dram_kb}K", "DRAM_SIZE")
    print_core_subsys_rows(core_lines, subsys_lines)
    input(c("\nPress ENTER to review the exact file changes and confirm...", C.DIM))

    changes = [
        {"label": f"{name} Makefile", "path": makefile_path, "old_lines": make_lines_orig, "new_lines": make_lines},
        {"label": "Core Macros", "path": CORE_SVH, "old_lines": core_lines_orig, "new_lines": core_lines},
        {"label": "Subsystem Macros", "path": SUBSYS_SVH, "old_lines": subsys_lines_orig, "new_lines": subsys_lines},
        {"label": f"{name} linker.ld", "path": linker_path, "old_lines": linker_lines_orig, "new_lines": linker_lines},
    ]
    applied = review_and_apply_all(changes, title=f"{name} Configuration — review before applying")
    if applied:
        print(f"\nPlease run  {c(f'make rvtest PGM={pgm} ISZ={kb_to_bytes(iram_kb)} DSZ={kb_to_bytes(dram_kb)}', C.CYAN, C.BOLD)}")
        if svh_toggle_get(core_lines, "MULTDIV"):
            print(c(f"  Add ARCH=rv32im to also compile {name} with native HW mul/div (M-extension) instructions.", C.YELLOW))
        print(c(f"Refer to {BUILD_NOTES} for more details.", C.DIM))


# =================================================================================================================================
# Regression Suite configuration
# =================================================================================================================================
def configure_regress():
    header("Regression Suite Configuration")
    print("Reference: see 'Running Regressions in the CPU' section of")
    print(f"{c(str(BUILD_NOTES), C.CYAN)} for full details.")
    print(c("Tip: type 's' at any prompt below to skip the remaining questions and jump to the summary.", C.DIM))
    print(c("Tip: type 'q' at any prompt (below or later) to quit immediately, with nothing further changed.\n", C.DIM))

    core_lines_orig = read_lines(CORE_SVH)
    subsys_lines_orig = read_lines(SUBSYS_SVH)
    core_lines = list(core_lines_orig)
    subsys_lines = list(subsys_lines_orig)

    print(c("NOTE: Regression always runs as a simulation (never Synthesis), and always needs Debug", C.YELLOW, C.BOLD))
    print(c("      interfaces + Register/Memory dumps enabled to verify results against the golden", C.YELLOW))
    print(c("      reference -- these are applied automatically below, not asked as questions.\n", C.YELLOW))

    try:
        # --- CPU configuration -----------------------------------------------------------------------------------------------
        print()
        print(c("CPU configuration:", C.BOLD, C.CYAN))
        guided_toggle(core_lines, "BPREDICT_DYN", "Enable Dynamic (GShare) Branch Predictor?",
                      note="Static = backward-always-taken heuristic (lighter). Dynamic = GShare, better prediction accuracy on real codes.")
        guided_toggle(core_lines, "RAS", "Enable the Return Address Stack (RAS) predictor?",
                      note="Predicts function-return branches; needs a small depth-N stack of PCs.")
        muldiv = guided_toggle(core_lines, "MULTDIV", "Enable the Hardware Multiplier/Divider (RISC-V M-extension)?",
                                note="Without HW multipliers/dividers, GCC must rely on mul/div/rem SW routines. If disabled,"
                                     " the 24_multdiv regression test is auto-skipped by scripts/regress_run.sh.")
        if muldiv:
            dsp_mult = guided_bool_choice(core_lines, "EN_FPGA_DSP_MULT",
                                           "Which HW multiplier should be used?",
                                           ("FPGA DSP-based x32 multiplier", "Radix-4 Booth multiplier"),
                                           note="DSP-based uses dedicated FPGA DSP slices.")
            if dsp_mult:
                guided_value(core_lines, "MULT_PIPE_STAGES", "Number of DSP multiplier pipeline stages (>= 2)?",
                             note="Tune the pipeline stages according to the target operating frequency.",
                             validator=lambda s: (s.isdigit() and int(s) >= 2, "Must be an integer >= 2"))
    except SkipRemaining:
        print(c("\n(Skipping remaining questions — keeping current/default values for anything not yet asked.)", C.DIM))

    # --- Apply the fixed regression prerequisites (not asked -- these are hard requirements, not choices) ------------------
    svh_toggle_set(core_lines, "CORE_SYNTH", False)
    svh_toggle_set(subsys_lines, "SUBSYS_SYNTH", False)

    svh_toggle_set(core_lines, "DBG", True)
    svh_toggle_set(subsys_lines, "SUBSYS_DBG", True)
    svh_toggle_set(subsys_lines, "MEM_DBG", True)
    svh_value_set(core_lines, "REGFILE_DUMP", "1")
    svh_value_set(subsys_lines, "IMEM_DUMP", "1")
    svh_value_set(subsys_lines, "DMEM_DUMP", "1")

    svh_toggle_set(subsys_lines, "SIMLIMIT", True)
    svh_toggle_set(core_lines, "SIMEXIT_INSTR_END", True)
    svh_value_set(core_lines, "PC_INIT", "32'h0000_0000")

    svh_value_set(subsys_lines, "IRAM_SIZE", "1024")
    svh_value_set(subsys_lines, "DRAM_SIZE", "1024")

    # --- Feature summary, then a single gate before the detailed file diff/apply step ---------------------------------------
    header("Regression Suite Configuration Summary")
    print_core_subsys_rows(core_lines, subsys_lines)
    input(c("\nPress ENTER to review the exact file changes and confirm...", C.DIM))

    changes = [
        {"label": "Core Macros", "path": CORE_SVH, "old_lines": core_lines_orig, "new_lines": core_lines},
        {"label": "Subsystem Macros", "path": SUBSYS_SVH, "old_lines": subsys_lines_orig, "new_lines": subsys_lines},
    ]
    applied = review_and_apply_all(changes, title="Regression Suite Configuration — review before applying")
    if applied:
        print(f"\nPlease run  {c('make regress', C.CYAN, C.BOLD)}")
        print(c(f"Refer to {BUILD_NOTES} for more details.", C.DIM))


# =================================================================================================================================
# Full guided macro-by-macro configuration
# =================================================================================================================================
def guided_toggle(lines, macro, question, note=None, label=None):
    cur = svh_toggle_get(lines, macro)
    print()
    print(c(f"[{label or macro}]", C.BOLD, C.MAGENTA) + c(f"  (currently {'ENABLED' if cur else 'disabled'})", C.DIM))
    if note:
        print(c(f"  {note}", C.GREY))
    new = ask_yes_no(question, default=cur, allow_skip=True)
    svh_toggle_set(lines, macro, new)
    return new


def guided_value(lines, macro, question, note=None, validator=None):
    cur = svh_value_get(lines, macro)
    print()
    print(c(f"[{macro}]", C.BOLD, C.MAGENTA) + c(f"  (current value: {cur})", C.DIM))
    if note:
        print(c(f"  {note}", C.GREY))
    new = ask_value(question, cur, validator=validator, allow_skip=True)
    svh_value_set(lines, macro, new)
    return new


def guided_choice_value(lines, macro, question, options, note=None):
    cur = svh_value_get(lines, macro)
    print()
    print(c(f"[{macro}]", C.BOLD, C.MAGENTA) + c(f"  (current value: {cur})", C.DIM))
    if note:
        print(c(f"  {note}", C.GREY))
    try:
        default_index = options.index(cur)
    except ValueError:
        default_index = 0
    idx = ask_choice(question, options, default_index=default_index, allow_skip=True)
    svh_value_set(lines, macro, options[idx])
    return options[idx]


def guided_bool_value(lines, macro, question, note=None, true_val="1", false_val="0"):
    """For value macros that are really booleans encoded as '1'/'0' (e.g. REGFILE_DUMP, IMEM_DUMP).
    Asked as a plain yes/no instead of a 1-vs-0 menu."""
    cur = svh_value_get(lines, macro)
    cur_bool = cur == true_val
    print()
    print(c(f"[{macro}]", C.BOLD, C.MAGENTA) + c(f"  (currently {'Yes' if cur_bool else 'No'})", C.DIM))
    if note:
        print(c(f"  {note}", C.GREY))
    new = ask_yes_no(question, default=cur_bool, allow_skip=True)
    svh_value_set(lines, macro, true_val if new else false_val)
    return new


def guided_bool_choice(lines, macro, question, options, note=None, true_val="1", false_val="0"):
    """Like guided_bool_value, but presented as a 2-option menu (descriptive labels) instead of a
    plain yes/no. options = (true_label, false_label); the current value is pre-selected and
    explicitly marked "(default)" so it's clear which one you'll get if you just press Enter."""
    cur = svh_value_get(lines, macro)
    cur_bool = cur == true_val
    print()
    print(c(f"[{macro}]", C.BOLD, C.MAGENTA) + c(f"  (currently {options[0] if cur_bool else options[1]})", C.DIM))
    if note:
        print(c(f"  {note}", C.GREY))
    default_index = 0 if cur_bool else 1
    hints = ["(default)" if default_index == 0 else "", "(default)" if default_index == 1 else ""]
    idx = ask_choice(question, list(options), default_index=default_index, hints=hints, allow_skip=True)
    new = (idx == 0)
    svh_value_set(lines, macro, true_val if new else false_val)
    return new


def int_validator(msg="Must be an integer"):
    return lambda s: (s.lstrip("-").isdigit(), msg)


def configure_guided():
    header("Full Custom Configuration — every configurable macro, one by one")
    print("Press ENTER at any prompt to keep the shown default/current value.")
    print(c("Tip: type 's' at any prompt to skip the remaining questions and jump to the summary.", C.DIM))
    print(c("Tip: type 'q' at any prompt (below or later) to quit immediately, with nothing further changed.\n", C.DIM))

    core_lines_orig = read_lines(CORE_SVH)
    subsys_lines_orig = read_lines(SUBSYS_SVH)
    core = list(core_lines_orig)
    subsys = list(subsys_lines_orig)

    bench_info = {}
    try:
        _configure_guided_questions(core, subsys, bench_info)
    except SkipRemaining:
        print(c("\n(Skipping remaining questions — keeping current/default values for anything not yet asked.)", C.DIM))

    # --- Feature summary, then a single gate before the detailed file diff/apply step ---------------------------------------
    header("Configuration Summary")
    print_core_subsys_rows(core, subsys)
    if bench_info:
        print(c(f"\n{bench_info['name']} Benchmark:", C.BOLD))
        print_row("Iterations", bench_info["iterations"], "ITERATIONS")
        print_row("IRAM size", f"{bench_info['iram_kb']}K", "IRAM_SIZE")
        print_row("DRAM size", f"{bench_info['dram_kb']}K", "DRAM_SIZE")
    input(c("\nPress ENTER to review the exact file changes and confirm...", C.DIM))

    changes = [
        {"label": "Core Macros", "path": CORE_SVH, "old_lines": core_lines_orig, "new_lines": core},
        {"label": "Subsystem Macros", "path": SUBSYS_SVH, "old_lines": subsys_lines_orig, "new_lines": subsys},
    ]
    if bench_info:
        changes.append({"label": f"{bench_info['name']} Makefile", "path": bench_info["makefile"],
                         "old_lines": bench_info["makefile_orig"], "new_lines": bench_info["makefile_new"]})
        changes.append({"label": f"{bench_info['name']} linker.ld", "path": bench_info["linker"],
                         "old_lines": bench_info["linker_orig"], "new_lines": bench_info["linker_new"]})
    review_and_apply_all(changes, title="Full Custom Configuration — review before applying")


def _configure_guided_questions(core, subsys, bench_info):
    # ---------------------------------------------------------------------------------------------------------------- CORE ---
    print(c("\n=== PQR5 CORE ===", C.BOLD, C.CYAN))

    guided_value(core, "PC_INIT", "What is the CPU's reset vector / boot address (32-bit hex, e.g. 32'h0000_0000)?")

    guided_toggle(core, "RF_ON_BRAM",
                  "Generate the Register File on Block RAM (instead of flops/LUT RAM)?",
                  note="Useful on FPGAs where LUT resources are scarce; adds a cycle of latency on some accesses.")

    dyn_bp = guided_toggle(core, "BPREDICT_DYN",
                            "Do you want a Dynamic (GShare) Branch Predictor instead of the Static predictor?",
                            note="Static = backward-always-taken heuristic (lighter). Dynamic = GShare, better prediction accuracy on real codes.")
    if dyn_bp:
        guided_value(core, "BHT_IDW", "Branch History Table (BHT) index width? (e.g. 10 = 1024 entries)",
                     validator=int_validator())
        guided_choice_value(core, "BHT_TYPE", "Where should the BHT be implemented?", ["blkram", "lutram", "flops"],
                             note='"blkram"=Block RAM, "lutram"=LUT RAM, "flops"=flip-flops (best for ASIC).')
        guided_choice_value(core, "BHT_BIAS", "BHT reset bias for the 2-bit saturating counters?",
                             ["2'b00", "2'b01", "2'b10", "2'b11"],
                             note="2'b00=Strongly not taken, 2'b01=Weakly not taken, 2'b10=Weakly taken"
                                  " (recommended default), 2'b11=Strongly taken.")

    ras = guided_toggle(core, "RAS",
                         "Enable the Return Address Stack (RAS) predictor?",
                         note="Predicts function-return branches; needs a small depth-N stack of PCs.")
    if ras:
        guided_value(core, "RAS_DPT", "RAS depth (must be a power of 2)?", validator=int_validator())

    muldiv = guided_toggle(core, "MULTDIV",
                            "Enable the Hardware Multiplier/Divider (adds the RISC-V M-extension)?",
                            note="Without HW multipliers/dividers, GCC must rely on mul/div/rem SW routines.")
    if muldiv:
        dsp = guided_bool_choice(core, "EN_FPGA_DSP_MULT", "Which HW multiplier should be used?",
                                  ("FPGA DSP-based x32 multiplier", "Radix-4 Booth multiplier"),
                                  note="DSP-based uses dedicated FPGA DSP slices.")
        if dsp:
            guided_value(core, "MULT_PIPE_STAGES", "Number of DSP multiplier pipeline stages (>= 2)?",
                         note="Tune the pipeline stages according to the target operating frequency.",
                         validator=lambda s: (s.isdigit() and int(s) >= 2, "Must be an integer >= 2"))

    guided_toggle(core, "TEST_PORTS",
                  "Generate extra test ports from the core (x31 register bits + boot flag)?",
                  note="Handy for board bring-up/debug; adds a few extra top-level ports.")

    synth = guided_toggle(core, "CORE_SYNTH",
                           "Should the CPU CORE be configured for Synthesis only?",
                           note="Disables debug prints, debug ports, CPU registers dump and other simulation-only features automatically when enabled.")

    if not synth:
        sim_note = "Simulation-only. Ignored/overridden automatically when CORE_SYNTH is enabled."
        dbg = guided_toggle(core, "DBG", "Enable Debug interfaces & performance summary (Simulation only)?", note=sim_note, label="DBG Macros")
        if dbg:
            guided_toggle(core, "DBG_PRINT", "Also print verbose per-cycle debug messages during simulation?", note=sim_note)
        guided_bool_value(core, "REGFILE_DUMP", "Dump the Register File contents at the end of simulation?", note=sim_note)
        guided_toggle(core, "SIMEXIT_INSTR_END",
                      "Exit simulation automatically when the END pseudo-instruction executes?", note=sim_note)
    else:
        print(c("\n  (Skipping DBG/DBG_PRINT/SIMEXIT_INSTR_END prompts — CORE_SYNTH disables them automatically.)", C.DIM))

    # ----------------------------------------------------------------------------------------------------------- SUBSYSTEM ---
    print(c("\n=== PQR5 SUBSYSTEM ===", C.BOLD, C.CYAN))

    loader = guided_toggle(subsys, "EN_LOADER",
                            "Enable the Loader (program the core on-the-fly over UART, without resynthesizing)?")
    if loader:
        guided_value(subsys, "BAUDRATE", "Loader UART baud rate?", validator=int_validator())
        guided_value(subsys, "TIMEOUT", "Loader timeout, in FCLK cycles (32-bit hex, e.g. 32'h5555_5555)?")

    benchmark_enabled = guided_toggle(subsys, "BENCHMARK",
                  "Enable support for running CoreMark/Dhrystone/RISC-V-test benchmarks?",
                  note="Forces zero-latency DMEM and the Debug UART on automatically when enabled.")

    if benchmark_enabled:
        bidx = ask_choice("Which benchmark should the IRAM/DRAM size & iterations below be sized for?",
                           ["CoreMark", "Dhrystone"], default_index=0, allow_skip=True)
        bprofile = BENCH_PROFILES["coremark" if bidx == 0 else "dhrystone"]
        bname = bprofile["name"]
        print(c(f"  This will also update {bname}'s Makefile (ITERATIONS) and linker.ld (IRAM/DRAM LENGTH) to match.", C.GREY))
        print(c(f"  NOTE: {bname} requires IRAM >= {bprofile['min_iram_kb']}K and DRAM >= {bprofile['min_dram_kb']}K.", C.YELLOW))

        b_make_orig = read_lines(bprofile["makefile"])
        b_make = list(b_make_orig)
        b_linker_orig = read_lines(bprofile["linker"])
        b_linker = list(b_linker_orig)
        # Register the file-change entry up front (same mutable list object) so that whatever
        # is answered below before a possible skip is still captured in the final review/apply.
        bench_info.update({
            "name": bname,
            "makefile": bprofile["makefile"], "makefile_orig": b_make_orig, "makefile_new": b_make,
            "linker": bprofile["linker"], "linker_orig": b_linker_orig, "linker_new": b_linker,
            "iram_kb": bytes_to_kb(int(svh_value_get(subsys, "IRAM_SIZE"))),
            "dram_kb": bytes_to_kb(int(svh_value_get(subsys, "DRAM_SIZE"))),
            "iterations": makefile_value_get(b_make, "ITERATIONS"),
        })

        cur_iram_kb = max(bench_info["iram_kb"], bprofile["min_iram_kb"])
        iram_kb = ask_size_kb(f"IRAM size for {bname} (KB)?", cur_iram_kb, bprofile["min_iram_kb"], bname, allow_skip=True)
        svh_value_set(subsys, "IRAM_SIZE", str(kb_to_bytes(iram_kb)))
        linker_length_set(b_linker, "IRAM", iram_kb)
        bench_info["iram_kb"] = iram_kb

        cur_dram_kb = max(bench_info["dram_kb"], bprofile["min_dram_kb"])
        dram_kb = ask_size_kb(f"DRAM size for {bname} (KB)?", cur_dram_kb, bprofile["min_dram_kb"], bname, allow_skip=True)
        svh_value_set(subsys, "DRAM_SIZE", str(kb_to_bytes(dram_kb)))
        linker_length_set(b_linker, "DRAM", dram_kb)
        bench_info["dram_kb"] = dram_kb

        iterations = ask_value(f"Number of {bname} iterations/runs?", bench_info["iterations"],
                                validator=lambda s: (s.isdigit() and int(s) > 0, "Must be a positive integer"),
                                allow_skip=True)
        makefile_value_set(b_make, "ITERATIONS", iterations)
        bench_info["iterations"] = iterations

    guided_value(subsys, "FCLK", "Target system clock speed, in MHz?", validator=int_validator())
    if bench_info:
        fclk_val = svh_value_get(subsys, "FCLK")
        if fclk_val.isdigit():
            makefile_value_set(bench_info["makefile_new"], "CLOCKS_PER_SEC", str(int(fclk_val) * 1_000_000))

    if not bench_info:
        guided_value(subsys, "IRAM_SIZE", "IRAM size, in bytes?", validator=int_validator())
        guided_value(subsys, "DRAM_SIZE", "DRAM size, in bytes (max. 65536)?",
                     validator=lambda s: (s.isdigit() and int(s) <= 65536, "Must be an integer <= 65536"))

    subsynth = guided_toggle(subsys, "SUBSYS_SYNTH",
                              "Should the SUBSYSTEM be configured for Synthesis only?",
                              note="Disables test clock/reset generation, memory debug ports and other simulation-only features automatically when enabled.")

    if not subsynth:
        sim_note = "Simulation-only. Ignored/overridden automatically when SUBSYS_SYNTH is enabled."
        subdbg = guided_toggle(subsys, "SUBSYS_DBG", "Generate the testbench clock & reset internally for simulation?", note=sim_note)
        if subdbg:
            guided_value(subsys, "SYSRST_LEN", "Reset length, in clock cycles?", validator=int_validator())
            simlimit = guided_toggle(subsys, "SIMLIMIT", "Limit the simulation to a maximum number of clock cycles?")
            if simlimit:
                guided_value(subsys, "SIMCYCLES", "Maximum number of simulation clock cycles?", validator=int_validator())
            guided_toggle(subsys, "DUMPVCD", "Dump a VCD waveform file during simulation?")

        mem_dbg = guided_toggle(subsys, "MEM_DBG", "Generate debug ports on IMEM/DMEM for simulation dumps?", note=sim_note)
        if mem_dbg:
            guided_bool_value(subsys, "IMEM_DUMP", "Dump IMEM content at the end of simulation?")
            guided_bool_value(subsys, "DMEM_DUMP", "Dump DMEM content at the end of simulation?")
    else:
        print(c("\n  (Skipping SUBSYS_DBG/MEM_DBG prompts — SUBSYS_SYNTH disables them automatically.)", C.DIM))

    zero_lat = guided_bool_value(subsys, "DMEM_IS_ZERO_LAT",
                                  "Model DMEM as zero-latency (100% hit, single-cycle) memory?",
                                  note="Required if the Debug UART or benchmarks are enabled.")
    if not zero_lat:
        rlat = guided_bool_value(subsys, "DMEM_IS_RLAT", "Use random latency (instead of fixed latency) for DMEM misses/hits?")
        if rlat:
            guided_value(subsys, "DMEM_HITRATE", "DMEM hit rate, in % (e.g. 90.0)?")
            guided_value(subsys, "DMEM_MISS_RLAT", "DMEM miss latency = value+1 cycles (range 0-15)?",
                         validator=lambda s: (s.isdigit() and 0 <= int(s) <= 15, "Must be an integer 0-15"))
        else:
            guided_value(subsys, "DMEM_FIXED_LAT", "DMEM fixed latency = value+1 cycles (range 0-15)?",
                         validator=lambda s: (s.isdigit() and 0 <= int(s) <= 15, "Must be an integer 0-15"))

    dbguart = guided_toggle(subsys, "DBGUART", "Enable the Debug UART?",
                             note="Only supported together with the DMEM zero-latency model.")
    if dbguart:
        guided_value(subsys, "DBGUART_BRATE", "Debug UART baud rate?", validator=int_validator())


# =================================================================================================================================
# View current configuration summary
# =================================================================================================================================
def show_summary():
    header("Current Configuration Summary")
    core = read_lines(CORE_SVH)
    subsys = read_lines(SUBSYS_SVH)
    print_core_subsys_rows(core, subsys)

    print(c("\nCoreMark:", C.BOLD))
    cmk_make = read_lines(CMK_MAKE)
    cmk_linker = read_lines(CMK_LINKER)
    print_row("Iterations", makefile_value_get(cmk_make, "ITERATIONS"), "ITERATIONS")
    print_row("Clock speed", makefile_value_get(cmk_make, "CLOCKS_PER_SEC"), "CLOCKS_PER_SEC")
    print_row("IRAM size", linker_length_get(cmk_linker, "IRAM"), "linker.ld IRAM")
    print_row("DRAM size", linker_length_get(cmk_linker, "DRAM"), "linker.ld DRAM")

    print(c("\nDhrystone:", C.BOLD))
    dhry_make = read_lines(DHRY_MAKE)
    dhry_linker = read_lines(DHRY_LINKER)
    print_row("Iterations", makefile_value_get(dhry_make, "ITERATIONS"), "ITERATIONS")
    print_row("Clock speed", makefile_value_get(dhry_make, "CLOCKS_PER_SEC"), "CLOCKS_PER_SEC")
    print_row("IRAM size", linker_length_get(dhry_linker, "IRAM"), "linker.ld IRAM")
    print_row("DRAM size", linker_length_get(dhry_linker, "DRAM"), "linker.ld DRAM")


# =================================================================================================================================
# Main menu
# =================================================================================================================================
MENU_OPTIONS = [
    "Configure to run CoreMark / Dhrystone Benchmark",
    "Configure to build RISC-V Standard Test Program",
    "Configure to run Regression Suite",
    "Full Custom Configuration (walk through every macro)",
    "View Current Configuration Summary",
    "Exit",
]


def print_welcome():
    print()
    print(c("Welcome to the Pequeno R5 CPU & Subsystem Configurator!", C.BOLD, C.WHITE))
    print(c("This interactive session guides you through configuring the CPU core, subsystem,", C.GREY))
    print(c("CoreMark/Dhrystone benchmark builds, and RISC-V Standard Test Program builds.", C.GREY))


def main_menu():
    exit_index = len(MENU_OPTIONS) - 1
    first = True
    while True:
        clear_screen()
        title()
        if first:
            print_welcome()
            first = False
        print()
        idx = arrow_select("Select an option:", MENU_OPTIONS, default_index=0)

        if idx == 0:
            configure_benchmark()
        elif idx == 1:
            configure_rvtest()
        elif idx == 2:
            configure_regress()
        elif idx == 3:
            configure_guided()
        elif idx == 4:
            show_summary()
        elif idx == exit_index:
            print(c("\nGoodbye!\n", C.CYAN))
            return
        pause()


# =================================================================================================================================
# Entrypoint
# =================================================================================================================================
def main():
    argparse.ArgumentParser(
        description="PQR5 Interactive Configurator - Chipmunk Logic (TM)",
    ).parse_args()

    try:
        main_menu()
    except (KeyboardInterrupt, EOFError):
        print(c("\n\nAborted by user.\n", C.YELLOW))
        sys.exit(130)
    except QuitConfigurator:
        print()
        sys.exit(0)


if __name__ == "__main__":
    main()

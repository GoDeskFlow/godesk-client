#!/usr/bin/env python3
"""
build_godesk_patch.py — patches upstream `build.py` to target the
`flutter_godesk/` sibling package instead of `flutter/`.

Per ADR-011 (overlay strategy = sibling package). Run once after each
`git pull upstream` of the rustdesk fork; it is idempotent.

Usage:
    python build_godesk_patch.py             # apply patch to ./build.py
    python build_godesk_patch.py --restore   # write build.py.upstream.bak as build.py

What it changes (all in ./build.py):

  1. Adds an argparse `--flutter-dir` flag (default: 'flutter_godesk').
  2. Replaces the literal `'flutter'` in:
       - `flutter_build_dir_2 = f'flutter/{flutter_build_dir}'`
       - every `os.chdir('flutter')`
       - sed paths referring to `./flutter/lib/generated_bridge.dart`
     with the value of args.flutter_dir.
  3. Leaves all other behavior (cargo, deb packaging, signing) untouched.
"""

from __future__ import annotations
import argparse
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / 'build.py'
BACKUP = HERE / 'build.py.upstream.bak'
MARKER = '# GODESK_PATCH_APPLIED'


def restore() -> int:
    if not BACKUP.exists():
        print(f'No backup at {BACKUP}; nothing to restore.')
        return 1
    shutil.copy2(BACKUP, SRC)
    print(f'Restored {SRC} from {BACKUP}.')
    return 0


def apply() -> int:
    if not SRC.exists():
        print(f'{SRC} missing — run from a checked-out godesk-client tree.')
        return 1
    content = SRC.read_text(encoding='utf-8')
    if MARKER in content:
        print(f'{SRC} already patched ({MARKER} present). Re-running is safe but a no-op.')
        return 0

    # Snapshot the upstream copy for re-apply / restore safety.
    if not BACKUP.exists():
        shutil.copy2(SRC, BACKUP)
        print(f'Snapshot saved: {BACKUP}')

    # 1. Inject the --flutter-dir argparse hook just after the --flutter flag.
    flag_pattern = re.compile(
        r"(    parser\.add_argument\('--flutter', action='store_true',\n"
        r"                        help='Build flutter package', default=False\)\n)"
    )
    inject = (
        "    parser.add_argument('--flutter-dir',\n"
        "                        help=\"Flutter package directory (GoDesk overlay: 'flutter_godesk')\",\n"
        "                        default='flutter_godesk')\n"
    )
    content, n = flag_pattern.subn(r"\1" + inject, content, count=1)
    if n != 1:
        print('FAIL: did not find the --flutter argparse line in build.py.')
        return 2

    # 2. Insert a global FLUTTER_DIR after `flutter_build_dir_2 = ...`.
    fbd2_pattern = re.compile(
        r"(flutter_build_dir_2 = f'flutter/\{flutter_build_dir\}'\n)"
    )
    fbd2_replacement = (
        "FLUTTER_DIR = 'flutter_godesk'  # GODESK_PATCH: overridden by --flutter-dir at runtime\n"
        "flutter_build_dir_2 = f'{FLUTTER_DIR}/{flutter_build_dir}'\n"
    )
    content, n = fbd2_pattern.subn(fbd2_replacement, content, count=1)
    if n != 1:
        print('FAIL: did not find flutter_build_dir_2 line.')
        return 2

    # 3. Replace every 'flutter' literal that refers to the package dir.
    #    Only inside `os.chdir(...)` and in sed scripts touching generated_bridge.dart.
    content = content.replace("os.chdir('flutter')", "os.chdir(FLUTTER_DIR)")
    content = content.replace(
        "./flutter/lib/generated_bridge.dart",
        "./' + FLUTTER_DIR + '/lib/generated_bridge.dart",
    )
    content = content.replace(
        "flutter/lib/generated_bridge.dart",
        "{FLUTTER_DIR}/lib/generated_bridge.dart",
    )

    # 4. After argparse parses, propagate args.flutter_dir into FLUTTER_DIR.
    parse_pattern = re.compile(r"(    args = parser\.parse_args\(\)\n)")
    propagate = (
        "    global FLUTTER_DIR\n"
        "    if getattr(args, 'flutter_dir', None):\n"
        "        FLUTTER_DIR = args.flutter_dir\n"
        "        global flutter_build_dir_2\n"
        "        flutter_build_dir_2 = f'{FLUTTER_DIR}/{flutter_build_dir}'\n"
    )
    content, n = parse_pattern.subn(r"\1" + propagate, content, count=1)
    if n != 1:
        print('WARN: could not find `args = parser.parse_args()`; --flutter-dir may not propagate at runtime.')

    # 5. Marker so re-runs are no-ops.
    content = MARKER + ' v1\n' + content

    SRC.write_text(content, encoding='utf-8')
    print(f'Patched {SRC}. Default flutter dir = "flutter_godesk".')
    print('Override per-run with: python build.py --flutter-dir <other> --flutter ...')
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--restore', action='store_true')
    args = p.parse_args()
    return restore() if args.restore else apply()


if __name__ == '__main__':
    sys.exit(main())

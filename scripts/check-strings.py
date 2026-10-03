#!/usr/bin/env python3
"""Checks the string catalogs against what the compiler found in the
code: every string the app shows has a Simplified Chinese translation,
and the catalogs keep no string the code no longer uses.

Usage: scripts/check-strings.py <DerivedData>, after a build of the
Explore scheme, which leaves the strings it found in .stringsdata files.
"""

from __future__ import annotations

import glob
import json
import pathlib
import sys

CATALOGS = {
    "Explore": "Explore/Resources/Localizable.xcstrings",
    "ExploreWidget": "ExploreWidget/Localizable.xcstrings",
}


def keys_in_code(derived: str, target: str) -> set[str]:
    pattern = f"{derived}/Build/Intermediates.noindex/Explore.build/*/{target}.build/**/*.stringsdata"
    files = glob.glob(pattern, recursive=True)
    if not files:
        sys.exit(f"No .stringsdata for {target} under {derived}: build the Explore scheme first.")
    keys = set()
    for name in files:
        with open(name, encoding="utf-8") as file:
            for entry in json.load(file).get("tables", {}).get("Localizable", []):
                keys.add(entry["key"])
    return keys


def translated(node) -> bool:
    """Whether a localization, plural variations included, is all translated."""
    if not isinstance(node, dict):
        return False
    if "stringUnit" in node:
        return node["stringUnit"].get("state") == "translated"
    if "variations" in node:
        return all(translated(form) for kind in node["variations"].values() for form in kind.values())
    return False


def main(derived: str) -> int:
    problems = []
    for target, catalog in CATALOGS.items():
        code = keys_in_code(derived, target)
        strings = json.loads(pathlib.Path(catalog).read_text(encoding="utf-8"))["strings"]
        for key in sorted(code - strings.keys()):
            problems.append(f"{catalog}: not in the catalog: {key!r}")
        for key, value in sorted(strings.items()):
            if key not in code and value.get("extractionState") != "manual":
                problems.append(f"{catalog}: no longer used: {key!r}")
            if value.get("shouldTranslate") is not False and not translated(value.get("localizations", {}).get("zh-Hans")):
                problems.append(f"{catalog}: no Chinese: {key!r}")
    if problems:
        print("\n".join(problems))
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))

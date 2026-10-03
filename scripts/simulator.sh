#!/bin/sh
# Prints the id of an iPhone simulator on the newest iOS runtime installed,
# the destination CI tests on. SIMCTL replaces "xcrun simctl" if set.
set -eu

# shellcheck disable=SC2086
${SIMCTL:-xcrun simctl} list devices available --json | python3 -c '
import json, sys

best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.rsplit(".iOS-", 1)[1].split("-"))
    for device in devices:
        if device["name"].startswith("iPhone") and (best is None or version > best[0]):
            best = (version, device["udid"])
if best is None:
    sys.exit("No iPhone simulator is available.")
print(best[1])
'

#!/bin/sh
# The review CI runs on every change: swift-format's rules with the house
# style in .swift-format, and code comments in plain ASCII English.
#
# swift-format's pretty printer would also rebreak calls that the code
# breaks by hand, so its findings about line breaks and indentation are
# left out; every other finding fails.
set -eu
cd "$(dirname "$0")/.."

sources="Explore Shared ExploreWidget ExploreTests"
status=0

# shellcheck disable=SC2086
findings=$(swift format lint --recursive --parallel $sources 2>&1 |
    grep -vE '\[(Indentation|AddLines|RemoveLine|LineLength)\]' || true)
if [ -n "$findings" ]; then
    echo "swift-format:"
    echo "$findings"
    status=1
fi

# shellcheck disable=SC2086
python3 scripts/check-comments.py $sources || status=1

exit "$status"

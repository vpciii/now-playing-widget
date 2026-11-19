#!/bin/sh
# Fail if a success criterion in the spec is not cited by any test.
# A citation is the criterion id (for example "SC-5") in a test's name.
set -eu
cd "$(dirname "$0")/.."

SPEC="specs/now-playing-widget/spec.md"
TESTS="Packages/NowPlayingCore/Tests"

missing=0
for id in $(grep -oE '^- \*\*SC-[0-9]+\*\*' "$SPEC" | grep -oE 'SC-[0-9]+' | sort -u -t- -k2 -n); do
    if ! grep -rqE "@Test\(\"[^\"]*\b$id\b" "$TESTS"; then
        echo "not covered by a test: $id"
        missing=1
    fi
done

if [ "$missing" -eq 0 ]; then
    echo "every success criterion is cited by a test"
fi
exit "$missing"

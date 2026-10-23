#!/bin/bash
# Runs every test. Exit 0 only if all pass.
cd "$(dirname "$0")" || exit 1
status=0
for t in test-*.sh; do bash "$t" || status=1; echo; done
[[ $status == 0 ]] && echo "ALL GREEN" || echo "SOME TESTS FAILED"
exit $status

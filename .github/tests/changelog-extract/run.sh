#!/usr/bin/env bash
# Regression tests for the "Extract changelog section" step in
# .github/workflows/rust-release.yml. The step's `run:` script is read from the
# workflow itself (via yq), so these tests exercise exactly what CI runs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
workflow="$repo_root/.github/workflows/rust-release.yml"

step="$(yq '.jobs.create-release.steps[] | select(.name == "Extract changelog section") | .run' "$workflow")"
if [[ -z "$step" || "$step" == "null" ]]; then
  echo "could not find the 'Extract changelog section' step in $workflow" >&2
  exit 1
fi

# The release runs on ubuntu-latest (GNU awk); macOS has BWK awk. Show which one ran.
echo "awk: $({ awk --version 2>/dev/null || awk -W version 2>/dev/null; } </dev/null | head -1)"

failures=0

# run_case NAME VERSION CHANGELOG EXPECTED
# CHANGELOG may be the literal string "<none>" to test a missing CHANGELOG.md.
run_case() {
  local name="$1" version="$2" changelog="$3" expected="$4" dir
  dir="$(mktemp -d)"
  if [[ "$changelog" != "<none>" ]]; then
    printf '%s\n' "$changelog" > "$dir/CHANGELOG.md"
  fi
  (cd "$dir" && VERSION="$version" bash --noprofile --norc -eo pipefail -c "$step")
  if diff -u <(printf '%s\n' "$expected") "$dir/current_changelog.md" > "$dir/diff"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    cat "$dir/diff"
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

keepachangelog='# Changelog

## [Unreleased]

## [0.7.2] - 2026-10-09

### Changed

- Stripped release binaries

### Fixed

- A test

## [0.7.1] - 2026-10-08

### Fixed

- Something older

## [0.7.0] - 2026-07-26

### Removed

- The oldest change'

run_case "keepachangelog section includes its subsections" "0.7.2" "$keepachangelog" '## [0.7.2] - 2026-10-09

### Changed

- Stripped release binaries

### Fixed

- A test
'

run_case "last section runs to end of file" "0.7.0" "$keepachangelog" '## [0.7.0] - 2026-07-26

### Removed

- The oldest change'

run_case "unbracketed version headings" "1.2.3" '# Changelog

## 1.2.4 (2026-02-01)

- Newer

## 1.2.3 (2026-01-01)

- Wanted

## 1.2.2 (2025-12-01)

- Older' '## 1.2.3 (2026-01-01)

- Wanted
'

run_case "0.7.1 does not match a 0.7.10 heading" "0.7.1" '# Changelog

## [0.7.10] - 2026-12-01

- Not this one

## [0.7.1] - 2026-10-08

- This one' '## [0.7.1] - 2026-10-08

- This one'

run_case "dots in the version are literal" "0.7.2" '# Changelog

## [0x7y2] - 2026-10-09

- Must not match' 'Release v0.7.2

See commit history for changes.'

run_case "missing version falls back to commit history" "9.9.9" "$keepachangelog" 'Release v9.9.9

See commit history for changes.'

run_case "missing CHANGELOG.md falls back to commit history" "0.7.2" "<none>" 'Release v0.7.2

See commit history for changes.'

if ((failures > 0)); then
  echo "$failures case(s) failed" >&2
  exit 1
fi
echo "all cases passed"

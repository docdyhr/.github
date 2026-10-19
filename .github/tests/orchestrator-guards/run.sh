#!/usr/bin/env bash
# Regression tests for the two guard steps in
# .github/workflows/claude-maintenance-orchestrator.yml:
#   - "Verify credentials" (preflight job), against stub curl and gh on PATH,
#     so no network and no real secrets are needed
#   - "Verify repo coverage" (orchestrate job), against report fixtures
# Each step's `run:` script is read from the workflow itself (via yq), so these
# tests exercise exactly what CI runs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
workflow="$repo_root/.github/workflows/claude-maintenance-orchestrator.yml"

read_step() {  # JOB STEP-NAME
  local s
  s="$(yq ".jobs.$1.steps[] | select(.name == \"$2\") | .run" "$workflow")"
  if [[ -z "$s" || "$s" == "null" ]]; then
    echo "could not find the '$2' step in job '$1' of $workflow" >&2
    exit 1
  fi
  printf '%s' "$s"
}
creds_step="$(read_step preflight "Verify credentials")"
coverage_step="$(read_step orchestrate "Verify repo coverage")"

# The workflow runs on ubuntu-latest (GNU awk); macOS has BWK awk. Show which one ran.
echo "awk: $({ awk --version 2>/dev/null || awk -W version 2>/dev/null; } </dev/null | head -1)"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# check NAME EXPECTED-EXIT EXPECTED-SUBSTRING ACTUAL-EXIT OUTPUT
check() {
  if [[ "$4" == "$2" && "$5" == *"$3"* ]]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1 (exit $4, wanted $2; wanted output containing: $3)"
    printf '%s\n' "$5" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

# ── Verify credentials ───────────────────────────────────────────────────────
# Stubs: curl records argv and stdin, prints STUB_CURL_CODE, exits STUB_CURL_EXIT;
# gh records that it ran and exits STUB_GH_EXIT.
stubs="$work/bin"
mkdir -p "$stubs"
cat > "$stubs/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_DIR/curl.argv"
cat > "$STUB_DIR/curl.stdin"
printf '%s' "${STUB_CURL_CODE:-200}"
exit "${STUB_CURL_EXIT:-0}"
STUB
cat > "$stubs/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$STUB_DIR/gh.argv"
[[ "${STUB_GH_EXIT:-0}" == 0 ]] && echo "octocat"
exit "${STUB_GH_EXIT:-0}"
STUB
chmod +x "$stubs/curl" "$stubs/gh"

# creds_case NAME EXPECTED-EXIT EXPECTED-SUBSTRING [VAR=value ...]
creds_case() {
  local name="$1" want_exit="$2" want="$3" out rc
  shift 3
  rm -f "$work"/curl.* "$work"/gh.*
  set +e
  out="$(env -i PATH="$stubs:$PATH" HOME="$work" STUB_DIR="$work" \
    ANTHROPIC_API_KEY="" GH_ORG_TOKEN="" "$@" \
    bash --noprofile --norc -e -c "$creds_step" 2>&1)"
  rc=$?
  set -e
  check "$name" "$want_exit" "$want" "$rc" "$out"
}

key="sk-ant-test-0123456789"
creds_case "missing ANTHROPIC_API_KEY fails" 1 "ANTHROPIC_API_KEY secret is not set"
creds_case "accepted key, no org token passes" 0 "ANTHROPIC_API_KEY accepted" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=200
if [[ -e "$work/gh.argv" ]]; then
  echo "FAIL - unset GH_ORG_TOKEN is not probed (gh ran)"; failures=$((failures + 1))
else
  echo "ok   - unset GH_ORG_TOKEN is not probed"
fi

# The key reaches curl on stdin, never on its command line.
if grep -qF -- "$key" "$work/curl.argv"; then
  echo "FAIL - key is not on curl's command line"; failures=$((failures + 1))
else
  echo "ok   - key is not on curl's command line"
fi
if grep -qF -- "x-api-key: $key" "$work/curl.stdin"; then
  echo "ok   - key reaches curl on stdin"
else
  echo "FAIL - key reaches curl on stdin"; failures=$((failures + 1))
fi

creds_case "rejected key (401) fails" 1 "was rejected (HTTP 401)" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=401
creds_case "rejected key (403) fails" 1 "was rejected (HTTP 403)" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=403
creds_case "no answer (curl error) fails as unverified" 1 "Could not verify ANTHROPIC_API_KEY (HTTP 000)" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=000 STUB_CURL_EXIT=7
creds_case "server error (503) fails as unverified" 1 "Could not verify ANTHROPIC_API_KEY (HTTP 503)" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=503
creds_case "accepted key, accepted org token passes" 0 "GH_ORG_TOKEN accepted (octocat)" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=200 GH_ORG_TOKEN="github_pat_test" STUB_GH_EXIT=0
creds_case "accepted key, rejected org token fails" 1 "GH_ORG_TOKEN was rejected" \
  ANTHROPIC_API_KEY="$key" STUB_CURL_CODE=200 GH_ORG_TOKEN="github_pat_test" STUB_GH_EXIT=1

# ── Verify repo coverage ─────────────────────────────────────────────────────
# report ROW... : a report whose health table holds the given rows
report() {
  printf '%s\n' '# Cross-Repo Maintenance Report' '' '<!-- ORCHESTRATOR_REPORT_START -->' \
    '## Repository Health Overview' '' \
    '| Repository | Health | Open PRs | CI (last 5) | Open Issues | Dependabot Alerts | Notes |' \
    '|---|---|---|---|---|---|---|'
  printf '%s\n' "$@"
  printf '%s\n' '' '## Dependabot PR Summary' '' \
    '| Repository | PR | Package | CI Status | Classification |' '|---|---|---|---|---|' \
    '| docdyhr/a | #1 | foo 1 → 2 | N/A | N/A |' '<!-- ORCHESTRATOR_REPORT_END -->'
}
ok_row() { echo "| docdyhr/$1 | HEALTHY | 1 | 5 success (main) | 0 | 0 | fine |"; }
na_row() { echo "| docdyhr/$1 | NEEDS_ATTENTION | N/A | N/A | N/A | N/A | Unverified: HTTP 401 |"; }

# coverage_case NAME EXPECTED-EXIT EXPECTED-SUBSTRING TASKS REPO-COUNT REPORT
coverage_case() {
  local name="$1" want_exit="$2" want="$3" tasks="$4" count="$5" out rc
  local dir="$work/report"
  mkdir -p "$dir"
  printf '%s\n' "$6" > "$dir/report.md"
  : > "$work/summary.md"
  set +e
  out="$(env -i PATH="$PATH" HOME="$work" REPORT_DIR="$dir" GITHUB_STEP_SUMMARY="$work/summary.md" \
    TASKS="$tasks" REPO_COUNT="$count" \
    bash --noprofile --norc -e -c "$coverage_step" 2>&1)"
  rc=$?
  set -e
  check "$name" "$want_exit" "$want" "$rc" "$out"
}

coverage_case "full coverage passes" 0 "3 of 3 rows have data" status 3 \
  "$(report "$(ok_row a)" "$(ok_row b)" "$(ok_row c)")"
coverage_case "every row N/A fails (the 2026-10-19 dead-token run)" 1 "None of the 3 repos returned data" status 3 \
  "$(report "$(na_row a)" "$(na_row b)" "$(na_row c)")"
coverage_case "partial coverage warns but passes" 0 "::warning::Only 2 of 3 repos returned data" all 3 \
  "$(report "$(ok_row a)" "$(na_row b)" "$(ok_row c)")"
coverage_case "a row with data in one column counts as covered" 0 "1 of 1 rows have data" status 1 \
  "$(report "| docdyhr/a | NEEDS_ATTENTION | N/A | N/A | N/A | 0 | alerts only |")"
coverage_case "'N/A (401)' counts as no data" 1 "None of the 1 repos returned data" status 1 \
  "$(report "| docdyhr/a | NEEDS_ATTENTION | N/A (401) | N/A (401) | N/A (401) | N/A (401) | x |")"
coverage_case "missing health table fails as unverified" 1 "coverage is unverified" status 3 \
  "ERROR: no result field in claude output"
coverage_case "rows outside the health table are not counted" 1 "None of the 1 repos returned data" status 1 \
  "$(report "$(na_row a)")"
coverage_case "dependabot-only run is skipped" 0 "Coverage check skipped" dependabot 3 \
  "$(report "$(na_row a)" "$(na_row b)" "$(na_row c)")"
if grep -qF '**Repo coverage:**' "$work/summary.md"; then
  echo "FAIL - skipped run writes no coverage line"; failures=$((failures + 1))
else
  echo "ok   - skipped run writes no coverage line"
fi
coverage_case "step summary records coverage" 0 "" status 2 "$(report "$(ok_row a)" "$(na_row b)")"
if grep -qF '**Repo coverage:** 1/2 repos returned data' "$work/summary.md"; then
  echo "ok   - step summary line reads 1/2"
else
  echo "FAIL - step summary line reads 1/2"; sed 's/^/       /' "$work/summary.md"; failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "$failures case(s) failed" >&2
  exit 1
fi
echo "all cases passed"

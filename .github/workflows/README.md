# Reusable workflows

This directory holds **reusable workflows** for `docdyhr/*` repos.

Unlike the community health files at the repo root (`SECURITY.md`, `CONTRIBUTING.md`, etc.), reusable workflows do **not** auto-cascade. Consumer repos must explicitly reference them via `uses:`.

## How consumers reference these

```yaml
jobs:
  call:
    uses: docdyhr/.github/.github/workflows/<workflow-name>.yml@v1
    permissions:
      # ... per-job permissions go here, not in the reusable workflow
    secrets: inherit
    with:
      # ... inputs defined by the reusable workflow's `on.workflow_call.inputs`
```

## Pinning rules

- **Always pin to a tag** (`@v1`, `@v2`, ...), never a branch.
- Re-tagging is force-push to a tag — audit-logged, but trustworthy because only repo admins can do it.
- Pinning to `@main` gives anyone with write access to this repo silent code execution on every consumer's runner. Never do this.

## Versioning

- `v1`: stable, breaking changes go to `v2`.
- Minor improvements and bug fixes re-tag `v1` to the new commit (consumers pick them up automatically).
- Breaking input/secret changes get a new major tag (`v2`) and consumers migrate when ready.

## Workflows available

| Name | Purpose | Tag |
|---|---|---|
| `claude-dependabot-merge.yml` | Headless Claude evaluation + merge of Dependabot PRs | `v1` |
| `claude-status-check.yml` | Weekly repo health check — PRs, CI, issues, Dependabot, stale branches | `v1` |

More to come in Phase 2: `python-ci.yml`, `node-ci.yml`, `rust-ci.yml`, `release-*.yml`, `homebrew-bump.yml`, `stale.yml`.

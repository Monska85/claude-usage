# AGENTS.md

## Project Overview

CLI dashboard + GNOME Shell extension for monitoring Claude Code usage. Reads rate-limit headers from minimal API polls and parses local JSONL conversation logs to show utilization percentages, token counts, reset times, and estimated costs.

**Tech stack:** Go 1.23, lipgloss (TUI), pflag (CLI flags), GNOME Shell JS (extension), YAML config.

## Setup

Local Go toolchain required. No Docker.

```bash
make build           # Build the binary
make install         # Build + install binary to ~/.local/bin + install GNOME extension
make install-binary  # Binary only
```

Ensure `~/.local/bin` is in `PATH`.

The project should transition from Makefile to a Justfile.

## Key Conventions

- Single static binary, no runtime dependencies.
- GNOME extension calls the CLI (`claude-usage --status`) as its sole API — no direct file I/O, no formatting logic.
- Extension is a pure renderer: CLI returns raw data (percentages, reset times, colors, stale flag), extension formats display text.
- Extension binary lookup: `$PATH` first, then `~/.local/bin/` fallback (GNOME Shell's PATH often excludes `~/.local/bin`).
- Extension errors (binary not found, spawn/parse failures) shown in dropdown menu with red text.
- Config lives at `~/.config/claude-code-usage/config.yaml` (YAML, loaded with `gopkg.in/yaml.v3`).
- Cache at `~/.cache/claude-code-usage/quota.json` (XDG Base Directory spec, configurable via `cache.path`).
- Cache directory created with `0700` permissions.
- Credentials read from `~/.claude/.credentials.json` (Claude Code OAuth, read-only — this file is managed by Claude Code).
- Never write to `~/.claude/` — that directory belongs to Claude Code.

### `--status` JSON API

The `--status` flag outputs a JSON object consumed by the extension and other tools.

> **Source of truth:** The `StatusResponse` struct in `cmd/claude-usage/main.go` defines the schema. When modifying that struct, verify this section still matches and update it if needed.

```json
{
  "c_pct": 42,       "c_reset": "3h12m",  "c_color": "#32c850",
  "w_pct": 67,       "w_reset": "5d02h",  "w_color": "#e6961e",
  "stale": false,
  "error": ""
}
```

- `c_pct`/`w_pct` — current (5h) and weekly (7d) utilization percentage (0–100).
- `c_reset`/`w_reset` — human-readable time until rate-limit window resets.
- `c_color`/`w_color` — hex color based on config thresholds.
- `stale` — true if cached data is older than the configured freshness window.
- `error` — non-empty on failure (no credentials, poll error, no cached data).

Flag combinations:
- `--status` — returns cached data if fresh, polls API if stale.
- `--status --force-poll` — always polls API regardless of cache freshness.
- `--status --no-poll` — returns cached data only, never polls. Error `"no cached data available"` if no cache exists.

### Extension Runtime Behavior

- Panel shows compact `C:42%  W:67%` (no reset times — those are in dropdown only).
- 30s timer calls `claude-usage --status` (CLI decides whether to poll or use cache).
- "Refresh Now" button calls `claude-usage --status --force-poll`.
- When `stale: true`: panel text at 50% opacity, dropdown shows orange "Cached data may be outdated" warning.
- When `error` is set: panel shows grey `C:--  W:--`, dropdown shows red error text.

### Project Structure

> **Keep this up to date.** When adding, removing, or renaming packages/files, update this tree.

```
cmd/claude-usage/     CLI entry point (main.go)
internal/
  analyzer/           Token aggregation, time periods, per-model breakdown
  auth/               OAuth credential loading from ~/.claude/
  cache/              Atomic JSON cache read/write
  config/             YAML config with defaults
  dashboard/          Lipgloss TUI rendering (tables, bars, panels)
  poller/             1-token Haiku API polling, rate-limit header parsing
  pricing/            Per-model pricing table with prefix fallback
  reader/             JSONL conversation log parser (filepath.WalkDir)
gnome-shell-extension/
  extension.js        GNOME Shell panel indicator
  metadata.json       Extension UUID and shell version compatibility
  sparkle.svg         Panel icon (8-point starburst)
```

## Code Style

- **Go**: standard `gofmt` formatting. Tabs for indentation.
- **JavaScript** (extension): 4-space indent, GJS/GNOME Shell API conventions.
- **YAML/JSON**: 2-space indent.
- `.editorconfig` enforces these settings.
- No golangci-lint configured yet — consider adding `.golangci.yml`.

## Git Workflow

### Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`, `build`.
**Scope** is optional — use the affected component (e.g., `poller`, `dashboard`, `extension`).

Keep the description lowercase, imperative, no period.

### Branching

- Branch naming: `feat/`, `fix/`, `chore/`, `test/`, `docs/` prefix + kebab-case description
  (e.g., `feat/add-export-csv`, `fix/broken-auth-redirect`).
- **Never push directly to `main`.** Always create a feature branch and open a pull request.

### Rebasing

- Always rebase onto `main` before pushing. No merge commits.
- Use `--force-with-lease` (never `--force`) after rebasing.

## Package Management

### Go

- Add: `go get <package>@latest`
- Tidy: `go mod tidy`
- Verify: `go mod verify`

### Dependency Safety

Before adding or upgrading any dependency, follow these rules:

1. **Never assume you know the latest version.** Your training data is outdated. Always verify against the live registry before adding or upgrading any package.

2. **Check the live registry:**

   ```bash
   curl -s "https://proxy.golang.org/<module>/@latest" | jq .
   ```

3. **Use the newest stable major version** compatible with Go 1.23. Check actual compatibility metadata.

4. **Avoid releases published within the last 5 days** to reduce supply chain attack risk. Check the release date from the registry response.

5. **Always run `go mod tidy`** after changing dependencies, then verify with `go mod verify`.

## Testing

No test files exist yet. When adding tests:

- Place `*_test.go` files alongside the code they test in `internal/*/`.
- Run with `go test ./...`.
- Add a `make test` target (or `just test` after Justfile migration).

## Command Safety

### Safe (run autonomously)

- `make build` — compile the binary
- `go vet ./...` — static analysis
- `go build ./...` — verify compilation
- `go mod verify` — verify dependency checksums
- `git status`, `git log`, `git diff`

### Dangerous (ask user first)

- `make install` — writes binary to `~/.local/bin`, copies extension files
- `make install-binary` — writes binary to `~/.local/bin`
- `make install-extension` — copies files to GNOME extensions directory
- `make reload-extension` — disables and re-enables the GNOME extension
- `go get <package>` — modifies `go.mod` and `go.sum`
- `git push`, `git commit`

### Destructive (never run)

- `make uninstall` — removes installed binary and extension
- `make uninstall-binary` — deletes binary from `~/.local/bin`
- `make uninstall-extension` — runs `rm -rf` on extension directory
- `make clean` — removes build artifacts
- `git push --force`

## Important Rules

- After any Go code change, always run `make build` to verify compilation. Then ask the user if they want to install the binary (`make install-binary`).
- After any extension JS change, ask the user if they want to install the extension (`make install-extension`).
- Never discard `os.UserHomeDir()` errors — propagate or handle them.
- Cache directory permissions must be `0700`, not `0755`.
- Extension JS errors must be logged (`log()`), never silently swallowed in catch blocks.
- Use `filepath.WalkDir` (not `filepath.Walk`) for filesystem traversal.
- Use `strings.HasPrefix` for prefix matching, not manual slice comparison.
- Pre-allocate slices when the capacity is known or estimable.
- Run `go vet ./...` before every commit.
- Follow conventional commits.
- Verify dependency versions against the live Go module proxy before adding.

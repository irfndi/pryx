# Onboarding sandbox

If you want to iterate on onboarding repeatedly without touching your real auth state, use a separate sandbox rooted under `PRYX_HOME` and `PRYX_RUNTIME_DIR`.

This repo already supports that isolation:

- `PRYX_HOME` redirects pryx-owned state such as `~/.pryx` into a sandbox directory.
- `PRYX_HOME` also redirects app config into `PRYX_HOME/config/pryx`.
- `PRYX_RUNTIME_DIR` redirects sockets and other ephemeral runtime files.
- External auth trust decisions are stored in the sandbox config, so a fresh sandbox starts with no trusted external auth imports.

## Fast start

```bash
scripts/onboarding_sandbox.sh fresh
```

That gives you a clean pryx launch with isolated state.

## Test with your REAL logins (import them in the sandbox)

A clean sandbox is fully isolated, so the onboarding "import existing logins"
step has nothing to import. To exercise the import + "continue where you left
off" steps against your actual accounts, seed copies of your real credential and
transcript files into the sandbox:

```bash
# Copy real external logins (Codex/Claude/Gemini/Copilot/Cursor/OpenCode/pi)
scripts/onboarding_sandbox.sh seed-real-logins

# Also copy your real Codex/Claude transcripts so the "continue a session"
# step has real history to resume:
scripts/onboarding_sandbox.sh seed-real-logins --with-transcripts

# Or do it all in one shot: reset, seed, and launch pryx
scripts/onboarding_sandbox.sh fresh-real --with-transcripts
```

How it works: when `PRYX_HOME` is set, pryx resolves every external credential
and transcript lookup to `$PRYX_HOME/external/<same-relative-path-as-$HOME>`.
`seed-real-logins` copies your real files there, so detection and import behave
exactly as they would on a first-run machine that already has those tools
installed. The copies are real tokens, so the sandbox stays local-only; your
original `$HOME` files are never moved, rewritten, or deleted.

Once seeded, just launch the sandbox and walk onboarding; it will detect and
offer to import each real login:

```bash
scripts/onboarding_sandbox.sh pryx
```

## Common commands

```bash
# Show the exact env vars and sandbox paths
scripts/onboarding_sandbox.sh env
scripts/onboarding_sandbox.sh status

# Start over from a blank onboarding state
scripts/onboarding_sandbox.sh reset
scripts/onboarding_sandbox.sh fresh

# Log into a provider without touching your normal pryx config
scripts/onboarding_sandbox.sh login openai
scripts/onboarding_sandbox.sh login claude
scripts/onboarding_sandbox.sh auth-status

# Save the resulting logged-in sandbox as a reusable local fixture
scripts/onboarding_sandbox.sh fixture-save normal-openai

# Later, restore that exact auth state without repeating browser login
scripts/onboarding_sandbox.sh fixture-load normal-openai
scripts/onboarding_sandbox.sh auth-status

# Or load and run one command in the fixture-backed sandbox
scripts/onboarding_sandbox.sh fixture-run normal-openai -- auth-test --provider openai --no-smoke

# Run arbitrary pryx commands in the sandbox
scripts/onboarding_sandbox.sh pryx auth status
scripts/onboarding_sandbox.sh pryx pair
```

## Reusable local auth fixtures

For repeated login testing, use local auth fixtures. A fixture is a copy of a
sandbox `PRYX_HOME` after you have put it into an interesting state, for
example a typical logged-in OpenAI user, an expired token state, or an external
auth import approval state.

The fixture store defaults to `.tmp/auth-fixtures`, which is intentionally local
developer state. Fixtures may contain real OAuth tokens or API-key references, so
do not commit or share them.

Recommended workflow:

```bash
# One-time setup for a realistic logged-in state
scripts/onboarding_sandbox.sh reset
scripts/onboarding_sandbox.sh login openai
scripts/onboarding_sandbox.sh auth-status
scripts/onboarding_sandbox.sh fixture-save normal-openai

# Fast repeat loop after that
scripts/onboarding_sandbox.sh fixture-load normal-openai
scripts/onboarding_sandbox.sh auth-status
scripts/onboarding_sandbox.sh pryx auth-test --provider openai
```

The lower-level helper can also be used directly:

```bash
scripts/auth_fixture.sh list
scripts/auth_fixture.sh save normal-openai
scripts/auth_fixture.sh load normal-openai
scripts/auth_fixture.sh run normal-openai -- auth status
```

Useful environment overrides:

- `PRYX_ONBOARDING_SANDBOX`: select which sandbox receives the fixture.
- `PRYX_ONBOARDING_DIR`: use an explicit sandbox directory.
- `PRYX_AUTH_FIXTURE_DIR`: use a fixture store outside the repo, for example
  `~/.local/share/pryx-auth-fixtures`.

Suggested fixture names:

- `normal-openai`
- `normal-claude`
- `expired-openai`
- `api-key-openrouter`
- `external-opencode-approved`

## Mobile onboarding simulator

The repo also has a resettable headless mobile simulator with predefined onboarding scenarios.

```bash
# Start the simulator in the background
scripts/onboarding_sandbox.sh mobile-start onboarding

# Inspect it
scripts/onboarding_sandbox.sh mobile-status
scripts/onboarding_sandbox.sh mobile-state
scripts/onboarding_sandbox.sh mobile-log

# Reset it back to the scenario start
scripts/onboarding_sandbox.sh mobile-reset
```

Supported scenarios today:

- `onboarding`
- `pairing_ready`
- `connected_chat`

## Why this is safer

A fresh sandbox means:

- no real pryx config files are reused
- no real runtime sockets are reused
- no previously trusted external auth sources are reused
- you can blow it away with one `reset`

When using fixtures, the sandbox is still isolated from your normal pryx state,
but the loaded fixture may intentionally contain copied auth state from an earlier
sandbox login.

## Recommended workflow

For tight onboarding iteration, use this loop:

1. `scripts/onboarding_sandbox.sh reset`
2. `scripts/onboarding_sandbox.sh fresh`
3. walk the onboarding flow
4. adjust code
5. repeat

If you are iterating specifically on mobile onboarding UX, keep the simulator running and use `mobile-reset` between passes.

## Caveat

This sandbox is designed to isolate pryx-owned state and trusted external-import state. If you later decide to test explicit import/reuse flows from external tools, do that intentionally and treat it as a separate test case from first-run onboarding.

# Upstream References

This project started as a fork of [`1jehuang/jcode`](https://github.com/1jehuang/jcode).
The codebase has been renamed to **Pryx**, but a few references to the original
upstream owner `1jehuang` remain intentional. They fall into two groups:

## 1. Third-party dependencies (keep as-is)

These are genuine external crates owned by the upstream author. Do **not** rename them:

| Dependency | Where declared |
| ------------ | ---------------- |
| `1jehuang/agentgrep` | `crates/pryx-app-core/Cargo.toml` |
| `1jehuang/mermaid-rs-renderer` | `crates/pryx-tui-mermaid/Cargo.toml` |
| `1jehuang/scrollwm` | source references |
| `1jehuang/handterm` | source references |
| `1jehuang/firefox-agent-bridge` | source references |

## 2. Sibling infrastructure (not yet migrated to `pryx-co`)

These repos/packages are published under the upstream `1jehuang` scope and do not
yet exist under `pryx-co`. They are referenced by the SDK, release workflow, and
Homebrew tap. Migrate them to `pryx-co` as they are created:

- `@1jehuang/pryx-sdk` and the platform packages (`@1jehuang/pryx-darwin-*`,
  `@1jehuang/pryx-linux-*`, `@1jehuang/pryx-win32-*`) — see `sdk/`
- `1jehuang/homebrew-pryx` — Homebrew formula, see `.github/workflows/release.yml`
- Release asset repos (`pryx-darwin-*`, `pryx-linux-*`, `pryx-win32-*`)

The **main repository** itself is `pryx-co/pryx` and is fully migrated.

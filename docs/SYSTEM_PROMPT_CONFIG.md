# Configuring the System Prompt

pryx builds its system prompt from several layers. Two of them are user-editable
files, so you can tune agent behavior without rebuilding.

## Layers (in order)

1. **Base system prompt** — built-in `crates/pryx-base/src/prompt/system_prompt.md`,
   overridable by file (see below).
2. Capability modules (e.g. Mermaid guidance).
3. Self-dev guidance (self-dev sessions only).
4. `AGENTS.md` — project `./AGENTS.md` and global `~/AGENTS.md`.
5. Prompt overlay — `./.pryx/prompt-overlay.md` and `~/.pryx/prompt-overlay.md`.
6. Preferred tools — `./.pryx/preferred-tools.md` and `~/.pryx/preferred-tools.md`.
7. Memory and the active skill prompt (dynamic, not cached).

## Adding guidance (most common)

Append instructions without touching the default prompt:

- `~/.pryx/prompt-overlay.md` — applies everywhere.
- `./.pryx/prompt-overlay.md` — applies to one project.

Both are included when present.

## Replacing the base prompt

To fully replace layer 1, create either file:

- `./.pryx/system-prompt.md` (project, highest precedence)
- `~/.pryx/system-prompt.md` (global)

The first non-empty file wins; otherwise the built-in default is used. An empty or
whitespace-only file falls back to the default, so you cannot accidentally ship an
empty prompt.

This replaces only the base prompt. AGENTS.md, overlays, skills, and memory still apply.

## Notes

- Changes to these files take effect for **new sessions**; a running session keeps the
  prompt captured at start.
- Editing the built-in `system_prompt.md` requires a rebuild (`selfdev build-reload`),
  since it is embedded with `include_str!`.
- Swarm model-routing guidance has its own analogous file: `.pryx/swarm-prompt.md`.

# Repository Guidelines

## Development Workflow

- **Stay on your own branch** - Do not take, cherry-pick, merge, or copy code from other
  people's or other agents' branches unless the source branch belongs to a repository
  maintainer and the user explicitly asks you to integrate it. Only work from your branch
  and its base (e.g. `main`) otherwise. Never integrate branches owned by non-maintainers
  or other agents yourself; tell the user and let them decide how to proceed.

## Install Notes
- `~/.local/bin/pryx` is the launcher symlink used from `PATH`.
- `~/.pryx/builds/current/pryx` is the active local/source-build channel; self-dev builds and `scripts/install_release.sh` point the launcher here.
- `~/.pryx/builds/stable/pryx` is the stable release channel; `scripts/install.sh` installs this and points the launcher here.
- `~/.pryx/builds/versions/<version>/pryx` stores immutable binaries.
- `~/.pryx/builds/canary/pryx` still exists for canary/testing flows, but it is not the primary self-dev install path.
- On Windows, the equivalents are `%LOCALAPPDATA%\\pryx\\bin\\pryx.exe` for the launcher, `%LOCALAPPDATA%\\pryx\\builds\\stable\\pryx.exe` for stable, and `%LOCALAPPDATA%\\pryx\\builds\\versions\\<version>\\pryx.exe` for immutable installs; `scripts/install.ps1` currently installs the stable channel.
- Ensure `~/.local/bin` is **before** `~/.cargo/bin` in `PATH`.

## Verifying a change at runtime

`cargo build` alone proves nothing about behavior. `pryx run` and interactive
sessions are served by the long-lived daemon at
`~/.pryx/builds/shared-server/pryx`, which is a symlink into
`~/.pryx/builds/versions/<version>/`. Until that symlink is repointed and the
daemon restarted (`pryx self-dev --build`), a freshly built binary is inert and
every runtime check silently measures the old code.

To test a change without disturbing the shared daemon or the caller's session,
run your build against its own socket:

```bash
cargo build --profile selfdev
./target/selfdev/pryx run --no-update --socket /run/user/1000/pryx-mytest.sock '<prompt>'
```

Two things that waste time otherwise:

- `crate::logging::info` writes to a log file, not stderr, so instrumenting a
  code path with it produces no visible output under `--trace`. Use `eprintln!`
  for throwaway diagnostics and delete it before committing.
- Confirm which binary you are actually inspecting. `strings` on
  `builds/shared-server/pryx` reads a 70-byte symlink, not a program; resolve it
  with `readlink -f` first.

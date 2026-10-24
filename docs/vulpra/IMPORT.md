# Importing pinned Firefox source

**Until a successful CI run and remote tree verification exist, this is a procedure, not an accomplished import.**

1. Trigger the `Import pinned Firefox source` Actions workflow on `main`.
2. Fetch Firefox 159.0b5 source from Mozilla and verify its SHA-256 against the release checksum list.
3. Expand into a temporary workspace and verify `mach` and `toolkit/content/license.html`.
4. Create `upstream-base` from the unmodified source files with a fresh root commit. Preserve full source tree and licenses, not the million-commit history.
5. Attach baseline ancestry to `main`, overlay source without overwriting Vulpra governance files and publish commits.
6. Independently inspect remote trees, check source checksums and compile/test before claiming success.

`upstream-base` is immutable after import. If an import is interrupted, inspect the remote branches and workflow logs before rerunning. Never force-push or overwrite an existing baseline without verifying and recording why.

**Known constraint:** standard GitHub-hosted Linux runners have 14 GB disk space. A source import is not a full browser build (Mozilla documents at least 30 GB for that). GitHub repository/object size and push limits may still make the initial import fail. A failure means no source import credit; adapt with staged pushes or a self-hosted runner and preserve the exact tag.

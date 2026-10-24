# Importing pinned Firefox source

**Source import completed on 2026-10-24:** [passing Actions run](https://github.com/sguzman/vulpra/actions/runs/40119418469). Full source file/content/symlink equivalence verification passed ([run 40120947358](https://github.com/sguzman/vulpra/actions/runs/40120947358)), modulo documented single-file CRLF normalization and empty Python cache directories.

1. Trigger the `Import pinned Firefox source` Actions workflow on `main`.
2. Fetch Firefox 159.0b5 source from Mozilla and verify its SHA-256 against the release checksum list.
3. Expand into a temporary workspace and verify `mach` and `toolkit/content/license.html`.
4. Create `upstream-base` from the source archive files with a fresh root commit. The GitHub Actions token cannot add `.github/workflows/*`, so those two excluded upstream files were restored after the initial push via connected GitHub permissions with identical upstream blob SHAs. Preserve original source, licenses, and track the exceptional import procedure.
5. Attach baseline ancestry to `main`, overlay source without overwriting Vulpra governance files and publish commits. Verified: `main` parentage includes root snapshot commit `5cbd6ba4b6ba11caa1cefed9fe5e9be0fdaf2783`.
6. Independently inspect remote trees, check source checksums and compile/test before claiming a working browser. Source-import CI, full source content/symlink comparison and critical-file checks passed; Linux builds are still open.

`upstream-base` is immutable after import. If an import is interrupted, inspect the remote branches and workflow logs before rerunning. Never force-push or overwrite an existing baseline without verifying and recording why.

**Known constraint:** standard GitHub-hosted Linux runners have 14 GB disk space. A source import is not a full browser build (Mozilla documents at least 30 GB for that). GitHub repository/object size and push limits may still make the initial import fail. A failure means no source import credit; adapt with staged pushes or a self-hosted runner and preserve the exact tag.

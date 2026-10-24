# Source provenance and legal boundary

## Pinned snapshot

- Product generation: Firefox 159.0b5, Beta / Developer Edition
- Official source repository: https://github.com/mozilla-firefox/firefox
- Exact Git tag: `FIREFOX_159_0b5_RELEASE`
- Verified tag target via GitHub API on 2026-10-24: `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`
- Release archive source: https://archive.mozilla.org/pub/firefox/releases/159.0b5/source/firefox-159.0b5.source.tar.xz
- Archive digest (SHA-256), verified against Mozilla's release SHA256SUMS in CI: `9145b8811cbb77108cdfc797e9119b69074aac6491b0df1fccd2c998ce706eb9`.
- GitHub Actions source import: **passed**, [run 40119418469](https://github.com/sguzman/vulpra/actions/runs/40119418469).
- Pristine snapshot initial import commit: `5cbd6ba4b6ba11caa1cefed9fe5e9be0fdaf2783` (root commit).
- `upstream-base` head after restoring original Mozilla workflow files: `0e324402e3e69b0b46e1d04452efe079c11a3794`.
- `main` integration commit: `58802537b337be6c1bf7a084f9ec51ab7f941a58` (contains a merge parent linking original Vulpra history to the source import root).
- Source paths `mach`, `LICENSE`, `Cargo.toml` and license template checked in CI. `mach` and `LICENSE` independently checked on `main` via GitHub.
- Full file/content/symlink equivalence check **passed** in [run 40120947358](https://github.com/sguzman/vulpra/actions/runs/40120947358), subject only to documented Git CRLF normalization and empty-directory handling.

## Licensing

Mozilla's source-tree `LICENSE` refers to a generated `toolkit/content/license.html` license page. Its source template is `toolkit/content/license.html.mako`; the actual source tree must preserve that template, `toolkit/content/licenses`, `LICENSE`, notices, `other-licenses` and per-file licenses. The Mozilla Firefox wordmark and logo are not granted by its code licenses.

The new repository was created with a template MIT license covering only appropriate originally authored Vulpra material before the import. Once the source import is complete, replace root `LICENSE` with Mozilla's upstream `LICENSE`. Do not pretend the old MIT template relicenses Mozilla code. Any unique Vulpra original material should be explicitly licensed and documented separately.

## Update discipline

For every future upstream revision: document its source tag and commit, review security advisories, produce a clean new upstream reference, compare and reapply personal patches, compile and test before shipping. Pinned release does not mean permanent abandonment of security updates.

## License/branding audit

Technical license integrity and upstream unofficial-branding selection checked in [run 40122675149](https://github.com/sguzman/vulpra/actions/runs/40122675149). This is not legal sign-off or clearance to distribute with Nightly/Firefox names; see [the dedicated audit](LICENSING-BRANDING.md).

## Full source-tree verification

The [full source audit](https://github.com/sguzman/vulpra/actions/runs/40120947358) passed on 2026-10-24. It compared file contents, paths and symlink targets against the SHA-256-verified source release archive. Two narrowly documented serialization exceptions apply: Git converted CRLF to LF for `dom/webgpu/tests/cts/checkout/node.tsconfig.json` (byte-identity after only that normalization was verified), and Git cannot store empty `__pycache__` directories from the archive. All other source paths compared without unexpected differences.

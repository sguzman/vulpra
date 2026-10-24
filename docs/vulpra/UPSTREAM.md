# Source provenance and legal boundary

## Pinned snapshot

- Product generation: Firefox 159.0b5, Beta / Developer Edition
- Official source repository: https://github.com/mozilla-firefox/firefox
- Exact Git tag: `FIREFOX_159_0b5_RELEASE`
- Verified tag target via GitHub API on 2026-10-24: `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`
- Release archive source: https://archive.mozilla.org/pub/firefox/releases/159.0b5/source/firefox-159.0b5.source.tar.xz
- Archive digest: **not yet recorded**; populate only after verifying Mozilla's release checksum.
- Actual imported tree: **not yet imported**.

## Licensing

Mozilla's source-tree `LICENSE` refers to a generated `toolkit/content/license.html` license page. Its source template is `toolkit/content/license.html.mako`; the actual source tree must preserve that template, `toolkit/content/licenses`, `LICENSE`, notices, `other-licenses` and per-file licenses. The Mozilla Firefox wordmark and logo are not granted by its code licenses.

The new repository was created with a template MIT license covering only appropriate originally authored Vulpra material before the import. Once the source import is complete, replace root `LICENSE` with Mozilla's upstream `LICENSE`. Do not pretend the old MIT template relicenses Mozilla code. Any unique Vulpra original material should be explicitly licensed and documented separately.

## Update discipline

For every future upstream revision: document its source tag and commit, review security advisories, produce a clean new upstream reference, compare and reapply personal patches, compile and test before shipping. Pinned release does not mean permanent abandonment of security updates.

# License and branding audit

This is a **technical source and packaging audit**, not legal advice or a trademark license. The snapshot and its licenses are real, and Vulpra remains an **independent, unofficial browser**.

## Examined pinned-source paths (Firefox 159.0b5)

| Requirement | Source evidence | Treatment |
| --- | --- | --- |
| Original source license notice | `LICENSE`, checked against `upstream-base` | Preserve in `main`, including attribution and Mozilla trademark disclaimer |
| MPL 2.0 per-file headers | `mach`, `browser/branding/unofficial/configure.sh`, `browser/branding/unofficial/locales/en-US/brand.ftl` | Preserve upstream headers and MPL-covered file-level requirements for modified files |
| Third-party licenses | `toolkit/content/licenses/`, `other-licenses/`, `third_party/` | Preserve; license obligations depend on individual included components, not only the top-level MPL |
| Browser license page | `toolkit/content/license.html.mako` and `LICENSES` collected into `licenses.json` | Preserve generation mechanism and the eventual packaged license page |
| Unofficial build selection | `ci/mozconfig-linux` chooses `browser/branding/unofficial` | Avoid selecting official Mozilla branding in Vulpra builds |
| **Unfinished independent branding** | `browser/branding/unofficial/configure.sh` originally set `MOZ_APP_DISPLAYNAME=Nightly`; Vulpra now overrides this in `main` | **Partially addressed:** main uses the Vulpra display name and app basename. Still verify compiled metadata, launcher and packaged identity |
| **Unfinished localized brand** | `browser/branding/unofficial/locales/en-US/brand.ftl` originally contained `Nightly`, `Firefox`, `Mozilla` | **Partially addressed:** main uses independent Vulpra Fluent display names; verify other visible references before release |
| Assets and executable identity | `browser/branding/unofficial/` contains upstream icons; launcher/profile are not yet isolated | **Release blocker:** review icons/trademarks; create independently named launcher, executable, app ID, desktop file and dedicated profile |

## Policy for the first usable personal build

1. Do **not** label the present CI package as a finished or safe-to-install Vulpra release. It still uses upstream unofficial names and launcher behavior. Do not replace the installed Firefox Developer Edition or reuse its profile.
2. Preserve original Mozilla attribution and all corresponding third-party license notices. The initial GitHub-template MIT commit does **not** relicense Mozilla's code. Unique Vulpra-authored files can have their own license but must not imply a repository-wide MIT grant.
3. Never enable `browser/branding/official` or use Mozilla's protected trademarks/logos as Vulpra branding. “Based on Mozilla Firefox” is factual attribution, not a claim of affiliation or endorsement.
4. Before producing a distributable personal build, validate Vulpra branding, runtime application ID, binary/desktop-file names, separate profile directory, update endpoints and removal of misleading Mozilla/Nightly-specific claims from visible UI.
5. Preserve or independently satisfy the generated `about:license` notices when pruning bundled dependencies. Removing a library from the build may change the needed notices, but do not casually delete license records.
6. Security maintenance is separate and mandatory: pinning a release snapshot does not excuse delaying upstream security fixes.

## Automated review

`ci/audit-licenses-branding.sh` checks the root LICENSE against `upstream-base`, representative upstream per-file licenses, license-generation infrastructure, third-party inventory locations, and the CI's nonofficial branding selection. GitHub Actions runs it on changes to license/branding/configuration files. The check **does not prove comprehensive third-party license compliance** and explicitly flags the remaining release blockers.

**Acceptance boundary:** This audit addresses the M1 source licensing/branding-plan task. It does **not** complete M2's independent binary, profile isolation, full compilation, or package distribution criteria.

## 2026-10-24 — independent visible identity (pending compiled acceptance)

The source's unofficial `configure.sh` and English Fluent brand strings now identify Vulpra. The Linux mozconfig explicitly uses upstream-supported `--with-app-basename=Vulpra`, intended to separate application.ini naming and system integration. This is source-level work, **not** proof that packaged UI or icons are independent. The Mozilla-defined Gecko application compatibility ID is deliberately unchanged until extension compatibility and migration behavior can be tested. Upstream icon assets, executable identity and isolated packaged application still require review and runtime evidence.

## Independent application vendor

The Vulpra development branch changes Firefox desktop's `MOZ_APP_VENDOR` implication from `Mozilla` to `Vulpra`, alongside the application basename and displayed brand strings. CI now requires `Vendor=Vulpra` in the generated `application.ini` before considering the packaged identity verified. The Gecko application compatibility GUID is left unchanged pending an extension-compatibility audit: it is not a substitute for independent trademarks and logos. No Mozilla endorsement is claimed.

## Vulpra update-help URLs

The manual-update and update-details browser preferences now point to the Vulpra GitHub releases page rather than `nightly.mozilla.org`. Automated source audit verifies this. These two preferences are *help links*, not the automatic update service URL. No automatic security updater has been implemented or verified for Vulpra; packaged distribution remains gated on an independent, tested update policy and upstream security maintenance.

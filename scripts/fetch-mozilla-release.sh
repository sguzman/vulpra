#!/usr/bin/env bash
# Recoverable acquisition of an authenticated Mozilla Git release.
# This helper never deletes, resets, or overwrites an existing source checkout.
set -Eeuo pipefail
umask 077
fail() { printf 'Vulpra source fetch: %s\n' "$*" >&2; exit 2; }
if [[ $# != 3 && $# != 4 ]]; then
  echo 'Usage: fetch-mozilla-release.sh ABSOLUTE_DIRECTORY RELEASE_TAG PINNED_SHA [GIT_REMOTE]' >&2
  exit 2
fi
target="$1"; tag="$2"; expected="$3"
remote="${4:-https://github.com/mozilla-firefox/firefox.git}"
[[ "$target" == /* && ! -L "$target" ]] || fail 'target must be an absolute non-symlink path'
[[ "$tag" =~ ^FIREFOX_[0-9]+_[0-9]+(_[0-9]+)?_RELEASE$ ]] || fail 'invalid Mozilla release tag'
[[ "$expected" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid pinned commit'
[[ "$remote" == https://github.com/mozilla-firefox/firefox.git || "$remote" == file:///* ]] ||
  fail 'unsupported upstream; only official Mozilla or an isolated local test fixture is permitted'
command -v git >/dev/null || fail 'Git is not installed'

if [[ ! -e "$target" ]]; then
  mkdir -p -- "$(dirname -- "$target")"
  mkdir -m 700 -- "$target"
  git -C "$target" init -q
  git -C "$target" remote add origin "$remote"
  git -C "$target" config vulpra.source-managed true
  echo 'Initialized isolated, reusable Mozilla source cache (no precompiled binary).'
else
  [[ -d "$target/.git" && ! -L "$target/.git" ]] ||
    fail "existing path is not a standalone Git source checkout; preserved: $target"
  [[ "$(git -C "$target" remote get-url origin 2>/dev/null || true)" == "$remote" ]] ||
    fail "existing Git source has an unexpected remote; preserved: $target"
  # Old interrupted git clones might lack our marker. Accept only a clean
  # exact-official-remote checkout; all other states fail without modifying it.
  [[ -z "$(git -C "$target" status --porcelain --untracked-files=all 2>/dev/null)" ]] ||
    fail "existing Mozilla source has local/partial checkout changes; preserved: $target"
  current="$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || true)"
  [[ -z "$current" || "$current" == "$expected" ]] ||
    fail "existing source is on a different revision; preserved: $target"
fi

# Repo-local setting only: never mutate global Git configuration or user repo.
git -C "$target" config http.version HTTP/1.1
current="$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || true)"
if [[ "$current" == "$expected" ]]; then
  printf 'PASS: verified Mozilla checkout already at %s\n' "$expected"
  exit 0
fi

# A failed pack is not byte-resumable in Git, but successfully stored objects
# are retained. Keep the cache and permit another explicit invocation.
for attempt in 1 2; do
  printf 'Fetching pinned Mozilla %s over HTTP/1.1 (attempt %s/2).\n' "$tag" "$attempt"
  if GIT_TERMINAL_PROMPT=0 git -C "$target" -c http.version=HTTP/1.1 \
      fetch --no-tags --depth=1 --filter=blob:none origin "refs/tags/$tag"; then
    break
  fi
  if [[ "$attempt" == 2 ]]; then
    fail 'remote Git transfer interrupted; retained fetched objects. Re-run the same opt-in command when the connection is stable'
  fi
  echo 'Transient fetch failure; trying one more time without deleting the cache.' >&2
done
fetched="$(git -C "$target" rev-parse FETCH_HEAD)"
[[ "$fetched" == "$expected" ]] ||
  fail "official tag resolves to unexpected commit ($fetched), refusing checkout"
git -C "$target" -c http.version=HTTP/1.1 checkout --detach "$expected" ||
  fail 'Git checkout interrupted; source cache preserved for inspection, no automatic reset'
[[ "$(git -C "$target" rev-parse HEAD)" == "$expected" ]] ||
  fail 'checkout commit mismatch'
[[ -z "$(git -C "$target" status --porcelain --untracked-files=all)" ]] ||
  fail 'checkout contains modifications; source cache preserved'
printf 'PASS: pinned official Mozilla source checkout at %s\n' "$expected"

#!/usr/bin/env bash
# Resume-safe Vulpra HEAD source downloader for Git partial clones.
# Downloads every missing tracked Git blob in small batches, then expands checkout.
set -Eeuo pipefail

REPO="${1:-$HOME/Code/Apps/vulpra}"
BATCH_SIZE="${VULPRA_BATCH_SIZE:-128}"
MAX_SINGLE_RETRIES="${VULPRA_SINGLE_RETRIES:-12}"

if ! [[ "$BATCH_SIZE" =~ ^[1-9][0-9]*$ && "$MAX_SINGLE_RETRIES" =~ ^[1-9][0-9]*$ ]]; then
  echo 'ERROR: Invalid batch-size or retry setting.' >&2
  exit 2
fi
cd "$REPO" || exit 2
if ! git rev-parse --is-inside-work-tree | grep -qx true; then
  echo "ERROR: Not a Git worktree: $REPO" >&2
  exit 2
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo 'ERROR: Missing origin remote.' >&2
  exit 2
fi
if [[ "$(git config --bool remote.origin.promisor || true)" != true ]]; then
  echo 'ERROR: This script is for an existing promisor/partial clone; refusing unexpected repository.' >&2
  exit 2
fi

COMMIT=$(git rev-parse --verify HEAD^{commit})
STATE_DIR=$(git rev-parse --path-format=absolute --git-path vulpra-complete-source)
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/download.log"
INDEX="$STATE_DIR/blobs-$COMMIT.txt"
MISSING="$STATE_DIR/missing-$COMMIT.txt"
BATCH_DIR="$STATE_DIR/batches"
mkdir -p "$BATCH_DIR"

log() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

# Prevent authentication prompts from hanging unattended retries.
export GIT_TERMINAL_PROMPT=0
unset GIT_NO_LAZY_FETCH # Never inhibit the actual inventory/download fetches.

log "==============================================="
log "Vulpra complete-source download: $(date -Is)"
log "Repo: $REPO"
log "Pinned HEAD: $COMMIT"
log "Batch size: $BATCH_SIZE blobs; Git transport: HTTP/1.1; stalled transfers time out after 90s"
log "Log: $LOG"
log "Stop with Ctrl-C; running this script again resumes automatically."
log "==============================================="

# Only enumerate files at the pinned commit. This fetches missing TREE metadata,
# not file contents, and stores a reusable sorted list of unique blob OIDs.
if [[ ! -s "$INDEX" ]]; then
  log 'STEP 1/4: Inventorying all tracked files (may fetch missing Git tree metadata)...'
  attempt=0
  until (
    git -c http.version=HTTP/1.1 \
      -c http.lowSpeedLimit=1 -c http.lowSpeedTime=90 \
      ls-tree -r -z \
      --format='%(objectname) %(objecttype)' "$COMMIT" \
      | tr '\0' '\n' \
      | awk '$2 == "blob" { print $1; n++; if (n % 10000 == 0) { printf "  Scanned %d file references...\n", n > "/dev/stderr"; fflush("/dev/stderr") }}' \
      | LC_ALL=C sort -u > "$INDEX.tmp"
  ); do
    attempt=$((attempt + 1))
    rm -f "$INDEX.tmp"
    delay=$((attempt * 5))
    ((delay > 60)) && delay=60
    log "Inventory interrupted. Retrying in ${delay}s (attempt $attempt)..."
    sleep "$delay"
  done
  if [[ ! -s "$INDEX.tmp" ]]; then
    log 'ERROR: Inventory empty; not changing checkout.'
    exit 1
  fi
  mv "$INDEX.tmp" "$INDEX"
fi
TOTAL=$(wc -l < "$INDEX")
TOTAL=${TOTAL//[[:space:]]/}
log "Tracked unique file-content objects: $TOTAL"

# Crucial: disable lazy fetching ONLY for the local-presence inventory.
# With lazy fetching enabled, a harmless 'cat-file' check would itself
# silently download blobs, potentially producing a gigantic transfer.
check_missing() {
  local source="$1" destination="$2" tmp="$2.tmp"
  GIT_NO_LAZY_FETCH=1 git cat-file \
    --batch-check='%(objectname) %(objecttype)' < "$source" \
    | awk '$2 == "missing" { print $1 }' > "$tmp"
  mv "$tmp" "$destination"
}

log 'STEP 2/4: Identifying only source objects not already downloaded...'
check_missing "$INDEX" "$MISSING"
NEEDED=$(wc -l < "$MISSING")
NEEDED=${NEEDED//[[:space:]]/}
PRESENT=$((TOTAL - NEEDED))
log "Already local: $PRESENT/$TOTAL unique blobs. Remaining: $NEEDED."

if (( NEEDED > 0 )); then
  rm -f "$BATCH_DIR"/chunk-* "$BATCH_DIR"/piece-* 2>/dev/null || true
  split -d -a 7 -l "$BATCH_SIZE" --additional-suffix=.oids \
    "$MISSING" "$BATCH_DIR/chunk-"
fi

DONE=$PRESENT
progress() {
  local percent=$((DONE * 100 / TOTAL))
  log "SOURCE OBJECTS: $DONE/$TOTAL ($percent%) present; $((TOTAL-DONE)) remaining."
}

# When a transfer fails, split it in half rather than retry a huge broken pack.
# Successful objects remain in .git and get skipped on future runs.
fetch_batch() {
  local file="$1" size="$2"
  local pending="$file.pending"
  check_missing "$file" "$pending"
  local left_before left_after
  left_before=$(wc -l < "$file"); left_before=${left_before//[[:space:]]/}
  left_after=$(wc -l < "$pending"); left_after=${left_after//[[:space:]]/}
  DONE=$((DONE + left_before - left_after))
  if ((left_after == 0)); then
    rm -f "$pending"
    return 0
  fi

  log "FETCH: $left_after missing blobs (original batch $size), $(date -Is)"
  local try=0
  while true; do
    # --progress explicitly enables visible output even through tee.
    if git -c http.version=HTTP/1.1 \
      -c http.lowSpeedLimit=1 -c http.lowSpeedTime=90 \
      -c fetch.negotiationAlgorithm=noop \
      fetch origin --no-tags --no-write-fetch-head \
      --recurse-submodules=no --filter=blob:none \
      --progress --stdin < "$pending" 2>&1 | tee -a "$LOG"; then
      local still="$file.verify"
      check_missing "$pending" "$still"
      local rem
      rem=$(wc -l < "$still"); rem=${rem//[[:space:]]/}
      DONE=$((DONE + left_after - rem))
      if ((rem == 0)); then
        rm -f "$pending" "$still"
        progress
        return 0
      fi
      mv "$still" "$pending"
      left_after=$rem
      log "WARNING: Fetch returned success but $rem blobs remain missing."
    else
      # If Git has retained a subset, count those before splitting.
      local still="$file.verify"
      check_missing "$pending" "$still"
      local rem
      rem=$(wc -l < "$still"); rem=${rem//[[:space:]]/}
      DONE=$((DONE + left_after - rem))
      mv "$still" "$pending"
      left_after=$rem
      if ((rem == 0)); then
        progress
        return 0
      fi
      log "Transfer failed; $rem blobs still missing."
    fi

    if ((left_after > 1)); then
      local half=$(((left_after + 1) / 2))
      local a="$file.left" b="$file.right"
      head -n "$half" "$pending" > "$a"
      tail -n +"$((half + 1))" "$pending" > "$b"
      rm -f "$pending"
      log "Automatically splitting failed batch into $half and $((left_after - half)) blobs."
      fetch_batch "$a" "$half"
      fetch_batch "$b" "$((left_after - half))"
      rm -f "$a" "$b"
      return 0
    fi

    try=$((try+1))
    if ((try >= MAX_SINGLE_RETRIES)); then
      log "ERROR: Single blob ${pending##*/} failed after $MAX_SINGLE_RETRIES attempts."
      log 'Nothing downloaded was lost. Re-run the same script to resume.'
      return 1
    fi
    local delay=$((try * 10))
    ((delay > 120)) && delay=120
    log "Retrying single remaining blob in ${delay}s ($try/$MAX_SINGLE_RETRIES)..."
    sleep "$delay"
  done
}

log 'STEP 3/4: Downloading missing blobs in retryable small batches...'
if ((NEEDED > 0)); then
  for batch in "$BATCH_DIR"/chunk-*.oids; do
    [[ -f "$batch" ]] || continue
    fetch_batch "$batch" "$BATCH_SIZE"
    rm -f "$batch"
  done
fi

log 'STEP 4/4: Verifying every tracked blob is present before expanding checkout...'
check_missing "$INDEX" "$MISSING"
NEEDED=$(wc -l < "$MISSING")
NEEDED=${NEEDED//[[:space:]]/}
if ((NEEDED > 0)); then
  log "ERROR: Still missing $NEEDED tracked blobs. Re-run this script; nothing needs resetting."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$COMMIT" ]]; then
  log 'ERROR: HEAD changed while downloading. Re-run to inventory the new commit; nothing was overwritten.'
  exit 1
fi
log "VERIFIED: All $TOTAL tracked file-content blobs are local."

if [[ "$(git config --bool core.sparseCheckout || true)" == true ]]; then
  log 'Expanding checkout to all tracked files (local disk operation; preserve tracked edits)...'
  # Since all objects are present, no more network transfer should be needed.
  if ! GIT_NO_LAZY_FETCH=1 git sparse-checkout disable 2>&1 | tee -a "$LOG"; then
    log 'ERROR: Working-tree expansion failed. All blobs are downloaded. Re-run safely.'
    exit 1
  fi
fi

log 'Checking selected files and sparse state...'
if [[ "$(git config --bool core.sparseCheckout || true)" == true ]]; then
  log 'ERROR: sparse checkout is still enabled.'
  exit 1
fi
# A successful object download is not enough: verify the index and worktree
# really expose all tracked files, even for an unusual previous checkout.
HEAD_FILES=$(git ls-tree -r --name-only "$COMMIT" | wc -l)
HEAD_FILES=${HEAD_FILES//[[:space:]]/}
INDEX_FILES=$(git ls-files | wc -l)
INDEX_FILES=${INDEX_FILES//[[:space:]]/}
MISSING_WORKTREE=$(git ls-files -d | wc -l)
MISSING_WORKTREE=${MISSING_WORKTREE//[[:space:]]/}
if ((INDEX_FILES < HEAD_FILES || MISSING_WORKTREE > 0)); then
  log "ERROR: Source blobs are local, but checkout is incomplete: $INDEX_FILES/$HEAD_FILES indexed; $MISSING_WORKTREE tracked worktree paths missing."
  log 'No user edits were discarded; inspect the repo rather than resetting it.'
  exit 1
fi
# Show a concise summary of any pre-existing local edits, including the
# user's deliberate mozbuild patch, without flooding the terminal.
GIT_NO_LAZY_FETCH=1 git status --short | sed -n '1,20p' | tee -a "$LOG"
log 'SUCCESS: Complete tracked HEAD source checkout; existing uncommitted edits preserved.'
log 'Not yet a successful native browser build; run ./mach build separately.'
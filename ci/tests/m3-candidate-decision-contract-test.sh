#!/usr/bin/env bash
# Actual candidate-policy schema with deliberate broken-ledger mutations.
# No Firefox binary, user profile or tracked source mutation.
set -euo pipefail
root="${1:-$(git rev-parse --show-toplevel)}"
contract="$root/ci/m3-candidate-decision-contract.jq"
ledger="$root/docs/vulpra/DEBLOAT-CANDIDATES.json"
test -s "$contract"
test -s "$ledger"
command -v jq >/dev/null
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
jq -e -f "$contract" "$ledger" > "$tmp/accepted.json"
jq -e '
  .schema_version==1 and
  .status=="scoped_candidate_policy_guard_passed" and
  .candidates_checked==20 and
  .classes=={"keep":11,"remove_source":4,"review":2,"conditional_compile":3} and
  .verified_distinct_pruned_source_paths==14867 and
  .verified_distinct_pruned_git_blob_bytes==129967585 and
  .incomplete_dependencies_preserved==true and
  .default_browser_changed==false and
  .new_source_deletion_authorized==false and
  .new_compiled_savings_claimed==false and
  .new_whole_M3_gate_passed==false and
  .exact_source_or_binary_runtime_proven_by_this_check==false
' "$tmp/accepted.json" >/dev/null

rejected=0
reject() {
  local label="$1" mutation="$2"
  jq "$mutation" "$ledger" > "$tmp/bad.json"
  if jq -e -f "$contract" "$tmp/bad.json" > "$tmp/false-pass.json" 2>/dev/null; then
    echo "FAIL: unsafe ledger accepted: $label" >&2
    exit 1
  fi
  rejected=$((rejected+1))
}
reject 'missing candidate' '.candidates |= .[:-1]'
reject 'duplicated candidate ID' '.candidates[1].id=.candidates[0].id'
reject 'unknown candidate class' '.candidates[0].m3_strategy.strategy="remove_everything"'
reject 'protect GTK by keeping it' '.candidates[0].m3_strategy.strategy="remove_source" | .candidates[0].m3_strategy.permanent_removal_accepted=true'
reject 'protect browser security' '(.candidates[]|select(.id=="core_web_security")|.m3_strategy.broad_feature_removal_authorized)=true'
reject 'protect FxAccounts' '(.candidates[]|select(.id=="firefox_accounts")|.m3_strategy.strategy)="review"'
reject 'protect browser Sync' '(.candidates[]|select(.id=="sync_services")|.m3_strategy.guarded_opt_in_omission_accepted)=true'
reject 'protect privacy deletion request machinery' '(.candidates[]|select(.id=="telemetry_internals")|.m3_strategy.permanent_removal_accepted)=true'
reject 'protect offline AI seed' '(.candidates[]|select(.id=="aiwindow_prompt_seed")|.m3_strategy.strategy)="conditional_compile"'
reject 'protect Hungarian hyphenation' '(.candidates[]|select(.id=="hungarian_hyphenation_patterns")|.m3_strategy.strategy)="remove_source"'
reject 'do not permanently prune guarded Normandy experiment' '(.candidates[]|select(.id=="normandy_and_healthreport")|.m3_strategy.permanent_removal_accepted)=true'
reject 'do not permanently prune guarded AdsFeed' '(.candidates[]|select(.id=="newtab_adsfeed_optout")|.m3_strategy.permanent_removal_accepted)=true'
reject 'do not permanently prune guarded PromoCard' '(.candidates[]|select(.id=="newtab_promocard_optout")|.m3_strategy.guarded_opt_in_omission_accepted)=false'
reject 'do not permanently remove protected GenAI root' '(.candidates[]|select(.id=="browser_genai")|.m3_strategy.strategy)="remove_source"'
reject 'do not approve full testing tree deletion' '(.candidates[]|select(.id=="source_testing")|.m3_strategy.permanent_removal_accepted)=true'
reject 'reject missing failure-safe fallback' '(.candidates[]|select(.id=="source_testing")|.m3_strategy.safety_and_fallback)=""'
reject 'reject missing runtime/source evidence' '(.candidates[]|select(.id=="newtab_and_messaging")|.evidence)=[]'
reject 'reject missing provenance' '(.candidates[]|select(.id=="browser_genai")|.m3_strategy.provenance)=""'
reject 'reject invalid flag type' '(.candidates[]|select(.id=="pocket_integration")|.m3_strategy.broad_feature_removal_authorized)="false"'
reject 'reject fake complete candidate map' '.m3_decision_classification.complete_feature_dependency_inventory=true'
reject 'reject fake fallback closure' '.m3_decision_classification.complete_candidate_fallback_validation=true'
reject 'reject unearned gate' '.m3_decision_classification.whole_m3_gate_passed=true'
reject 'reject inflated summary count' '.m3_decision_classification.categories.keep=11'
reject 'reject claimed new normal browser change' '.m3_decision_classification.no_normal_browser_feature_changed=false'
reject 'reject compiled saving without build' '.m3_decision_classification.new_compiled_savings_bytes=500000'
reject 'reject inflated pruned Git file count' '.accepted_source_pruning_cohort_totals.aggregate_removed_git_paths+=1'
reject 'reject fabricated platform prune size' '.accepted_source_pruning_cohort_totals.cohorts[0].original_git_blob_bytes+=100'
reject 'reject fake new deletion approval' '.accepted_source_pruning_cohort_totals.new_pruning_authorized=true'
reject 'reject source-only claims of binary savings' '.accepted_source_pruning_cohort_totals.compiled_package_bytes_saved=1234'
reject 'reject source-only claims of native library removal' '.accepted_source_pruning_cohort_totals.native_library_removed=true'
reject 'reject add old overlapping candidate inventories' '.accepted_source_pruning_cohort_totals.candidate_fields_source_files_not_additive_as_pruned_totals=false'
reject 'reject incorrectly declared milestone progress' '.accepted_source_pruning_cohort_totals.broader_m3_gate_advanced_by_this_accounting=true'
if [[ "$rejected" -ne 32 ]]; then
  echo "FAIL: expected 32 unsafe mutation rejections, saw $rejected" >&2
  exit 1
fi
echo "PASS: real 20-candidate scoped policy; $rejected deliberately unsafe mutations rejected"
echo "PASS: verified 14,867 distinct source paths and 129,967,585 original Git blob bytes"
echo "LIMIT: no current binary test, broad dependency closure, new deletion or saving"

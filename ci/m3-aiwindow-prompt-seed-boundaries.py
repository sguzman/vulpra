#!/usr/bin/env python3
"""Pinned bounded AI Window Remote Settings prompt-seed dependency audit.

Only source anchors are read; the large untrusted prompt-data JSON is never
loaded or interpreted. This is not proof of live runtime reachability or safe
omission, package byte savings, or remote availability.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
FILES={
    "browser":"browser/components/moz.build",
    "aiwindow":"browser/components/aiwindow/moz.build",
    "models":"browser/components/aiwindow/models/moz.build",
    "seed":"services/settings/dumps/main/moz.build",
    "client":"browser/components/aiwindow/models/Utils.sys.mjs",
    "loader":"browser/components/aiwindow/models/PromptLoader.sys.mjs",
    "settings":"services/settings/dumps/moz.build",
}
def tracked():
    return {k:subprocess.check_output(
        ["git","-C",str(ROOT),"show","HEAD:"+path],text=True,
        stderr=subprocess.PIPE) for k,path in FILES.items()}

def anchor(texts,key,lit):
    raw=texts[key]
    if raw.count(lit)!=1: raise ValueError("Missing/ambiguous "+key+": "+lit)
    return {"path":FILES[key],"line":raw.count("\n",0,raw.index(lit))+1,
            "literal":lit}

def scoped(texts,key,start,end,*tokens):
    raw=texts[key]
    if raw.count(start)!=1: raise ValueError("Missing/ambiguous guard "+key)
    b=raw.find(end,raw.index(start)+len(start))
    if b<0: raise ValueError("Missing guard terminator "+key)
    block=raw[raw.index(start):b]
    for item in tokens:
        if item not in block:
            raise ValueError("Required source escaped guard "+key+": "+item)
    return anchor(texts,key,start)

def validate(texts):
    b=[]
    def add(name,decision,note,*items):
        b.append({"id":name,"decision":decision,"safety_rationale":note,
                  "anchors":list(items)})
    add("browser_traverses_aiwindow","retain_pending_fallback",
        "AIWindow is included as a browser component, not a standalone dead asset.",
        anchor(texts,"browser",'    "aiwindow",'),
        anchor(texts,"aiwindow",'    "models",'))
    add("prompts_seed_packaged_for_browser","retain_pending_fallback",
        "The browser-specific Remote Settings dumps include the prompts seed.",
        anchor(texts,"settings",'    "main",'),
        scoped(texts,"seed",'if CONFIG["MOZ_BUILD_APP"] == "browser":',
               '# These collections are referenced in toolkit/',
               '"ai-window-prompts.json"'))
    add("prompt_loader_compiled_into_models","retain_pending_fallback",
        "AIWindow model build includes the prompt loader regardless of preference.",
        anchor(texts,"models",'    "PromptLoader.sys.mjs",'))
    add("remote_client_reads_named_seed_collection","retain_pending_fallback",
        "Remote Settings named collection and main bucket supply model records.",
        anchor(texts,"client",'const RS_AI_WINDOW_COLLECTION = "ai-window-prompts";'),
        anchor(texts,"client",'const client = lazy.RemoteSettings(RS_AI_WINDOW_COLLECTION, {'),
        anchor(texts,"client",'    bucketName: "main",'),
        anchor(texts,"client",'  const promise = getRemoteClient()'))
    add("chat_prompt_requires_published_manifest","retain_pending_fallback",
        "The v2 chat prompt path rejects absent manifest rather than silently "
        "continuing; offline first-run and fallback are unverified.",
        anchor(texts,"loader",'export async function buildChatSystemPrompt(model) {'),
        anchor(texts,"loader",'const err = new Error("Missing chat module manifest");'),
        anchor(texts,"loader",'const records = await loadV2Records();'))
    add("generic_loader_has_remote_and_override_paths","retain_pending_fallback",
        "Prompt loader imports Remote Settings record retrieval and custom pref "
        "overrides; none proves replacing the full seed is safe.",
        anchor(texts,"loader",'  getRemoteRecords,'),
        anchor(texts,"loader",'const CUSTOM_PROMPTS_PREF = "browser.smartwindow.customPrompts";'),
        anchor(texts,"loader",'export async function loadPrompt(feature, opts = {}) {'))
    return {"schema_version":1,"scope":"AIWindow prompt seed packaging, RemoteSettings and prompt loader",
            "source_only":True,"prompt_json_body_not_read":True,
            "source_removal_authorized":False,"offline_fallback_verified":False,
            "compiled_package_bytes_saved":None,"boundaries":b,
            "next_required":[
              "Investigate RemoteSettings shipped seed and sync fallback across fresh offline profile.",
              "Design opt-in omission guard that leaves first-run startup and required prompt manifests intact.",
              "Repeat exact-source native Wayland, AI Window smoke, WebExtension, profile and package checks.",
              "Measure paired archive sizes; a source file's logical size is not compressed saving."],
            "limitations":[
              "Source contracts do not prove all dynamic AIWindow callers or actual first-run behavior.",
              "Remote Settings may serve updated records after network access; no service check made.",
              "Prompt content/data not read, modified or sent anywhere.",
              "No safe omission, linker trace, native build, or runtime test performed."]}

def selftest(t):
    changes=[
      ("browser",'    "aiwindow",'),
      ("aiwindow",'    "models",'),
      ("settings",'    "main",'),
      ("seed",'if CONFIG["MOZ_BUILD_APP"] == "browser":'),
      ("seed",'"ai-window-prompts.json"'),
      ("models",'    "PromptLoader.sys.mjs",'),
      ("client",'const RS_AI_WINDOW_COLLECTION = "ai-window-prompts";'),
      ("client",'    bucketName: "main",'),
      ("client",'  const promise = getRemoteClient()'),
      ("loader",'const err = new Error("Missing chat module manifest");'),
      ("loader",'const CUSTOM_PROMPTS_PREF = "browser.smartwindow.customPrompts";'),
      ("loader",'export async function buildChatSystemPrompt(model) {'),
    ]
    for key,lit in changes:
        if t[key].count(lit)!=1:raise AssertionError("Bad fixture "+key+": "+lit)
        damaged=dict(t);damaged[key]=damaged[key].replace(lit,"__BROKEN_DEPENDENCY__",1)
        try:validate(damaged)
        except ValueError:continue
        raise AssertionError("Broken prompt fallback anchor accepted: "+lit)
    return len(changes)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--self-test",action="store_true")
    parser.add_argument("--output")
    args=parser.parse_args()
    texts=tracked()
    commit=subprocess.check_output(
        ["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    result=validate(texts);result["source_commit"]=commit
    if args.self_test:result["negative_mutations_rejected"]=selftest(texts)
    if args.output:
        path=Path(args.output);path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(result,indent=2)+"\n")
    print(f"PASS: {len(result['boundaries'])} AI Window prompt seed source contracts at {commit}")
    if args.self_test:print(f"PASS: {result['negative_mutations_rejected']} corruptions rejected")
    print("Source-only and no prompt data read; no omission or compression saving")
if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL AI Window prompt seed audit:",e,file=sys.stderr)
        raise SystemExit(1)

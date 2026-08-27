#!/usr/bin/env python3
"""Auditz — AI-assisted Flutter codebase audit pipeline.

Commands:
  scan      Per-file audit (map phase) + optional cross-file reduce phase.
  visual    Audit UI screenshots with a vision model.
  baseline  Snapshot current findings as the accepted baseline.
  report    Regenerate report.md + findings.sarif from findings on disk.

Outputs live in <project>/.auditz/
Requires: pip install anthropic ; env ANTHROPIC_API_KEY (not needed for --dry-run).
"""

import argparse
import base64
import concurrent.futures
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

TOOL_DIR = Path(__file__).resolve().parent
OUT_DIRNAME = ".auditz"
DEFAULT_MODEL = "claude-sonnet-4-6"          # map phase default (cost-efficient)
DEFAULT_REDUCE_MODEL = "claude-sonnet-4-6"   # override with --reduce-model claude-fable-5
DEFAULT_MIN_CONFIDENCE = 0.7
MAX_TOKENS = 4096
CODE_PACKS = ["correctness", "performance", "flow_ux"]
REDUCE_PACK = "architecture"
VISUAL_PACK = "visual"

DEFAULT_EXCLUDES = [
    "**/*.g.dart", "**/*.freezed.dart", "**/*.gr.dart", "**/*.mocks.dart",
    "**/generated/**", "**/gen/**", "**/l10n/**", "**/*.gen.dart",
]

# pubspec dependency -> stack tag
STACK_TAGS = {
    "flutter_riverpod": "riverpod", "hooks_riverpod": "riverpod", "riverpod": "riverpod",
    "flutter_bloc": "bloc", "bloc": "bloc",
    "provider": "provider",
    "get": "get",
    "go_router": "go_router",
    "auto_route": "auto_route",
    "hive": "hive", "hive_flutter": "hive", "hive_ce": "hive",
    "isar": "isar", "drift": "drift",
    "freezed_annotation": "freezed", "freezed": "freezed",
    "dio": "dio", "http": "http",
    "liquid_glass_widgets": "liquid_glass",
    "cached_network_image": "cached_network_image",
    "intl": "intl", "easy_localization": "i18n", "slang": "i18n", "flutter_localizations": "i18n",
}

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}
SARIF_LEVEL = {"high": "error", "medium": "warning", "low": "note"}

# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------

def log(msg):
    print(f"[auditz] {msg}", file=sys.stderr)


def out_dir(project: Path) -> Path:
    d = project / OUT_DIRNAME
    d.mkdir(exist_ok=True)
    return d


def load_json(path: Path, default):
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            log(f"warning: could not parse {path}, ignoring")
    return default


def save_json(path: Path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def norm_ws(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def fingerprint(f: dict) -> str:
    key = f"{f.get('rule_id','')}|{f.get('file','')}|{norm_ws(f.get('evidence','') or f.get('why',''))}"
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:16]


def load_config(project: Path) -> dict:
    return load_json(project / "auditz.json", {})


# ----------------------------------------------------------------------------
# Stack detection + file discovery
# ----------------------------------------------------------------------------

def detect_stack(project: Path) -> set:
    tags = {"core", "flutter"}
    pubspec = project / "pubspec.yaml"
    if not pubspec.exists():
        log("warning: no pubspec.yaml found — only core rules will apply")
        return {"core"}
    deps = set()
    in_deps = False
    for line in pubspec.read_text(encoding="utf-8", errors="replace").splitlines():
        if re.match(r"^(dependencies|dev_dependencies):\s*$", line):
            in_deps = True
            continue
        if in_deps and re.match(r"^\S", line):  # left-aligned key ends the block
            in_deps = False
        if in_deps:
            m = re.match(r"^\s{2}([a-z0-9_]+)\s*:", line)
            if m:
                deps.add(m.group(1))
    for dep, tag in STACK_TAGS.items():
        if dep in deps:
            tags.add(tag)
    # hive without generated TypeAdapters => raw-JSON storage pattern
    if "hive" in tags:
        has_adapter = any(
            "TypeAdapter" in p.read_text(encoding="utf-8", errors="replace")
            for p in (project / "lib").rglob("*.dart") if p.is_file()
        ) if (project / "lib").exists() else False
        if not has_adapter:
            tags.add("hive_json")
    return tags


def excluded(rel: str, excludes) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in excludes)


def dart_files(project: Path, excludes) -> list:
    lib = project / "lib"
    if not lib.exists():
        return []
    files = []
    for p in sorted(lib.rglob("*.dart")):
        rel = p.relative_to(project).as_posix()
        if not excluded(rel, excludes):
            files.append(rel)
    return files


# ----------------------------------------------------------------------------
# Repo map (lightweight, regex-based)
# ----------------------------------------------------------------------------

CLASS_RE = re.compile(r"^(?:abstract\s+)?class\s+(\w+)\s+extends\s+(\w+)", re.M)
PROVIDER_RE = re.compile(r"^(?:final|var)\s+(\w*[Pp]rovider\w*)\s*=", re.M)
RIVERPOD_GEN_RE = re.compile(r"@[Rr]iverpod[\s\S]{0,80}?class\s+(\w+)\s+extends", re.M)
WATCH_RE = re.compile(r"ref\.(?:watch|read|listen)\(\s*([A-Za-z_]\w*)")
ROUTE_RE = re.compile(r"GoRoute\(\s*[\s\S]{0,200}?path:\s*['\"]([^'\"]+)['\"]")
IMPORT_RE = re.compile(r"^import\s+['\"]([^'\"]+)['\"]", re.M)


def build_repo_map(project: Path, files: list) -> dict:
    rmap = {"files": {}, "providers": {}, "routes": [], "generated_at": datetime.now(timezone.utc).isoformat()}
    for rel in files:
        text = (project / rel).read_text(encoding="utf-8", errors="replace")
        classes = [f"{m.group(1)}:{m.group(2)}" for m in CLASS_RE.finditer(text)]
        providers = PROVIDER_RE.findall(text) + [f"{c}Provider" for c in RIVERPOD_GEN_RE.findall(text)]
        watches = sorted(set(WATCH_RE.findall(text)))
        routes = ROUTE_RE.findall(text)
        imports = [i for i in IMPORT_RE.findall(text) if not i.startswith("dart:")]
        rmap["files"][rel] = {
            "loc": text.count("\n") + 1,
            "classes": classes,
            "providers": providers,
            "watches": watches,
            "imports": imports,
        }
        for pv in providers:
            rmap["providers"].setdefault(pv, {"defined_in": rel, "watched_by": []})
        rmap["routes"] += [{"path": r, "file": rel} for r in routes]
    for rel, info in rmap["files"].items():
        for w in info["watches"]:
            if w in rmap["providers"]:
                rmap["providers"][w]["watched_by"].append(rel)
    return rmap


def repo_map_summary(rmap: dict, budget_chars: int = 9000) -> str:
    lines = [f"{len(rmap['files'])} dart files, {len(rmap['providers'])} providers, {len(rmap['routes'])} routes."]
    lines.append("\nFILES (path | loc | classes | watches):")
    for rel, i in rmap["files"].items():
        cls = ",".join(c.split(":")[0] for c in i["classes"][:4]) or "-"
        w = ",".join(i["watches"][:4]) or "-"
        lines.append(f"  {rel} | {i['loc']} | {cls} | {w}")
    lines.append("\nPROVIDERS (name -> defined_in <- watched_by):")
    for name, p in rmap["providers"].items():
        lines.append(f"  {name} -> {p['defined_in']} <- {', '.join(p['watched_by']) or '(nobody)'}")
    lines.append("\nROUTES:")
    for r in rmap["routes"]:
        lines.append(f"  {r['path']}  ({r['file']})")
    text = "\n".join(lines)
    if len(text) > budget_chars:  # large repo: drop per-file detail, keep graphs
        text = "\n".join([lines[0]] + lines[lines.index("\nPROVIDERS (name -> defined_in <- watched_by):"):])
        text = text[:budget_chars]
    return text


# ----------------------------------------------------------------------------
# Tier 0 — dart analyze (deterministic, free)
# ----------------------------------------------------------------------------

def run_tier0(project: Path) -> list:
    try:
        proc = subprocess.run(
            ["dart", "analyze", "--format=machine"],
            cwd=project, capture_output=True, text=True, timeout=300,
        )
    except FileNotFoundError:
        log("tier0: `dart` not on PATH — skipping (AI packs still run)")
        return []
    except subprocess.TimeoutExpired:
        log("tier0: dart analyze timed out — skipping")
        return []
    diags = []
    for line in (proc.stdout + proc.stderr).splitlines():
        parts = line.split("|")
        if len(parts) >= 8:
            sev, _type, code, fpath, ln = parts[0], parts[1], parts[2], parts[3], parts[4]
            try:
                rel = Path(fpath).resolve().relative_to(project.resolve()).as_posix()
            except ValueError:
                rel = fpath
            diags.append({"severity": sev.lower(), "code": code, "file": rel,
                          "line": int(ln) if ln.isdigit() else 0,
                          "message": "|".join(parts[7:])})
    log(f"tier0: {len(diags)} analyzer diagnostics")
    return diags


# ----------------------------------------------------------------------------
# Rule packs
# ----------------------------------------------------------------------------

RULE_HEADER_RE = re.compile(r"^### rule_id:\s*(\w+)\s*$", re.M)


def load_pack(name: str, stack: set) -> str:
    """Return the pack's markdown with rules filtered by detected stack tags."""
    path = TOOL_DIR / "rulepacks" / f"{name}.md"
    if not path.exists():
        raise SystemExit(f"rule pack not found: {path}")
    text = path.read_text(encoding="utf-8")
    blocks = RULE_HEADER_RE.split(text)
    header, kept = blocks[0], []
    for i in range(1, len(blocks), 2):
        rule_id, body = blocks[i], blocks[i + 1]
        m = re.search(r"^requires:\s*(.+)$", body, re.M)
        req = {t.strip() for t in m.group(1).split(",")} if m else {"core"}
        if req <= stack:
            kept.append(f"### rule_id: {rule_id}{body}")
    return header + "".join(kept)


def pack_rule_ids(pack_text: str) -> list:
    return RULE_HEADER_RE.findall(pack_text)


# ----------------------------------------------------------------------------
# Prompts
# ----------------------------------------------------------------------------

MAP_CONTRACT = """You are a senior Flutter code reviewer. Audit ONE file against the rules below.

Return ONLY valid JSON, no markdown fences, no prose:
{"findings": [{"file": "<given path>", "line": <int>, "rule_id": "<from rules>",
  "severity": "high|medium|low", "confidence": <0..1>,
  "evidence": "<verbatim contiguous code from the file, 1-3 lines, copied exactly, WITHOUT the line-number prefixes>",
  "why": "<1-2 specific sentences, in Vietnamese>",
  "fix": "<short corrected code, in Dart>"}]}

Rules of engagement:
- Report only violations of the listed rules. No stylistic nitpicks, no invented rules.
- Skip anything already flagged by the analyzer (listed in the user message).
- "evidence" must exist verbatim in the file; it is used to verify your finding. Findings with fabricated evidence are discarded.
- Unsure => lower confidence. Clean file => {"findings": []}.
"""

REDUCE_CONTRACT = """You are a senior Flutter architect. You get a repository map and the per-file findings already collected. Report ONLY cross-file / architectural issues per the rules below — things invisible when reading one file at a time. Do not repeat per-file findings.

Return ONLY valid JSON, no markdown fences, no prose:
{"findings": [{"file": "<primary file or empty string>", "related_files": ["..."],
  "line": 0, "rule_id": "<from rules>", "severity": "high|medium|low",
  "confidence": <0..1>, "evidence": "",
  "why": "<2-3 specific sentences, in Vietnamese, naming concrete files/providers/routes>",
  "fix": "<concrete restructuring suggestion, in Vietnamese>"}]}
"""

VISUAL_CONTRACT = """You are a senior mobile UI/UX reviewer. You get screenshots of one screen rendered in several variants (sizes, light/dark, text scale). Filenames encode the variant. Compare variants and audit against the rules below.

Return ONLY valid JSON, no markdown fences, no prose:
{"findings": [{"file": "<screenshot filename>", "line": 0, "rule_id": "<from rules>",
  "severity": "high|medium|low", "confidence": <0..1>, "evidence": "",
  "why": "<what is visibly wrong and where on the screen, in Vietnamese>",
  "fix": "<concrete UI change, in Vietnamese>"}]}

Only report real, visible problems. Clean screens => {"findings": []}.
"""


def numbered(text: str) -> str:
    return "\n".join(f"{i + 1:>5}| {l}" for i, l in enumerate(text.splitlines()))


def build_map_prompt(pack_texts: list, stack: set, rmap_summary: str):
    static = (
        MAP_CONTRACT
        + f"\nDetected stack tags: {', '.join(sorted(stack))}\n\n"
        + "\n\n".join(pack_texts)
        + "\n\n== REPOSITORY MAP ==\n" + rmap_summary
    )
    return static


# ----------------------------------------------------------------------------
# Anthropic API
# ----------------------------------------------------------------------------

def get_client():
    try:
        import anthropic
    except ImportError:
        raise SystemExit("pip install anthropic  (or use --dry-run)")
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit("ANTHROPIC_API_KEY is not set (or use --dry-run)")
    return anthropic.Anthropic()


def system_blocks(static_text: str):
    return [{"type": "text", "text": static_text, "cache_control": {"type": "ephemeral"}}]


def call_model(client, model: str, system_text: str, user_content) -> str:
    for attempt in range(3):
        try:
            resp = client.messages.create(
                model=model, max_tokens=MAX_TOKENS,
                system=system_blocks(system_text),
                messages=[{"role": "user", "content": user_content}],
            )
            return "".join(b.text for b in resp.content if b.type == "text")
        except Exception as e:  # noqa: BLE001 — retry transient API errors
            if attempt == 2:
                raise
            log(f"api error ({e}); retrying in {2 ** attempt * 5}s")
            time.sleep(2 ** attempt * 5)


def extract_json(text: str):
    t = text.strip()
    t = re.sub(r"^```(?:json)?\s*|\s*```$", "", t, flags=re.S)
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        pass
    start = t.find("{")
    if start == -1:
        return None
    depth = 0
    for i in range(start, len(t)):
        if t[i] == "{":
            depth += 1
        elif t[i] == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(t[start:i + 1])
                except json.JSONDecodeError:
                    return None
    return None


# ----------------------------------------------------------------------------
# Verification / suppression
# ----------------------------------------------------------------------------

IGNORE_LINE_RE = re.compile(r"//\s*audit:ignore\s+([\w,\s\-]+)")
IGNORE_FILE_RE = re.compile(r"//\s*audit:ignore-file\s+([\w,\s\-]+)")


def collect_ignores(text: str):
    file_ids, line_ids = set(), {}
    for i, line in enumerate(text.splitlines(), start=1):
        m = IGNORE_FILE_RE.search(line)
        if m:
            file_ids |= {t.strip() for t in m.group(1).split(",")}
            continue
        m = IGNORE_LINE_RE.search(line)
        if m:
            ids = {t.strip() for t in m.group(1).split(",")}
            line_ids[i] = line_ids.get(i, set()) | ids       # same line
            line_ids[i + 1] = line_ids.get(i + 1, set()) | ids  # comment above
    return file_ids, line_ids


def verify_evidence(finding: dict, lines: list):
    """Locate evidence verbatim in the file; fix the line number; else None."""
    ev_lines = [l.strip() for l in (finding.get("evidence") or "").splitlines() if l.strip()]
    if not ev_lines:
        return None
    for i in range(len(lines)):
        if lines[i].strip() == ev_lines[0]:
            if all(i + k < len(lines) and lines[i + k].strip() == ev_lines[k]
                   for k in range(len(ev_lines))):
                finding["line"] = i + 1
                return finding
    if len(ev_lines) == 1:  # tolerate partial-line evidence
        for i, line in enumerate(lines):
            if ev_lines[0] in line:
                finding["line"] = i + 1
                return finding
    return None


def clean_findings(raw, rel, valid_rules, text, min_conf, stats):
    """Validate model output for one file: schema, evidence, ignores, confidence."""
    out = []
    lines = text.splitlines()
    file_ids, line_ids = collect_ignores(text)
    for f in raw or []:
        if not isinstance(f, dict) or f.get("rule_id") not in valid_rules:
            stats["invalid"] += 1
            continue
        f["file"] = rel
        f["severity"] = f.get("severity") if f.get("severity") in SEVERITY_ORDER else "medium"
        try:
            f["confidence"] = float(f.get("confidence", 0))
        except (TypeError, ValueError):
            f["confidence"] = 0.0
        if verify_evidence(f, lines) is None:
            stats["unverified"] += 1
            continue
        rid = f["rule_id"]
        if "all" in file_ids or rid in file_ids or rid in line_ids.get(f["line"], set()) \
                or "all" in line_ids.get(f["line"], set()):
            stats["suppressed"] += 1
            continue
        if f["confidence"] < min_conf:
            stats["low_confidence"] += 1
            continue
        f["fingerprint"] = fingerprint(f)
        out.append(f)
    return out


# ----------------------------------------------------------------------------
# scan
# ----------------------------------------------------------------------------

def diff_targets(project: Path, base: str, all_files: list, rmap: dict) -> list:
    for ref in ([base] if base else ["origin/main", "main", "master"]):
        proc = subprocess.run(["git", "diff", "--name-only", f"{ref}...HEAD"],
                              cwd=project, capture_output=True, text=True)
        if proc.returncode == 0:
            changed = {l.strip() for l in proc.stdout.splitlines() if l.strip().endswith(".dart")}
            if not changed:
                return []
            # one hop of reverse-import dependents
            dependents = set()
            for rel, info in rmap["files"].items():
                for imp in info["imports"]:
                    tail = imp.split("/")[-1]
                    if any(c.endswith(tail) for c in changed):
                        dependents.add(rel)
            targets = [f for f in all_files if f in changed or f in dependents]
            log(f"diff mode vs {ref}: {len(changed)} changed, {len(targets)} files to scan")
            return targets
    log("warning: git diff failed for all base refs — falling back to full scan")
    return all_files


def scan_one_file(client, model, system_text, project, rel, tier0_by_file):
    text = (project / rel).read_text(encoding="utf-8", errors="replace")
    notes = tier0_by_file.get(rel, [])
    lint = "\n".join(f"- L{d['line']} {d['code']}: {d['message']}" for d in notes[:20]) or "(none)"
    user = (f"FILE: {rel}\n\nAnalyzer already flagged (do not repeat):\n{lint}\n\n"
            f"== SOURCE (line-numbered; evidence must NOT include the number prefix) ==\n{numbered(text)}")
    reply = call_model(client, model, system_text, user)
    data = extract_json(reply)
    return rel, text, (data or {}).get("findings", []), data is None


def run_batch(client, model, system_text, project, targets, tier0_by_file):
    """Message Batches API: ~50% cheaper, minutes-to-hours latency."""
    requests = []
    texts = {}
    for rel in targets:
        text = (project / rel).read_text(encoding="utf-8", errors="replace")
        texts[rel] = text
        notes = tier0_by_file.get(rel, [])
        lint = "\n".join(f"- L{d['line']} {d['code']}: {d['message']}" for d in notes[:20]) or "(none)"
        user = (f"FILE: {rel}\n\nAnalyzer already flagged (do not repeat):\n{lint}\n\n"
                f"== SOURCE (line-numbered; evidence must NOT include the number prefix) ==\n{numbered(text)}")
        requests.append({
            "custom_id": hashlib.sha1(rel.encode()).hexdigest()[:24],
            "params": {"model": model, "max_tokens": MAX_TOKENS,
                       "system": system_blocks(system_text),
                       "messages": [{"role": "user", "content": user}]},
        })
    id_to_rel = {r["custom_id"]: rel for r, rel in zip(requests, targets)}
    batch = client.messages.batches.create(requests=requests)
    log(f"batch {batch.id} submitted ({len(requests)} requests); polling...")
    while True:
        time.sleep(30)
        batch = client.messages.batches.retrieve(batch.id)
        c = batch.request_counts
        log(f"  batch: {c.succeeded} ok / {c.errored} err / {c.processing} processing")
        if batch.processing_status == "ended":
            break
    results = {}
    for item in client.messages.batches.results(batch.id):
        rel = id_to_rel.get(item.custom_id)
        if rel is None:
            continue
        if item.result.type == "succeeded":
            reply = "".join(b.text for b in item.result.message.content if b.type == "text")
            data = extract_json(reply)
            results[rel] = ((data or {}).get("findings", []), data is None)
        else:
            log(f"  batch item failed for {rel}: {item.result.type}")
            results[rel] = ([], True)
    return results, texts


def cmd_scan(args):
    project = Path(args.path).resolve()
    cfg = load_config(project)
    excludes = DEFAULT_EXCLUDES + cfg.get("exclude", [])
    min_conf = args.min_confidence if args.min_confidence is not None \
        else cfg.get("min_confidence", DEFAULT_MIN_CONFIDENCE)
    model = args.model or cfg.get("model", DEFAULT_MODEL)
    reduce_model = args.reduce_model or cfg.get("reduce_model", DEFAULT_REDUCE_MODEL)
    packs = [p.strip() for p in (args.packs or ",".join(CODE_PACKS + [REDUCE_PACK])).split(",") if p.strip()]

    stack = detect_stack(project)
    log(f"stack: {', '.join(sorted(stack))}")
    files = dart_files(project, excludes)
    if not files:
        raise SystemExit("no dart files found under lib/ — is this a Flutter project?")
    rmap = build_repo_map(project, files)
    save_json(out_dir(project) / "repo_map.json", rmap)
    rsum = repo_map_summary(rmap)

    tier0 = run_tier0(project)
    tier0_by_file = {}
    for d in tier0:
        tier0_by_file.setdefault(d["file"], []).append(d)
    save_json(out_dir(project) / "tier0.json", tier0)

    targets = diff_targets(project, args.diff_base, files, rmap) if args.diff else files
    if args.max_files:
        targets = targets[:args.max_files]
    code_packs = [p for p in packs if p != REDUCE_PACK]
    pack_texts = [load_pack(p, stack) for p in code_packs]
    valid_rules = {rid for t in pack_texts for rid in pack_rule_ids(t)}
    system_text = build_map_prompt(pack_texts, stack, rsum)

    if args.dry_run:
        preview = out_dir(project) / "prompt_preview.txt"
        sample = targets[0] if targets else "(none)"
        preview.write_text(
            f"MODEL: {model}\nTARGETS ({len(targets)}):\n" + "\n".join(targets)
            + f"\n\n===== SYSTEM PROMPT ({len(system_text)} chars) =====\n{system_text}"
            + f"\n\n===== SAMPLE USER MESSAGE ({sample}) =====\n"
            + numbered((project / sample).read_text(encoding='utf-8', errors='replace'))[:2000],
            encoding="utf-8")
        log(f"dry-run: no API calls. Wrote {preview}")
        return

    client = get_client()
    stats = {"invalid": 0, "unverified": 0, "suppressed": 0, "low_confidence": 0, "parse_errors": 0}
    findings = []

    if targets and code_packs:
        if args.batch:
            results, texts = run_batch(client, model, system_text, project, targets, tier0_by_file)
            for rel in targets:
                raw, parse_err = results.get(rel, ([], True))
                stats["parse_errors"] += int(parse_err)
                findings += clean_findings(raw, rel, valid_rules, texts[rel], min_conf, stats)
        else:
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
                futs = [ex.submit(scan_one_file, client, model, system_text, project, rel, tier0_by_file)
                        for rel in targets]
                for i, fut in enumerate(concurrent.futures.as_completed(futs), 1):
                    rel, text, raw, parse_err = fut.result()
                    stats["parse_errors"] += int(parse_err)
                    findings += clean_findings(raw, rel, valid_rules, text, min_conf, stats)
                    log(f"[{i}/{len(targets)}] {rel}: {len(raw)} raw findings")

    if REDUCE_PACK in packs:
        log(f"reduce phase ({reduce_model})...")
        pack = load_pack(REDUCE_PACK, stack)
        condensed = "\n".join(
            f"- {f['rule_id']} {f['file']}:{f['line']} ({f['severity']}) {norm_ws(f['why'])[:140]}"
            for f in findings) or "(no per-file findings)"
        user = f"== REPOSITORY MAP ==\n{repo_map_summary(rmap, 20000)}\n\n== PER-FILE FINDINGS ==\n{condensed}"
        reply = call_model(client, reduce_model, REDUCE_CONTRACT + "\n" + pack, user)
        data = extract_json(reply)
        if data is None:
            stats["parse_errors"] += 1
        for f in (data or {}).get("findings", []):
            if not isinstance(f, dict) or f.get("rule_id") not in set(pack_rule_ids(pack)):
                stats["invalid"] += 1
                continue
            f.setdefault("file", "")
            f.setdefault("line", 0)
            f["severity"] = f.get("severity") if f.get("severity") in SEVERITY_ORDER else "medium"
            try:
                f["confidence"] = float(f.get("confidence", 0))
            except (TypeError, ValueError):
                f["confidence"] = 0.0
            if f["confidence"] < min_conf:
                stats["low_confidence"] += 1
                continue
            f["fingerprint"] = fingerprint(f)
            findings.append(f)

    baseline = set(load_json(out_dir(project) / "baseline.json", {"fingerprints": []})["fingerprints"])
    for f in findings:
        f["new"] = f["fingerprint"] not in baseline
    save_json(out_dir(project) / "findings.json",
              {"generated_at": datetime.now(timezone.utc).isoformat(), "model": model,
               "stack": sorted(stack), "scanned": targets, "stats": stats, "findings": findings})
    log(f"findings: {len(findings)} kept "
        f"({sum(f['new'] for f in findings)} new) | dropped: {stats}")
    write_reports(project)


# ----------------------------------------------------------------------------
# visual
# ----------------------------------------------------------------------------

MEDIA = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}


def cmd_visual(args):
    project = Path(args.path).resolve()
    shots_dir = Path(args.dir).resolve()
    imgs = sorted(p for p in shots_dir.rglob("*") if p.suffix.lower() in MEDIA)
    if not imgs:
        raise SystemExit(f"no images found under {shots_dir}")
    groups = {}
    for p in imgs:  # group variants of one screen: name__variant.png
        groups.setdefault(p.name.split("__")[0], []).append(p)
    stack = detect_stack(project)
    pack = load_pack(VISUAL_PACK, stack)
    valid_rules = set(pack_rule_ids(pack))
    system_text = VISUAL_CONTRACT + "\n" + pack
    model = args.model or load_config(project).get("visual_model", DEFAULT_MODEL)

    if args.dry_run:
        log(f"dry-run: {len(imgs)} screenshots in {len(groups)} screen groups: "
            + ", ".join(f"{k}({len(v)})" for k, v in groups.items()))
        return

    client = get_client()
    findings, min_conf = [], args.min_confidence or DEFAULT_MIN_CONFIDENCE
    for screen, paths in groups.items():
        for chunk_start in range(0, len(paths), 4):  # <=4 images per request
            chunk = paths[chunk_start:chunk_start + 4]
            content = [{"type": "text",
                        "text": f"Screen: {screen}. Variants: {', '.join(p.name for p in chunk)}"}]
            for p in chunk:
                content.append({"type": "image", "source": {
                    "type": "base64", "media_type": MEDIA[p.suffix.lower()],
                    "data": base64.b64encode(p.read_bytes()).decode()}})
            reply = call_model(client, model, system_text, content)
            data = extract_json(reply)
            for f in (data or {}).get("findings", []):
                if not isinstance(f, dict) or f.get("rule_id") not in valid_rules:
                    continue
                try:
                    f["confidence"] = float(f.get("confidence", 0))
                except (TypeError, ValueError):
                    f["confidence"] = 0.0
                if f["confidence"] < min_conf:
                    continue
                f["severity"] = f.get("severity") if f.get("severity") in SEVERITY_ORDER else "medium"
                f.setdefault("line", 0)
                f["evidence"] = ""
                f["fingerprint"] = fingerprint(f)
                findings.append(f)
        log(f"{screen}: done")
    baseline = set(load_json(out_dir(project) / "baseline.json", {"fingerprints": []})["fingerprints"])
    for f in findings:
        f["new"] = f["fingerprint"] not in baseline
    save_json(out_dir(project) / "findings_visual.json",
              {"generated_at": datetime.now(timezone.utc).isoformat(), "model": model,
               "findings": findings})
    log(f"visual findings: {len(findings)}")
    write_reports(project)


# ----------------------------------------------------------------------------
# baseline / report
# ----------------------------------------------------------------------------

def all_findings(project: Path) -> list:
    d = out_dir(project)
    return (load_json(d / "findings.json", {"findings": []})["findings"]
            + load_json(d / "findings_visual.json", {"findings": []})["findings"])


def cmd_baseline(args):
    project = Path(args.path).resolve()
    fps = sorted({f["fingerprint"] for f in all_findings(project)})
    save_json(out_dir(project) / "baseline.json",
              {"created_at": datetime.now(timezone.utc).isoformat(), "fingerprints": fps})
    log(f"baseline snapshot: {len(fps)} fingerprints")


def write_reports(project: Path, include_baselined=False):
    d = out_dir(project)
    meta = load_json(d / "findings.json", {})
    findings = all_findings(project)
    new = [f for f in findings if f.get("new", True)]
    shown = findings if include_baselined else new
    shown.sort(key=lambda f: (SEVERITY_ORDER.get(f["severity"], 3), -f.get("confidence", 0)))

    counts = {s: {"new": 0, "baseline": 0} for s in SEVERITY_ORDER}
    for f in findings:
        counts[f["severity"]]["new" if f.get("new", True) else "baseline"] += 1

    lines = [f"# Auditz report — {project.name}",
             f"_Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}"
             f" · model {meta.get('model', '?')} · stack: {', '.join(meta.get('stack', []))}_",
             "", "| Severity | New | Baseline |", "|---|---|---|"]
    for s in SEVERITY_ORDER:
        lines.append(f"| {s} | {counts[s]['new']} | {counts[s]['baseline']} |")
    if meta.get("stats"):
        st = meta["stats"]
        lines.append(f"\n_Dropped: {st.get('unverified', 0)} unverified evidence · "
                     f"{st.get('low_confidence', 0)} low confidence · {st.get('suppressed', 0)} suppressed · "
                     f"{st.get('invalid', 0)} invalid · {st.get('parse_errors', 0)} parse errors_")
    lines.append("")
    for f in shown:
        loc = f"`{f['file']}:{f['line']}`" if f.get("file") else "(cross-file)"
        lines.append(f"## [{f['severity'].upper()}] {f['rule_id']} — {loc}")
        lines.append(f"confidence {f.get('confidence', 0):.2f}"
                     + ("" if f.get("new", True) else " · _baseline_"))
        if f.get("related_files"):
            lines.append(f"related: {', '.join(f['related_files'])}")
        lines.append(f"\n{f.get('why', '')}\n")
        if f.get("evidence"):
            lines.append(f"```dart\n{f['evidence']}\n```")
        if f.get("fix"):
            lines.append(f"**Fix:**\n```dart\n{f['fix']}\n```")
        lines.append("")
    if not shown:
        lines.append("Không có finding mới. 🎉")
    (d / "report.md").write_text("\n".join(lines), encoding="utf-8")

    rules_used = sorted({f["rule_id"] for f in new})
    sarif = {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {"name": "auditz", "informationUri": "https://local",
                                "rules": [{"id": r} for r in rules_used]}},
            "results": [{
                "ruleId": f["rule_id"],
                "level": SARIF_LEVEL[f["severity"]],
                "message": {"text": f"{f.get('why', '')} — fix: {norm_ws(f.get('fix', ''))[:300]}"},
                "locations": [{"physicalLocation": {
                    "artifactLocation": {"uri": f.get("file") or "lib"},
                    "region": {"startLine": max(1, int(f.get("line") or 1))}}}],
            } for f in new],
        }],
    }
    save_json(d / "findings.sarif", sarif)
    log(f"wrote {d / 'report.md'} and {d / 'findings.sarif'}")


def cmd_report(args):
    write_reports(Path(args.path).resolve(), include_baselined=args.include_baselined)


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(prog="auditz", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("scan", help="audit dart files with AI rule packs")
    s.add_argument("--path", default=".", help="Flutter project root")
    s.add_argument("--packs", help=f"comma list (default: {','.join(CODE_PACKS + [REDUCE_PACK])})")
    s.add_argument("--diff", action="store_true", help="only changed files + their dependents")
    s.add_argument("--diff-base", help="git base ref for --diff (default: origin/main)")
    s.add_argument("--model", help=f"map-phase model (default {DEFAULT_MODEL})")
    s.add_argument("--reduce-model", help="reduce-phase model, e.g. claude-fable-5")
    s.add_argument("--min-confidence", type=float)
    s.add_argument("--batch", action="store_true", help="use Message Batches API (~50%% cheaper, slower)")
    s.add_argument("--workers", type=int, default=4)
    s.add_argument("--max-files", type=int)
    s.add_argument("--dry-run", action="store_true", help="build prompts only, no API calls")
    s.set_defaults(fn=cmd_scan)

    v = sub.add_parser("visual", help="audit UI screenshots with a vision model")
    v.add_argument("dir", help="directory of screenshots (name__variant.png groups variants)")
    v.add_argument("--path", default=".")
    v.add_argument("--model")
    v.add_argument("--min-confidence", type=float)
    v.add_argument("--dry-run", action="store_true")
    v.set_defaults(fn=cmd_visual)

    b = sub.add_parser("baseline", help="snapshot current findings as accepted baseline")
    b.add_argument("--path", default=".")
    b.set_defaults(fn=cmd_baseline)

    r = sub.add_parser("report", help="regenerate report.md + findings.sarif from disk")
    r.add_argument("--path", default=".")
    r.add_argument("--include-baselined", action="store_true")
    r.set_defaults(fn=cmd_report)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()

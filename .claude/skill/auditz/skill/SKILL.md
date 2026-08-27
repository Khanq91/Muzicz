---
name: auditz
description: AI-assisted Flutter codebase audit. Use when asked to audit, review, or find bugs/UX issues in a Flutter project. Applies the Auditz rule packs and writes findings compatible with the auditz CLI (baseline + report).
---

# Auditz (Claude Code mode)

Run the Auditz rule packs directly inside Claude Code — no API key needed, uses the active subscription. Produces the same `.auditz/findings.json` the CLI consumes, so `baseline` and `report` still work.

## Steps

1. Detect stack: read `pubspec.yaml`; note which of riverpod / bloc / provider / go_router / hive / freezed / liquid_glass are present. If Hive is present and no `TypeAdapter` exists in `lib/`, the `hive_json` tag applies.
2. Read the rule packs from `<auditz repo>/rulepacks/`: `correctness.md`, `performance.md`, `flow_ux.md`. Skip any rule whose `requires:` tags aren't all in the detected stack (`core` and `flutter` always apply).
3. Optionally run `dart analyze` first; do not report anything it already reports.
4. Audit files under `lib/` (skip `*.g.dart`, `*.freezed.dart`, generated dirs). For each finding record:
   `file, line, rule_id, severity(high|medium|low), confidence(0..1), evidence(verbatim 1-3 lines from the file), why(Vietnamese), fix(Dart code)`.
   Respect `// audit:ignore <rule_id>` (line) and `// audit:ignore-file <rule_id|all>` comments.
5. Cross-file pass: apply `architecture.md` against the overall structure (provider graph, routes, folder layout). `file` may be empty; add `related_files`.
6. Compute `fingerprint = sha1(rule_id|file|normalized_evidence)[:16]` per finding, set `"new": true`, and write:
   `.auditz/findings.json` = `{"generated_at": "<iso>", "model": "claude-code", "stack": [...], "stats": {}, "findings": [...]}`.
7. Finish with `python <auditz repo>/auditz.py report --path .` to produce `report.md` + `findings.sarif`, and tell the user the top findings by severity.

Only report violations of listed rules with real evidence. When unsure, lower confidence instead of inventing certainty.

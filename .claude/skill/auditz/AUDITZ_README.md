# Auditz

AI-assisted audit pipeline cho mọi project Flutter. 5 rule pack, 1 pipeline:

| Pack | Chạy ở | Bắt gì |
|---|---|---|
| `correctness` | scan (per-file) | context sau await, leak controller, ref.watch sai chỗ, Hive JSON không version, catch nuốt lỗi... |
| `performance` | scan (per-file) | rebuild thừa, thiếu `.select()`, saveLayer/blur chồng, shouldRepaint=true, work nặng trong build... |
| `flow_ux` | scan (per-file) | error/empty/loading state thiếu, back stack deep link, form ergonomics, double-submit, i18n debt... |
| `architecture` | scan (reduce, cross-file) | provider cycle, logic trong widget, layering, god file, dead screen... |
| `visual` | `visual` (ảnh) | overflow ở textScale 1.3, contrast dark mode, hierarchy, spacing, tap target... |

**Generalization:** tool đọc `pubspec.yaml` → bật đúng rule cho stack của từng project (rule có `requires: riverpod` chỉ chạy khi project dùng Riverpod, v.v.). Không hardcode cho project nào.

## Cài đặt

```bash
pip install anthropic
export ANTHROPIC_API_KEY=sk-ant-...
```

## Dùng

```bash
# Lần đầu trên một project: full scan rồi chốt baseline
python auditz.py scan --path /path/to/project
python auditz.py baseline --path /path/to/project

# Hằng ngày: chỉ file thay đổi + file phụ thuộc, chỉ báo finding MỚI
python auditz.py scan --path . --diff

# Full scan rẻ (Batch API ~50% giá, chờ vài phút–vài giờ)
python auditz.py scan --path . --batch

# Reduce phase bằng model mạnh nhất
python auditz.py scan --path . --reduce-model claude-fable-5

# Xem prompt trước khi đốt token
python auditz.py scan --path . --dry-run

# Visual audit: sinh goldens rồi đưa vào vision model
#   copy templates/auditz_screens_template.dart -> test/auditz_screens_test.dart, khai báo screens
flutter test --update-goldens test/auditz_screens_test.dart
python auditz.py visual test/goldens/auditz --path .
```

Output nằm trong `.auditz/`: `report.md`, `findings.json`, `findings.sarif`, `repo_map.json`, `baseline.json`.

## Chống noise (đã tích hợp sẵn)

- **Evidence verification** — finding nào mà đoạn `evidence` không tồn tại verbatim trong file thì bị drop. Diệt hallucination.
- **Baseline** — sau lần chốt `baseline`, các lần scan sau chỉ báo finding *mới*. Fingerprint theo `rule|file|evidence` nên không vỡ khi code dịch dòng.
- **Suppress inline** — `// audit:ignore rule_id` (dòng đó hoặc dòng dưới), `// audit:ignore-file rule_id` hoặc `all`.
- **Confidence filter** — mặc định bỏ finding < 0.7 (`--min-confidence`).
- **Tier 0** — `dart analyze` chạy trước, kết quả đưa vào prompt để model không lặp lại thứ linter đã bắt.

## Config per-project (tùy chọn): `auditz.json` ở root

```json
{
  "exclude": ["lib/legacy/**"],
  "min_confidence": 0.75,
  "model": "claude-sonnet-4-6",
  "reduce_model": "claude-fable-5"
}
```

## CI (GitHub Actions)

```yaml
- run: pip install anthropic
- run: python tools/auditz/auditz.py scan --path . --diff --diff-base origin/${{ github.base_ref }}
  env: { ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }} }
- uses: github/codeql-action/upload-sarif@v3
  with: { sarif_file: .auditz/findings.sarif }
```

SARIF upload → finding hiện thẳng trên tab Security / PR annotations.

## Chạy bằng Claude Code (Max plan, không tốn API)

Copy `skill/` vào skills của Claude Code. Trong repo Flutter, yêu cầu "audit repo này bằng auditz" — nó áp rule packs, ghi `.auditz/findings.json` đúng schema, rồi gọi `auditz.py report`. Baseline/report dùng chung với CLI.

## Chi phí

- Map phase mặc định `claude-sonnet-4-6`; system prompt (contract + rule packs + repo map) được prompt-cache — các file sau lần đầu chỉ trả ~10% giá phần đó.
- `--batch` giảm thêm 50% cho full scan không cần realtime.
- Reduce phase chỉ 1 call — đáng dùng `claude-fable-5`.

## Giới hạn v1

- Repo map dùng regex, không phải AST đầy đủ (đủ cho provider/route/import graph; muốn chính xác tuyệt đối thì thay bằng script Dart `analyzer` sau).
- `visual` cần goldens deterministic — screen gọi network thật phải mock trong template.

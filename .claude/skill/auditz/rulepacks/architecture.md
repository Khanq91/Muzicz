# Pack: architecture — cross-file issues (reduce phase; input = repo map + per-file findings)

### rule_id: provider_cycle
requires: riverpod
Circular dependencies in the provider graph (A watches B watches A, directly or transitively). Name the exact cycle from the map.

### rule_id: logic_in_presentation
requires: core
Business rules (validation, pricing, game rules, data transforms) living inside widget files instead of a controller/service/notifier layer. Use per-file findings + file names/watch patterns as signals; name the files and what should move where.

### rule_id: layering_violation
requires: core
Presentation importing data-layer internals directly (widgets importing dio/http clients, DB boxes, DTOs), skipping the repository/controller layer the project otherwise uses. Judge against the project's own dominant pattern, not an imposed ideal.

### rule_id: duplicate_logic
requires: core
The same non-trivial logic implemented in multiple files (e.g., two date formatters, two versions of the same mapper, copy-pasted validators). Name both locations and propose the single home.

### rule_id: route_screen_orphan
requires: go_router
Screen widgets that exist in the map but are reachable from no declared route and no navigation call — dead screens; or routes pointing at screens with mismatched naming suggesting a stale wiring.

### rule_id: state_pattern_mix
requires: core
Multiple state-management patterns coexisting without a boundary (e.g., Riverpod + setState-heavy screens + a stray ChangeNotifier), increasing onboarding cost. Only flag when the mix is clearly accidental, not a deliberate layered choice.

### rule_id: god_file
requires: core
Files that are extreme LOC outliers versus the rest of the repo AND accumulate many per-file findings — the hotspots to split first. Use the map's loc numbers; name concrete extraction seams.

### rule_id: feature_structure_drift
requires: core
Feature folders that deviate from the project's dominant structure (some features with data/domain/ui split, others dumping everything flat), making navigation unpredictable. Describe the dominant convention and the outliers.

### rule_id: singleton_state_leak
requires: core
Global mutable singletons / top-level mutable variables holding user or session state outside the state-management system, invisible to rebuilds and to logout/reset flows.

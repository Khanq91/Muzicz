# Library test fonts

These font fixtures are checked into the repository so Library widget tests and
optional screenshot previews work offline, including on clean CI runners.
Tests must not read fonts from `FLUTTER_ROOT/bin/cache`: the contents of that cache
depend on the platform and which Flutter artifacts have been downloaded.

The files were copied without modification from the Flutter 3.44.5 SDK's
`bin/cache/artifacts/material_fonts` directory:

- `materialicons-regular.otf`: Material Icons by Google; see
  `materialicons_license.txt` (CC BY 4.0).
- `roboto-regular.ttf`: Roboto by Google; see `roboto_license.txt` (Apache 2.0).

The fixture maps Outfit font requests to Roboto for deterministic offline tests.
Preview images therefore verify layout, not the production Outfit typeface.
These files are not listed in `pubspec.yaml` and are not bundled into the app.

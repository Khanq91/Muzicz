import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter engine setup does not initialize the Python runtime', () {
    final source =
        File(
          'android/app/src/main/kotlin/com/muziczz/muziczz/MainActivity.kt',
        ).readAsStringSync();
    final configureBody = _functionBody(source, 'configureFlutterEngine');

    expect(configureBody, isNot(contains('Python.start')));
    expect(configureBody, isNot(contains('Python.getInstance')));
    expect(configureBody, isNot(contains('getModule("ytdlp_bridge")')));
    expect(
      source,
      contains('by lazy(LazyThreadSafetyMode.SYNCHRONIZED)'),
      reason:
          'The first concurrent downloader calls must share one initializer.',
    );
  });
}

String _functionBody(String source, String functionName) {
  final declaration = source.indexOf("fun $functionName(");
  expect(declaration, isNonNegative, reason: '$functionName must exist');

  final openingBrace = source.indexOf('{', declaration);
  expect(openingBrace, isNonNegative, reason: '$functionName must have a body');

  var depth = 0;
  for (var index = openingBrace; index < source.length; index++) {
    switch (source[index]) {
      case '{':
        depth++;
      case '}':
        depth--;
        if (depth == 0) {
          return source.substring(openingBrace + 1, index);
        }
    }
  }

  fail('Could not find the end of $functionName');
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muziczz/services/lyrics_ai_service.dart';
import 'package:muziczz/services/lyrics_service.dart';
import 'package:muziczz/services/lyrics_parser.dart';

void main() {
  const config = LyricsAiConfig(
    provider: LyricsAiProvider.compatible,
    baseUrl: 'https://example.com/v1',
    apiKey: 'secret',
    model: 'test',
  );
  final original = LyricsResult.parse(
    '[00:01]<00:01>Hello <00:02>world\n[00:04]\n[00:05]Again',
    source: 'Import',
  );
  test(
    'translation preserves timings, blank lines and survives cache export',
    () async {
      final service = LyricsAiService(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/chat/completions');
          expect(request.headers['Authorization'], 'Bearer secret');
          expect(request.url.toString(), isNot(contains('secret')));
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {
                    'content': jsonEncode([
                      {'id': 0, 'translation': 'Xin chào'},
                      {'id': 1, 'translation': ''},
                      {'id': 2, 'translation': 'Lần nữa'},
                    ]),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await service.translate(config, original);
      final restored = LyricsParser.parse(result.raw);
      expect(restored.length, 3);
      expect(restored.first.words.last.start.inSeconds, 2);
      expect(restored.first.translation, 'Xin chào');
      expect(restored.last.time!.inSeconds, 5);
      expect(original.lines.first.translation, isNull);
    },
  );
  test(
    'incomplete response rejects translation without changing source',
    () async {
      final service = LyricsAiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '[]'},
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.translate(config, original),
        throwsA(isA<LyricsAiException>()),
      );
      expect(original.lines.first.translation, isNull);
    },
  );
  test(
    'Gemini authentication uses header and model response is parsed',
    () async {
      final service = LyricsAiService(
        client: MockClient((request) async {
          expect(request.headers['x-goog-api-key'], 'secret');
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/example',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/embedding',
                  'supportedGenerationMethods': ['embedContent'],
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect(await service.models(const LyricsAiConfig(apiKey: 'secret')), [
        'example',
      ]);
    },
  );
  test(
    'errors never echo response credentials; insecure endpoints rejected',
    () async {
      final service = LyricsAiService(
        client: MockClient((_) async => http.Response('secret', 401)),
      );
      addTearDown(service.dispose);
      try {
        await service.translate(config, original);
        fail('Expected authentication failure');
      } on LyricsAiException catch (e) {
        expect(e.message, isNot(contains('secret')));
      }
      expect(
        () =>
            const LyricsAiConfig(
              baseUrl: 'http://example.com',
              apiKey: 'x',
              model: 'x',
            ).validate(),
        throwsFormatException,
      );
    },
  );
}

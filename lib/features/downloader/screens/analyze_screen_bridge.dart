// lib/features/downloader/screens/analyze_screen_bridge.dart
//
// Bridge này bọc ProviderScope (Riverpod) quanh AnalyzeScreen của ytdlp.
// Muzicz dùng Provider (ChangeNotifier), ytdlp dùng Riverpod — cả hai
// cùng tồn tại tốt. ProviderScope chỉ cần bọc đúng chỗ dùng Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_router.dart';

class AnalyzeScreenBridge extends StatelessWidget {
  const AnalyzeScreenBridge({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Dùng lại theme của Muzicz (đã được set ở root) thông qua
        // Theme.of(context) — tuy nhiên vì đây là MaterialApp mới
        // ta copy lại darkTheme để giữ consistent
        theme: Theme.of(context),
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.analyze,
      ),
    );
  }
}
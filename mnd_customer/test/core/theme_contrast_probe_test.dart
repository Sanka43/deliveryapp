import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/theme/app_theme.dart';

void _writeDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, Object?> data,
  String runId = 'post-fix',
}) {
  final File logFile = File('debug-8dfbba.log');
  final Map<String, Object?> payload = <String, Object?>{
    'sessionId': '8dfbba',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  logFile.writeAsStringSync(
    '${jsonEncode(payload)}\n',
    mode: FileMode.append,
  );
}

void main() {
  testWidgets('ThemeMode.light stays readable even when OS prefers dark',
      (WidgetTester tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(() {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    late ThemeData capturedTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: Builder(
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            capturedTheme = theme;
            final Color scaffoldBg = theme.scaffoldBackgroundColor;
            final Color hardcodedPrimary = AppColors.textPrimary;
            final Color? bodyColor = theme.textTheme.bodyLarge?.color;
            final Color whiteScaffold = Colors.white;

            final double storeContrastGap =
                (scaffoldBg.computeLuminance() - hardcodedPrimary.computeLuminance())
                    .abs();
            final double profileContrastGap =
                (whiteScaffold.computeLuminance() -
                        (bodyColor ?? theme.colorScheme.onSurface)
                            .computeLuminance())
                    .abs();

            _writeDebugLog(
              hypothesisId: 'A',
              location: 'theme_contrast_probe_test.dart:store',
              message: 'Post-fix store contrast under OS dark + ThemeMode.light',
              data: <String, Object?>{
                'brightness': theme.brightness.name,
                'scaffoldBg': scaffoldBg.toARGB32().toRadixString(16),
                'hardcodedTextPrimary':
                    hardcodedPrimary.toARGB32().toRadixString(16),
                'scaffoldLuminance': scaffoldBg.computeLuminance(),
                'textPrimaryLuminance': hardcodedPrimary.computeLuminance(),
                'lowContrastLikely': storeContrastGap < 0.2,
                'readableOnScaffold': theme.brightness == Brightness.light,
              },
            );

            _writeDebugLog(
              hypothesisId: 'B',
              location: 'theme_contrast_probe_test.dart:profile',
              message: 'Post-fix profile text under OS dark + ThemeMode.light',
              data: <String, Object?>{
                'brightness': theme.brightness.name,
                'forcedScaffold': whiteScaffold.toARGB32().toRadixString(16),
                'bodyLargeColor': bodyColor?.toARGB32().toRadixString(16),
                'onSurface':
                    theme.colorScheme.onSurface.toARGB32().toRadixString(16),
                'bodyLuminance':
                    (bodyColor ?? theme.colorScheme.onSurface).computeLuminance(),
                'whiteLuminance': whiteScaffold.computeLuminance(),
                'typedTextInvisibleLikely': profileContrastGap < 0.25,
                'typedTextVisibleLikely': theme.brightness == Brightness.light &&
                    (bodyColor ?? theme.colorScheme.onSurface)
                            .computeLuminance() <
                        0.4,
              },
            );

            _writeDebugLog(
              hypothesisId: 'C',
              location: 'theme_contrast_probe_test.dart:inputTheme',
              message: 'Post-fix light theme inputDecoration',
              data: <String, Object?>{
                'brightness': theme.brightness.name,
                'hasFilled': theme.inputDecorationTheme.filled,
                'fillColor': theme.inputDecorationTheme.fillColor
                    ?.toARGB32()
                    .toRadixString(16),
                'lightInputThemeActive':
                    theme.brightness == Brightness.light &&
                        theme.inputDecorationTheme.fillColor != null,
              },
            );

            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(capturedTheme.brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });
}

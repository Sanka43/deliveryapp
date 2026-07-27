import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const String passwordHint = '••••••••';
  const String stockLabel = 'Stock · 5';

  Future<void> log(
    String hypothesisId,
    String message,
    Map<String, Object?> data,
  ) async {
    final Map<String, Object?> payload = <String, Object?>{
      'sessionId': '5d2b4e',
      'runId': 'post-fix',
      'hypothesisId': hypothesisId,
      'location': 'runtime_mojibake_probe.dart',
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final String line = jsonEncode(payload);
    await File(r'e:\mnd\debug-5d2b4e.log').writeAsString(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
    try {
      final HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 800);
      final HttpClientRequest req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:7437/ingest/a1750396-3fb6-4d48-9288-0e72095d66e6',
        ),
      );
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('X-Debug-Session-Id', '5d2b4e');
      req.add(utf8.encode(line));
      await req.close();
      client.close(force: true);
    } catch (_) {}
  }

  // Re-read actual source constants after fix
  final String login = await File(
    r'e:\mnd\mnd_shop\lib\features\auth\presentation\pages\shop_login_page.dart',
  ).readAsString();
  final String catalog = await File(
    r'e:\mnd\mnd_shop\lib\features\products\presentation\pages\vendor_catalog_hub_page.dart',
  ).readAsString();

  final RegExp hintRe = RegExp(
    r"const String passwordHint =\s*'([^']*)';",
  );
  final String? sourceHint = hintRe.firstMatch(login)?.group(1);
  final bool stockOk = catalog.contains("en: 'Stock · \${widget.stockQty}'");
  final bool sinhalaOk = login.contains("si: 'මුරපදය'");

  int gamma = 0;
  int box = 0;
  int sinhalaCorrupt = 0;
  await for (final FileSystemEntity e
      in Directory(r'e:\mnd\mnd_shop\lib').list(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final String t = await e.readAsString();
    gamma += 'ΓÇó'.allMatches(t).length;
    box += '┬╖'.allMatches(t).length;
    sinhalaCorrupt += 'α╢'.allMatches(t).length;
  }

  await log('A', 'post-fix password hint from source', <String, Object?>{
    'sourceHint': sourceHint,
    'hintCodeUnits': sourceHint?.codeUnits,
    'hintIsCorrectBullets':
        sourceHint == passwordHint &&
        (sourceHint?.codeUnits.every((int u) => u == 0x2022) ?? false),
    'hintLooksLikeMojibake': sourceHint?.contains('ΓÇó') ?? false,
  });

  await log('B', 'post-fix stock label from source', <String, Object?>{
    'expectedSample': stockLabel,
    'stockLabelFixedInSource': stockOk,
    'labelHasBoxDrawingMojibake': catalog.contains('┬╖'),
  });

  await log('C', 'post-fix mojibake marker scan', <String, Object?>{
    'countGammaCAco': gamma,
    'countBoxMiddot': box,
    'countSinhalaMojibakeAlpha': sinhalaCorrupt,
    'sinhalaPasswordLabelRestored': sinhalaOk,
  });

  stdout.writeln('post-fix logs written');
}

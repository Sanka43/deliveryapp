import 'dart:js_interop';

@JS('__mndIsStandalone')
external bool _mndIsStandalone();

@JS('__mndCanPromptInstall')
external bool _mndCanPromptInstall();

@JS('__mndPromptInstall')
external JSPromise<_InstallChoice> _mndPromptInstall();

extension type _InstallChoice._(JSObject _) implements JSObject {
  external String get outcome;
}

bool isPwaStandalone() {
  try {
    return _mndIsStandalone();
  } catch (_) {
    return false;
  }
}

bool canPromptPwaInstall() {
  try {
    return _mndCanPromptInstall();
  } catch (_) {
    return false;
  }
}

/// Returns `true` when the user accepted the native install prompt.
Future<bool> promptPwaInstall() async {
  try {
    final _InstallChoice choice = await _mndPromptInstall().toDart;
    return choice.outcome == 'accepted';
  } catch (_) {
    return false;
  }
}

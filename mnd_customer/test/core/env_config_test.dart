import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';

void main() {
  test('default env resolves to dev outside release dart-defines', () {
    // Tests run in debug; empty APP_ENV → dev.
    expect(EnvConfig.current, AppEnvironment.dev);
    expect(EnvConfig.isDev, isTrue);
    expect(EnvConfig.appTitle, contains('Dev'));
    expect(EnvConfig.includeAdminUi, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';

void main() {
  test('default env is dev', () {
    expect(EnvConfig.current, AppEnvironment.dev);
    expect(EnvConfig.isDev, isTrue);
    expect(EnvConfig.appTitle, contains('Dev'));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kOnboardingCompleteKey = 'mnd_rider_onboarding_complete';

final AsyncNotifierProvider<RiderOnboardingNotifier, bool> riderOnboardingCompleteProvider =
    AsyncNotifierProvider<RiderOnboardingNotifier, bool>(RiderOnboardingNotifier.new);

class RiderOnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingCompleteKey) ?? false;
  }

  Future<void> markComplete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
    state = const AsyncData<bool>(true);
  }
}

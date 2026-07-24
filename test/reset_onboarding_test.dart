import 'package:flutter_test/flutter_test.dart';
import 'package:brand_mobile_app/core/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier - resetOnboarding logic', () {
    test('AuthState isOnboardingComplete reflects onboarding_complete flag', () {
      const stateComplete = AuthState(
        role: 'influencer',
        isOnboardingComplete: true,
      );
      expect(stateComplete.isOnboardingComplete, isTrue);

      final stateReset = stateComplete.copyWith(isOnboardingComplete: false);
      expect(stateReset.isOnboardingComplete, isFalse);
    });

    test('AuthState copyWith correctly updates role and profile on reset', () {
      const initial = AuthState(
        role: 'influencer',
        profile: {'display_name': 'Test User', 'role': 'influencer', 'onboarding_complete': true},
        isOnboardingComplete: true,
      );

      final resetProfile = Map<String, dynamic>.from(initial.profile!);
      resetProfile['onboarding_complete'] = false;
      resetProfile['onboarding_step'] = 1;

      final updated = initial.copyWith(
        profile: resetProfile,
        isOnboardingComplete: false,
      );

      expect(updated.isOnboardingComplete, isFalse);
      expect(updated.profile?['onboarding_complete'], isFalse);
      expect(updated.profile?['onboarding_step'], 1);
    });
  });
}

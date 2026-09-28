import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/hive_service.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  // Firebase stays dormant without native config; never blocks startup.
  await AuthService.init();
  // Auto-post due recurring entries (bills, subscriptions, salary) so the
  // user's books stay current even if they never open the Recurring tab.
  // A recurring item is "due" when its day-of-month has passed and it has
  // not been posted yet this month.
  try {
    final now = DateTime.now();
    for (final r in HiveService.dueRecurrings(now)) {
      await HiveService.postRecurring(r, on: now);
      debugPrint('Hisab auto-posted recurring: ${r.title}');
    }
  } catch (e) {
    debugPrint('Hisab recurring auto-post failed: $e');
  }
  runApp(const HisabApp());
}

class HisabApp extends StatelessWidget {
  const HisabApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds live when the theme mode changes in Settings.
    return ValueListenableBuilder<Box>(
      valueListenable: HiveService.settings.listenable(),
      builder: (context, _, __) => MaterialApp(
        title: 'Hisab',
        theme: buildLightTheme(),
        darkTheme: buildTheme(),
        themeMode: themeModeFromSettings(),
        debugShowCheckedModeBanner: false,
        home: const RootGate(),
      ),
    );
  }
}

/// Decides onboarding -> PIN setup -> lock -> main shell.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: HiveService.settings.listenable(),
      builder: (context, box, _) {
        final onboarded = box.get('onboardingDone') == true;
        if (!onboarded) {
          return OnboardingScreen(
            onDone: () => box.put('onboardingDone', true),
          );
        }
        final hash = box.get('pinHash') as String?;
        if (hash == null || hash.isEmpty) {
          return const PinSetupScreen();
        }
        if (!_unlocked) {
          return LockScreen(onUnlock: () {
            setState(() => _unlocked = true);
            debugPrint('Hisab unlocked');
          });
        }
        return const MainShell();
      },
    );
  }
}

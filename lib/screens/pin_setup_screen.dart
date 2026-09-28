import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';
import 'lock_screen.dart' show hashPin;

/// First-launch PIN creation: enter + confirm.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String? _first;
  bool _error = false;

  void _onKey(String key) {
    if (key == 'back') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = false;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _step);
    }
  }

  Future<void> _step() async {
    if (!mounted) return;
    if (_first == null) {
      setState(() {
        _first = _pin;
        _pin = '';
      });
    } else {
      if (_pin == _first) {
        await HiveService.setPinHash(hashPin(_pin));
        // RootGate listens to the settings box and will move on.
      } else {
        setState(() {
          _error = true;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const GlassCard(
                  radius: 36,
                  padding: EdgeInsets.all(20),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Secure your Hisab',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _first == null
                      ? 'Choose a 4-digit PIN'
                      : 'Enter it again to confirm',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (_error
                                ? AppColors.danger
                                : AppColors.gold)
                            : Colors.white.withOpacity(0.12),
                      ),
                    );
                  }),
                ),
                if (_error)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'PINs did not match — try again',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 36),
                _numpad(),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numpad() {
    const keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '', '0', 'back',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final k = keys[i];
          if (k.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _onKey(k),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
                border:
                    Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Center(
                child: k == 'back'
                    ? const Icon(Icons.backspace_outlined,
                        color: AppColors.textSecondary, size: 26)
                    : Text(
                        k,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

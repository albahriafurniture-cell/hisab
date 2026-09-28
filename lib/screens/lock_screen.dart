import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;

  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;

  void _onKey(String key) {
    if (key == 'back') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = false;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 120), _verify);
    }
  }

  void _verify() {
    if (!mounted) return;
    if (hashPin(_pin) == HiveService.pinHash) {
      widget.onUnlock();
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
          'This erases ALL accounts, transactions, budgets and settings '
          'on this device, then lets you set a new PIN. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Erase all data'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.resetAll();
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
                GlassCard(
                  radius: 36,
                  padding: const EdgeInsets.all(20),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 40,
                    color: AppColors.emerald,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hisab',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your PIN',
                  style: TextStyle(
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
                                : AppColors.emerald)
                            : Colors.white.withOpacity(0.12),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color: (_error
                                          ? AppColors.danger
                                          : AppColors.emerald)
                                      .withOpacity(0.5),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
                if (_error)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Wrong PIN — try again',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 36),
                _numpad(),
                const Spacer(),
                TextButton(
                  onPressed: _confirmReset,
                  child: const Text(
                    'Forgot PIN? Reset all data',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
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
          return _keyButton(
            k == 'back'
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
            () => _onKey(k),
          );
        },
      ),
    );
  }

  Widget _keyButton(Widget label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Center(child: label),
      ),
    );
  }
}

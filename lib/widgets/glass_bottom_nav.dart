import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Floating glass bottom nav with 4 tabs and a glowing center FAB.
/// Bar, icons and labels adapt to the current brightness.
class GlassBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const GlassBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onAdd,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.receipt_long_rounded, 'Activity'),
    (Icons.bar_chart_rounded, 'Reports'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 92 + bottomPad,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // glass bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 14 + bottomPad,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0B1220).withOpacity(0.72)
                        : Colors.white.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : const Color(0xFF0F172A).withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      _navButton(context, 0),
                      _navButton(context, 1),
                      const Spacer(),
                      _navButton(context, 2),
                      _navButton(context, 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // glowing FAB
          Positioned(
            bottom: 34 + bottomPad,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.5),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(BuildContext context, int i) {
    final active = index == i;
    final data = _items[i];
    final inactiveColor = context.tTextSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.emerald.withOpacity(0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.$1,
                color: active ? AppColors.emerald : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.$2,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.emerald : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

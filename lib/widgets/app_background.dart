import 'package:flutter/material.dart';

import '../theme.dart';

/// Gradient background with soft radial glow blobs — brightness-aware.
/// Dark: near-black navy/purple. Light: soft light gradient with subtle
/// emerald/violet glows at low opacity.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.bgTop, AppColors.bgBottom]
              : [const Color(0xFFE8EEF7), const Color(0xFFF8FAFC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _blob(AppColors.emerald, 300, isDark),
          ),
          Positioned(
            bottom: -100,
            right: -70,
            child: _blob(AppColors.violet, 320, isDark),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.42,
            left: MediaQuery.of(context).size.width * 0.55,
            child: _blob(AppColors.gold, 220, isDark),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size, bool isDark) {
    // Glows need a touch more opacity on light backgrounds to stay visible.
    final peak = isDark ? 0.10 : 0.16;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(peak),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

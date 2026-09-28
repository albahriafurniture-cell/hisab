import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';

/// Animated 4-page onboarding flow for the Hisab personal finance app.
///
/// Rendered on a transparent [Scaffold] — the parent shell provides the
/// [AppBackground], so this widget intentionally adds no background of its own.
///
/// Pure Dart only: no plugins, no platform channels.
///
/// Dependencies (nothing else):
/// - `flutter/material`
/// - `../theme.dart` — [AppColors] plus the `ThemeCtx` extension contract
///   (`context.tTextPrimary` / `context.tTextSecondary` / `context.tTextMuted`)
/// - `../widgets/glass_card.dart` — [GlassCard]
class OnboardingScreen extends StatefulWidget {
  /// Called when the user finishes (last page "Get Started") or taps "Skip".
  final VoidCallback onDone;

  const OnboardingScreen({required this.onDone, super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Static content for one onboarding page.
class _OnboardingPageData {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final List<_StatChipData> chips;

  const _OnboardingPageData({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.chips,
  });
}

/// One small floating glass chip shown under a page's subtitle.
class _StatChipData {
  final IconData icon;
  final String label;

  const _StatChipData(this.icon, this.label);
}

/// The four feature-intro pages, in order.
const List<_OnboardingPageData> _pages = [
  _OnboardingPageData(
    icon: Icons.account_balance_wallet_rounded,
    accent: AppColors.emerald,
    title: 'Know every rupee',
    subtitle: 'Track income & expenses across cash, bank and wallets — all in one place.',
    chips: [
      _StatChipData(Icons.trending_up_rounded, 'Income vs spend'),
      _StatChipData(Icons.account_balance_rounded, 'Cash · Bank · Wallet'),
    ],
  ),
  _OnboardingPageData(
    icon: Icons.pie_chart_rounded,
    accent: AppColors.violet,
    title: 'Budgets that keep you honest',
    subtitle: 'Set monthly limits per category and get smart alerts before you overshoot.',
    chips: [
      _StatChipData(Icons.donut_large_rounded, 'Groceries · 68% used'),
      _StatChipData(Icons.notifications_active_rounded, 'Alert at 80%'),
    ],
  ),
  _OnboardingPageData(
    icon: Icons.track_changes_rounded,
    accent: AppColors.gold,
    title: 'Goals & reports',
    subtitle: 'Hit savings goals, read your money in charts, and export PDF or CSV reports.',
    chips: [
      _StatChipData(Icons.flag_rounded, 'Goal 75% there'),
      _StatChipData(Icons.picture_as_pdf_rounded, 'PDF · CSV exports'),
    ],
  ),
  _OnboardingPageData(
    icon: Icons.lock_rounded,
    accent: AppColors.cyan,
    title: 'Private by design',
    subtitle: 'PIN lock, offline-first. Your data stays on your device — never in the cloud.',
    chips: [
      _StatChipData(Icons.pin_rounded, 'PIN protected'),
      _StatChipData(Icons.cloud_off_rounded, 'Offline first'),
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _nextPressed = false;

  /// Gentle floating motion for the icon orbs (repeats, reverses).
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final Animation<double> _float = Tween<double>(begin: -9, end: 9)
      .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

  @override
  void dispose() {
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pages[_page].accent;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: brand mark + Skip ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    child: Text(
                      '₨',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                        shadows: [
                          Shadow(
                            color: AppColors.emerald.withOpacity(0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: context.tTextMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ──────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) =>
                    _OnboardingPageBody(data: _pages[i], float: _float),
              ),
            ),

            // ── Animated indicators ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? accent
                        : Colors.white.withOpacity(0.18),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: accent.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Bottom bar: Skip + Next / Get Started ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: context.tTextMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _nextPressed = true),
                    onTapUp: (_) => setState(() => _nextPressed = false),
                    onTapCancel: () => setState(() => _nextPressed = false),
                    onTap: _next,
                    child: AnimatedScale(
                      scale: _nextPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: _isLast
                          ? _getStartedButton(context, accent)
                          : _nextButton(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glass "Next" button with a forward arrow.
  Widget _nextButton(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Next',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.tTextPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: context.tTextPrimary,
          ),
        ],
      ),
    );
  }

  /// Emerald gradient "Get Started" button shown on the last page.
  Widget _getStartedButton(BuildContext context, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald, AppColors.emeraldDim],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Get Started',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.check_rounded,
            size: 20,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// One page's content: glowing icon orb, title, subtitle, floating glass chips.
///
/// Fades + slides in every time its page becomes current — [PageView.builder]
/// rebuilds it with a fresh [ValueKey] on each page change.
class _OnboardingPageBody extends StatelessWidget {
  final _OnboardingPageData data;
  final Animation<double> float;

  const _OnboardingPageBody({required this.data, required this.float});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // New key per page instance → the entrance animation replays on change.
      key: ValueKey<String>(data.title),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - t)),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // ── Glowing gradient icon orb ────────────────────────────
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft radial glow behind the orb.
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            data.accent.withOpacity(0.38),
                            data.accent.withOpacity(0.0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                    // The orb itself, gently floating.
                    AnimatedBuilder(
                      animation: float,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, float.value),
                        child: child,
                      ),
                      child: GlassCard(
                        radius: 46,
                        padding: const EdgeInsets.all(38),
                        child: Icon(
                          data.icon,
                          size: 72,
                          color: data.accent,
                          shadows: [
                            Shadow(
                              color: data.accent.withOpacity(0.7),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Title & subtitle ─────────────────────────────────────
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: context.tTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: context.tTextSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Floating glass stat chips ────────────────────────────
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: data.chips
                    .map(
                      (c) => GlassCard(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(c.icon, size: 16, color: data.accent),
                            const SizedBox(width: 6),
                            Text(
                              c.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.tTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

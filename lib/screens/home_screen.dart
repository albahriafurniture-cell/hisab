import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../models/account.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/txn_tile.dart';
import 'accounts_screen.dart';
import 'add_txn_sheet.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAllTxns;

  const HomeScreen({super.key, required this.onSeeAllTxns});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        HiveService.accounts.listenable(),
        HiveService.txns.listenable(),
        HiveService.budgets.listenable(),
        HiveService.recurring.listenable(),
        HiveService.categories.listenable(),
        HiveService.goals.listenable(),
        HiveService.settings.listenable(),
      ]),
      builder: (context, _) {
        final now = DateTime.now();
        final key = monthKey(now);
        // All money is normalized to the base currency so mixed-currency
        // accounts still produce one meaningful total.
        final monthTxns = HiveService.txnsForMonth(key);
        final balance = HiveService.accounts.values
            .fold(0.0, (s, a) => s + CurrencyService.toBase(a.balance, a.currency));
        final income = monthTxns
            .where((t) => t.kind == 'income')
            .fold(0.0, (s, t) => s + _toBase(t));
        final expense = monthTxns
            .where((t) => t.kind == 'expense')
            .fold(0.0, (s, t) => s + _toBase(t));
        final accounts = HiveService.accounts.values.toList();
        final due = HiveService.dueRecurrings(now);
        final recent = HiveService.recentTxns(5);
        final alerts = _budgetAlerts(key);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 18),
              _heroCard(context, balance, income, expense),
              const SizedBox(height: 22),
              _sectionHeader(context, 'Accounts', 'Manage',
                  () => _push(context, const AccountsScreen())),
              const SizedBox(height: 12),
              _accountsRow(context, accounts),
              const SizedBox(height: 22),
              _sectionHeader(context, 'Savings goals', 'View all',
                  () => _push(context, const GoalsScreen())),
              const SizedBox(height: 12),
              _goalsPreview(context),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionHeader(context, 'Budget alerts', 'All budgets',
                    () => _push(context, const BudgetsScreen())),
                const SizedBox(height: 12),
                for (final a in alerts) _budgetAlertTile(context, a, key),
              ],
              if (due.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionHeader(context, 'Due now', 'Recurring',
                    () => _push(context, const RecurringScreen())),
                const SizedBox(height: 12),
                for (final r in due) _dueTile(context, r),
              ],
              const SizedBox(height: 22),
              _sectionHeader(context, 'Recent activity', 'See all',
                  onSeeAllTxns),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions yet',
                  subtitle:
                      'Tap the + button to record your first income or expense.',
                  actionLabel: 'Add transaction',
                  onAction: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddTxnSheet(),
                  ),
                )
              else
                for (final t in recent)
                  TxnTile(
                    txn: t,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddTxnSheet(existing: t),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// Converts a txn amount into the base currency using its account's
  /// currency. Falls back to base when the account is gone.
  double _toBase(Txn t) {
    final a = HiveService.accounts.get(t.accountId);
    return CurrencyService.toBase(t.amount, a?.currency ?? CurrencyService.baseCurrency);
  }

  /// Compact savings-goals preview: top 2 goals or a CTA card.
  Widget _goalsPreview(BuildContext context) {
    final goals = HiveService.goals.values.toList()
      ..sort((a, b) => HiveService.goalProgress(b)
          .compareTo(HiveService.goalProgress(a)));
    if (goals.isEmpty) {
      return GlassCard(
        onTap: () => _push(context, const GoalsScreen()),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: const Icon(Icons.track_changes_rounded,
                  color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start your first savings goal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.tTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Car, trip, emergency fund — track it here',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.gold),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final g in goals.take(2)) _goalMiniTile(context, g),
      ],
    );
  }

  Widget _goalMiniTile(BuildContext context, Goal g) {
    final progress = HiveService.goalProgress(g);
    final color = Color(g.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 18,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => _push(context, const GoalsScreen()),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(appIcon(g.icon), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.tTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      builder: (ctx, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: context.isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${CurrencyService.format(g.savedAmount, CurrencyService.baseCurrency)} of ${CurrencyService.format(g.targetAmount, CurrencyService.baseCurrency)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tTextSecondary,
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

  Widget _header(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting(),
                style: TextStyle(
                  fontSize: 15,
                  color: context.tTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your money, in control',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: context.tTextPrimary,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          radius: 18,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            dayLabel(now),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.tTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(
      BuildContext context, double balance, double income, double expense) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.tTextSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.emerald.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 12, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyService.format(
                balance, CurrencyService.baseCurrency),
            style: moneyStyle(38,
                weight: FontWeight.w800, color: context.tTextPrimary),
          ),
          const SizedBox(height: 14),
          _trendLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _monthStat(
                  context,
                  'Income',
                  income,
                  AppColors.emerald,
                  Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.08)),
              Expanded(
                child: _monthStat(
                  context,
                  'Expense',
                  expense,
                  AppColors.danger,
                  Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthStat(BuildContext context, String label, double value,
      Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.tTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            CurrencyService.format(value, CurrencyService.baseCurrency),
            style: moneyStyle(17, color: color),
          ),
        ),
      ],
    );
  }

  /// Net cashflow for the last 14 days.
  Widget _trendLine() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (var i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      spots.add(FlSpot((13 - i).toDouble(),
          HiveService.netForDay(day)));
    }
    final allZero = spots.every((s) => s.y == 0);
    return SizedBox(
      height: 72,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: allZero ? -1 : null,
          maxY: allZero ? 1 : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.emerald, AppColors.cyan],
              ),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.emerald.withOpacity(0.28),
                    AppColors.emerald.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      String action, VoidCallback onTap) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.tTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.emerald,
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountsRow(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_rounded,
        title: 'No accounts',
        subtitle: 'Add a wallet to start tracking.',
      );
    }
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = accounts[i];
          final c = Color(a.color);
          return GlassCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            onTap: () =>
                _push(context, const AccountsScreen()),
            child: SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(appIcon(a.icon, Icons.wallet),
                            size: 18, color: c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ctx.tTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatCompact(a.balance),
                    style: moneyStyle(18, color: ctx.tTextPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_BudgetAlert> _budgetAlerts(String key) {
    final out = <_BudgetAlert>[];
    for (final b in HiveService.budgets.values) {
      if (b.monthKey != key) continue;
      final spent = HiveService.spentForCategory(b.categoryId, key);
      final pct = b.monthlyLimit <= 0 ? 0.0 : spent / b.monthlyLimit;
      if (pct >= 0.8) out.add(_BudgetAlert(budgetId: b.id, pct: pct));
    }
    out.sort((a, b) => b.pct.compareTo(a.pct));
    return out.take(3).toList();
  }

  Widget _budgetAlertTile(
      BuildContext context, _BudgetAlert alert, String key) {
    final b = HiveService.budgets.get(alert.budgetId);
    if (b == null) return const SizedBox.shrink();
    final cat = HiveService.categories.get(b.categoryId);
    final spent = HiveService.spentForCategory(b.categoryId, key);
    final over = alert.pct >= 1.0;
    final c = over ? AppColors.danger : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 18,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    over
                        ? Icons.warning_rounded
                        : Icons.timer_rounded,
                    size: 16,
                    color: c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    over
                        ? '${cat?.name ?? 'Budget'} is over budget'
                        : '${cat?.name ?? 'Budget'} is ${(alert.pct * 100).round()}% used',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tTextPrimary,
                    ),
                  ),
                ),
                Text(
                  '${formatCompact(spent)} / ${formatCompact(b.monthlyLimit)}',
                  style: moneyStyle(12, color: context.tTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: alert.pct.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueTile(BuildContext context, Recurring r) {
    final cat = HiveService.categories.get(r.categoryId);
    final acc = HiveService.accounts.get(r.accountId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 18,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_repeat_rounded,
                  color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cat?.name ?? ''} • ${acc?.name ?? ''} • Day ${r.dayOfMonth}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(r.amount),
              style: moneyStyle(14, color: context.tTextPrimary),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await HiveService.postRecurring(r);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Recurring entry posted')),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.emerald.withOpacity(0.35)),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetAlert {
  final String budgetId;
  final double pct;
  _BudgetAlert({required this.budgetId, required this.pct});
}

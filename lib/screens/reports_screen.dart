import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../models/txn.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/empty_state.dart';
import '../widgets/export_buttons.dart';
import '../widgets/glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _month = '';
  String _pieKind = 'expense';

  @override
  void initState() {
    super.initState();
    _month = monthKey(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        HiveService.txns.listenable(),
        HiveService.categories.listenable(),
      ]),
      builder: (context, _) {
        // Normalized to base currency so mixed-currency accounts aggregate.
        final txns = HiveService.txnsForMonth(_month);
        final income = txns
            .where((t) => t.kind == 'income')
            .fold(0.0, (s, t) => s + _toBase(t));
        final expense = txns
            .where((t) => t.kind == 'expense')
            .fold(0.0, (s, t) => s + _toBase(t));
        final net = income - expense;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: context.tTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _monthNav(context),
              const SizedBox(height: 10),
              ExportButtons(monthKey: _month),
              const SizedBox(height: 16),
              if (txns.isEmpty)
                const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No data this month',
                  subtitle:
                      'Add some transactions and your charts will appear here.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                        child: _summaryCard(context,
                            'Income', income, AppColors.emerald)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _summaryCard(context,
                            'Expense', expense, AppColors.danger)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _summaryCard(
                            context,
                            'Net',
                            net,
                            net >= 0
                                ? AppColors.gold
                                : AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Income vs expense'),
                const SizedBox(height: 10),
                GlassCard(child: _barChart(context, income, expense)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _sectionTitle(context, 'Spending by category'),
                    const Spacer(),
                    _pieToggle(context),
                  ],
                ),
                const SizedBox(height: 10),
                GlassCard(child: _pieChart(context, txns)),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Top categories'),
                const SizedBox(height: 10),
                for (final e in _topCategories(txns).take(5))
                  _topCategoryRow(context, e.$1, e.$2, expense),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Daily spending'),
                const SizedBox(height: 10),
                GlassCard(child: _dailyLine(context)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Text(
        t,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: context.tTextPrimary,
          letterSpacing: -0.3,
        ),
      );

  Widget _monthNav(BuildContext context) {
    final isCurrent = _month == monthKey(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrow(Icons.chevron_left_rounded,
            () => setState(() => _month = prevMonthKey(_month))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            fullMonthLabel(_month),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.tTextPrimary,
            ),
          ),
        ),
        _arrow(
          Icons.chevron_right_rounded,
          isCurrent
              ? null
              : () => setState(() => _month = nextMonthKey(_month)),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 20,
            color: onTap == null
                ? AppColors.textMuted.withOpacity(0.4)
                : AppColors.textSecondary),
      ),
    );
  }

  Widget _summaryCard(
      BuildContext context, String label, double value, Color color) {
    return GlassCard(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: context.tTextSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(formatCompact(value),
              style: moneyStyle(16, color: color)),
        ],
      ),
    );
  }

  Widget _barChart(BuildContext context, double income, double expense) {
    final maxY = (income > expense ? income : expense) * 1.25;
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 10 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    formatCompact(v),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.tTextMuted,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final label = v == 0
                      ? 'Income'
                      : v == 1
                          ? 'Expense'
                          : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.tTextSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: income,
                  width: 54,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF0D9488), AppColors.emerald],
                  ),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: expense,
                  width: 54,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFFB91C1C), AppColors.danger],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pieToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleTab(context, 'expense', 'Out'),
          _toggleTab(context, 'income', 'In'),
        ],
      ),
    );
  }

  Widget _toggleTab(BuildContext context, String kind, String label) {
    final active = _pieKind == kind;
    return GestureDetector(
      onTap: () => setState(() => _pieKind = kind),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.emerald.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active
                ? AppColors.emerald
                : context.tTextSecondary,
          ),
        ),
      ),
    );
  }

  /// Txn amount in base currency (via its account's currency).
  double _toBase(Txn t) {
    final a = HiveService.accounts.get(t.accountId);
    return CurrencyService.toBase(
        t.amount, a?.currency ?? CurrencyService.baseCurrency);
  }

  Map<String, double> _byCategory(List<Txn> txns) {
    final map = <String, double>{};
    for (final t in txns) {
      if (t.kind != _pieKind) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + _toBase(t);
    }
    return map;
  }

  Widget _pieChart(BuildContext context, List<Txn> txns) {
    final data = _byCategory(txns);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No data',
            style: TextStyle(color: context.tTextSecondary)),
      );
    }
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final rest = sorted.skip(6).fold(0.0, (s, e) => s + e.value);
    final total = data.values.fold(0.0, (s, v) => s + v);

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < top.length; i++) {
      final e = top[i];
      final cat = HiveService.categories.get(e.key);
      sections.add(PieChartSectionData(
        value: e.value,
        color: Color(cat?.color ?? 0xFF94A3B8),
        radius: 62,
        title: '',
        badgePositionPercentageOffset: 1,
      ));
    }
    if (rest > 0) {
      sections.add(PieChartSectionData(
        value: rest,
        color: const Color(0xFF475569),
        radius: 62,
        title: '',
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 3,
                  centerSpaceRadius: 52,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _pieKind == 'expense' ? 'Spent' : 'Earned',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tTextSecondary,
                    ),
                  ),
                  Text(formatCompact(total),
                      style: moneyStyle(20, color: context.tTextPrimary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (var i = 0; i < top.length; i++)
              _legendDot(context, top[i].key),
            if (rest > 0) _legendDot(context, null),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(BuildContext context, String? categoryId) {
    final cat = categoryId == null
        ? null
        : HiveService.categories.get(categoryId);
    final color =
        categoryId == null ? const Color(0xFF475569) : Color(cat?.color ?? 0xFF94A3B8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          categoryId == null ? 'Other' : (cat?.name ?? ''),
          style: TextStyle(
            fontSize: 12,
            color: context.tTextSecondary,
          ),
        ),
      ],
    );
  }

  List<(String, double)> _topCategories(List<Txn> txns) {
    final map = <String, double>{};
    for (final t in txns) {
      if (t.kind != 'expense') continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + _toBase(t);
    }
    final list = map.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  Widget _topCategoryRow(BuildContext context, String categoryId,
      double amount, double totalExpense) {
    final cat = HiveService.categories.get(categoryId);
    final pct = totalExpense <= 0 ? 0.0 : amount / totalExpense;
    final color = Color(cat?.color ?? 0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(appIcon(cat?.icon ?? 'other'),
                color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat?.name ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          Colors.white.withOpacity(0.08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    CurrencyService.format(
                        amount, CurrencyService.baseCurrency),
                    style: moneyStyle(14, color: context.tTextPrimary)),
                Text('${(pct * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11,
                        color: context.tTextMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyLine(BuildContext context) {
    final d = monthDate(_month);
    final dim = daysInMonth(d.year, d.month);
    final spots = <FlSpot>[];
    for (var day = 1; day <= dim; day++) {
      final dayTotal = HiveService.txns.values
          .where((t) =>
              t.kind == 'expense' &&
              t.date.year == d.year &&
              t.date.month == d.month &&
              t.date.day == day)
          .fold(0.0, (s, t) => s + _toBase(t));
      spots.add(FlSpot(day.toDouble(), dayTotal));
    }
    final maxY = spots
        .map((s) => s.y)
        .fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    formatCompact(v),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.tTextMuted,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (dim / 4).ceilToDouble(),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.tTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 1,
          maxX: dim.toDouble(),
          maxY: maxY <= 0 ? 10 : maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.gold, Color(0xFFF97316)],
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
                    AppColors.gold.withOpacity(0.25),
                    AppColors.gold.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

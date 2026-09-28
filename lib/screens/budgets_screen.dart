import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  String _month = '';

  @override
  void initState() {
    super.initState();
    _month = monthKey(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.emerald),
            onPressed: () => _budgetDialog(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          HiveService.budgets.listenable(),
          HiveService.txns.listenable(),
          HiveService.categories.listenable(),
        ]),
        builder: (context, _) {
          final budgets = HiveService.budgets.values
              .where((b) => b.monthKey == _month)
              .toList();
          final totalLimit =
              budgets.fold(0.0, (s, b) => s + b.monthlyLimit);
          final totalSpent = budgets.fold(
              0.0,
              (s, b) =>
                  s + HiveService.spentForCategory(b.categoryId, _month));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              _monthNav(),
              const SizedBox(height: 14),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _stat('Total budget', totalLimit,
                          AppColors.gold),
                    ),
                    Expanded(
                      child: _stat('Spent', totalSpent,
                          totalSpent > totalLimit
                              ? AppColors.danger
                              : AppColors.textPrimary),
                    ),
                    Expanded(
                      child: _stat(
                          'Left',
                          totalLimit - totalSpent,
                          (totalLimit - totalSpent) < 0
                              ? AppColors.danger
                              : AppColors.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (budgets.isEmpty)
                EmptyState(
                  icon: Icons.savings_rounded,
                  title: 'No budgets for ${monthLabel(_month)}',
                  subtitle:
                      'Set monthly spending limits per category to stay in control.',
                  actionLabel: 'Add budget',
                  onAction: () => _budgetDialog(context),
                )
              else
                for (final b in budgets) _budgetCard(context, b),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(formatCompact(value), style: moneyStyle(17, color: color)),
      ],
    );
  }

  Widget _monthNav() {
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
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

  Widget _budgetCard(BuildContext context, Budget b) {
    final cat = HiveService.categories.get(b.categoryId);
    final spent = HiveService.spentForCategory(b.categoryId, _month);
    final pct = b.monthlyLimit <= 0 ? 0.0 : spent / b.monthlyLimit;
    final over = pct >= 1.0;
    final color = over
        ? AppColors.danger
        : pct >= 0.8
            ? AppColors.gold
            : AppColors.emerald;
    final catColor = Color(cat?.color ?? 0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(appIcon(cat?.icon ?? 'other'),
                      color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat?.name ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoney(spent)} of ${formatMoney(b.monthlyLimit)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  over
                      ? '${((pct - 1) * 100).round()}% over'
                      : '${(pct * 100).round()}%',
                  style: moneyStyle(14, color: color),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 20),
                  color: const Color(0xFF0E1626),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _budgetDialog(context, existing: b);
                    } else if (v == 'delete') {
                      _confirmDelete(context, b);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (ctx, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 9,
                  backgroundColor:
                      Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _budgetDialog(BuildContext context,
      {Budget? existing}) async {
    final limitCtrl = TextEditingController(
        text: existing != null ? existing.monthlyLimit.truncate().toString() : '');
    final expenseCats = HiveService.categories.values
        .where((c) => c.kind == 'expense')
        .toList();
    final usedIds = HiveService.budgets.values
        .where((b) => b.monthKey == _month && b.id != existing?.id)
        .map((b) => b.categoryId)
        .toSet();
    final available =
        expenseCats.where((c) => !usedIds.contains(c.id)).toList();
    Category? selected = existing != null
        ? HiveService.categories.get(existing.categoryId)
        : (available.isNotEmpty ? available.first : null);

    if (available.isEmpty && existing == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Every expense category already has a budget this month')),
        );
      }
      limitCtrl.dispose();
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'New budget' : 'Edit budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existing == null) ...[
                const Text('Category',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                DropdownButton<Category>(
                  value: selected,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0E1626),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  items: available
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setS(() => selected = v),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: limitCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit (Rs)',
                  labelStyle:
                      TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final limit =
                    double.tryParse(limitCtrl.text.trim()) ?? 0;
                if (limit <= 0 || selected == null) return;
                if (existing == null) {
                  final b = Budget(
                    id: Uuid().v4(),
                    categoryId: selected!.id,
                    monthlyLimit: limit,
                    monthKey: _month,
                  );
                  await HiveService.budgets.put(b.id, b);
                } else {
                  existing.monthlyLimit = limit;
                  await HiveService.budgets
                      .put(existing.id, existing);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.emerald)),
            ),
          ],
        ),
      ),
    );
    limitCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget?'),
        content: const Text(
            'The spending limit for this month will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.budgets.delete(b.id);
    }
  }
}

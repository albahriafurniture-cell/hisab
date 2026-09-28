import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../models/goal.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';

/// Savings goals: track progress toward targets, contribute from an account,
/// or withdraw back into one.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  // Palette of ARGB colors offered in the add/edit dialog.
  static const List<int> _goalColors = [
    0xFF10B981, // emerald
    0xFFF59E0B, // gold
    0xFF8B5CF6, // violet
    0xFF22D3EE, // cyan
    0xFF3B82F6, // blue
    0xFFF472B6, // pink
    0xFFEF4444, // red
    0xFF34D399, // mint
    0xFFFB7185, // rose
    0xFF2DD4BF, // teal
  ];

  // Goal-flavoured subset of kAppIcons offered in the add/edit dialog.
  static const List<String> _goalIconKeys = [
    'travel',
    'shopping',
    'health',
    'education',
    'business',
    'investment',
    'cash',
    'bank',
    'wallet',
    'family',
    'entertainment',
    'bills',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.emerald),
            onPressed: () => _goalDialog(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          HiveService.goals.listenable(),
          HiveService.accounts.listenable(),
        ]),
        builder: (context, _) {
          final goals = HiveService.goals.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              if (goals.isNotEmpty) ...[
                _summaryCard(context, goals),
                const SizedBox(height: 16),
              ],
              if (goals.isEmpty)
                EmptyState(
                  icon: Icons.savings_rounded,
                  title: 'No savings goals yet',
                  subtitle:
                      'Set a target — a new phone, a trip, an emergency fund — and watch your progress grow.',
                  actionLabel: 'Add goal',
                  onAction: () => _goalDialog(context),
                )
              else
                for (final g in goals) _goalCard(context, g),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ summary card
  Widget _summaryCard(BuildContext context, List<Goal> goals) {
    final saved = goals.fold(0.0, (s, g) => s + g.savedAmount);
    final target = goals.fold(0.0, (s, g) => s + g.targetAmount);
    final pct = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total saved',
              style:
                  TextStyle(fontSize: 13, color: context.tTextSecondary)),
          const SizedBox(height: 4),
          Text(formatMoney(saved),
              style: moneyStyle(26, color: context.tTextPrimary)),
          const SizedBox(height: 4),
          Text(
            'of ${formatMoney(target)} across ${goals.length} ${goals.length == 1 ? 'goal' : 'goals'}',
            style:
                TextStyle(fontSize: 13, color: context.tTextMuted),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (ctx, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.emerald),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(pct * 100).round()}% of all goals funded',
              style:
                  TextStyle(fontSize: 13, color: context.tTextSecondary)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- goal card
  Widget _goalCard(BuildContext context, Goal g) {
    final color = Color(g.color);
    final pct = HiveService.goalProgress(g);
    final complete = pct >= 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _detailSheet(context, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(appIcon(g.icon), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.tTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _deadlineLabel(g.deadline),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  complete
                      ? 'Done!'
                      : '${(pct * 100).round()}%',
                  style: moneyStyle(14,
                      color: complete
                          ? AppColors.emerald
                          : context.tTextPrimary),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: context.tTextSecondary, size: 20),
                  color: const Color(0xFF0E1626),
                  onSelected: (v) {
                    if (v == 'contribute') {
                      _amountDialog(context, g, isWithdraw: false);
                    } else if (v == 'withdraw') {
                      _amountDialog(context, g, isWithdraw: true);
                    } else if (v == 'edit') {
                      _goalDialog(context, existing: g);
                    } else if (v == 'delete') {
                      _confirmDelete(context, g);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                        value: 'contribute', child: Text('Contribute')),
                    PopupMenuItem(
                        value: 'withdraw', child: Text('Withdraw')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (ctx, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 9,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatMoney(g.savedAmount),
                    style: moneyStyle(14,
                        color: context.tTextPrimary)),
                Text(
                  'of ${formatMoney(g.targetAmount)}',
                  style: TextStyle(
                      fontSize: 13, color: context.tTextSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- detail sheet
  /// Bottom sheet with full goal info and the contribute / withdraw actions.
  Future<void> _detailSheet(BuildContext context, Goal g) async {
    final color = Color(g.color);
    final pct = HiveService.goalProgress(g);
    final remaining = (g.targetAmount - g.savedAmount).clamp(0.0, double.infinity);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1626),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.12)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(appIcon(g.icon), color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: ctx.tTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _deadlineLabel(g.deadline),
                        style: TextStyle(
                            fontSize: 13,
                            color: ctx.tTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _detailStat(ctx, 'Saved',
                      formatMoney(g.savedAmount), ctx.tTextPrimary),
                ),
                Expanded(
                  child: _detailStat(ctx, 'Remaining',
                      formatMoney(remaining),
                      remaining <= 0
                          ? AppColors.emerald
                          : ctx.tTextPrimary),
                ),
                Expanded(
                  child: _detailStat(ctx, 'Target',
                      formatMoney(g.targetAmount), ctx.tTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (c, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(pct * 100).round()}% funded',
                style:
                    TextStyle(fontSize: 13, color: ctx.tTextMuted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _sheetButton(
                    ctx,
                    label: 'Contribute',
                    icon: Icons.add_rounded,
                    color: AppColors.emerald,
                    onTap: () {
                      Navigator.pop(ctx);
                      _amountDialog(context, g, isWithdraw: false);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sheetButton(
                    ctx,
                    label: 'Withdraw',
                    icon: Icons.remove_rounded,
                    color: AppColors.gold,
                    onTap: () {
                      Navigator.pop(ctx);
                      _amountDialog(context, g, isWithdraw: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _goalDialog(context, existing: g);
                  },
                  child: Text('Edit',
                      style: TextStyle(color: ctx.tTextSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, g);
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(
      BuildContext ctx, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: ctx.tTextSecondary)),
        const SizedBox(height: 4),
        Text(value, style: moneyStyle(16, color: color)),
      ],
    );
  }

  Widget _sheetButton(BuildContext ctx,
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- add/edit dialog
  Future<void> _goalDialog(BuildContext context,
      {Goal? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final targetCtrl = TextEditingController(
        text: existing != null
            ? existing.targetAmount.truncate().toString()
            : '');
    DateTime? deadline = existing?.deadline;
    int color = existing?.color ?? _goalColors.first;
    String iconKey = existing?.icon ?? 'other';
    if (!kAppIcons.containsKey(iconKey)) iconKey = 'other';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'New savings goal' : 'Edit goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: ctx.tTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Goal title',
                    labelStyle:
                        TextStyle(color: ctx.tTextSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: ctx.tTextMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ctx.tTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Target amount (Rs)',
                    labelStyle:
                        TextStyle(color: ctx.tTextSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: ctx.tTextMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deadline == null
                            ? 'No deadline'
                            : 'Deadline: ${DateFormat('d MMM yyyy').format(deadline!)}',
                        style: TextStyle(
                            color: ctx.tTextSecondary, fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              deadline ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                              const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setS(() => deadline = picked);
                        }
                      },
                      child: const Text('Pick date',
                          style:
                              TextStyle(color: AppColors.emerald)),
                    ),
                    if (deadline != null)
                      IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 18, color: ctx.tTextMuted),
                        onPressed: () =>
                            setS(() => deadline = null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Color',
                    style: TextStyle(
                        color: ctx.tTextSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _goalColors)
                      GestureDetector(
                        onTap: () => setS(() => color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: color == c
                                ? Border.all(
                                    color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Icon',
                    style: TextStyle(
                        color: ctx.tTextSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in _goalIconKeys)
                      GestureDetector(
                        onTap: () => setS(() => iconKey = key),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconKey == key
                                ? Color(color).withOpacity(0.22)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: iconKey == key
                                ? Border.all(
                                    color: Color(color), width: 1.5)
                                : null,
                          ),
                          child: Icon(
                            appIcon(key),
                            color: iconKey == key
                                ? Color(color)
                                : ctx.tTextSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: ctx.tTextSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final target =
                    double.tryParse(targetCtrl.text.trim()) ?? 0;
                if (title.isEmpty || target <= 0) return;
                if (existing == null) {
                  final g = Goal(
                    id: Uuid().v4(),
                    title: title,
                    targetAmount: target,
                    deadline: deadline,
                    color: color,
                    icon: iconKey,
                    createdAt: DateTime.now(),
                  );
                  await HiveService.goals.put(g.id, g);
                } else {
                  existing.title = title;
                  existing.targetAmount = target;
                  existing.deadline = deadline;
                  existing.color = color;
                  existing.icon = iconKey;
                  await HiveService.goals.put(existing.id, existing);
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
    titleCtrl.dispose();
    targetCtrl.dispose();
  }

  // ------------------------------------------------- contribute/withdraw dialog
  Future<void> _amountDialog(BuildContext context, Goal g,
      {required bool isWithdraw}) async {
    final amtCtrl = TextEditingController();
    final accts = HiveService.accounts.values.toList();
    String? accountId; // null = external, no account movement

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isWithdraw
              ? 'Withdraw from goal'
              : 'Contribute to goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWithdraw
                    ? 'Saved so far: ${formatMoney(g.savedAmount)}'
                    : '${g.title} · ${formatMoney(g.savedAmount)} of ${formatMoney(g.targetAmount)} saved',
                style: TextStyle(
                    color: ctx.tTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                style: TextStyle(color: ctx.tTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs)',
                  labelStyle:
                      TextStyle(color: ctx.tTextSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: ctx.tTextMuted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isWithdraw
                    ? 'Return to account (optional)'
                    : 'Take from account (optional)',
                style: TextStyle(
                    color: ctx.tTextSecondary, fontSize: 13),
              ),
              DropdownButton<String?>(
                value: accountId,
                isExpanded: true,
                dropdownColor: const Color(0xFF0E1626),
                style:
                    TextStyle(color: ctx.tTextPrimary, fontSize: 15),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No account')),
                  for (final a in accts)
                    DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(
                          '${a.name} · ${formatMoney(a.balance)}'),
                    ),
                ],
                onChanged: (v) => setS(() => accountId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: ctx.tTextSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amtCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                if (isWithdraw) {
                  if (amount > g.savedAmount) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Only ${formatMoney(g.savedAmount)} saved in this goal')),
                      );
                    }
                    return;
                  }
                  await HiveService.withdrawFromGoal(g.id, amount,
                      toAccountId: accountId);
                } else {
                  if (accountId != null) {
                    final a =
                        HiveService.accounts.get(accountId);
                    if (a != null && amount > a.balance) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Insufficient balance in ${a.name}')),
                        );
                      }
                      return;
                    }
                  }
                  await HiveService.contributeToGoal(g.id, amount,
                      fromAccountId: accountId);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isWithdraw ? 'Withdraw' : 'Contribute',
                  style: TextStyle(
                      color: isWithdraw
                          ? AppColors.gold
                          : AppColors.emerald)),
            ),
          ],
        ),
      ),
    );
    amtCtrl.dispose();
  }

  // ------------------------------------------------------------ delete flow
  Future<void> _confirmDelete(BuildContext context, Goal g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(
            '"${g.title}" and its ${formatMoney(g.savedAmount)} saved record will be removed. Money already in your accounts stays there.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ctx.tTextSecondary)),
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
      await HiveService.deleteGoal(g.id);
    }
  }

  // ----------------------------------------------------------------- helpers
  String _deadlineLabel(DateTime? d) {
    if (d == null) return 'No deadline';
    final label = DateFormat('MMM yyyy').format(d);
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '$label · overdue';
    if (days == 0) return '$label · due today';
    return '$label · $days days left';
  }
}

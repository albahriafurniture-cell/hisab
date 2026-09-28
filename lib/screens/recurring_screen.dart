import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.emerald),
            onPressed: () => _recurringDialog(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          HiveService.recurring.listenable(),
          HiveService.txns.listenable(),
          HiveService.categories.listenable(),
          HiveService.accounts.listenable(),
        ]),
        builder: (context, _) {
          final now = DateTime.now();
          final items = HiveService.recurring.values.toList()
            ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              if (items.isEmpty)
                EmptyState(
                  icon: Icons.event_repeat_rounded,
                  title: 'No recurring entries',
                  subtitle:
                      'Add monthly bills like rent or subscriptions and post them with one tap.',
                  actionLabel: 'Add recurring',
                  onAction: () => _recurringDialog(context),
                )
              else
                for (final r in items) _card(context, r, now),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Recurring r, DateTime now) {
    final due = HiveService.isDue(r, now);
    final cat = HiveService.categories.get(r.categoryId);
    final acc = HiveService.accounts.get(r.accountId);
    final isIncome = r.kind == 'income';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: r.active
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                if (due)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Due',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                Switch(
                  value: r.active,
                  activeColor: AppColors.emerald,
                  onChanged: (v) async {
                    r.active = v;
                    await HiveService.recurring.put(r.id, r);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${isIncome ? 'Income' : 'Expense'} • Day ${r.dayOfMonth} of every month',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${cat?.name ?? ''} • ${acc?.name ?? ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  formatMoney(r.amount),
                  style: moneyStyle(
                    20,
                    color: isIncome
                        ? AppColors.emerald
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (r.lastPostedKey != null)
                  Text(
                    'Posted ${monthLabel(r.lastPostedKey!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                const SizedBox(width: 8),
                _postButton(context, r),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 20),
                  color: const Color(0xFF0E1626),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _recurringDialog(context, existing: r);
                    } else if (v == 'delete') {
                      _confirmDelete(context, r);
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
          ],
        ),
      ),
    );
  }

  Widget _postButton(BuildContext context, Recurring r) {
    return GestureDetector(
      onTap: () async {
        await HiveService.postRecurring(r);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '"${r.title}" posted as ${formatMoney(r.amount)}')),
          );
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.emerald.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.emerald.withOpacity(0.4)),
        ),
        child: const Text(
          'Post now',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.emerald,
          ),
        ),
      ),
    );
  }

  Future<void> _recurringDialog(BuildContext context,
      {Recurring? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.truncate().toString() : '');
    String kind = existing?.kind ?? 'expense';
    int day = existing?.dayOfMonth ?? 1;
    bool active = existing?.active ?? true;
    // Selection state lives outside the StatefulBuilder so rebuilds
    // (e.g. toggling kind) don't wipe the user's pick.
    Category? selCat = existing != null
        ? HiveService.categories.get(existing.categoryId)
        : null;
    selCat ??= HiveService.categories.values
        .where((c) => c.kind == kind)
        .cast<Category?>()
        .firstWhere((_) => true, orElse: () => null);
    Account? selAcc = existing != null
        ? HiveService.accounts.get(existing.accountId)
        : null;
    selAcc ??= HiveService.accounts.values
        .cast<Account?>()
        .firstWhere((_) => true, orElse: () => null);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final cats = HiveService.categories.values
              .where((c) => c.kind == kind)
              .toList();
          final accs = HiveService.accounts.values.toList();
          // Keep the user's pick across rebuilds; fall back only when the
          // current pick is invalid for the selected kind.
          if (selCat == null ||
              cats.every((c) => c.id != selCat!.id)) {
            selCat = cats.isNotEmpty ? cats.first : null;
          }
          if (selAcc == null ||
              accs.every((a) => a.id != selAcc!.id)) {
            selAcc = accs.isNotEmpty ? accs.first : null;
          }

          return AlertDialog(
            title:
                Text(existing == null ? 'New recurring' : 'Edit recurring'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Title (e.g. House rent)',
                      labelStyle:
                          TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Amount (Rs)',
                      labelStyle:
                          TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniKind(setS, 'expense', 'Expense', kind,
                          (v) => kind = v),
                      const SizedBox(width: 8),
                      _miniKind(setS, 'income', 'Income', kind,
                          (v) => kind = v),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Category',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  DropdownButton<Category>(
                    value: selCat,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0E1626),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 15),
                    items: cats
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setS(() => selCat = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('Account',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  DropdownButton<Account>(
                    value: selAcc,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0E1626),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 15),
                    items: accs
                        .map((a) => DropdownMenuItem(
                            value: a, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setS(() => selAcc = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Day of month',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: day,
                        dropdownColor: const Color(0xFF0E1626),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15),
                        items: List.generate(
                            28,
                            (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'))),
                        onChanged: (v) =>
                            setS(() => day = v ?? 1),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Active',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: active,
                        activeColor: AppColors.emerald,
                        onChanged: (v) => setS(() => active = v),
                      ),
                    ],
                  ),
                ],
              ),
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
                  final title = titleCtrl.text.trim();
                  final amount =
                      double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (title.isEmpty ||
                      amount <= 0 ||
                      selCat == null ||
                      selAcc == null) {
                    return;
                  }
                  if (existing == null) {
                    final r = Recurring(
                      id: Uuid().v4(),
                      title: title,
                      amount: amount,
                      kind: kind,
                      categoryId: selCat!.id,
                      accountId: selAcc!.id,
                      dayOfMonth: day,
                      active: active,
                    );
                    await HiveService.recurring.put(r.id, r);
                  } else {
                    existing.title = title;
                    existing.amount = amount;
                    existing.kind = kind;
                    existing.categoryId = selCat!.id;
                    existing.accountId = selAcc!.id;
                    existing.dayOfMonth = day;
                    existing.active = active;
                    await HiveService.recurring
                        .put(existing.id, existing);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save',
                    style: TextStyle(color: AppColors.emerald)),
              ),
            ],
          );
        },
      ),
    );
    titleCtrl.dispose();
    amountCtrl.dispose();
  }

  Widget _miniKind(StateSetter setS, String value, String label,
      String current, ValueChanged<String> onPick) {
    final active = current == value;
    final color =
        value == 'income' ? AppColors.emerald : AppColors.danger;
    return Expanded(
      child: GestureDetector(
        onTap: () => setS(() => onPick(value)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.16)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? color.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Recurring r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${r.title}"?'),
        content: const Text(
            'Future postings stop. Already-posted transactions stay.'),
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
      await HiveService.recurring.delete(r.id);
    }
  }
}

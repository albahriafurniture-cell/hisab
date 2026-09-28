import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../models/txn.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  String _kind = 'all'; // all | income | expense
  String _month = '';
  String? _categoryId;
  String? _accountId;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _month = monthKey(DateTime.now());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Txn> _filtered() {
    final q = _query.trim().toLowerCase();
    final list = HiveService.txns.values.where((t) {
      if (monthKey(t.date) != _month) return false;
      if (_kind != 'all' && t.kind != _kind) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_accountId != null && t.accountId != _accountId) return false;
      if (q.isNotEmpty) {
        final cat = HiveService.categories.get(t.categoryId)?.name ?? '';
        final acc = HiveService.accounts.get(t.accountId)?.name ?? '';
        final hay = '${t.note} $cat $acc'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _deleteWithUndo(Txn t) async {
    await HiveService.deleteTxn(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${formatMoney(t.amount)}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.gold,
          onPressed: () => HiveService.restoreTxn(t),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _openEdit(Txn t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTxnSheet(existing: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        HiveService.txns.listenable(),
        HiveService.categories.listenable(),
        HiveService.accounts.listenable(),
      ]),
      builder: (context, _) {
        final list = _filtered();
        final grouped = <String, List<Txn>>{};
        for (final t in list) {
          final label = _dayHeader(t.date);
          grouped.putIfAbsent(label, () => []).add(t);
        }
        final income = list
            .where((t) => t.kind == 'income')
            .fold(0.0, (s, t) => s + t.amount);
        final expense = list
            .where((t) => t.kind == 'expense')
            .fold(0.0, (s, t) => s + t.amount);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: context.tTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _searchField(context),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _kindChips(context)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _monthNav(context),
                      const Spacer(),
                      _filterDropdown(
                        context: context,
                        hint: 'Category',
                        value: _categoryId,
                        items: HiveService.categories.values
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _categoryId = v),
                      ),
                      const SizedBox(width: 8),
                      _filterDropdown(
                        context: context,
                        hint: 'Account',
                        value: _accountId,
                        items: HiveService.accounts.values
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _accountId = v),
                      ),
                    ],
                  ),
                  if (_categoryId != null || _accountId != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _categoryId = null;
                          _accountId = null;
                        }),
                        child: const Text('Clear filters',
                            style: TextStyle(
                                color: AppColors.gold, fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  _summaryStrip(context, list.length, income, expense),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nothing found',
                      subtitle:
                          'No transactions match these filters. Try a different month or clear the search.',
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemCount: grouped.length,
                      itemBuilder: (ctx, gi) {
                        final label = grouped.keys.elementAt(gi);
                        final items = grouped[label]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 10, bottom: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ctx.tTextSecondary,
                                ),
                              ),
                            ),
                            for (final t in items)
                              Dismissible(
                                key: ValueKey(t.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white),
                                ),
                                confirmDismiss: (_) async {
                                  await _deleteWithUndo(t);
                                  return false; // we handle removal via Hive listener
                                },
                                child: TxnTile(
                                    txn: t,
                                    onTap: () => _openEdit(t)),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _dayHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return dayLabel(d);
  }

  Widget _searchField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(fontSize: 14, color: context.tTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search notes, categories, accounts',
          hintStyle:
              TextStyle(fontSize: 13, color: context.tTextMuted),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 20),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _kindChips(BuildContext context) {
    const kinds = [('all', 'All'), ('expense', 'Expense'), ('income', 'Income')];
    return Row(
      children: kinds.map((k) {
        final active = _kind == k.$1;
        final color = k.$1 == 'income'
            ? AppColors.emerald
            : k.$1 == 'expense'
                ? AppColors.danger
                : AppColors.gold;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _kind = k.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: active
                    ? color.withOpacity(0.16)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? color.withOpacity(0.45)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                k.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? color : context.tTextSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _monthNav(BuildContext context) {
    final isCurrent = _month == monthKey(DateTime.now());
    return GlassCard(
      radius: 14,
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navArrow(Icons.chevron_left_rounded,
              () => setState(() => _month = prevMonthKey(_month))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              monthLabel(_month),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.tTextPrimary,
              ),
            ),
          ),
          _navArrow(
            Icons.chevron_right_rounded,
            isCurrent
                ? null
                : () => setState(() => _month = nextMonthKey(_month)),
          ),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? AppColors.textMuted.withOpacity(0.4)
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required BuildContext context,
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: (value != null)
            ? AppColors.gold.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (value != null)
              ? AppColors.gold.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: TextStyle(
                  fontSize: 12, color: context.tTextSecondary)),
          dropdownColor:
              context.isDarkMode ? const Color(0xFF0E1626) : Colors.white,
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.textSecondary, size: 20),
          style: TextStyle(
              fontSize: 12, color: context.tTextPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _summaryStrip(
      BuildContext context, int count, double income, double expense) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Text(
            '$count transactions',
            style: TextStyle(
                fontSize: 12, color: context.tTextMuted),
          ),
          const Spacer(),
          Text(
            '+${formatCompact(income)}',
            style: moneyStyle(12, color: AppColors.emerald),
          ),
          const SizedBox(width: 10),
          Text(
            '-${formatCompact(expense)}',
            style: moneyStyle(12, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

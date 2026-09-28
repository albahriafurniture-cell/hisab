import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/txn.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/glass_card.dart';

/// Glass bottom sheet: numpad amount input, kind toggle, category grid,
/// account picker, date picker, note field. Used for both add and edit.
class AddTxnSheet extends StatefulWidget {
  final Txn? existing;

  const AddTxnSheet({super.key, this.existing});

  @override
  State<AddTxnSheet> createState() => _AddTxnSheetState();
}

class _AddTxnSheetState extends State<AddTxnSheet> {
  late String _amountStr;
  late String _kind;
  String? _categoryId;
  String? _accountId;
  late DateTime _date;
  final _noteCtrl = TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountStr = _trimAmount(e.amount);
      _kind = e.kind;
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _date = e.date;
      _noteCtrl.text = e.note;
    } else {
      _amountStr = '0';
      _kind = 'expense';
      final cats = HiveService.categories.values
          .where((c) => c.kind == 'expense')
          .toList();
      _categoryId = cats.isNotEmpty ? cats.first.id : null;
      final accs = HiveService.accounts.values.toList();
      _accountId = accs.isNotEmpty ? accs.first.id : null;
      _date = DateTime.now();
    }
  }

  String _trimAmount(double v) {
    if (v == v.truncateToDouble()) return v.truncate().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
        return;
      }
      if (key == '.') {
        if (_amountStr.contains('.')) return;
        _amountStr += '.';
        return;
      }
      if (_amountStr.contains('.')) {
        final decimals = _amountStr.split('.').last;
        if (decimals.length >= 2) return;
      }
      if (_amountStr.replaceAll('.', '').length >= 12) return;
      _amountStr = _amountStr == '0' ? key : _amountStr + key;
    });
  }

  double get _amount => double.tryParse(_amountStr) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.emerald,
            surface: Color(0xFF0E1626),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = _amount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    if (_categoryId == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a category and an account')),
      );
      return;
    }
    final now = DateTime.now();
    if (_isEdit) {
      final old = widget.existing!;
      final updated = Txn(
        id: old.id,
        amount: amount,
        kind: _kind,
        categoryId: _categoryId!,
        accountId: _accountId!,
        date: _date,
        note: _noteCtrl.text.trim(),
        createdAt: old.createdAt,
        updatedAt: now,
      );
      await HiveService.updateTxn(old, updated);
    } else {
      final t = Txn(
        id: Uuid().v4(),
        amount: amount,
        kind: _kind,
        categoryId: _categoryId!,
        accountId: _accountId!,
        date: _date,
        note: _noteCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await HiveService.addTxn(t);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit ? 'Transaction updated' : 'Transaction added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = HiveService.categories.values
        .where((c) => c.kind == _kind)
        .toList();
    if (_categoryId != null && cats.every((c) => c.id != _categoryId)) {
      _categoryId = cats.isNotEmpty ? cats.first.id : null;
    }
    final accounts = HiveService.accounts.values.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.6,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220).withOpacity(0.92),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit transaction' : 'New transaction',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // amount display
            GlassCard(
              radius: 20,
              child: Column(
                children: [
                  _kindToggle(),
                  const SizedBox(height: 10),
                  Text(
                    'Rs ${_amountStr.isEmpty ? '0' : _amountStr}',
                    style: moneyStyle(40,
                        color: _kind == 'income'
                            ? AppColors.emerald
                            : AppColors.textPrimary,
                        weight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _numpad(),
            const SizedBox(height: 16),
            const _Label('Category'),
            const SizedBox(height: 8),
            _categoryGrid(cats),
            const SizedBox(height: 16),
            const _Label('Account'),
            const SizedBox(height: 8),
            _accountChips(accounts),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateTile()),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _noteField()),
              ],
            ),
            const SizedBox(height: 20),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _kindToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _kindTab('expense', 'Expense', AppColors.danger),
          _kindTab('income', 'Income', AppColors.emerald),
        ],
      ),
    );
  }

  Widget _kindTab(String kind, String label, Color color) {
    final active = _kind == kind;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _kind = kind;
          _categoryId = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _numpad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final k = keys[i];
        return GestureDetector(
          onTap: () => _onKey(k),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Center(
              child: k == 'back'
                  ? const Icon(Icons.backspace_outlined,
                      color: AppColors.textSecondary, size: 22)
                  : Text(
                      k,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryGrid(List<Category> cats) {
    if (cats.isEmpty) {
      return const Text('No categories found',
          style: TextStyle(color: AppColors.textSecondary));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.92,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: cats.length,
      itemBuilder: (ctx, i) {
        final c = cats[i];
        final selected = c.id == _categoryId;
        final color = Color(c.color);
        return GestureDetector(
          onTap: () => setState(() => _categoryId = c.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.18)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? color.withOpacity(0.55)
                    : Colors.white.withOpacity(0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(appIcon(c.icon), color: color, size: 24),
                const SizedBox(height: 6),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _accountChips(List<Account> accounts) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final a = accounts[i];
          final selected = a.id == _accountId;
          final color = Color(a.color);
          return GestureDetector(
            onTap: () => setState(() => _accountId = a.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.18)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? color.withOpacity(0.55)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(appIcon(a.icon, Icons.wallet),
                      size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    a.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateTile() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dayLabel(_date),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _noteCtrl,
        style:
            const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Note (optional)',
          hintStyle:
              TextStyle(fontSize: 13, color: AppColors.textMuted),
          border: InputBorder.none,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _save,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _kind == 'income'
                ? const [Color(0xFF10B981), Color(0xFF0D9488)]
                : const [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (_kind == 'income'
                      ? AppColors.emerald
                      : AppColors.gold)
                  .withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          _isEdit ? 'Save changes' : 'Add ${_kind == 'income' ? 'income' : 'expense'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

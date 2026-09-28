import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../models/account.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../utils/icons.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_sheet.dart';

const _accountTypes = [
  ('cash', 'Cash'),
  ('bank', 'Bank'),
  ('jazzcash', 'JazzCash'),
  ('easypaisa', 'Easypaisa'),
  ('other', 'Other'),
];

const _swatches = [
  0xFF10B981,
  0xFF3B82F6,
  0xFF8B5CF6,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF22D3EE,
  0xFFF472B6,
  0xFF94A3B8,
];

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Accounts')),
      body: AnimatedBuilder(
        animation: HiveService.accounts.listenable(),
        builder: (context, _) {
          final accounts = HiveService.accounts.values.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              GlassCard(
                child: Row(
                  children: [
                    const Text(
                      'Net worth',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      // Net worth across all accounts, in base currency.
                      CurrencyService.format(
                        HiveService.accounts.values.fold(
                            0.0,
                            (s, a) => s +
                                CurrencyService.toBase(
                                    a.balance, a.currency)),
                        CurrencyService.baseCurrency,
                      ),
                      style: moneyStyle(22,
                          color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (accounts.isEmpty)
                const EmptyState(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'No accounts yet',
                  subtitle: 'Add your first wallet or bank account.',
                )
              else
                for (final a in accounts) _accountCard(context, a),
              const SizedBox(height: 8),
              _addButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _accountCard(BuildContext context, Account a) {
    final c = Color(a.color);
    final typeLabel = _accountTypes
        .firstWhere((t) => t.$1 == a.type, orElse: () => ('other', 'Other'))
        .$2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AccountDetailScreen(accountId: a.id)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.withOpacity(0.3)),
              ),
              child:
                  Icon(appIcon(a.icon, Icons.wallet), color: c, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$typeLabel • ${a.currency}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(CurrencyService.format(a.balance, a.currency),
                style: moneyStyle(17)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              color: const Color(0xFF0E1626),
              onSelected: (v) {
                if (v == 'edit') {
                  _accountDialog(context, existing: a);
                } else if (v == 'delete') {
                  _confirmDelete(context, a);
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
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _accountDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: AppColors.emerald, size: 20),
            SizedBox(width: 8),
            Text(
              'Add account',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accountDialog(BuildContext context,
      {Account? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'cash';
    int color = existing?.color ?? _swatches[0];
    String currency = existing?.currency ?? 'PKR';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'New account' : 'Edit account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Account name',
                    labelStyle:
                        TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Type',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0E1626),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  items: _accountTypes
                      .map((t) => DropdownMenuItem(
                          value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) =>
                      setS(() => type = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                const Text('Currency',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                DropdownButton<String>(
                  value: currency,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0E1626),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  items: CurrencyService.supported
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                                '$c (${CurrencyService.symbolOf(c)})'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setS(() => currency = v ?? 'PKR'),
                ),
                const SizedBox(height: 12),
                const Text('Color',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _swatches.map((s) {
                    final selected = s == color;
                    return GestureDetector(
                      onTap: () => setS(() => color = s),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(s),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final iconKey = type == 'other' ? 'wallet' : type;
                if (existing == null) {
                  final a = Account(
                    id: Uuid().v4(),
                    name: name,
                    type: type,
                    balance: 0,
                    color: color,
                    icon: iconKey,
                    createdAt: DateTime.now(),
                    currency: currency,
                  );
                  await HiveService.accounts.put(a.id, a);
                } else {
                  existing.name = name;
                  existing.type = type;
                  existing.color = color;
                  existing.icon = iconKey;
                  existing.currency = currency;
                  await HiveService.accounts
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
    nameCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Account a) async {
    final txnCount = HiveService.txns.values
        .where((t) => t.accountId == a.id)
        .length;
    final others =
        HiveService.accounts.values.where((x) => x.id != a.id).toList();
    String? moveTo = others.isNotEmpty ? others.first.id : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Delete "${a.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (txnCount > 0 && others.isNotEmpty) ...[
                Text(
                  '$txnCount transactions use this account. Move them to:',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: moveTo,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0E1626),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  items: others
                      .map((x) => DropdownMenuItem(
                          value: x.id, child: Text(x.name)))
                      .toList(),
                  onChanged: (v) => setS(() => moveTo = v),
                ),
              ] else if (txnCount > 0) ...[
                Text(
                  '$txnCount transactions use this account, and there is no other account to move them to. Add another account first.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ] else ...[
                const Text(
                  'This account has no transactions. It will be removed permanently.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
            if (!(txnCount > 0 && others.isEmpty))
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (txnCount > 0 && moveTo != null) {
      await HiveService.moveTxns(a.id, moveTo!);
    }
    await HiveService.accounts.delete(a.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
    }
  }
}

/// Per-account transaction history.
class AccountDetailScreen extends StatelessWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Account')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          HiveService.accounts.listenable(),
          HiveService.txns.listenable(),
        ]),
        builder: (context, _) {
          final a = HiveService.accounts.get(accountId);
          if (a == null) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Account not found',
              subtitle: 'It may have been deleted.',
            );
          }
          final c = Color(a.color);
          final list = HiveService.txnsForAccount(accountId);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(appIcon(a.icon, Icons.wallet),
                              color: c, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          a.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Balance',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    Text(CurrencyService.format(a.balance, a.currency),
                        style: moneyStyle(32,
                            weight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions',
                  subtitle:
                      'Nothing recorded on this account yet.',
                )
              else
                for (final t in list)
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
          );
        },
      ),
    );
  }
}

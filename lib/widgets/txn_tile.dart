import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../models/txn.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import 'glass_card.dart';

/// Shared transaction list row.
class TxnTile extends StatelessWidget {
  final Txn txn;
  final VoidCallback? onTap;

  const TxnTile({super.key, required this.txn, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = HiveService.categories.get(txn.categoryId);
    final acc = HiveService.accounts.get(txn.accountId);
    final catColor = Color(cat?.color ?? 0xFF94A3B8);
    final isIncome = txn.kind == 'income';
    final title =
        txn.note.isNotEmpty ? txn.note : (cat?.name ?? 'Transaction');
    // Amounts are stored in the account's own currency.
    final currency = acc?.currency ?? 'PKR';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 18,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: catColor.withOpacity(0.25)),
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
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.tTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${cat?.name ?? ''}  •  ${acc?.name ?? ''}  •  ${dayLabel(txn.date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome ? '+' : '-'}${CurrencyService.format(txn.amount, currency)}',
              style: moneyStyle(
                15,
                color:
                    isIncome ? AppColors.emerald : context.tTextPrimary,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

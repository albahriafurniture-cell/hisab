import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

/// Settings screen: pick the base currency and edit PKR-per-unit FX rates.
/// Glassmorphism; reactive via ValueListenableBuilder on the settings box.
class CurrencyScreen extends StatelessWidget {
  const CurrencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Currency')),
      body: ValueListenableBuilder(
        valueListenable: HiveService.settings.listenable(),
        builder: (context, _, __) {
          final base = CurrencyService.baseCurrency;
          final rates = CurrencyService.rates;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            children: [
              Text(
                'Base currency',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.tTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Totals and net worth are shown in this currency.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.tTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < CurrencyService.supported.length; i++)
                      _baseRow(context, CurrencyService.supported[i],
                          isLast: i ==
                              CurrencyService.supported.length - 1,
                          selected: base ==
                              CurrencyService.supported[i]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Exchange rates',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: context.tTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await CurrencyService.resetRates();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Rates reset to defaults')),
                        );
                      }
                    },
                    child: const Text('Reset to defaults',
                        style: TextStyle(color: AppColors.emerald)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rate = PKR per 1 unit of the currency. Tap a row to edit.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.tTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final code in CurrencyService.supported)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    onTap: () => _editRateDialog(context, code),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.emerald.withOpacity(0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            CurrencyService.symbolOf(code),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.tTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                code,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.tTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                code == 'PKR'
                                    ? 'Base unit (fixed at 1.0)'
                                    : 'Rs ${rates[code]!.toStringAsFixed(rates[code]! < 10 ? 2 : 1)} per $code',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.tTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_rounded,
                            color: context.tTextMuted, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _baseRow(BuildContext context, String code,
      {required bool isLast, required bool selected}) {
    return InkWell(
      onTap: () => CurrencyService.setBaseCurrency(code),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.08)),
                ),
              ),
        child: Row(
          children: [
            Text(
              CurrencyService.symbolOf(code),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.tTextPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              code,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.tTextPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? AppColors.emerald
                  : context.tTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRateDialog(BuildContext context, String code) async {
    if (code == 'PKR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PKR is the base unit — its rate is fixed at 1.0')),
      );
      return;
    }
    final ctrl = TextEditingController(
        text: CurrencyService.rate(code).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rate for $code',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'PKR per 1 unit',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.textMuted),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(color: AppColors.emerald)),
          ),
        ],
      ),
    );
    final raw = ctrl.text.trim();
    final v = double.tryParse(raw);
    ctrl.dispose();
    if (ok != true) return;
    if (v == null || v <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a positive number')),
        );
      }
      return;
    }
    await CurrencyService.setRate(code, v);
  }
}

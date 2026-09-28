import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/data_file.dart';
import '../data/hive_service.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import 'currency_screen.dart';
import 'lock_screen.dart' show hashPin;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Appearance'),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: HiveService.settings.listenable(),
            builder: (context, box, _) {
              final mode =
                  (box.get('themeMode') as String?) ?? 'dark';
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.tTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how the app looks',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _themeOption(context, 'dark', 'Dark',
                            Icons.dark_mode_rounded, mode == 'dark'),
                        const SizedBox(width: 8),
                        _themeOption(context, 'light', 'Light',
                            Icons.light_mode_rounded, mode == 'light'),
                        const SizedBox(width: 8),
                        _themeOption(context, 'system', 'System',
                            Icons.settings_suggest_rounded,
                            mode == 'system'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _sectionLabel('Preferences'),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: _row(
              context,
              icon: Icons.currency_exchange_rounded,
              color: AppColors.violet,
              title: 'Currency',
              subtitle: 'Base currency and exchange rates',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CurrencyScreen()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Security'),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: _row(
              context,
              icon: Icons.lock_rounded,
              color: AppColors.gold,
              title: 'Change PIN',
              subtitle: 'Update your 4-digit app lock',
              onTap: () => _changePinDialog(context),
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Backup & restore'),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  context,
                  icon: Icons.cloud_upload_rounded,
                  color: AppColors.emerald,
                  title: 'Backup data',
                  subtitle: 'Export everything to a JSON file',
                  onTap: () => _backup(context),
                ),
                _divider(),
                _row(
                  context,
                  icon: Icons.cloud_download_rounded,
                  color: AppColors.blue,
                  title: 'Restore data',
                  subtitle: 'Import from a backup file',
                  onTap: () => _restore(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Cloud sync'),
          const SizedBox(height: 8),
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.cloud_off_rounded,
                      color: AppColors.textMuted, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud sync',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Not configured — coming after Firebase setup',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('About'),
          const SizedBox(height: 8),
          const GlassCard(
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.emerald, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hisab',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 • Your data stays on your device',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _confirmWipe(context),
              child: const Text(
                'Erase all data',
                style: TextStyle(
                    color: AppColors.danger, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 64,
        color: Colors.white.withOpacity(0.07),
      );

  /// Segmented Dark | Light | System control. Uses theme-aware text colors
  /// so it reads correctly in both modes.
  Widget _themeOption(BuildContext context, String value, String label,
      IconData icon, bool selected) {
    final isDark = context.isDarkMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setThemeModeSetting(value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.emerald.withOpacity(0.16)
                : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFF0F172A).withOpacity(0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.emerald.withOpacity(0.45)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFF0F172A).withOpacity(0.10)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    selected ? AppColors.emerald : context.tTextSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.emerald : context.tTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ change PIN
  Future<void> _changePinDialog(BuildContext context) async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pinField(cur, 'Current PIN'),
            const SizedBox(height: 8),
            _pinField(next, 'New 4-digit PIN'),
            const SizedBox(height: 8),
            _pinField(confirm, 'Confirm new PIN'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final valid = hashPin(cur.text.trim()) ==
                      HiveService.pinHash &&
                  next.text.trim().length == 4 &&
                  next.text.trim() == confirm.text.trim() &&
                  RegExp(r'^\d{4}$').hasMatch(next.text.trim());
              Navigator.pop(ctx, valid);
              if (valid) {
                HiveService.setPinHash(hashPin(next.text.trim()));
              }
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.emerald)),
          ),
        ],
      ),
    );
    cur.dispose();
    next.dispose();
    confirm.dispose();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok == true
                ? 'PIN updated'
                : 'PIN not changed — check your entries')),
      );
    }
  }

  Widget _pinField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle:
            const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  // ----------------------------------------------------------------- backup

  Future<void> _backup(BuildContext context) async {
    try {
      final data = {
        'app': 'hisab',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'accounts': HiveService.accounts.values
            .map((a) => a.toJson())
            .toList(),
        'categories': HiveService.categories.values
            .map((c) => c.toJson())
            .toList(),
        'txns':
            HiveService.txns.values.map((t) => t.toJson()).toList(),
        'budgets': HiveService.budgets.values
            .map((b) => b.toJson())
            .toList(),
        'recurring': HiveService.recurring.values
            .map((r) => r.toJson())
            .toList(),
        'settings': {'pinHash': HiveService.pinHash},
      };
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final message = await saveTextFile(
          'backups', 'hisab-backup-$stamp.json', jsonEncode(data));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      if (kIsWeb) {
        // Web: pick a previously downloaded backup JSON file.
        final raw = await pickTextFile();
        if (raw == null) return; // user cancelled
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['app'] != 'hisab') {
          throw const FormatException('Not a Hisab backup file');
        }
        if (!context.mounted) return;
        await _confirmAndImport(context, data);
        return;
      }
      final files =
          await listStoredBackups('backups', 'hisab-backup-');
      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'No backups found. Create a backup first.')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      final picked = await showDialog<StoredBackup>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Choose backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (c, i) {
                final f = files[i];
                return ListTile(
                  title: Text(f.label,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(f.sizeLabel,
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
      if (picked == null || !context.mounted) return;
      final raw = await readStoredBackup('backups', picked);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['app'] != 'hisab') {
        throw const FormatException('Not a Hisab backup file');
      }
      if (!context.mounted) return;
      await _confirmAndImport(context, data);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  /// "Replace everything?" confirmation, then import.
  Future<void> _confirmAndImport(
      BuildContext context, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'This replaces ALL current data with the backup from '
          '${data['exportedAt'] ?? 'unknown time'}. This cannot be undone.',
        ),
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
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _importData(data);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored')),
      );
    }
  }

  Future<void> _importData(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> listOf(String key) =>
        ((data[key] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    await HiveService.accounts.clear();
    for (final j in listOf('accounts')) {
      final a = Account.fromJson(j);
      await HiveService.accounts.put(a.id, a);
    }
    await HiveService.categories.clear();
    for (final j in listOf('categories')) {
      final c = Category.fromJson(j);
      await HiveService.categories.put(c.id, c);
    }
    await HiveService.txns.clear();
    for (final j in listOf('txns')) {
      final t = Txn.fromJson(j);
      await HiveService.txns.put(t.id, t);
    }
    await HiveService.budgets.clear();
    for (final j in listOf('budgets')) {
      final b = Budget.fromJson(j);
      await HiveService.budgets.put(b.id, b);
    }
    await HiveService.recurring.clear();
    for (final j in listOf('recurring')) {
      final r = Recurring.fromJson(j);
      await HiveService.recurring.put(r.id, r);
    }
    final settings = data['settings'] as Map<String, dynamic>?;
    final pinHash = settings?['pinHash'] as String?;
    if (pinHash != null && pinHash.isNotEmpty) {
      await HiveService.setPinHash(pinHash);
    }
    // Re-seed if the backup was somehow empty, so the app stays usable.
    await HiveService.seedDefaults();
    // SyncService is dormant until Firebase is configured; referencing it
    // here keeps the import used and documents the future hookup point.
    debugPrint('Cloud sync status: ${SyncService.statusText}');
  }

  Future<void> _confirmWipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'Every account, transaction, budget and setting on this device '
          'will be permanently deleted.',
        ),
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
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.resetAll();
    }
  }
}

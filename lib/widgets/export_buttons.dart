import 'package:flutter/material.dart';

import '../services/export_service.dart';
import '../theme.dart';

/// Glass-style PDF/CSV export buttons for the Reports screen.
///
/// Renders two side-by-side buttons ("PDF", "CSV") that generate the
/// current month's report via [ExportService] and confirm the saved file
/// with a SnackBar. Shows a small spinner in the tapped button while the
/// export runs and disables both buttons meanwhile.
class ExportButtons extends StatefulWidget {
  /// Month to export, in "YYYY-MM" form (see `monthKey` in utils/format).
  final String monthKey;

  const ExportButtons({required this.monthKey, super.key});

  @override
  State<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<ExportButtons> {
  /// Which export is in flight: 'pdf', 'csv', or null when idle.
  String? _busy;

  Future<void> _export(String which) async {
    if (_busy != null) return; // one export at a time
    setState(() => _busy = which);
    try {
      final message = which == 'pdf'
          ? await ExportService.exportMonthPdf(widget.monthKey)
          : await ExportService.exportMonthCsv(widget.monthKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _glassButton(
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            accent: AppColors.emerald,
            loading: _busy == 'pdf',
            onTap: () => _export('pdf'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _glassButton(
            label: 'CSV',
            icon: Icons.table_chart_rounded,
            accent: AppColors.cyan,
            loading: _busy == 'csv',
            onTap: () => _export('csv'),
          ),
        ),
      ],
    );
  }

  /// Frosted-glass chip matching the app's card style (rounded 14).
  Widget _glassButton({
    required String label,
    required IconData icon,
    required Color accent,
    required bool loading,
    required VoidCallback onTap,
  }) {
    final disabled = _busy != null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled && !loading ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              else
                Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

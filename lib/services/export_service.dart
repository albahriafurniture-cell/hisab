import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/hive_service.dart';
import '../models/txn.dart';
import '../utils/data_file.dart';
import '../utils/format.dart';

/// Generates month-end PDF + CSV reports.
///
/// Native: saved into the app's `exports` folder (same browsable storage
/// area as the JSON backups: Android/data/com.hisab.finance/files/exports).
/// Web: downloaded through the browser.
///
/// Pure Dart only — the `pdf` and `csv` packages have no platform code — so
/// this works with the manual (Gradle-less) APK pipeline where
/// GeneratedPluginRegistrant is empty. No `printing`, no share sheets:
/// the file is written/downloaded and a message is surfaced via SnackBar.
class ExportService {
  // ------------------------------------------------------------------ paths

  // ------------------------------------------------------------ PDF styling

  // Clean light-document palette (dark theme can't translate to paper):
  // white page, dark slate text, Hisab emerald accents.
  static final _emeraldDark = PdfColor.fromHex('#065F46');
  static final _ink = PdfColor.fromHex('#0F172A');
  static final _muted = PdfColor.fromHex('#64748B');
  static final _line = PdfColor.fromHex('#E2E8F0');
  static const _pageMargin = pw.EdgeInsets.all(36);

  static pw.Widget _docTitle(String monthLabel) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Hisab',
              style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: _emeraldDark)),
          pw.SizedBox(height: 2),
          pw.Text('Monthly Report — $monthLabel',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink)),
          pw.SizedBox(height: 4),
          pw.Text(
              'Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())} • All amounts in PKR',
              style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      );

  static pw.Widget _sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _emeraldDark)),
      );

  static pw.Widget _summaryCard(String label, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
          ],
        ),
      ),
    );
  }

  static pw.Table _styledTable(
      List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: const pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 11),
      headerDecoration: pw.BoxDecoration(color: _emeraldDark),
      headerPadding: const pw.EdgeInsets.all(8),
      cellStyle: pw.TextStyle(fontSize: 10, color: _ink),
      cellPadding: const pw.EdgeInsets.all(8),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _line),
    );
  }

  // ------------------------------------------------------------ PDF export

  /// Builds a styled monthly report PDF and saves/downloads it.
  /// Returns a user-facing confirmation message.
  ///
  /// Contains: title + month label, Income / Expense / Net summary row,
  /// a "Spending by category" table (name, amount, % of expense), and a
  /// "Transactions" table (date, details, account, kind, amount).
  /// An empty month still produces a valid report with zeros and a
  /// "No transactions" note.
  static Future<String> exportMonthPdf(String monthKeyStr) async {
    final txns = HiveService.txnsForMonth(monthKeyStr);
    final income = HiveService.incomeForMonth(monthKeyStr);
    final expense = HiveService.expenseForMonth(monthKeyStr);
    final net = income - expense;
    final label = fullMonthLabel(monthKeyStr);

    final doc = pw.Document();

    // --- category breakdown (expenses only), biggest first
    final byCat = <String, double>{};
    for (final t in txns) {
      if (t.kind != 'expense') continue;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final catRows = sortedCats.map((e) {
      final cat = HiveService.categories.get(e.key);
      final pct = expense > 0 ? e.value / expense * 100 : 0.0;
      return [
        cat?.name ?? 'Unknown',
        formatMoney(e.value),
        '${pct.toStringAsFixed(1)}%',
      ];
    }).toList();

    // --- transaction rows, newest first (txnsForMonth is already sorted)
    final txnRows = txns.map((t) => _txnRow(t)).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        build: (context) => [
          _docTitle(label),
          pw.SizedBox(height: 16),
          pw.Row(children: [
            _summaryCard(
                'Income', formatMoney(income), _emeraldDark),
            pw.SizedBox(width: 10),
            _summaryCard('Expense', formatMoney(expense),
                PdfColor.fromHex('#B91C1C')),
            pw.SizedBox(width: 10),
            _summaryCard('Net', formatMoney(net),
                net >= 0 ? _emeraldDark : PdfColor.fromHex('#B91C1C')),
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('Spending by category'),
          if (catRows.isEmpty)
            pw.Text('No expenses this month.',
                style: pw.TextStyle(fontSize: 11, color: _muted))
          else
            _styledTable(
                ['Category', 'Amount', '% of spend'], catRows),
          pw.SizedBox(height: 20),
          _sectionTitle('Transactions'),
          if (txnRows.isEmpty)
            pw.Text('No transactions recorded this month.',
                style: pw.TextStyle(fontSize: 11, color: _muted))
          else
            _styledTable(
                ['Date', 'Details', 'Account', 'Kind', 'Amount'],
                txnRows),
          pw.SizedBox(height: 24),
          pw.Divider(color: _line),
          pw.Text(
              'Generated by Hisab • Offline-first personal finance',
              style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );

    return saveDataFile(
        'exports', 'hisab-report-$monthKeyStr.pdf', await doc.save());
  }

  /// One PDF table row per transaction: date, details (note, or category
  /// name when the note is empty), account, kind, amount.
  static List<String> _txnRow(Txn t) {
    final cat = HiveService.categories.get(t.categoryId);
    final acct = HiveService.accounts.get(t.accountId);
    final details = t.note.isNotEmpty ? t.note : (cat?.name ?? '—');
    final kindLabel = t.kind == 'income' ? 'Income' : 'Expense';
    return [
      dayLabel(t.date),
      details,
      acct?.name ?? '—',
      kindLabel,
      formatMoney(t.amount),
    ];
  }

  // ------------------------------------------------------------ CSV export

  /// Exports the month's transactions as CSV and saves/downloads it.
  /// Returns a user-facing confirmation message.
  ///
  /// Header: `date,kind,category,account,note,amount`.
  /// Notes are escaped by ListToCsvConverter (commas/quotes safe).
  /// An empty month yields a header-only file.
  static Future<String> exportMonthCsv(String monthKeyStr) async {
    final txns = HiveService.txnsForMonth(monthKeyStr);
    final rows = <List<dynamic>>[
      const ['date', 'kind', 'category', 'account', 'note', 'amount'],
      for (final t in txns)
        [
          DateFormat('yyyy-MM-dd').format(t.date),
          t.kind,
          HiveService.categories.get(t.categoryId)?.name ?? '',
          HiveService.accounts.get(t.accountId)?.name ?? '',
          t.note,
          t.amount.toStringAsFixed(2),
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);

    return saveTextFile(
        'exports', 'hisab-report-$monthKeyStr.csv', csv);
  }
}

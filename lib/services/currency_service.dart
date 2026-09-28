import '../data/hive_service.dart';

/// Multi-currency support for Hisab.
///
/// RATE CONVENTION: every rate is stored as **PKR per 1 unit of the currency**.
/// E.g. USD → 278.0 means 1 USD = Rs 278. PKR → 1.0 by definition.
///
/// Conversion math (all through the implicit PKR pivot):
///   convert(amount, from, to) = amount * rate(to) / rate(from)
/// Proof: amount_in_PKR = amount * rate(from); target_units = amount_in_PKR / rate(to).
///
/// Rates and the base currency live in [HiveService.settings]:
///   - 'fx_rates'     → Map<String, double> (per-currency PKR-per-unit rates)
///   - 'base_currency' → String ISO code, default 'PKR'
///
/// Base currency is what cross-currency totals (e.g. dashboard net worth)
/// are expressed in. Rates have sensible defaults and are user-editable on
/// the Currency settings screen.
class CurrencyService {
  static const List<String> supported = [
    'PKR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'SAR',
    'INR',
    'CNY',
  ];

  static const Map<String, String> symbols = {
    'PKR': 'Rs',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'SAR': 'ر.س',
    'INR': '₹',
    'CNY': '¥',
  };

  /// Default rates: PKR per 1 unit of the currency.
  static const Map<String, double> defaultRates = {
    'PKR': 1.0,
    'USD': 278.0,
    'EUR': 301.0,
    'GBP': 352.0,
    'AED': 75.7,
    'SAR': 74.1,
    'INR': 3.34,
    'CNY': 38.4,
  };

  static String symbolOf(String code) => symbols[code] ?? code;

  // ------------------------------------------------------------------ rates
  /// All current rates (PKR per 1 unit), merging stored overrides over defaults.
  static Map<String, double> get rates {
    final stored = HiveService.settings.get('fx_rates');
    final Map<String, double> out = Map.of(defaultRates);
    if (stored is Map) {
      for (final e in stored.entries) {
        final code = e.key.toString();
        final v = e.value is num ? (e.value as num).toDouble() : null;
        if (supported.contains(code) && v != null && v > 0) {
          out[code] = v;
        }
      }
    }
    return out;
  }

  /// Rate for [code]: PKR per 1 unit. Unknown codes fall back to 1.0 (PKR).
  static double rate(String code) => rates[code] ?? 1.0;

  static Future<void> setRate(String code, double value) async {
    if (!supported.contains(code) || value <= 0) return;
    final map = Map<String, double>.of(rates);
    map[code] = value;
    await HiveService.settings.put('fx_rates', map);
  }

  static Future<void> resetRates() async {
    await HiveService.settings.put('fx_rates', Map.of(defaultRates));
  }

  // ------------------------------------------------------------ base currency
  static String get baseCurrency =>
      (HiveService.settings.get('base_currency') as String?) ?? 'PKR';

  static Future<void> setBaseCurrency(String code) async {
    if (!supported.contains(code)) return;
    await HiveService.settings.put('base_currency', code);
  }

  // --------------------------------------------------------------- convert
  /// Converts [amount] from [from] currency to [to] currency.
  /// Convention: amount * rate(to) / rate(from)  (rates = PKR per 1 unit).
  static double convert(double amount, String from, String to) {
    if (from == to) return amount;
    final rFrom = rate(from);
    final rTo = rate(to);
    if (rFrom <= 0 || rTo <= 0) return amount;
    return amount * rTo / rFrom;
  }

  /// Converts [amount] in [from] currency into the base currency.
  static double toBase(double amount, String from) =>
      convert(amount, from, baseCurrency);

  // ----------------------------------------------------------------- format
  /// Formats [amount] in [code] with Pakistani (lakh/crore) grouping:
  /// "Rs 1,25,000", "\$ 2,50,000", "€ 1,00,000", etc.
  static String format(double amount, String code) {
    final symbol = symbolOf(code);
    final negative = amount < 0;
    final abs = amount.abs();
    var intPart = abs.truncate();
    var frac = ((abs - intPart) * 100).round();
    if (frac == 100) {
      intPart += 1;
      frac = 0;
    }
    final grouped = _groupPakistani(intPart.toString());
    final sign = negative ? '-' : '';
    if (frac == 0) return '$symbol $sign$grouped';
    return '$symbol $sign$grouped.${frac.toString().padLeft(2, '0')}';
  }

  /// Formats [amount] converted into the base currency.
  static String formatBase(double amount, String from) =>
      format(convert(amount, from, baseCurrency), baseCurrency);
}

/// Pakistani (lakh/crore) digit grouping: 1,25,000 / 2,50,00,000.
/// Mirrors the algorithm in utils/format.dart (kept local so format.dart stays untouched).
String _groupPakistani(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  parts.add(last3);
  return parts.join(',');
}

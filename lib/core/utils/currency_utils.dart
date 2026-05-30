import 'package:intl/intl.dart';

class CurrencyUtils {
  static final _mxnFmt = NumberFormat.currency(
      locale: 'es_MX', symbol: '\$', decimalDigits: 2);
  static final _usdFmt = NumberFormat.currency(
      locale: 'en_US', symbol: 'US\$', decimalDigits: 2);

  // Formatea un monto con su símbolo y sufijo de divisa.
  static String format(double amount, String currency) {
    return currency == 'USD'
        ? '${_usdFmt.format(amount)} USD'
        : '${_mxnFmt.format(amount)} MXN';
  }

  // Solo símbolo + número, sin sufijo.
  static String formatShort(double amount, String currency) {
    return currency == 'USD'
        ? _usdFmt.format(amount)
        : _mxnFmt.format(amount);
  }

  // Convierte a la divisa base usando aritmética de enteros para evitar
  // errores de punto flotante (opera en centavos).
  static double toBaseCurrency({
    required double amount,
    required String fromCurrency,
    required String baseCurrency,
    required double usdToMxnRate,
  }) {
    if (fromCurrency == baseCurrency) return _round(amount);

    if (fromCurrency == 'USD' && baseCurrency == 'MXN') {
      // cents_usd * rate → centavos_mxn
      final centavos = (amount * 100).round();
      final rateX100 = (usdToMxnRate * 100).round();
      return _round((centavos * rateX100) / 10000.0);
    }

    if (fromCurrency == 'MXN' && baseCurrency == 'USD') {
      final centavos = (amount * 100).round();
      final rateX100 = (usdToMxnRate * 100).round();
      return _round((centavos * 10000.0) / rateX100);
    }

    return _round(amount);
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static String currencySymbol(String currency) =>
      currency == 'USD' ? 'US\$' : '\$';

  static String currencyFlag(String currency) =>
      currency == 'USD' ? '🇺🇸' : '🇲🇽';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';

// 1 USD = X MXN  — actualiza llamando ref.read(exchangeRateProvider.notifier).state = nuevoTipo
final exchangeRateProvider = StateProvider<double>(
  (_) => AppConfig.defaultExchangeRate,
);

// Divisa base del usuario para el balance consolidado
final baseCurrencyProvider = StateProvider<String>(
  (_) => AppConfig.baseCurrency,
);

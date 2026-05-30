// ══════════════════════════════════════════════════════
//  CONFIGURACIÓN — Coloca aquí tus credenciales de Supabase
//  Dashboard → Settings → API
// ══════════════════════════════════════════════════════
class AppConfig {
  static const String supabaseUrl = 'https://rstccscqlcuovaluhnjw.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_rc2J5KFEXdwwnokAWZcXeQ_30sJoYrb';

  // Divisa base para el balance consolidado ('MXN' o 'USD')
  static const String baseCurrency = 'MXN';

  // Tipo de cambio inicial: 1 USD = X MXN
  // Se puede actualizar dinámicamente desde ExchangeRateProvider
  static const double defaultExchangeRate = 17.50;
}

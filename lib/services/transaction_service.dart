import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';

/// Resumen mensual para la gráfica de tendencia.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.gastos,
    required this.ingresos,
  });
  final DateTime month;   // primer día del mes
  final double gastos;    // en MXN
  final double ingresos;  // en MXN
}

class TransactionService {
  const TransactionService(this._client);

  final SupabaseClient _client;

  /// Obtiene transacciones del mes especificado (UTC).
  Future<List<Transaction>> fetchByMonth(int year, int month) async {
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear  = month == 12 ? year + 1 : year;
    final from = DateTime.utc(year, month, 1).toIso8601String();
    final to   = DateTime.utc(nextYear, nextMonth, 1).toIso8601String();

    final data = await _client
        .from('transacciones')
        .select('*, cuentas(*), categorias(*)')
        .gte('fecha', from)
        .lt('fecha', to)
        .order('fecha', ascending: false);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  /// Resumen de los últimos 6 meses para la gráfica de tendencia.
  Future<List<MonthSummary>> fetchSixMonthSummary() async {
    final now     = DateTime.now();
    final sixAgo  = DateTime(now.year, now.month - 5);
    final from    = DateTime.utc(sixAgo.year, sixAgo.month, 1).toIso8601String();

    final data = await _client
        .from('transacciones')
        .select('monto, divisa, tipo_cambio, fecha, categorias(tipo)')
        .gte('fecha', from)
        .order('fecha', ascending: true);

    // Agrupar por mes: [gastos, ingresos]
    final Map<String, List<double>> byMonth = {};

    for (final row in data as List) {
      final cat    = row['categorias'];
      final tipo   = cat != null ? (cat['tipo'] as String? ?? '') : '';
      final monto  = (row['monto'] as num).toDouble();
      final divisa = row['divisa'] as String;
      final tc     = (row['tipo_cambio'] as num?)?.toDouble() ?? 1.0;
      final mxn    = divisa == 'MXN' ? monto : monto * tc;
      final fecha  = DateTime.parse(row['fecha'] as String).toLocal();
      final key    = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

      byMonth.putIfAbsent(key, () => [0.0, 0.0]);
      if (tipo == 'gasto') {
        byMonth[key]![0] += mxn;
      } else {
        byMonth[key]![1] += mxn;
      }
    }

    // Rellenar los 6 meses (incluyendo meses vacíos)
    final result = <MonthSummary>[];
    for (int i = 5; i >= 0; i--) {
      final m   = DateTime(now.year, now.month - i);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final d   = byMonth[key] ?? [0.0, 0.0];
      result.add(MonthSummary(
        month:    DateTime(m.year, m.month),
        gastos:   d[0],
        ingresos: d[1],
      ));
    }
    return result;
  }

  Future<void> delete(int id) async {
    await _client.from('transacciones').delete().eq('id', id);
  }

  Future<Transaction> insert(Transaction tx) async {
    final data = await _client
        .from('transacciones')
        .insert(tx.toJson())
        .select('*, cuentas(*), categorias(*)')
        .single();
    return Transaction.fromJson(data);
  }

  Future<Transaction> update(Transaction tx) async {
    final data = await _client
        .from('transacciones')
        .update(tx.toJson())
        .eq('id', tx.id!)
        .select('*, cuentas(*), categorias(*)')
        .single();
    return Transaction.fromJson(data);
  }
}

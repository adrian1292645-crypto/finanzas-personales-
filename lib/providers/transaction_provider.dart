import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'account_provider.dart';
import 'exchange_rate_provider.dart';
import 'service_providers.dart';

/// Mes que se muestra en dashboard y estadísticas.
final selectedMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);

/// Texto de búsqueda para filtrar transacciones.
final searchQueryProvider = StateProvider<String>((_) => '');

/// Tendencia de los últimos 6 meses.
final trendProvider = FutureProvider<List<MonthSummary>>((ref) {
  return ref.read(transactionServiceProvider).fetchSixMonthSummary();
});

/// Lista filtrada según [searchQueryProvider].
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final txs   = ref.watch(transactionProvider).valueOrNull ?? [];
  if (query.isEmpty) return txs;
  return txs.where((t) {
    return (t.categoria?.nombre.toLowerCase().contains(query) ?? false) ||
           (t.cuenta?.nombre.toLowerCase().contains(query) ?? false) ||
           (t.nota?.toLowerCase().contains(query) ?? false) ||
           t.etiquetas.toLowerCase().contains(query);
  }).toList();
});

// ─────────────────────────────────────────────────────────────

class TransactionNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() {
    final month = ref.watch(selectedMonthProvider);
    return ref
        .read(transactionServiceProvider)
        .fetchByMonth(month.year, month.month);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final month = ref.read(selectedMonthProvider);
    state = await AsyncValue.guard(
      () => ref
          .read(transactionServiceProvider)
          .fetchByMonth(month.year, month.month),
    );
  }

  Future<void> deleteTransaction(int id,
      {required int cuentaId,
      required double monto,
      required String tipo}) async {
    await ref.read(transactionServiceProvider).delete(id);

    final delta = tipo == 'gasto' ? monto : -monto;
    await ref.read(accountProvider.notifier).applyDelta(cuentaId, delta);

    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }

  Future<void> updateTransaction({
    required Transaction oldTx,
    required int cuentaId,
    required int categoriaId,
    required double monto,
    required String tipo,
    required String divisa,
    String? nota,
    bool esRecurrente = false,
    String etiquetas = '',
  }) async {
    final rate = ref.read(exchangeRateProvider);

    // 1. Revertir impacto anterior en la cuenta original
    final oldDelta = oldTx.esGasto ? oldTx.monto : -oldTx.monto;
    await ref
        .read(accountProvider.notifier)
        .applyDelta(oldTx.cuentaId, oldDelta);

    // 2. Persistir la transacción actualizada
    final updated = Transaction(
      id:           oldTx.id,
      cuentaId:     cuentaId,
      categoriaId:  categoriaId,
      monto:        monto,
      divisa:       divisa,
      tipoCambio:   rate,
      fecha:        oldTx.fecha,
      nota:         nota,
      esRecurrente: esRecurrente,
      etiquetas:    etiquetas,
    );
    final saved =
        await ref.read(transactionServiceProvider).update(updated);

    // 3. Aplicar nuevo impacto en la cuenta (puede ser diferente)
    final newDelta = tipo == 'gasto' ? -monto : monto;
    await ref
        .read(accountProvider.notifier)
        .applyDelta(cuentaId, newDelta);

    // 4. Actualizar lista local
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((t) => t.id == oldTx.id ? saved : t).toList(),
    );
  }

  Future<void> addTransaction({
    required int cuentaId,
    required int categoriaId,
    required double monto,
    required String tipo,
    required String divisa,
    String? nota,
    bool esRecurrente = false,
    String etiquetas = '',
    DateTime? fecha,
  }) async {
    final rate = ref.read(exchangeRateProvider);

    final tx = Transaction(
      cuentaId:     cuentaId,
      categoriaId:  categoriaId,
      monto:        monto,
      divisa:       divisa,
      tipoCambio:   rate,
      fecha:        fecha ?? DateTime.now(),
      nota:         nota,
      esRecurrente: esRecurrente,
      etiquetas:    etiquetas,
    );

    final saved =
        await ref.read(transactionServiceProvider).insert(tx);

    final delta = tipo == 'gasto' ? -monto : monto;
    await ref
        .read(accountProvider.notifier)
        .applyDelta(cuentaId, delta);

    // Solo agrega a la lista si pertenece al mes visualizado
    final selMonth = ref.read(selectedMonthProvider);
    final sameMonth = saved.fecha.year == selMonth.year &&
        saved.fecha.month == selMonth.month;
    if (sameMonth) {
      final current = state.valueOrNull ?? [];
      state = AsyncData([saved, ...current]);
    }
  }

  /// Copia las transacciones recurrentes del mes anterior al mes actual.
  /// Devuelve el número de transacciones insertadas.
  Future<int> insertRecurrentes() async {
    final now     = DateTime.now();
    final prev    = DateTime(now.year, now.month - 1);
    final service = ref.read(transactionServiceProvider);

    final prevTxs    = await service.fetchByMonth(prev.year, prev.month);
    final recurrentes = prevTxs.where((t) => t.esRecurrente).toList();

    for (final tx in recurrentes) {
      final day     = tx.fecha.day.clamp(1, 28);
      final newDate = DateTime(now.year, now.month, day);

      final copy = Transaction(
        cuentaId:     tx.cuentaId,
        categoriaId:  tx.categoriaId,
        monto:        tx.monto,
        divisa:       tx.divisa,
        tipoCambio:   tx.tipoCambio,
        fecha:        newDate,
        nota:         tx.nota,
        esRecurrente: true,
        etiquetas:    tx.etiquetas,
      );

      final saved = await service.insert(copy);
      final delta = tx.esGasto ? -tx.monto : tx.monto;
      await ref
          .read(accountProvider.notifier)
          .applyDelta(tx.cuentaId, delta);

      final selMonth  = ref.read(selectedMonthProvider);
      final sameMonth = saved.fecha.year == selMonth.year &&
          saved.fecha.month == selMonth.month;
      if (sameMonth) {
        final current = state.valueOrNull ?? [];
        state = AsyncData([saved, ...current]);
      }
    }

    return recurrentes.length;
  }
}

final transactionProvider =
    AsyncNotifierProvider<TransactionNotifier, List<Transaction>>(
  TransactionNotifier.new,
);

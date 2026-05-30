import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import 'service_providers.dart';

class AccountNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() {
    return ref.read(accountServiceProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(accountServiceProvider).fetchAll(),
    );
  }

  // Actualización optimista: modifica el estado local inmediatamente
  // y luego persiste en Supabase para que la UI no espere la red.
  Future<void> applyDelta(int accountId, double delta) async {
    final accounts = state.valueOrNull ?? [];

    final updated = accounts.map((a) {
      if (a.id != accountId) return a;
      final newBalance = double.parse(
        (a.saldoActual + delta).toStringAsFixed(2),
      );
      return a.copyWith(saldoActual: newBalance);
    }).toList();

    state = AsyncData(updated);

    final account = updated.firstWhere((a) => a.id == accountId);
    await ref
        .read(accountServiceProvider)
        .updateBalance(accountId, account.saldoActual);
  }
}

final accountProvider =
    AsyncNotifierProvider<AccountNotifier, List<Account>>(
  AccountNotifier.new,
);

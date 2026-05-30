import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deuda.dart';
import 'service_providers.dart';

class DeudaNotifier extends AsyncNotifier<List<Deuda>> {
  @override
  Future<List<Deuda>> build() =>
      ref.read(deudaServiceProvider).fetchAll();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
        () => ref.read(deudaServiceProvider).fetchAll());
  }

  Future<void> create(Deuda deuda) async {
    await ref.read(deudaServiceProvider).create(deuda);
    await refresh();
  }

  Future<void> updateDeuda(Deuda deuda) async {
    await ref.read(deudaServiceProvider).update(deuda);
    await refresh();
  }

  Future<void> deleteDeuda(int id) async {
    await ref.read(deudaServiceProvider).delete(id);
    await refresh();
  }
}

final deudaProvider =
    AsyncNotifierProvider<DeudaNotifier, List<Deuda>>(DeudaNotifier.new);

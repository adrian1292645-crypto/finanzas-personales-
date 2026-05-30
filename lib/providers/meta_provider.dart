import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meta.dart';
import 'service_providers.dart';

class MetaNotifier extends AsyncNotifier<List<Meta>> {
  @override
  Future<List<Meta>> build() => ref.read(metaServiceProvider).fetchAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(metaServiceProvider).fetchAll(),
    );
  }

  Future<void> create(Meta meta) async {
    final saved = await ref.read(metaServiceProvider).create(meta);
    state = AsyncData([...state.valueOrNull ?? [], saved]);
  }

  Future<void> updateMeta(Meta meta) async {
    final saved = await ref.read(metaServiceProvider).update(meta);
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((m) => m.id == meta.id ? saved : m).toList(),
    );
  }

  Future<void> deleteMeta(int id) async {
    await ref.read(metaServiceProvider).delete(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((m) => m.id != id).toList());
  }
}

final metaProvider =
    AsyncNotifierProvider<MetaNotifier, List<Meta>>(MetaNotifier.new);

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meta.dart';

class MetaService {
  const MetaService(this._client);
  final SupabaseClient _client;

  Future<List<Meta>> fetchAll() async {
    final data = await _client
        .from('metas')
        .select()
        .eq('activa', true)
        .order('id', ascending: true);
    return (data as List).map((e) => Meta.fromJson(e)).toList();
  }

  Future<Meta> create(Meta meta) async {
    final data = await _client
        .from('metas')
        .insert(meta.toJson())
        .select()
        .single();
    return Meta.fromJson(data);
  }

  Future<Meta> update(Meta meta) async {
    final data = await _client
        .from('metas')
        .update(meta.toJson())
        .eq('id', meta.id!)
        .select()
        .single();
    return Meta.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _client.from('metas').delete().eq('id', id);
  }
}

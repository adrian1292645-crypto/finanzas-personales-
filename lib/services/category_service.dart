import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryService {
  const CategoryService(this._client);

  final SupabaseClient _client;

  Future<List<Category>> fetchAll() async {
    final data = await _client
        .from('categorias')
        .select()
        .order('nombre', ascending: true);
    return _buildHierarchy(
      (data as List).map((e) => Category.fromJson(e)).toList(),
    );
  }

  /// Devuelve categorías padre con sus subcategorías embebidas.
  /// Actualiza el límite mensual de una categoría (null = sin límite).
  Future<void> updateLimit(int id, double? limit) async {
    await _client
        .from('categorias')
        .update({'limite_mensual': limit})
        .eq('id', id);
  }

  Future<List<Category>> fetchByType(String tipo) async {
    final data = await _client
        .from('categorias')
        .select()
        .eq('tipo', tipo)
        .order('nombre', ascending: true);

    return _buildHierarchy(
      (data as List).map((e) => Category.fromJson(e)).toList(),
    );
  }

  /// Organiza la lista plana en padres con hijos embebidos.
  List<Category> _buildHierarchy(List<Category> flat) {
    final parents  = flat.where((c) => c.parentId == null).toList();
    final children = flat.where((c) => c.parentId != null).toList();

    return parents.map((p) {
      final subs = children.where((c) => c.parentId == p.id).toList();
      return subs.isEmpty ? p : p.copyWith(subcategorias: subs);
    }).toList();
  }
}

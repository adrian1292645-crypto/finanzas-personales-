// Tabla: categorias
class Category {
  const Category({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.icono,
    this.parentId,
    this.subcategorias = const [],
    this.limiteMensual,
  });

  final int id;
  final String nombre;
  final String tipo;            // 'ingreso' | 'gasto'
  final String icono;
  final int? parentId;          // null = categoría padre
  final List<Category> subcategorias;
  final double? limiteMensual;

  bool get isParent        => parentId == null;
  bool get hasSubcategories => subcategorias.isNotEmpty;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id:            json['id'] as int,
        nombre:        json['nombre'] as String,
        tipo:          json['tipo'] as String,
        icono:         (json['icono'] as String?) ?? '💸',
        parentId:      json['parent_id'] as int?,
        limiteMensual: json['limite_mensual'] != null
            ? (json['limite_mensual'] as num).toDouble()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'tipo':   tipo,
        'icono':  icono,
        if (parentId != null)      'parent_id':      parentId,
        if (limiteMensual != null) 'limite_mensual': limiteMensual,
      };

  Category copyWith({List<Category>? subcategorias}) => Category(
        id:            id,
        nombre:        nombre,
        tipo:          tipo,
        icono:         icono,
        parentId:      parentId,
        subcategorias: subcategorias ?? this.subcategorias,
        limiteMensual: limiteMensual,
      );
}

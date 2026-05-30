// Tabla: metas (metas de ahorro)
class Meta {
  const Meta({
    this.id,
    required this.nombre,
    required this.montoMeta,
    required this.montoActual,
    required this.divisa,
    this.fechaLimite,
    this.activa = true,
    this.icono = '🎯',
  });

  final int? id;
  final String nombre;
  final double montoMeta;
  final double montoActual;
  final String divisa;
  final DateTime? fechaLimite;
  final bool activa;
  final String icono;

  double get progreso =>
      montoMeta > 0 ? (montoActual / montoMeta).clamp(0.0, 1.0) : 0.0;
  bool get completada => montoActual >= montoMeta;
  double get faltante =>
      (montoMeta - montoActual).clamp(0.0, double.infinity);

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
        id:          json['id'] as int?,
        nombre:      json['nombre'] as String,
        montoMeta:   (json['monto_meta'] as num).toDouble(),
        montoActual: (json['monto_actual'] as num?)?.toDouble() ?? 0,
        divisa:      json['divisa'] as String? ?? 'MXN',
        fechaLimite: json['fecha_limite'] != null
            ? DateTime.tryParse(json['fecha_limite'] as String)
            : null,
        activa: json['activa'] as bool? ?? true,
        icono:  json['icono'] as String? ?? '🎯',
      );

  Map<String, dynamic> toJson() => {
        'nombre':       nombre,
        'monto_meta':   montoMeta,
        'monto_actual': montoActual,
        'divisa':       divisa,
        'activa':       activa,
        'icono':        icono,
        if (fechaLimite != null)
          'fecha_limite':
              '${fechaLimite!.year.toString().padLeft(4, '0')}-'
              '${fechaLimite!.month.toString().padLeft(2, '0')}-'
              '${fechaLimite!.day.toString().padLeft(2, '0')}',
      };

  Meta copyWith({
    String? nombre,
    double? montoMeta,
    double? montoActual,
    String? divisa,
    String? icono,
    bool? activa,
  }) =>
      Meta(
        id:          id,
        nombre:      nombre ?? this.nombre,
        montoMeta:   montoMeta ?? this.montoMeta,
        montoActual: montoActual ?? this.montoActual,
        divisa:      divisa ?? this.divisa,
        fechaLimite: fechaLimite,
        activa:      activa ?? this.activa,
        icono:       icono ?? this.icono,
      );
}

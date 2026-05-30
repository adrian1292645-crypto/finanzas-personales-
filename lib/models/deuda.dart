import 'dart:math' as math;

class Deuda {
  const Deuda({
    this.id,
    required this.nombre,
    required this.montoTotal,
    required this.montoActual,
    this.tasaInteres = 0,
    this.pagoMinimo = 0,
    this.divisa = 'MXN',
    this.fechaCorte,
    this.icono = '💳',
  });

  final int?     id;
  final String   nombre;
  final double   montoTotal;   // Deuda original
  final double   montoActual;  // Saldo pendiente
  final double   tasaInteres;  // Tasa anual %
  final double   pagoMinimo;   // Pago mínimo mensual
  final String   divisa;
  final DateTime? fechaCorte;  // Fecha de corte / vencimiento
  final String   icono;

  // % liquidado
  double get progreso => montoTotal > 0
      ? ((montoTotal - montoActual) / montoTotal).clamp(0.0, 1.0)
      : 0.0;

  bool get pagada => montoActual <= 0;

  // Interés que se acumula en un mes
  double get interesMensual =>
      tasaInteres > 0 ? montoActual * (tasaInteres / 100 / 12) : 0;

  // Meses para liquidar pagando el mínimo
  int? get mesesParaPagar {
    if (pagoMinimo <= 0 || montoActual <= 0) return null;
    if (tasaInteres <= 0) return (montoActual / pagoMinimo).ceil();
    final r     = tasaInteres / 100 / 12;
    final ratio = r * montoActual / pagoMinimo;
    if (ratio >= 1) return null; // El pago mínimo no cubre ni el interés
    return (-math.log(1 - ratio) / math.log(1 + r)).ceil();
  }

  factory Deuda.fromJson(Map<String, dynamic> json) => Deuda(
        id:           json['id'] as int?,
        nombre:       json['nombre'] as String,
        montoTotal:   (json['monto_total'] as num).toDouble(),
        montoActual:  (json['monto_actual'] as num).toDouble(),
        tasaInteres:  (json['tasa_interes'] as num?)?.toDouble() ?? 0,
        pagoMinimo:   (json['pago_minimo'] as num?)?.toDouble() ?? 0,
        divisa:       json['divisa'] as String? ?? 'MXN',
        fechaCorte: json['fecha_corte'] != null
            ? DateTime.parse(json['fecha_corte'] as String)
            : null,
        icono: json['icono'] as String? ?? '💳',
      );

  Map<String, dynamic> toJson() => {
        'nombre':       nombre,
        'monto_total':  montoTotal,
        'monto_actual': montoActual,
        'tasa_interes': tasaInteres,
        'pago_minimo':  pagoMinimo,
        'divisa':       divisa,
        'fecha_corte':  fechaCorte?.toIso8601String().substring(0, 10),
        'icono':        icono,
      };

  Deuda copyWith({
    int? id, String? nombre, double? montoTotal, double? montoActual,
    double? tasaInteres, double? pagoMinimo, String? divisa,
    DateTime? fechaCorte, String? icono,
  }) => Deuda(
        id:           id ?? this.id,
        nombre:       nombre ?? this.nombre,
        montoTotal:   montoTotal ?? this.montoTotal,
        montoActual:  montoActual ?? this.montoActual,
        tasaInteres:  tasaInteres ?? this.tasaInteres,
        pagoMinimo:   pagoMinimo ?? this.pagoMinimo,
        divisa:       divisa ?? this.divisa,
        fechaCorte:   fechaCorte ?? this.fechaCorte,
        icono:        icono ?? this.icono,
      );
}

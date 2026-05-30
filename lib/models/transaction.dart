import 'account.dart';
import 'category.dart';

// Tabla: transacciones
class Transaction {
  const Transaction({
    this.id,
    required this.cuentaId,
    required this.categoriaId,
    required this.monto,
    required this.divisa,
    required this.tipoCambio,
    required this.fecha,
    this.nota,
    this.cuenta,
    this.categoria,
    this.esRecurrente = false,
    this.etiquetas = '',
  });

  final int? id;
  final int cuentaId;
  final int categoriaId;
  final double monto;
  final String divisa;       // 'USD' | 'MXN'
  final double tipoCambio;   // tasa USD→MXN al momento de registrar
  final DateTime fecha;
  final String? nota;
  final Account? cuenta;
  final Category? categoria;
  final bool esRecurrente;
  final String etiquetas;    // coma-separado: "comida,fijo,trabajo"

  bool get esGasto   => categoria?.tipo == 'gasto';
  bool get esIngreso => categoria?.tipo == 'ingreso';

  /// Lista de etiquetas parseada y limpia
  List<String> get tagList {
    if (etiquetas.isEmpty) return [];
    return etiquetas
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final cuentaData    = json['cuentas'];
    final categoriaData = json['categorias'];
    return Transaction(
      id:           json['id'] as int?,
      cuentaId:     json['cuenta_id'] as int,
      categoriaId:  json['categoria_id'] as int,
      monto:        (json['monto'] as num).toDouble(),
      divisa:       json['divisa'] as String,
      tipoCambio:   (json['tipo_cambio'] as num?)?.toDouble() ?? 1.0,
      fecha:        DateTime.parse(json['fecha'] as String).toLocal(),
      nota:         json['nota'] as String?,
      esRecurrente: json['es_recurrente'] as bool? ?? false,
      etiquetas:    json['etiquetas'] as String? ?? '',
      cuenta: cuentaData != null
          ? Account.fromJson(cuentaData as Map<String, dynamic>)
          : null,
      categoria: categoriaData != null
          ? Category.fromJson(categoriaData as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'cuenta_id':     cuentaId,
        'categoria_id':  categoriaId,
        'monto':         monto,
        'divisa':        divisa,
        'tipo_cambio':   tipoCambio,
        'fecha':         fecha.toIso8601String(),
        'es_recurrente': esRecurrente,
        'etiquetas':     etiquetas,
        if (nota != null && nota!.isNotEmpty) 'nota': nota,
      };
}

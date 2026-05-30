// Tabla: cuentas
class Account {
  const Account({
    required this.id,
    required this.nombre,
    required this.divisa,
    required this.saldoActual,
  });

  final int id;
  final String nombre;
  final String divisa;      // 'USD' | 'MXN'
  final double saldoActual;

  Account copyWith({double? saldoActual}) => Account(
        id: id,
        nombre: nombre,
        divisa: divisa,
        saldoActual: saldoActual ?? this.saldoActual,
      );

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        divisa: json['divisa'] as String,
        saldoActual: (json['saldo_actual'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'divisa': divisa,
        'saldo_actual': saldoActual,
      };

  @override
  String toString() => 'Account($id, $nombre, $divisa, $saldoActual)';
}

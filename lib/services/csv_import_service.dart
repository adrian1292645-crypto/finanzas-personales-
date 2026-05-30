class CsvRow {
  const CsvRow({
    required this.fecha,
    required this.descripcion,
    required this.monto,
    required this.esGasto,
  });
  final DateTime fecha;
  final String   descripcion;
  final double   monto;
  final bool     esGasto;
}

class CsvImportService {
  /// Parsea el contenido de un CSV bancario.
  /// Soporta formatos BBVA, Banamex y genérico.
  static List<CsvRow> parse(String csv) {
    final lines = csv
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final header = lines.first.toLowerCase();

    if (header.contains('retiro') || header.contains('cargo')) {
      return _parseMexicanBank(lines.skip(1).toList());
    }
    return _parseGeneric(lines.skip(1).toList());
  }

  /// BBVA / Banamex / Santander:
  /// Fecha, Descripción, Retiro (o Cargo), Depósito (o Abono), Saldo
  static List<CsvRow> _parseMexicanBank(List<String> lines) {
    final rows = <CsvRow>[];
    for (final line in lines) {
      final parts = _split(line);
      if (parts.length < 4) continue;
      final fecha = _parseDate(parts[0].trim());
      if (fecha == null) continue;
      final desc    = parts[1].trim().replaceAll('"', '');
      final retiro  = _parseNum(parts[2]);
      final deposito = _parseNum(parts[3]);
      if (retiro > 0) {
        rows.add(CsvRow(fecha: fecha, descripcion: desc, monto: retiro, esGasto: true));
      } else if (deposito > 0) {
        rows.add(CsvRow(fecha: fecha, descripcion: desc, monto: deposito, esGasto: false));
      }
    }
    return rows;
  }

  /// Formato genérico: Fecha, Descripción, Monto (negativo = gasto)
  static List<CsvRow> _parseGeneric(List<String> lines) {
    final rows = <CsvRow>[];
    for (final line in lines) {
      final parts = _split(line);
      if (parts.length < 3) continue;
      final fecha = _parseDate(parts[0].trim());
      if (fecha == null) continue;
      final desc  = parts[1].trim().replaceAll('"', '');
      final raw   = _parseNum(parts[2]) * (parts[2].trim().startsWith('-') ? -1 : 1);
      rows.add(CsvRow(
        fecha:       fecha,
        descripcion: desc,
        monto:       raw.abs(),
        esGasto:     raw <= 0,
      ));
    }
    return rows;
  }

  static List<String> _split(String line) {
    final result  = <String>[];
    var inQuotes  = false;
    final current = StringBuffer();
    for (final char in line.split('')) {
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if ((char == ',' || char == ';') && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  static double _parseNum(String s) {
    final clean = s.trim().replaceAll('"', '').replaceAll(',', '').replaceAll(r'$', '');
    return double.tryParse(clean) ?? 0;
  }

  static DateTime? _parseDate(String s) {
    s = s.replaceAll('"', '').trim();
    try {
      // dd/MM/yyyy or d/M/yyyy
      if (s.contains('/')) {
        final p = s.split('/');
        if (p.length == 3) {
          final day   = int.parse(p[0]);
          final month = int.parse(p[1]);
          var   year  = int.parse(p[2]);
          if (year < 100) year += 2000;
          return DateTime(year, month, day);
        }
      }
      // yyyy-MM-dd
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }
}

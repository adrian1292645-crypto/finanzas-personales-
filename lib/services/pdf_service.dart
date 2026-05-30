// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction.dart';

class PdfService {
  // ── Colores ──────────────────────────────────────────────────
  static const _bg     = PdfColor(0.031, 0.047, 0.078);   // #080C14
  static const _card   = PdfColor(0.075, 0.110, 0.180);   // #131C2E
  static const _border = PdfColor(0.102, 0.145, 0.220);   // #1A2538
  static const _text   = PdfColor(0.910, 0.929, 0.961);   // #E8EDF5
  static const _muted  = PdfColor(0.478, 0.545, 0.659);   // #7A8BA8
  static const _lime   = PdfColor(0.784, 1.000, 0.196);   // #C8FF32
  static const _green  = PdfColor(0.118, 0.851, 0.486);   // #1ED97C
  static const _red    = PdfColor(1.000, 0.239, 0.341);   // #FF3D57

  static Future<void> generateMonthlyReport({
    required List<Transaction> transactions,
    required DateTime month,
  }) async {
    final rawLabel  = DateFormat('MMMM yyyy', 'es').format(month);
    final monthLabel = rawLabel[0].toUpperCase() + rawLabel.substring(1);
    final amtFmt    = NumberFormat('#,##0.00');
    final dateFmt   = DateFormat('dd/MM');

    // ── Cómputos ────────────────────────────────────────────
    double totalIngresos = 0;
    double totalGastos   = 0;
    final Map<String, double> byCategory = {};

    for (final tx in transactions) {
      final mxn = tx.divisa == 'MXN' ? tx.monto : tx.monto * tx.tipoCambio;
      if (tx.esGasto) {
        totalGastos += mxn;
        final cat = tx.categoria?.nombre ?? 'Sin categoría';
        byCategory[cat] = (byCategory[cat] ?? 0) + mxn;
      } else {
        totalIngresos += mxn;
      }
    }
    final net = totalIngresos - totalGastos;

    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Construcción del PDF ─────────────────────────────────
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _bg),
          ),
        ),
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MIS FINANZAS',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _lime,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Reporte mensual — $monthLabel',
                    style: const pw.TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _lime,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'PDF',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _bg,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 6),
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 18),

          // ── Summary cards ────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _card,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryCol('INGRESOS', totalIngresos, _green, amtFmt),
                pw.Container(width: 1, height: 44, color: _border),
                _summaryCol('GASTOS', totalGastos, _red, amtFmt),
                pw.Container(width: 1, height: 44, color: _border),
                _summaryCol(
                  net >= 0 ? 'AHORRO' : 'DÉFICIT',
                  net.abs(),
                  net >= 0 ? _lime : _red,
                  amtFmt,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 22),

          // ── Category breakdown ───────────────────────────────
          if (sortedCats.isNotEmpty) ...[
            pw.Text(
              'GASTOS POR CATEGORÍA',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 10),
            ...sortedCats.take(10).map((e) {
              final pct = totalGastos > 0
                  ? (e.value / totalGastos).clamp(0.0, 1.0)
                  : 0.0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(e.key,
                            style: const pw.TextStyle(
                                fontSize: 10, color: _text)),
                        pw.Text(
                          '\$${amtFmt.format(e.value)} MXN  (${(pct * 100).toStringAsFixed(1)}%)',
                          style: const pw.TextStyle(
                              fontSize: 10, color: _red),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        if (pct > 0)
                          pw.Expanded(
                            flex: (pct * 100).round().clamp(1, 99),
                            child: pw.Container(height: 4, color: _red),
                          ),
                        if (pct < 1)
                          pw.Expanded(
                            flex: ((1 - pct) * 100).round().clamp(1, 99),
                            child: pw.Container(height: 4, color: _border),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 22),
          ],

          // ── Transaction list ─────────────────────────────────
          pw.Text(
            'MOVIMIENTOS — ${transactions.length} transacciones',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 8),

          // Table header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: _card,
            child: pw.Row(children: [
              pw.Expanded(
                  flex: 2,
                  child: pw.Text('FECHA',
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _muted,
                          letterSpacing: 1))),
              pw.Expanded(
                  flex: 4,
                  child: pw.Text('CATEGORÍA',
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _muted,
                          letterSpacing: 1))),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('CUENTA',
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _muted,
                          letterSpacing: 1))),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('MONTO',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _muted,
                          letterSpacing: 1))),
            ]),
          ),

          ...transactions.take(300).toList().asMap().entries.map((entry) {
            final i   = entry.key;
            final tx  = entry.value;
            final mxn = tx.divisa == 'MXN'
                ? tx.monto
                : tx.monto * tx.tipoCambio;
            final rowBg = i.isEven ? _card : _bg;
            final amtColor = tx.esGasto ? _red : _green;
            final prefix   = tx.esGasto ? '-' : '+';

            return pw.Container(
              color: rowBg,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(dateFmt.format(tx.fecha),
                        style: const pw.TextStyle(
                            fontSize: 8, color: _muted))),
                pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                        tx.categoria?.nombre ?? 'Sin categoría',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _text))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(tx.cuenta?.nombre ?? '—',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _muted))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      '$prefix\$${amtFmt.format(mxn)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: amtColor),
                    )),
              ]),
            );
          }),

          pw.SizedBox(height: 20),
          pw.Divider(color: _border),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generado por Mis Finanzas',
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fname =
        'finanzas_${DateFormat('yyyy_MM').format(month)}.pdf';
    final blob = html.Blob([bytes], 'application/pdf');
    final url  = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fname)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _summaryCol(
      String label, double amount, PdfColor color, NumberFormat fmt) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 1,
            )),
        pw.SizedBox(height: 5),
        pw.Text(
          '\$${fmt.format(amount)}',
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color),
        ),
        pw.Text('MXN',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    );
  }
}

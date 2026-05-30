// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/deuda.dart';
import '../../models/meta.dart';
import '../../models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/deuda_provider.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../providers/meta_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/csv_import_service.dart';
import '../../services/pdf_service.dart';
import '../deudas/deuda_form_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _rateCtrl;
  bool _exportingCsv  = false;
  bool _exportingPdf  = false;
  bool _importingCsv  = false;
  bool _insertingRec  = false;

  @override
  void initState() {
    super.initState();
    final rate = ref.read(exchangeRateProvider);
    _rateCtrl = TextEditingController(text: rate.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final rate         = ref.watch(exchangeRateProvider);
    final metaAsync    = ref.watch(metaProvider);
    final deudaAsync   = ref.watch(deudaProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ajustes',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── DIVISA BASE ─────────────────────────────────────
          _SectionTitle('DIVISA BASE'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El balance consolidado se muestra en esta divisa.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _CurrencyBtn(
                    label: 'MXN 🇲🇽',
                    active: baseCurrency == 'MXN',
                    color: AppTheme.mxnColor,
                    onTap: () =>
                        ref.read(baseCurrencyProvider.notifier).state = 'MXN',
                  ),
                  const SizedBox(width: 10),
                  _CurrencyBtn(
                    label: 'USD 🇺🇸',
                    active: baseCurrency == 'USD',
                    color: AppTheme.usdColor,
                    onTap: () =>
                        ref.read(baseCurrencyProvider.notifier).state = 'USD',
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── TIPO DE CAMBIO ──────────────────────────────────
          _SectionTitle('TIPO DE CAMBIO'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('1 USD =',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 14)),
                    Text('${rate.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                            color: AppTheme.accentLime,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(
                            color: AppTheme.mxnColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                        hintText: '17.50',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final newRate = double.tryParse(_rateCtrl.text);
                      if (newRate != null && newRate > 0) {
                        ref.read(exchangeRateProvider.notifier).state =
                            newRate;
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Tipo de cambio: \$${newRate.toStringAsFixed(2)} MXN'),
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLime,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Actualizar',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Actualiza el tipo de cambio manualmente para que el\nbalance consolidado refleje el valor real.',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── TRANSACCIONES RECURRENTES ───────────────────────
          _SectionTitle('RECURRENTES'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copia automáticamente las transacciones marcadas como recurrentes del mes anterior al mes actual.',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _insertingRec ? null : _insertarRecurrentes,
                    icon: _insertingRec
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.repeat_rounded, size: 18),
                    label: Text(
                      _insertingRec
                          ? 'Insertando...'
                          : 'Insertar recurrentes del mes anterior',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLime,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── EXPORTAR / IMPORTAR ──────────────────────────────
          _SectionTitle('DATOS'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exporta o importa tus movimientos del mes seleccionado.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),

                // PDF
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportingPdf ? null : _exportarPdf,
                    icon: _exportingPdf
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(
                      _exportingPdf ? 'Generando PDF...' : 'Descargar reporte PDF',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.expenseRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // CSV export
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportingCsv ? null : _exportarCsv,
                    icon: _exportingCsv
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _exportingCsv ? 'Generando...' : 'Descargar CSV',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLime,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // CSV import
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importingCsv ? null : _importarCsv,
                    icon: _importingCsv
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLime))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      _importingCsv ? 'Procesando...' : 'Importar CSV bancario',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Soporta BBVA, Banamex, Santander y formato genérico (Fecha, Descripción, Monto).',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── DEUDAS ──────────────────────────────────────────
          _SectionTitle('DEUDAS Y CRÉDITOS'),
          const SizedBox(height: 10),
          deudaAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accentLime)),
            error: (e, _) => _DeudaErrorCard(error: e),
            data: (deudas) => Column(
              children: [
                if (deudas.isEmpty)
                  _Card(
                    child: const Column(children: [
                      Text('💳', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 8),
                      Text('Sin deudas registradas',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Registra tarjetas, préstamos o créditos para\nrastrear cuándo los liquidas.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
                          textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ...deudas.map((d) => _DeudaCard(deuda: d)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openDeudaForm(null),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva deuda', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseRed,
                      side: BorderSide(color: AppTheme.expenseRed.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── METAS DE AHORRO ─────────────────────────────────
          _SectionTitle('METAS DE AHORRO'),
          const SizedBox(height: 10),
          metaAsync.when(
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.accentLime)),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: AppTheme.expenseRed)),
            data: (metas) => Column(
              children: [
                if (metas.isEmpty)
                  _Card(
                    child: const Column(children: [
                      Text('🎯',
                          style: TextStyle(fontSize: 36)),
                      SizedBox(height: 8),
                      Text('Sin metas activas',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Agrega una meta de ahorro para visualizar tu progreso.',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              height: 1.5),
                          textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ...metas.map((m) => _MetaCard(meta: m)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMetaForm(null),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva meta',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentLime,
                      side: const BorderSide(color: AppTheme.accentLime),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── ACERCA DE ───────────────────────────────────────
          _SectionTitle('ACERCA DE'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Versión',
                    value: '2.0.0'),
                const Divider(color: AppTheme.borderColor, height: 20),
                _InfoRow(
                    icon: Icons.storage_rounded,
                    label: 'Base de datos',
                    value: 'Supabase (PostgreSQL)'),
                const Divider(color: AppTheme.borderColor, height: 20),
                _InfoRow(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Divisas',
                    value: 'MXN · USD'),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Insertar recurrentes ──────────────────────────────────
  Future<void> _insertarRecurrentes() async {
    setState(() => _insertingRec = true);
    try {
      final n = await ref
          .read(transactionProvider.notifier)
          .insertRecurrentes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'No hay recurrentes del mes anterior'
              : '🔁 $n transacción(es) recurrente(s) insertada(s)'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _insertingRec = false);
    }
  }

  // ── Exportar PDF ─────────────────────────────────────────
  Future<void> _exportarPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final txs = ref.read(transactionProvider).valueOrNull ?? [];
      if (txs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay transacciones para exportar')),
        );
        return;
      }
      final month = ref.read(selectedMonthProvider);
      await PdfService.generateMonthlyReport(transactions: txs, month: month);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📄 Reporte PDF descargado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  // ── Importar CSV ──────────────────────────────────────────
  Future<void> _importarCsv() async {
    final accounts = ref.read(accountProvider).valueOrNull ?? [];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea al menos una cuenta antes de importar')),
      );
      return;
    }

    // Abrir selector de archivo via dart:html
    final input = html.FileUploadInputElement()..accept = '.csv,.txt';
    input.click();

    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;

    setState(() => _importingCsv = true);
    try {
      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      final content = reader.result as String;

      final rows = CsvImportService.parse(content);
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron filas válidas en el CSV')),
          );
        }
        return;
      }

      if (!mounted) return;
      await _showCsvPreview(rows, accounts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al leer el archivo: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _importingCsv = false);
    }
  }

  Future<void> _showCsvPreview(List<CsvRow> rows, List accounts) async {
    int? selectedAccountId;
    int? selectedCategoryId;

    // Obtener categorías desde la primera transacción disponible
    final txs = ref.read(transactionProvider).valueOrNull ?? [];
    final cats = <Map<String, dynamic>>[];
    final seenCats = <int>{};
    for (final tx in txs) {
      if (tx.categoria != null && !seenCats.contains(tx.categoriaId)) {
        seenCats.add(tx.categoriaId);
        cats.add({'id': tx.categoriaId, 'nombre': tx.categoria!.nombre, 'icono': tx.categoria!.icono});
      }
    }

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra al menos una transacción para tener categorías disponibles')),
      );
      return;
    }

    selectedAccountId  = accounts.first.id as int?;
    selectedCategoryId = cats.first['id'] as int?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Importar ${rows.length} movimientos',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account selector
                const Text('Cuenta destino:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: selectedAccountId,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  isExpanded: true,
                  items: accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                    value: a.id as int,
                    child: Text(a.nombre as String),
                  )).toList(),
                  onChanged: (v) => setS(() => selectedAccountId = v),
                ),
                const SizedBox(height: 12),
                // Category selector
                const Text('Categoría por defecto:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: selectedCategoryId,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  isExpanded: true,
                  items: cats.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text('${c['icono']} ${c['nombre']}'),
                  )).toList(),
                  onChanged: (v) => setS(() => selectedCategoryId = v),
                ),
                const SizedBox(height: 16),
                // Preview
                const Text('Vista previa (primeros 5):', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                ...rows.take(5).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(
                      r.esGasto ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 12,
                      color: r.esGasto ? AppTheme.expenseRed : AppTheme.incomeGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${r.descripcion.length > 25 ? r.descripcion.substring(0, 25) + '…' : r.descripcion}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${r.monto.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: r.esGasto ? AppTheme.expenseRed : AppTheme.incomeGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar todo', style: TextStyle(color: AppTheme.accentLime, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (selectedAccountId == null || selectedCategoryId == null) return;

    // Importar las transacciones
    int imported = 0;
    for (final row in rows) {
      try {
        await ref.read(transactionProvider.notifier).addTransaction(
          cuentaId:    selectedAccountId!,
          categoriaId: selectedCategoryId!,
          monto:       row.monto,
          tipo:        row.esGasto ? 'gasto' : 'ingreso',
          divisa:      'MXN',
          nota:        row.descripcion,
          fecha:       row.fecha,
        );
        imported++;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $imported movimientos importados'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Formulario de deuda ───────────────────────────────────
  void _openDeudaForm(Deuda? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeudaFormSheet(existing: existing),
    );
  }

  // ── Exportar CSV ──────────────────────────────────────────
  Future<void> _exportarCsv() async {
    setState(() => _exportingCsv = true);
    try {
      final txs = ref.read(transactionProvider).valueOrNull ?? [];
      if (txs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No hay transacciones para exportar')),
        );
        return;
      }

      final sb = StringBuffer();
      sb.writeln(
          'Fecha,Cuenta,Categoría,Tipo,Monto,Divisa,Nota,Etiquetas,Recurrente');

      final fmt = DateFormat('yyyy-MM-dd');
      for (final tx in txs) {
        final row = [
          fmt.format(tx.fecha),
          '"${tx.cuenta?.nombre ?? ''}"',
          '"${tx.categoria?.nombre ?? ''}"',
          tx.esGasto ? 'Gasto' : 'Ingreso',
          tx.monto.toStringAsFixed(2),
          tx.divisa,
          '"${(tx.nota ?? '').replaceAll('"', '""')}"',
          '"${tx.etiquetas.replaceAll('"', '""')}"',
          tx.esRecurrente ? 'Sí' : 'No',
        ];
        sb.writeln(row.join(','));
      }

      final bytes = utf8.encode(sb.toString());
      final blob  = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url   = html.Url.createObjectUrlFromBlob(blob);
      final sel   = ref.read(selectedMonthProvider);
      final fname = 'finanzas_${sel.year}-${sel.month.toString().padLeft(2, '0')}.csv';

      html.AnchorElement(href: url)
        ..setAttribute('download', fname)
        ..click();

      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('📤 Exportado: $fname (${txs.length} movimientos)'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  // ── Formulario de meta ────────────────────────────────────
  void _openMetaForm(Meta? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MetaFormSheet(existing: existing),
    );
  }
}

// ── Error card con SQL y retry ────────────────────────────────
class _DeudaErrorCard extends ConsumerWidget {
  const _DeudaErrorCard({required this.error});
  final Object error;

  static const _createSql =
      'CREATE TABLE IF NOT EXISTS deudas (\n'
      '  id BIGSERIAL PRIMARY KEY,\n'
      '  nombre TEXT NOT NULL,\n'
      '  monto_total NUMERIC(12,2) DEFAULT 0,\n'
      '  monto_actual NUMERIC(12,2) DEFAULT 0,\n'
      '  tasa_interes NUMERIC(5,2) DEFAULT 0,\n'
      '  pago_minimo NUMERIC(12,2) DEFAULT 0,\n'
      '  divisa TEXT DEFAULT \'MXN\',\n'
      '  fecha_corte DATE,\n'
      '  icono TEXT DEFAULT \'💳\',\n'
      '  created_at TIMESTAMPTZ DEFAULT NOW()\n'
      ');\n'
      '\n'
      '-- Deshabilitar RLS (app personal sin auth)\n'
      'ALTER TABLE deudas DISABLE ROW LEVEL SECURITY;\n'
      '\n'
      '-- Dar permisos al rol anon\n'
      'GRANT ALL ON TABLE deudas TO anon;\n'
      'GRANT ALL ON TABLE deudas TO authenticated;\n'
      'GRANT USAGE, SELECT ON SEQUENCE deudas_id_seq TO anon;\n'
      'GRANT USAGE, SELECT ON SEQUENCE deudas_id_seq TO authenticated;';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errStr = error.toString();
    // Si ya existe la tabla, el error es de permisos
    final isPermission = errStr.contains('permission') ||
        errStr.contains('policy') ||
        errStr.contains('42501') ||
        errStr.contains('PGRST');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.expenseRed, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Error al cargar deudas',
                style: TextStyle(
                    color: AppTheme.expenseRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => ref.invalidate(deudaProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentLime,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            isPermission
                ? 'La tabla existe pero faltan permisos. Ejecuta este SQL en Supabase → SQL Editor:'
                : 'Crea la tabla y da permisos. Ejecuta este SQL en Supabase → SQL Editor:',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgPrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: SelectableText(
              _createSql,
              style: const TextStyle(
                  color: AppTheme.accentLime,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  height: 1.6),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Después haz Ctrl+Shift+R en el navegador para recargar.',
            style: TextStyle(
                color: AppTheme.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Card de deuda ─────────────────────────────────────────────
class _DeudaCard extends ConsumerWidget {
  const _DeudaCard({required this.deuda});
  final Deuda deuda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct   = deuda.progreso;
    final meses = deuda.mesesParaPagar;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DeudaFormSheet(existing: deuda),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(deuda.icono, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(deuda.nombre,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (deuda.pagada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Pagada ✓',
                      style: TextStyle(color: AppTheme.incomeGreen, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textMuted),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  CurrencyUtils.formatShort(deuda.montoActual, deuda.divisa),
                  style: const TextStyle(color: AppTheme.expenseRed, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text('/ ${CurrencyUtils.formatShort(deuda.montoTotal, deuda.divisa)} ${deuda.divisa}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
              if (meses != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$meses meses',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const Text('para liquidar', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ]),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.bgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                    deuda.pagada ? AppTheme.incomeGreen : AppTheme.expenseRed),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(pct * 100).toStringAsFixed(0)}% liquidado',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              if (deuda.tasaInteres > 0)
                Text('${deuda.tasaInteres.toStringAsFixed(1)}% anual · '
                    '${CurrencyUtils.formatShort(deuda.interesMensual, deuda.divisa)}/mes en interés',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Card de meta ──────────────────────────────────────────────
class _MetaCard extends ConsumerWidget {
  const _MetaCard({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct   = meta.progreso;
    final color = meta.completada ? AppTheme.incomeGreen : AppTheme.accentLime;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MetaFormSheet(existing: meta),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(meta.icono, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(meta.nombre,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              if (meta.completada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.incomeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Completada',
                      style: TextStyle(
                          color: AppTheme.incomeGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_rounded,
                  size: 16, color: AppTheme.textMuted),
            ]),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyUtils.formatShort(meta.montoActual, meta.divisa),
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  '/ ${CurrencyUtils.formatShort(meta.montoMeta, meta.divisa)} ${meta.divisa}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.bgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% completado',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
                if (!meta.completada)
                  Text(
                    'Faltan ${CurrencyUtils.formatShort(meta.faltante, meta.divisa)}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet formulario de meta ──────────────────────────
class _MetaFormSheet extends ConsumerStatefulWidget {
  const _MetaFormSheet({this.existing});
  final Meta? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<_MetaFormSheet> createState() => _MetaFormSheetState();
}

class _MetaFormSheetState extends ConsumerState<_MetaFormSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _metaCtrl;
  late final TextEditingController _actualCtrl;
  late final TextEditingController _iconoCtrl;
  late String _divisa;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _metaCtrl   = TextEditingController(
        text: e != null ? e.montoMeta.toStringAsFixed(2) : '');
    _actualCtrl = TextEditingController(
        text: e != null ? e.montoActual.toStringAsFixed(2) : '0.00');
    _iconoCtrl  = TextEditingController(text: e?.icono ?? '🎯');
    _divisa     = e?.divisa ?? 'MXN';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _metaCtrl.dispose();
    _actualCtrl.dispose();
    _iconoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nombreCtrl.text.trim().isNotEmpty &&
        _metaCtrl.text.isNotEmpty &&
        !_saving;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isEditing ? 'Editar meta' : 'Nueva meta de ahorro',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Icono + nombre
            Row(children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _iconoCtrl,
                  style: const TextStyle(fontSize: 28),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '🎯'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nombreCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Nombre de la meta'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Divisa
            _Label('DIVISA'),
            const SizedBox(height: 8),
            _DivisaRow(
              selected: _divisa,
              onChanged: (v) => setState(() => _divisa = v),
            ),
            const SizedBox(height: 16),

            // Monto meta
            _Label('MONTO OBJETIVO'),
            const SizedBox(height: 8),
            TextField(
              controller: _metaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
                prefixStyle: const TextStyle(
                    color: AppTheme.accentLime,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Monto actual
            _Label('MONTO AHORRADO HASTA AHORA'),
            const SizedBox(height: 8),
            TextField(
              controller: _actualCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
                prefixStyle: const TextStyle(
                    color: AppTheme.incomeGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 28),

            // Botones
            Row(children: [
              if (widget.isEditing) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseRed,
                      side: const BorderSide(color: AppTheme.expenseRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Eliminar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: canSave
                        ? AppTheme.accentLime
                        : AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: canSave ? _save : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(
                            widget.isEditing ? 'Guardar cambios' : 'Crear meta',
                            style: TextStyle(
                              color: canSave
                                  ? Colors.black
                                  : AppTheme.textMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final nombre  = _nombreCtrl.text.trim();
    final meta    = double.tryParse(_metaCtrl.text) ?? 0;
    final actual  = double.tryParse(_actualCtrl.text) ?? 0;
    final icono   = _iconoCtrl.text.trim().isNotEmpty
        ? _iconoCtrl.text.trim()
        : '🎯';

    if (nombre.isEmpty || meta <= 0) return;
    setState(() => _saving = true);

    try {
      final m = Meta(
        id:          widget.existing?.id,
        nombre:      nombre,
        montoMeta:   meta,
        montoActual: actual,
        divisa:      _divisa,
        icono:       icono,
      );

      if (widget.isEditing) {
        await ref.read(metaProvider.notifier).updateMeta(m);
      } else {
        await ref.read(metaProvider.notifier).create(m);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEditing ? '✅ Meta actualizada' : '✅ Meta creada'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existing?.id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(metaProvider.notifier).deleteMeta(widget.existing!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Meta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Widgets internos ───────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

class _DivisaRow extends StatelessWidget {
  const _DivisaRow({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        _DBtn('MXN', AppTheme.mxnColor, selected == 'MXN',
            () => onChanged('MXN')),
        _DBtn('USD', AppTheme.usdColor, selected == 'USD',
            () => onChanged('USD')),
      ]),
    );
  }
}

class _DBtn extends StatelessWidget {
  const _DBtn(this.label, this.color, this.active, this.onTap);
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : AppTheme.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: child,
      );
}

class _CurrencyBtn extends StatelessWidget {
  const _CurrencyBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.15)
                  : AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color : AppTheme.borderColor,
                width: active ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: active ? color : AppTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

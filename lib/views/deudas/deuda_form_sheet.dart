import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/deuda.dart';
import '../../providers/deuda_provider.dart';

class DeudaFormSheet extends ConsumerStatefulWidget {
  const DeudaFormSheet({super.key, this.existing});
  final Deuda? existing;
  bool get isEditing => existing != null;

  @override
  ConsumerState<DeudaFormSheet> createState() => _DeudaFormSheetState();
}

class _DeudaFormSheetState extends ConsumerState<DeudaFormSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _actualCtrl;
  late final TextEditingController _tasaCtrl;
  late final TextEditingController _pagoCtrl;
  late final TextEditingController _iconoCtrl;
  late String _divisa;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _totalCtrl  = TextEditingController(
        text: e != null ? e.montoTotal.toStringAsFixed(2) : '');
    _actualCtrl = TextEditingController(
        text: e != null ? e.montoActual.toStringAsFixed(2) : '');
    _tasaCtrl   = TextEditingController(
        text: e != null && e.tasaInteres > 0
            ? e.tasaInteres.toStringAsFixed(1)
            : '');
    _pagoCtrl   = TextEditingController(
        text: e != null && e.pagoMinimo > 0
            ? e.pagoMinimo.toStringAsFixed(2)
            : '');
    _iconoCtrl  = TextEditingController(text: e?.icono ?? '💳');
    _divisa     = e?.divisa ?? 'MXN';
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _totalCtrl, _actualCtrl, _tasaCtrl, _pagoCtrl, _iconoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _nombreCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_totalCtrl.text) ?? 0) > 0 &&
      !_saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
              widget.isEditing ? 'Editar deuda' : 'Nueva deuda',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tarjetas, créditos, préstamos',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Icono + nombre
            Row(children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _iconoCtrl,
                  style: const TextStyle(fontSize: 26),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '💳'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nombreCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Ej: Tarjeta Banamex'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Divisa
            _label('DIVISA'),
            const SizedBox(height: 8),
            _DivisaToggle(
              selected: _divisa,
              onChanged: (v) => setState(() => _divisa = v),
            ),
            const SizedBox(height: 16),

            // Deuda original y saldo actual (dos campos en fila)
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('DEUDA ORIGINAL'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _totalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
                        prefixStyle: const TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SALDO PENDIENTE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _actualCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
                        prefixStyle: const TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Tasa y pago mínimo
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('TASA ANUAL (CAT %)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tasaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))],
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        suffixText: '%',
                        suffixStyle: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('PAGO MÍNIMO'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pagoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
                        prefixStyle: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            // Preview de meses para liquidar
            const SizedBox(height: 12),
            _PayoffPreview(
              montoActual: double.tryParse(_actualCtrl.text) ?? 0,
              tasa:        double.tryParse(_tasaCtrl.text) ?? 0,
              pago:        double.tryParse(_pagoCtrl.text) ?? 0,
              divisa:      _divisa,
            ),

            const SizedBox(height: 24),

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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _canSave ? AppTheme.accentLime : AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: _canSave ? _save : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(
                            widget.isEditing ? 'Guardar' : 'Crear deuda',
                            style: TextStyle(
                              color: _canSave ? Colors.black : AppTheme.textMuted,
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );

  Future<void> _save() async {
    final nombre  = _nombreCtrl.text.trim();
    final total   = double.tryParse(_totalCtrl.text) ?? 0;
    final actual  = double.tryParse(_actualCtrl.text) ?? total;
    final tasa    = double.tryParse(_tasaCtrl.text) ?? 0;
    final pago    = double.tryParse(_pagoCtrl.text) ?? 0;
    final icono   = _iconoCtrl.text.trim().isNotEmpty ? _iconoCtrl.text.trim() : '💳';

    if (nombre.isEmpty || total <= 0) return;
    setState(() => _saving = true);

    try {
      final d = Deuda(
        id:          widget.existing?.id,
        nombre:      nombre,
        montoTotal:  total,
        montoActual: actual,
        tasaInteres: tasa,
        pagoMinimo:  pago,
        divisa:      _divisa,
        icono:       icono,
      );

      if (widget.isEditing) {
        await ref.read(deudaProvider.notifier).updateDeuda(d);
      } else {
        await ref.read(deudaProvider.notifier).create(d);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEditing ? '✅ Deuda actualizada' : '✅ Deuda registrada'),
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
      await ref.read(deudaProvider.notifier).deleteDeuda(widget.existing!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Deuda eliminada')),
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

// ── Toggle de divisa ──────────────────────────────────────────
class _DivisaToggle extends StatelessWidget {
  const _DivisaToggle({required this.selected, required this.onChanged});
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
        _Btn('MXN', AppTheme.mxnColor, selected == 'MXN', () => onChanged('MXN')),
        _Btn('USD', AppTheme.usdColor, selected == 'USD', () => onChanged('USD')),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.color, this.active, this.onTap);
  final String label; final Color color; final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
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
            child: Text(label,
                style: TextStyle(
                  color: active ? color : AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                )),
          ),
        ),
      );
}

// ── Preview de liquidación ────────────────────────────────────
class _PayoffPreview extends StatelessWidget {
  const _PayoffPreview({
    required this.montoActual,
    required this.tasa,
    required this.pago,
    required this.divisa,
  });
  final double montoActual;
  final double tasa;
  final double pago;
  final String divisa;

  @override
  Widget build(BuildContext context) {
    if (pago <= 0 || montoActual <= 0) return const SizedBox.shrink();

    final deuda = Deuda(
      nombre: '',
      montoTotal: montoActual,
      montoActual: montoActual,
      tasaInteres: tasa,
      pagoMinimo: pago,
      divisa: divisa,
    );

    final meses = deuda.mesesParaPagar;
    final interes = deuda.interesMensual;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_rounded, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: meses == null
                ? const Text(
                    'El pago mínimo no cubre el interés — considerá aumentarlo',
                    style: TextStyle(color: AppTheme.expenseRed, fontSize: 11),
                  )
                : Text(
                    'Liquidas en $meses ${meses == 1 ? 'mes' : 'meses'}'
                    '${interes > 0 ? '  ·  Interés mensual: ${CurrencyUtils.formatShort(interes, divisa)}' : ''}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
          ),
        ],
      ),
    );
  }
}

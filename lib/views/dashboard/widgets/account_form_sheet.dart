import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/account.dart';
import '../../../providers/account_provider.dart';
import '../../../services/account_service.dart';
import '../../../providers/service_providers.dart';

/// Bottom sheet para CREAR o EDITAR una cuenta.
/// Si [account] es null → modo crear. Si viene → modo editar.
class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});
  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _saldoCtrl;
  late String _divisa;
  bool _saving = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.account?.nombre ?? '');
    _saldoCtrl  = TextEditingController(
      text: widget.account != null
          ? widget.account!.saldoActual.toStringAsFixed(2)
          : '',
    );
    _divisa = widget.account?.divisa ?? 'MXN';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nombreCtrl.text.trim().isNotEmpty &&
        _saldoCtrl.text.isNotEmpty &&
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

          // Título
          Text(
            _isEditing ? 'Editar cuenta' : 'Nueva cuenta',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),

          // Nombre
          _Label('NOMBRE DE LA CUENTA'),
          const SizedBox(height: 8),
          TextField(
            controller: _nombreCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'ej. BBVA MXN, Wise USD...'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Divisa
          _Label('DIVISA'),
          const SizedBox(height: 8),
          _DivisaToggle(
            selected: _divisa,
            onChanged: (v) => setState(() => _divisa = v),
          ),
          const SizedBox(height: 16),

          // Saldo
          _Label(_isEditing ? 'SALDO ACTUAL' : 'SALDO INICIAL'),
          const SizedBox(height: 8),
          TextField(
            controller: _saldoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: _divisa == 'USD' ? 'US\$ ' : '\$ ',
              prefixStyle: const TextStyle(
                color: AppTheme.accentLime,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),

          // Botones
          Row(
            children: [
              if (_isEditing) ...[
                // Botón eliminar
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _confirmDelete(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseRed,
                      side: const BorderSide(color: AppTheme.expenseRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Eliminar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Botón guardar
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: canSave ? AppTheme.accentLime : AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: canSave ? () => _save(context) : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                        : Text(
                            _isEditing ? 'Guardar cambios' : 'Crear cuenta',
                            style: TextStyle(
                              color: canSave ? Colors.black : AppTheme.textMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final nombre = _nombreCtrl.text.trim();
    final saldo  = double.tryParse(_saldoCtrl.text) ?? 0;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(accountServiceProvider);

      if (_isEditing) {
        await service.updateAccount(
          id:          widget.account!.id,
          nombre:      nombre,
          divisa:      _divisa,
          saldoActual: saldo,
        );
      } else {
        await service.createAccount(
          nombre:      nombre,
          divisa:      _divisa,
          saldoActual: saldo,
        );
      }

      await ref.read(accountProvider.notifier).refresh();

      if (context.mounted) {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? '✅ Cuenta actualizada'
              : '✅ Cuenta creada'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar cuenta',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          '¿Eliminar "${widget.account!.nombre}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(accountServiceProvider).deleteAccount(widget.account!.id);
      await ref.read(accountProvider.notifier).refresh();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🗑️ Cuenta eliminada'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
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

// ── Helpers internos ──────────────────────────────────────────

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

class _DivisaToggle extends StatelessWidget {
  const _DivisaToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        _DivisaBtn(label: 'MXN', color: AppTheme.mxnColor,
            active: selected == 'MXN', onTap: () => onChanged('MXN')),
        _DivisaBtn(label: 'USD', color: AppTheme.usdColor,
            active: selected == 'USD', onTap: () => onChanged('USD')),
      ]),
    );
  }
}

class _DivisaBtn extends StatelessWidget {
  const _DivisaBtn({
    required this.label, required this.color,
    required this.active, required this.onTap,
  });
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
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : AppTheme.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

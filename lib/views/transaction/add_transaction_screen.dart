import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import 'widgets/account_chip_selector.dart';
import 'widgets/amount_input_field.dart';
import 'widgets/category_grid_selector.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  /// [transaction] = null → modo crear  |  non-null → modo editar
  const AddTransactionScreen({super.key, this.transaction});
  final Transaction? transaction;

  bool get isEditing => transaction != null;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  late String    _tipo;
  late double    _monto;
  Category?      _categoria;
  Account?       _cuenta;
  bool           _saving = false;
  bool           _esRecurrente = false;
  late final TextEditingController _notaCtrl;
  late final TextEditingController _etiquetasCtrl;

  bool get _isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx    = widget.transaction!;
      _tipo       = tx.esGasto ? 'gasto' : 'ingreso';
      _monto      = tx.monto;
      _categoria  = tx.categoria;
      _cuenta     = tx.cuenta;
      _esRecurrente = tx.esRecurrente;
      _notaCtrl     = TextEditingController(text: tx.nota ?? '');
      _etiquetasCtrl = TextEditingController(text: tx.etiquetas);
    } else {
      _tipo      = 'gasto';
      _monto     = 0;
      _notaCtrl  = TextEditingController();
      _etiquetasCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _etiquetasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En modo crear, pre-selecciona la primera cuenta cuando cargan
    if (!_isEditing) {
      ref.listen(accountProvider, (_, next) {
        next.whenData((accounts) {
          if (_cuenta == null && accounts.isNotEmpty) {
            setState(() => _cuenta = accounts.first);
          }
        });
      });
    }

    final accountsAsync   = ref.watch(accountProvider);
    final categoriesAsync = ref.watch(
      _tipo == 'gasto' ? gastosCategoryProvider : ingresosCategoryProvider,
    );
    final canSave =
        _monto > 0 && _categoria != null && _cuenta != null && !_saving;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar transacción' : 'Nueva transacción',
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tipo ─────────────────────────────────────
            _TypeToggle(
              selected: _tipo,
              onChanged: (t) => setState(() {
                _tipo = t;
                _categoria = null;
              }),
            ),
            const SizedBox(height: 28),

            // ── Monto ────────────────────────────────────
            AmountInputField(
              key: ValueKey(_cuenta?.divisa ?? 'MXN'),
              currency: _cuenta?.divisa ?? 'MXN',
              initialValue: _monto,
              onChanged: (v) => setState(() => _monto = v),
            ),
            const SizedBox(height: 28),

            // ── Categorías ───────────────────────────────
            const _SectionLabel('CATEGORÍA'),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (cats) => CategoryGridSelector(
                categories: cats,
                selected: _categoria,
                onSelected: (c) => setState(() => _categoria = c),
              ),
              loading: () => const _LoadingRow(),
              error: (e, _) => _InlineError(e.toString()),
            ),
            const SizedBox(height: 28),

            // ── Cuenta ───────────────────────────────────
            const _SectionLabel('CUENTA'),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) => AccountChipSelector(
                accounts: accounts,
                selected: _cuenta,
                onSelected: (a) => setState(() => _cuenta = a),
              ),
              loading: () => const _LoadingRow(),
              error: (e, _) => _InlineError(e.toString()),
            ),
            const SizedBox(height: 28),

            // ── Nota ─────────────────────────────────────
            const _SectionLabel('NOTA (OPCIONAL)'),
            const SizedBox(height: 12),
            TextField(
              controller: _notaCtrl,
              maxLines: 2,
              maxLength: 120,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Descripción breve...',
                counterStyle: TextStyle(color: Color(0xFF3A3A3A)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Etiquetas ────────────────────────────────
            const _SectionLabel('ETIQUETAS (OPCIONAL)'),
            const SizedBox(height: 4),
            const Text(
              'Separa con comas: trabajo, comida, fijo...',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _etiquetasCtrl,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'ej. fijo, nómina, renta',
                prefixIcon: Icon(Icons.label_outline_rounded,
                    size: 18, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            // ── Recurrente ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: _esRecurrente
                          ? AppTheme.accentLime
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transacción recurrente',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Se puede reinsertar cada mes',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ]),
                  Switch(
                    value: _esRecurrente,
                    onChanged: (v) => setState(() => _esRecurrente = v),
                    activeColor: AppTheme.accentLime,
                    activeTrackColor:
                        AppTheme.accentLime.withValues(alpha: 0.25),
                    inactiveThumbColor: AppTheme.textMuted,
                    inactiveTrackColor: AppTheme.bgSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Botón Guardar ────────────────────────────
            _SaveButton(
              canSave: canSave,
              saving: _saving,
              isEditing: _isEditing,
              onPressed: () => _save(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (_monto <= 0 || _categoria == null || _cuenta == null) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final etiquetasLimpias = _etiquetasCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join(',');

    try {
      if (_isEditing) {
        await ref.read(transactionProvider.notifier).updateTransaction(
              oldTx:        widget.transaction!,
              cuentaId:     _cuenta!.id,
              categoriaId:  _categoria!.id,
              monto:        _monto,
              tipo:         _tipo,
              divisa:       _cuenta!.divisa,
              nota:         _notaCtrl.text.trim(),
              esRecurrente: _esRecurrente,
              etiquetas:    etiquetasLimpias,
            );
      } else {
        await ref.read(transactionProvider.notifier).addTransaction(
              cuentaId:     _cuenta!.id,
              categoriaId:  _categoria!.id,
              monto:        _monto,
              tipo:         _tipo,
              divisa:       _cuenta!.divisa,
              nota:         _notaCtrl.text.trim(),
              esRecurrente: _esRecurrente,
              etiquetas:    etiquetasLimpias,
            );
      }

      if (!context.mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? '✅ Transacción actualizada'
              : '✅ Transacción guardada'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Componentes internos ──────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        _TypeBtn(
          label: 'Gasto',
          icon: Icons.arrow_downward_rounded,
          active: selected == 'gasto',
          color: AppTheme.expenseRed,
          onTap: () => onChanged('gasto'),
        ),
        _TypeBtn(
          label: 'Ingreso',
          icon: Icons.arrow_upward_rounded,
          active: selected == 'ingreso',
          color: AppTheme.incomeGreen,
          onTap: () => onChanged('ingreso'),
        ),
      ]),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String   label;
  final IconData icon;
  final bool     active;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: active ? color : AppTheme.textMuted, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : AppTheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.canSave,
    required this.saving,
    required this.isEditing,
    required this.onPressed,
  });
  final bool         canSave;
  final bool         saving;
  final bool         isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: canSave ? AppTheme.accentLime : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: canSave ? null : Border.all(color: AppTheme.borderColor),
          boxShadow: canSave
              ? [
                  BoxShadow(
                    color: AppTheme.accentLime.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: TextButton(
          onPressed: canSave ? onPressed : null,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black),
                )
              : Text(
                  isEditing ? 'Guardar cambios' : 'Guardar transacción',
                  style: TextStyle(
                    color: canSave ? Colors.black : AppTheme.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message,
        style: const TextStyle(color: AppTheme.expenseRed, fontSize: 13));
  }
}

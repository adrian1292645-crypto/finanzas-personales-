import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/exchange_rate_provider.dart';

class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key, required this.accounts});
  final List<Account> accounts;

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  Account? _from;
  Account? _to;
  double   _amount = 0;
  bool     _saving = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.accounts.length >= 2) {
      _from = widget.accounts[0];
      _to   = widget.accounts[1];
    } else if (widget.accounts.isNotEmpty) {
      _from = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canTransfer =>
      _from != null &&
      _to != null &&
      _from!.id != _to!.id &&
      _amount > 0 &&
      !_saving;

  /// Calcula el monto que llega al destino según las divisas.
  double _toAmount(double rate) {
    if (_from == null || _to == null) return 0;
    if (_from!.divisa == _to!.divisa) return _amount;
    if (_from!.divisa == 'USD' && _to!.divisa == 'MXN') return _amount * rate;
    if (_from!.divisa == 'MXN' && _to!.divisa == 'USD') return _amount / rate;
    return _amount;
  }

  @override
  Widget build(BuildContext context) {
    final rate          = ref.watch(exchangeRateProvider);
    final toAmt         = _toAmount(rate);
    final crossCurrency = _from != null && _to != null &&
        _from!.divisa != _to!.divisa;

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

          const Text('Transferencia entre cuentas',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // ── Cuenta origen ────────────────────────────────
          _Label('DE'),
          const SizedBox(height: 8),
          _AccountDropdown(
            accounts: widget.accounts,
            selected: _from,
            excluded: _to,
            onChanged: (a) => setState(() {
              _from = a;
              _ctrl.clear();
              _amount = 0;
            }),
          ),

          const SizedBox(height: 14),

          // ── Cuenta destino ───────────────────────────────
          _Label('HACIA'),
          const SizedBox(height: 8),
          _AccountDropdown(
            accounts: widget.accounts,
            selected: _to,
            excluded: _from,
            onChanged: (a) => setState(() => _to = a),
          ),

          const SizedBox(height: 14),

          // ── Monto ────────────────────────────────────────
          _Label('MONTO${_from != null ? ' (${_from!.divisa})' : ''}'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: _from != null
                  ? '${CurrencyUtils.currencySymbol(_from!.divisa)} '
                  : '\$ ',
              prefixStyle: const TextStyle(
                  color: AppTheme.accentLime,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            onChanged: (v) =>
                setState(() => _amount = double.tryParse(v) ?? 0),
          ),

          // ── Conversión cross-currency ─────────────────────
          if (crossCurrency && _amount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentLime.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.accentLime.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: AppTheme.accentLime, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${CurrencyUtils.formatShort(_amount, _from!.divisa)}'
                  ' → '
                  '${CurrencyUtils.formatShort(toAmt, _to!.divisa)}',
                  style: const TextStyle(
                      color: AppTheme.accentLime,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          // ── Botón Transferir ─────────────────────────────
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _canTransfer
                    ? AppTheme.accentLime
                    : AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: _canTransfer
                    ? () => _transfer(context, rate)
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text(
                        'Transferir',
                        style: TextStyle(
                          color: _canTransfer
                              ? Colors.black
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _transfer(BuildContext context, double rate) async {
    if (!_canTransfer) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final toAmt = _toAmount(rate);
      await ref.read(accountProvider.notifier).applyDelta(_from!.id, -_amount);
      await ref.read(accountProvider.notifier).applyDelta(_to!.id, toAmt);

      if (context.mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${CurrencyUtils.formatShort(_amount, _from!.divisa)}'
              ' transferido a ${_to!.nombre}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
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

// ── Helpers ───────────────────────────────────────────────────

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

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.accounts,
    required this.selected,
    required this.excluded,
    required this.onChanged,
  });
  final List<Account>       accounts;
  final Account?            selected;
  final Account?            excluded;
  final ValueChanged<Account> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = accounts.where((a) => a.id != excluded?.id).toList();
    final color = selected != null
        ? (selected!.divisa == 'USD'
            ? AppTheme.usdColor
            : AppTheme.mxnColor)
        : AppTheme.borderColor;

    // Si el selected fue excluido, mostramos null en el dropdown
    final dropdownValue = (selected != null &&
            available.any((a) => a.id == selected!.id))
        ? selected
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Account>(
          value: dropdownValue,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          hint: const Text('Selecciona cuenta',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          items: available
              .map((a) {
                final c = a.divisa == 'USD'
                    ? AppTheme.usdColor
                    : AppTheme.mxnColor;
                return DropdownMenuItem<Account>(
                  value: a,
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.nombre,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      CurrencyUtils.formatShort(a.saldoActual, a.divisa),
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ]),
                );
              })
              .toList(),
          onChanged: (a) {
            if (a != null) onChanged(a);
          },
        ),
      ),
    );
  }
}

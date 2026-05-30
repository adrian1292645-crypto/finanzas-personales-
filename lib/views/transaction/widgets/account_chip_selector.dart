import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../models/account.dart';

class AccountChipSelector extends StatelessWidget {
  const AccountChipSelector({
    super.key,
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  final List<Account> accounts;
  final Account? selected;
  final ValueChanged<Account> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: accounts
          .map((a) => _AccountChip(
                account: a,
                isSelected: selected?.id == a.id,
                onTap: () => onSelected(a),
              ))
          .toList(),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final Account account;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUSD   = account.divisa == 'USD';
    final accent  = isUSD ? AppTheme.usdColor : AppTheme.mxnColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.1) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de color por divisa
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.nombre,
                  style: TextStyle(
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${CurrencyUtils.currencyFlag(account.divisa)} ${account.divisa}  ·  ${CurrencyUtils.formatShort(account.saldoActual, account.divisa)}',
                  style: TextStyle(
                    color: isSelected ? accent : const Color(0xFF444444),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

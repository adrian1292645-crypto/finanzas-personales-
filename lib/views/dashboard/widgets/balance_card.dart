import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../models/account.dart';
import '../../../providers/exchange_rate_provider.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key, required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate         = ref.watch(exchangeRateProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final total        = _consolidate(accounts, rate, baseCurrency);

    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2A4A),  // Rich navy blue
            Color(0xFF0E1626),  // Deep navy
            Color(0xFF080C14),  // Near black
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: const Color(0xFF253552), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentLime.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lime glow — top left
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x22C8FF32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Subtle circle decoration — bottom right
          Positioned(
            bottom: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1A2D50),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            right: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF152240),
                  width: 1,
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentLime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'BALANCE TOTAL',
                          style: TextStyle(
                            color: Color(0xFF7A9AC5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                    _CurrencyToggle(baseCurrency),
                  ],
                ),

                const Spacer(),

                // ── Balance number ────────────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtils.formatShort(total, baseCurrency),
                    style: const TextStyle(
                      color: Color(0xFFF0F4FF),
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  baseCurrency == 'MXN' ? 'Pesos mexicanos' : 'US Dollars',
                  style: const TextStyle(
                    color: Color(0xFF4A6080),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),

                const Spacer(),

                // ── Bottom row ────────────────────────────
                Row(
                  children: [
                    _StatPill(
                      label: 'CAMBIO',
                      value: '1 USD = \$${rate.toStringAsFixed(2)}',
                      color: AppTheme.usdColor,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      label: 'CUENTAS',
                      value: accounts.length.toString(),
                      color: AppTheme.accentCyan,
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentLime.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: AppTheme.accentLime,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _consolidate(
      List<Account> accounts, double rate, String baseCurrency) {
    var total = 0.0;
    for (final a in accounts) {
      total += CurrencyUtils.toBaseCurrency(
        amount: a.saldoActual,
        fromCurrency: a.divisa,
        baseCurrency: baseCurrency,
        usdToMxnRate: rate,
      );
    }
    return double.parse(total.toStringAsFixed(2));
  }
}

// ── Stat pill ─────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Currency toggle ───────────────────────────────────────────
class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle(this.currency);
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isMxn = currency == 'MXN';
    final color = isMxn ? AppTheme.mxnColor : AppTheme.usdColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            currency,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

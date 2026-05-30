import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../models/transaction.dart';
import '../../../providers/transaction_provider.dart';
import '../../transaction/add_transaction_screen.dart';

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.bgCard,
                      AppTheme.bgSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Center(
                  child: Text('💸', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sin movimientos aún',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toca el botón + para registrar\ntu primera transacción',
                style: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _TransactionTile(
            transaction: transactions[i],
            showHeader: _needsHeader(i),
            isLast: i == transactions.length - 1,
          ),
          childCount: transactions.length,
        ),
      ),
    );
  }

  bool _needsHeader(int i) {
    if (i == 0) return true;
    return !_sameDay(transactions[i].fecha, transactions[i - 1].fecha);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────
class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.showHeader,
    this.isLast = false,
  });

  final Transaction transaction;
  final bool showHeader;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGasto  = transaction.esGasto;
    final amtColor = isGasto ? AppTheme.expenseRed : AppTheme.incomeGreen;
    final iconBg   = isGasto
        ? AppTheme.expenseRed.withValues(alpha: 0.12)
        : AppTheme.incomeGreen.withValues(alpha: 0.12);
    final iconBorder = isGasto
        ? AppTheme.expenseRed.withValues(alpha: 0.20)
        : AppTheme.incomeGreen.withValues(alpha: 0.20);
    final timeFmt  = DateFormat('HH:mm');
    final tags     = transaction.tagList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) _DateHeader(date: transaction.fecha),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(transaction: transaction),
              fullscreenDialog: true,
            ),
          ),
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLast
                    ? AppTheme.borderColor
                    : AppTheme.borderColor.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // ── Icono ──────────────────────────────
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconBorder),
                  ),
                  child: Center(
                    child: Text(
                      transaction.categoria?.icono ?? '💸',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Info ───────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.categoria?.nombre ??
                                  'Sin categoría',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (transaction.esRecurrente)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.repeat_rounded,
                                size: 13,
                                color: AppTheme.accentLime
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.cuenta?.nombre ?? '—'}'
                        '  ·  ${timeFmt.format(transaction.fecha)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (transaction.nota != null &&
                          transaction.nota!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          transaction.nota!,
                          style: TextStyle(
                            color: AppTheme.textMuted.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          children: tags
                              .map((tag) => _TagChip(tag: tag))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // ── Monto + Eliminar ───────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isGasto ? '−' : '+'}${CurrencyUtils.formatShort(transaction.monto, transaction.divisa)}',
                      style: TextStyle(
                        color: amtColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, ref),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppTheme.expenseRed.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: AppTheme.expenseRed.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar movimiento',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        content: Text(
          'Se eliminará este movimiento de '
          '${CurrencyUtils.formatShort(transaction.monto, transaction.divisa)} '
          'y se ajustará el saldo de la cuenta.',
          style: const TextStyle(
              color: AppTheme.textMuted, height: 1.6, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(
                    color: AppTheme.expenseRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(transactionProvider.notifier).deleteTransaction(
            transaction.id!,
            cuentaId: transaction.cuentaId,
            monto:    transaction.monto,
            tipo:     transaction.esGasto ? 'gasto' : 'ingreso',
          );
      if (context.mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento eliminado'),
            duration: Duration(seconds: 2),
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
    }
  }
}

// ── Tag chip ──────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentLime.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accentLime.withValues(alpha: 0.15)),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Date header ───────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(date.year, date.month, date.day);

    final String label;
    if (d == today) {
      label = 'Hoy';
    } else if (d == yesterday) {
      label = 'Ayer';
    } else {
      label = DateFormat('EEEE d MMM', 'es').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.borderColor,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

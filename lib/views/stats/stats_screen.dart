import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/transaction.dart';
import '../../providers/service_providers.dart';
import '../../providers/transaction_provider.dart';

// ── Paleta de colores para el pie chart ──────────────────────
const _kPieColors = [
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
  Color(0xFF6C5CE7),
  Color(0xFFA29BFE),
  Color(0xFFFF9F43),
  Color(0xFF00B894),
  Color(0xFF0984E3),
  Color(0xFFE17055),
  Color(0xFF74B9FF),
];

// ─────────────────────────────────────────────────────────────
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month    = ref.watch(selectedMonthProvider);
    final txAsync  = ref.watch(transactionProvider);
    final rawLabel = DateFormat('MMMM yyyy', 'es').format(month);
    final label    = rawLabel[0].toUpperCase() + rawLabel.substring(1);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(label,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppTheme.textMuted,
            onPressed: () =>
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: _isCurrentMonth(month)
                ? AppTheme.borderColor
                : AppTheme.textMuted,
            onPressed: _isCurrentMonth(month)
                ? null
                : () => ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentLime)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.expenseRed))),
        data: (txs) => _StatsBody(transactions: txs),
      ),
    );
  }

  static bool _isCurrentMonth(DateTime m) {
    final now = DateTime.now();
    return m.year == now.year && m.month == now.month;
  }
}

// ─────────────────────────────────────────────────────────────
class _CatStat {
  _CatStat({
    required this.id,
    required this.icono,
    required this.nombre,
    this.total = 0,
    this.limiteMensual,
  });
  final int id;
  final String icono;
  final String nombre;
  double total;
  final double? limiteMensual;
}

// ─────────────────────────────────────────────────────────────
class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.transactions});
  final List<Transaction> transactions;

  double _mxn(Transaction tx) =>
      tx.divisa == 'MXN' ? tx.monto : tx.monto * tx.tipoCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gastos   = transactions.where((t) => t.esGasto).toList();
    final ingresos = transactions.where((t) => !t.esGasto).toList();

    final totalGastos   = gastos.fold(0.0,   (s, t) => s + _mxn(t));
    final totalIngresos = ingresos.fold(0.0, (s, t) => s + _mxn(t));
    final net           = totalIngresos - totalGastos;

    // Agrupar gastos por categoría
    final Map<int, _CatStat> byCat = {};
    for (final tx in gastos) {
      final key = tx.categoriaId;
      byCat.putIfAbsent(
        key,
        () => _CatStat(
          id:           key,
          icono:        tx.categoria?.icono ?? '💸',
          nombre:       tx.categoria?.nombre ?? 'Sin categoría',
          limiteMensual: tx.categoria?.limiteMensual,
        ),
      );
      byCat[key]!.total += _mxn(tx);
    }
    final cats = byCat.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Resumen ──────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _SummaryCard(
              label: 'Ingresos',
              amount: totalIngresos,
              color: AppTheme.incomeGreen,
              icon: Icons.arrow_upward_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Gastos',
              amount: totalGastos,
              color: AppTheme.expenseRed,
              icon: Icons.arrow_downward_rounded,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _NetCard(net: net),

        // ── Sin movimientos ───────────────────────────────────
        if (transactions.isEmpty) ...[
          const SizedBox(height: 60),
          const Center(
            child: Column(children: [
              Text('📭', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Sin movimientos este mes',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
            ]),
          ),
        ],

        // ── Pie chart ─────────────────────────────────────────
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 32),
          _sectionLabel('GASTOS POR CATEGORÍA'),
          const SizedBox(height: 16),
          _PieSection(cats: cats, totalGastos: totalGastos),
        ],

        // ── Barras con presupuesto ────────────────────────────
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionLabel('DESGLOSE Y PRESUPUESTO'),
          const SizedBox(height: 12),
          ...cats.asMap().entries.map((entry) {
            final color = _kPieColors[entry.key % _kPieColors.length];
            return _CategoryBudgetBar(
              cat: entry.value,
              totalGastos: totalGastos,
              color: color,
            );
          }),
        ],

        // ── Tendencia 6 meses ─────────────────────────────────
        const SizedBox(height: 32),
        _sectionLabel('TENDENCIA 6 MESES'),
        const SizedBox(height: 16),
        const _TrendSection(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

// ── Pie chart con leyenda ─────────────────────────────────────
class _PieSection extends StatelessWidget {
  const _PieSection({required this.cats, required this.totalGastos});
  final List<_CatStat> cats;
  final double totalGastos;

  @override
  Widget build(BuildContext context) {
    final sections = cats.asMap().entries.map((e) {
      final i   = e.key;
      final cat = e.value;
      final pct = totalGastos > 0 ? cat.total / totalGastos : 0.0;
      return PieChartSectionData(
        color:     _kPieColors[i % _kPieColors.length],
        value:     cat.total,
        radius:    72,
        showTitle: pct > 0.04,
        title:     '${(pct * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 54,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyUtils.formatShort(totalGastos, 'MXN'),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'total',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Leyenda
        Wrap(
          spacing: 14,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: cats.asMap().entries.map((e) {
            final i     = e.key;
            final cat   = e.value;
            final color = _kPieColors[i % _kPieColors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${cat.icono} ${cat.nombre}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Barra de categoría con presupuesto ────────────────────────
class _CategoryBudgetBar extends ConsumerStatefulWidget {
  const _CategoryBudgetBar({
    required this.cat,
    required this.totalGastos,
    required this.color,
  });
  final _CatStat cat;
  final double totalGastos;
  final Color color;

  @override
  ConsumerState<_CategoryBudgetBar> createState() =>
      _CategoryBudgetBarState();
}

class _CategoryBudgetBarState extends ConsumerState<_CategoryBudgetBar> {
  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final pct = widget.totalGastos > 0
        ? (cat.total / widget.totalGastos).clamp(0.0, 1.0)
        : 0.0;

    final limit      = cat.limiteMensual;
    final budgetPct  = limit != null && limit > 0
        ? (cat.total / limit).clamp(0.0, 1.0)
        : null;
    final overBudget = budgetPct != null && budgetPct >= 1.0;

    return GestureDetector(
      onTap: () => _editLimit(context, cat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: overBudget
                ? AppTheme.expenseRed.withValues(alpha: 0.5)
                : AppTheme.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(cat.icono, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(cat.nombre,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatShort(cat.total, 'MXN'),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  if (limit != null)
                    Text(
                      '/ ${CurrencyUtils.formatShort(limit, 'MXN')}',
                      style: TextStyle(
                          color: overBudget
                              ? AppTheme.expenseRed
                              : AppTheme.textMuted,
                          fontSize: 10),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Barra de % del total de gastos
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.bgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 4,
              ),
            ),
            // Barra de presupuesto
            if (budgetPct != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: budgetPct,
                  backgroundColor: AppTheme.bgSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overBudget
                        ? AppTheme.expenseRed
                        : AppTheme.incomeGreen,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  overBudget
                      ? '¡Presupuesto excedido!'
                      : 'Presupuesto: ${(budgetPct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: overBudget
                        ? AppTheme.expenseRed
                        : AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Toca para fijar presupuesto',
                  style: const TextStyle(
                    color: AppTheme.accentLime,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editLimit(BuildContext context, _CatStat cat) async {
    final ctrl = TextEditingController(
      text: cat.limiteMensual != null
          ? cat.limiteMensual!.toStringAsFixed(2)
          : '',
    );

    final result = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${cat.icono} ${cat.nombre}',
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Presupuesto mensual (MXN)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                    color: AppTheme.accentLime,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deja vacío para eliminar el presupuesto.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          if (cat.limiteMensual != null)
            TextButton(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppTheme.expenseRed)),
            ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(context, v ?? -1);
            },
            child: const Text('Guardar',
                style: TextStyle(
                    color: AppTheme.accentLime,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      final newLimit = result <= 0 ? null : result;
      await ref.read(categoryServiceProvider).updateLimit(cat.id, newLimit);
      await ref.read(transactionProvider.notifier).refresh();
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

// ── Gráfica de tendencia 6 meses ─────────────────────────────
class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(trendProvider);

    return asyncData.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(
            child: CircularProgressIndicator(color: AppTheme.accentLime)),
      ),
      error: (e, _) => Text('Error cargando tendencia: $e',
          style: const TextStyle(color: AppTheme.expenseRed)),
      data: (summaries) {
        final allZero =
            summaries.every((s) => s.gastos == 0 && s.ingresos == 0);
        if (allZero) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Text('Sin datos históricos todavía',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          );
        }

        final maxVal = summaries.fold(0.0, (m, s) {
          final top = s.gastos > s.ingresos ? s.gastos : s.ingresos;
          return top > m ? top : m;
        });
        final chartMax = maxVal <= 0 ? 1000.0 : maxVal * 1.3;

        final groups = summaries.asMap().entries.map((e) {
          final s = e.value;
          return BarChartGroupData(
            x: e.key,
            barsSpace: 3,
            barRods: [
              BarChartRodData(
                toY: s.gastos,
                color: AppTheme.expenseRed,
                width: 11,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: s.ingresos,
                color: AppTheme.incomeGreen,
                width: 11,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              // Leyenda
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(AppTheme.expenseRed, 'Gastos'),
                  const SizedBox(width: 20),
                  _dot(AppTheme.incomeGreen, 'Ingresos'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 190,
                child: BarChart(
                  BarChartData(
                    maxY: chartMax,
                    minY: 0,
                    barGroups: groups,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: chartMax / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.borderColor,
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 54,
                          interval: chartMax / 4,
                          getTitlesWidget: (value, meta) => Text(
                            _fmtY(value),
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 9),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= summaries.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('MMM', 'es')
                                    .format(summaries[idx].month),
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      );

  String _fmtY(double val) {
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000)    return '\$${(val / 1000).toStringAsFixed(0)}k';
    return '\$${val.toStringAsFixed(0)}';
  }
}

// ── Cards y widgets auxiliares (igual que antes) ──────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String   label;
  final double   amount;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(
            CurrencyUtils.formatShort(amount, 'MXN'),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text('MXN',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.net});
  final double net;

  @override
  Widget build(BuildContext context) {
    final pos   = net >= 0;
    final color = pos ? AppTheme.incomeGreen : AppTheme.expenseRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pos ? 'Balance positivo ✨' : 'Balance negativo',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            '${pos ? '+' : '−'}${CurrencyUtils.formatShort(net.abs(), 'MXN')} MXN',
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

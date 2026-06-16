import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/meta.dart';
import '../../../models/transaction.dart';
import '../../../providers/meta_provider.dart';
import '../../../providers/transaction_provider.dart';

// ─── Modelo de puntuación ─────────────────────────────────────

class _HealthScore {
  const _HealthScore({
    required this.flujo,
    required this.presupuesto,
    required this.metas,
  });

  final double flujo;        // 0–40 pts
  final double presupuesto;  // 0–30 pts
  final double metas;        // 0–30 pts

  double get total => (flujo + presupuesto + metas).clamp(0, 100);

  String get label {
    final t = total;
    if (t >= 80) return 'Excelente';
    if (t >= 60) return 'Buena';
    if (t >= 40) return 'Regular';
    if (t >= 20) return 'Débil';
    return 'Crítica';
  }

  Color get color {
    final t = total;
    if (t >= 80) return AppTheme.incomeGreen;
    if (t >= 60) return AppTheme.accentLime;
    if (t >= 40) return AppTheme.mxnColor;
    return AppTheme.expenseRed;
  }
}

// ─── Cálculo de puntuación ────────────────────────────────────

_HealthScore _calcScore(
  List<Transaction> transactions,
  List<Meta> metas,
) {
  double mxn(Transaction tx) =>
      tx.divisa == 'MXN' ? tx.monto : tx.monto * tx.tipoCambio;

  final gastos   = transactions.where((t) => t.esGasto).toList();
  final ingresos = transactions.where((t) => !t.esGasto).toList();

  final totalG = gastos.fold(0.0, (s, t) => s + mxn(t));
  final totalI = ingresos.fold(0.0, (s, t) => s + mxn(t));

  // ── Flujo (0–40 pts): ratio ingresos/gastos ──────────────
  double flujoScore;
  if (totalI == 0 && totalG == 0) {
    flujoScore = 20; // mes sin movimientos → neutro
  } else if (totalG == 0) {
    flujoScore = 40;
  } else {
    final ratio = totalI / totalG;
    flujoScore = (ratio.clamp(0, 2) / 2 * 40);
  }

  // ── Presupuesto (0–30 pts): categorías dentro de límite ──
  final Map<int, double> gastadoPorCat = {};
  for (final tx in gastos) {
    gastadoPorCat.update(tx.categoriaId, (v) => v + mxn(tx),
        ifAbsent: () => mxn(tx));
  }

  int catsConLimite = 0;
  int catsDentroLimite = 0;
  for (final tx in gastos) {
    final lim = tx.categoria?.limiteMensual;
    if (lim == null || lim <= 0) continue;
    final key = tx.categoriaId;
    if (!gastadoPorCat.containsKey(key)) continue;
    catsConLimite++;
    if ((gastadoPorCat[key]! / lim) <= 1.0) catsDentroLimite++;
  }
  // Deduplicar: solo contamos una vez por categoría
  final Set<int> catsVisited = {};
  int catsConLimiteUniq = 0;
  int catsDentroLimiteUniq = 0;
  for (final tx in gastos) {
    final lim = tx.categoria?.limiteMensual;
    if (lim == null || lim <= 0) continue;
    final key = tx.categoriaId;
    if (catsVisited.contains(key)) continue;
    catsVisited.add(key);
    catsConLimiteUniq++;
    final gastado = gastadoPorCat[key] ?? 0;
    if (gastado / lim <= 1.0) catsDentroLimiteUniq++;
  }

  double presupuestoScore;
  if (catsConLimiteUniq == 0) {
    presupuestoScore = 15; // sin presupuestos definidos → parcial
  } else {
    presupuestoScore = (catsDentroLimiteUniq / catsConLimiteUniq) * 30;
  }

  // ── Metas (0–30 pts): progreso promedio de metas ─────────
  double metasScore;
  final metasActivas = metas.where((m) => !m.completada).toList();
  final metasCompletadas = metas.where((m) => m.completada).toList();
  if (metas.isEmpty) {
    metasScore = 10; // sin metas → mínimo
  } else {
    final progTotal = metasActivas.fold(0.0, (s, m) => s + m.progreso) +
        metasCompletadas.length.toDouble();
    final avgProg = progTotal / metas.length;
    metasScore = (avgProg * 30).clamp(0, 30);
  }

  return _HealthScore(
    flujo: flujoScore,
    presupuesto: presupuestoScore,
    metas: metasScore,
  );
}

// ─── Widget principal ─────────────────────────────────────────

class FinancialHealthCard extends ConsumerWidget {
  const FinancialHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync   = ref.watch(transactionProvider);
    final metaAsync = ref.watch(metaProvider);

    final transactions = txAsync.valueOrNull ?? [];
    final metas        = metaAsync.valueOrNull ?? [];

    final score = _calcScore(transactions, metas);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: score.color.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: score.color.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────
            Row(children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: score.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SALUD FINANCIERA',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Gauge + detalle ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ScoreGauge(score: score),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FactorRow(
                        label: 'Flujo mensual',
                        icon: Icons.swap_vert_rounded,
                        value: score.flujo,
                        max: 40,
                        color: AppTheme.incomeGreen,
                      ),
                      const SizedBox(height: 10),
                      _FactorRow(
                        label: 'Presupuesto',
                        icon: Icons.pie_chart_rounded,
                        value: score.presupuesto,
                        max: 30,
                        color: AppTheme.accentCyan,
                      ),
                      const SizedBox(height: 10),
                      _FactorRow(
                        label: 'Metas de ahorro',
                        icon: Icons.flag_rounded,
                        value: score.metas,
                        max: 30,
                        color: AppTheme.accentLime,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Sugerencia contextual ──────────────────────
            const SizedBox(height: 16),
            _Tip(score: score),
          ],
        ),
      ),
    );
  }
}

// ─── Gauge circular ───────────────────────────────────────────

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});
  final _HealthScore score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(96, 96),
            painter: _ArcPainter(
              value: score.total / 100,
              color: score.color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: score.color,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              Text(
                score.label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 6;

    const startAngle = math.pi * 0.75;
    const sweepMax   = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = AppTheme.bgSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweepMax, false, trackPaint);

    if (value > 0) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startAngle, sweepMax * value.clamp(0, 1), false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}

// ─── Fila de factor ───────────────────────────────────────────

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.max,
    required this.color,
  });
  final String   label;
  final IconData icon;
  final double   value;
  final double   max;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(0)}/${max.toInt()}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppTheme.bgSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ─── Sugerencia contextual ────────────────────────────────────

class _Tip extends StatelessWidget {
  const _Tip({required this.score});
  final _HealthScore score;

  String get _tipText {
    if (score.total >= 80) {
      return '¡Excelente manejo! Mantén el ritmo y considera diversificar tus inversiones.';
    }
    if (score.flujo < 20) {
      return 'Tus gastos superan tus ingresos. Revisa tus categorías principales.';
    }
    if (score.presupuesto < 15) {
      return 'Define presupuestos mensuales por categoría para ganar control.';
    }
    if (score.metas < 10) {
      return 'Crea metas de ahorro para orientar tus finanzas hacia objetivos claros.';
    }
    return 'Vas por buen camino. Ajusta tus presupuestos para mejorar tu puntuación.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: score.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: score.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 13, color: score.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tipText,
              style: TextStyle(
                color: score.color.withValues(alpha: 0.85),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

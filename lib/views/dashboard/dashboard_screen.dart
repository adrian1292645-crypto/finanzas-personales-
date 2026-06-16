import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/meta.dart';
import '../../models/transaction.dart';
import '../../providers/deuda_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/meta_provider.dart';
import '../../providers/transaction_provider.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../transaction/add_transaction_screen.dart';
import 'widgets/accounts_horizontal_list.dart';
import 'widgets/balance_card.dart';
import 'widgets/financial_health_card.dart';
import 'widgets/recent_transactions_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchCtrl.clear();
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync     = ref.watch(accountProvider);
    final transactionsAsync = ref.watch(transactionProvider);
    final filteredTxs       = ref.watch(filteredTransactionsProvider);
    final selectedMonth     = ref.watch(selectedMonthProvider);
    final metaAsync         = ref.watch(metaProvider);
    final deudaAsync        = ref.watch(deudaProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.read(accountProvider.notifier).refresh(),
          ref.read(transactionProvider.notifier).refresh(),
          ref.read(metaProvider.notifier).refresh(),
        ]),
        color: AppTheme.accentLime,
        backgroundColor: AppTheme.bgCard,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ─────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 64,
              backgroundColor: AppTheme.bgPrimary,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.accentLime, Color(0xFF9ADB00)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mis Finanzas',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                _AppBarIcon(
                  icon: _showSearch
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
                  active: _showSearch,
                  onTap: _toggleSearch,
                  tooltip: 'Buscar',
                ),
                const SizedBox(width: 8),
                _AppBarIcon(
                  icon: Icons.bar_chart_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  ),
                  tooltip: 'Estadísticas',
                ),
                const SizedBox(width: 8),
                _AppBarIcon(
                  icon: Icons.tune_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                  tooltip: 'Ajustes',
                ),
                const SizedBox(width: 16),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),
              ),
            ),

            // ── Balance Card ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: accountsAsync.when(
                  data: (accounts) => BalanceCard(accounts: accounts),
                  loading: () => const _Shimmer(height: 200),
                  error: (e, _) => _ErrorBanner(message: e.toString()),
                ),
              ),
            ),

            // ── Salud financiera ─────────────────────────
            const SliverToBoxAdapter(
              child: FinancialHealthCard(),
            ),

            // ── Resumen del mes (Ingresos / Gastos) ──────
            SliverToBoxAdapter(
              child: transactionsAsync.when(
                data: (_) => _MonthSummaryRow(transactions: filteredTxs),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Alertas de presupuesto ───────────────────
            SliverToBoxAdapter(
              child: transactionsAsync.maybeWhen(
                data: (_) => _BudgetAlertsBanner(transactions: filteredTxs),
                orElse: () => const SizedBox.shrink(),
              ),
            ),

            // ── Cuentas horizontal ───────────────────────
            SliverToBoxAdapter(
              child: accountsAsync.when(
                data: (accounts) =>
                    AccountsHorizontalList(accounts: accounts),
                loading: () => const _Shimmer(
                    height: 130,
                    margin: EdgeInsets.fromLTRB(20, 28, 20, 14)),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Deudas ───────────────────────────────────
            deudaAsync.maybeWhen(
              data: (deudas) {
                final activas = deudas.where((d) => !d.pagada).toList();
                if (activas.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(child: _DeudasSection(deudas: activas));
              },
              orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // ── Metas de ahorro ──────────────────────────
            metaAsync.when(
              data: (metas) => metas.isEmpty
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : SliverToBoxAdapter(
                      child: _GoalsSection(metas: metas),
                    ),
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // ── Buscador ─────────────────────────────────
            if (_showSearch)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accentLime.withValues(alpha: 0.35),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Categoría, cuenta, nota o etiqueta...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.textMuted, size: 18),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                      .read(searchQueryProvider.notifier)
                                      .state = '';
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        ref.read(searchQueryProvider.notifier).state = v;
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),

            // ── Navegación por mes + header ───────────────
            SliverToBoxAdapter(
              child: _MonthNav(
                month: selectedMonth,
                onPrev: () =>
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year,
                            selectedMonth.month - 1),
                onNext: () =>
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year,
                            selectedMonth.month + 1),
              ),
            ),

            // ── Header Movimientos ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MOVIMIENTOS',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    transactionsAsync.maybeWhen(
                      data: (t) {
                        final q =
                            ref.watch(searchQueryProvider).trim();
                        final shown = filteredTxs.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            q.isNotEmpty
                                ? '$shown / ${t.length}'
                                : '${t.length} total',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Lista transacciones ──────────────────────
            transactionsAsync.when(
              data: (_) =>
                  RecentTransactionsList(transactions: filteredTxs),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _Shimmer(
                      height: 72,
                      margin: EdgeInsets.fromLTRB(20, 0, 20, 4)),
                  childCount: 5,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorBanner(message: e.toString()),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────
      floatingActionButton: _FAB(onTap: () => _openAdd(context)),
    );
  }

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días ☀️';
    if (h < 19) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }
}

// ── Resumen mensual ────────────────────────────────────────────
class _MonthSummaryRow extends StatelessWidget {
  const _MonthSummaryRow({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    double ingresos = 0;
    double gastos = 0;
    for (final t in transactions) {
      if (t.esGasto) {
        gastos += t.monto;
      } else {
        ingresos += t.monto;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'INGRESOS',
              amount: ingresos,
              icon: Icons.arrow_downward_rounded,
              color: AppTheme.incomeGreen,
              isIncome: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'GASTOS',
              amount: gastos,
              icon: Icons.arrow_upward_rounded,
              color: AppTheme.expenseRed,
              isIncome: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.isIncome,
  });
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyUtils.formatShort(amount, 'MXN'),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAB personalizado ─────────────────────────────────────────
class _FAB extends StatelessWidget {
  const _FAB({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.accentLime, Color(0xFF9ADB00)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentLime.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }
}

// ── Icon button del AppBar ────────────────────────────────────
class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip = '',
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accentLime.withValues(alpha: 0.15)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? AppTheme.accentLime.withValues(alpha: 0.35)
                  : AppTheme.borderColor,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? AppTheme.accentLime : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Metas de ahorro ───────────────────────────────────────────
class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.metas});
  final List<Meta> metas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.accentLime,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'METAS DE AHORRO',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: metas.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _GoalCard(meta: metas[i]),
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    final pct   = meta.progreso;
    final color = meta.completada
        ? AppTheme.incomeGreen
        : AppTheme.accentLime;

    return Container(
      width: 185,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar at top
          FractionallySizedBox(
            widthFactor: pct.clamp(0.0, 1.0),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.3)],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Text(meta.icono,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta.nombre,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (meta.completada)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '✓ Listo',
                          style: TextStyle(
                              color: AppTheme.incomeGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                  ]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyUtils.formatShort(
                            meta.montoActual, meta.divisa),
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'de ${CurrencyUtils.formatShort(meta.montoMeta, meta.divisa)}  ·  ${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navegación de mes ─────────────────────────────────────────
class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static bool _isCurrentMonth(DateTime m) {
    final n = DateTime.now();
    return m.year == n.year && m.month == n.month;
  }

  @override
  Widget build(BuildContext context) {
    final rawLabel  = DateFormat('MMMM yyyy', 'es').format(month);
    final label     = rawLabel[0].toUpperCase() + rawLabel.substring(1);
    final isCurrent = _isCurrentMonth(month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            _NavBtn(
              icon: Icons.chevron_right_rounded,
              onTap: isCurrent ? null : onNext,
              disabled: isCurrent,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap, this.disabled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: disabled
              ? null
              : Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled
              ? AppTheme.borderColor
              : AppTheme.textMuted,
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.height, this.margin});
  final double height;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
    );
  }
}

// ── Alertas de presupuesto ────────────────────────────────────
class _BudgetAlertsBanner extends StatelessWidget {
  const _BudgetAlertsBanner({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    // Agrupar gastos por categoría y comparar con límites
    final Map<int, _CatAlert> alerts = {};
    for (final tx in transactions) {
      if (!tx.esGasto) continue;
      final cat   = tx.categoria;
      if (cat == null || cat.limiteMensual == null) continue;
      final key   = tx.categoriaId;
      final mxn   = tx.divisa == 'MXN' ? tx.monto : tx.monto * tx.tipoCambio;
      alerts.putIfAbsent(key, () => _CatAlert(
        icono:  cat.icono,
        nombre: cat.nombre,
        limite: cat.limiteMensual!,
      ));
      alerts[key]!.gastado += mxn;
    }

    final over80 = alerts.values
        .where((a) => a.pct >= 0.80)
        .toList()
      ..sort((a, b) => b.pct.compareTo(a.pct));

    if (over80.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: AppTheme.mxnColor),
            const SizedBox(width: 6),
            Text(
              'ALERTAS DE PRESUPUESTO',
              style: TextStyle(
                color: AppTheme.mxnColor.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: over80.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = over80[i];
                final isOver = a.pct >= 1.0;
                final color  = isOver ? AppTheme.expenseRed : AppTheme.mxnColor;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Text(a.icono, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(a.nombre,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOver ? '¡Excedido!' : '${(a.pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: a.pct.clamp(0.0, 1.0),
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatAlert {
  _CatAlert({required this.icono, required this.nombre, required this.limite});
  final String icono;
  final String nombre;
  final double limite;
  double gastado = 0;
  double get pct => limite > 0 ? gastado / limite : 0;
}

// ── Sección de deudas en dashboard ───────────────────────────
class _DeudasSection extends StatelessWidget {
  const _DeudasSection({required this.deudas});
  final List<dynamic> deudas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              decoration: BoxDecoration(
                color: AppTheme.expenseRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DEUDAS',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: deudas.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final d = deudas[i];
              final pct = d.progreso as double;
              return Container(
                width: 175,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text(d.icono as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(d.nombre as String,
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyUtils.formatShort(d.montoActual as double, d.divisa as String),
                          style: const TextStyle(
                              color: AppTheme.expenseRed,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.expenseRed.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.incomeGreen),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.expenseRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.expenseRed.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.expenseRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppTheme.expenseRed, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

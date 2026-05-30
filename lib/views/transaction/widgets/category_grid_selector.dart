import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/category.dart';

class CategoryGridSelector extends StatefulWidget {
  const CategoryGridSelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  /// Lista de categorías PADRE (con sus subcategorías embebidas).
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category> onSelected;

  @override
  State<CategoryGridSelector> createState() => _CategoryGridSelectorState();
}

class _CategoryGridSelectorState
    extends State<CategoryGridSelector> {
  int? _expandedId; // id del padre cuyas subcategorías están visibles

  @override
  void initState() {
    super.initState();
    _syncExpanded();
  }

  @override
  void didUpdateWidget(CategoryGridSelector old) {
    super.didUpdateWidget(old);
    if (old.selected?.id != widget.selected?.id) _syncExpanded();
  }

  void _syncExpanded() {
    final sel = widget.selected;
    if (sel == null) {
      _expandedId = null;
    } else if (sel.parentId != null) {
      // Es subcategoría → expandir su padre
      _expandedId = sel.parentId;
    } else if (sel.hasSubcategories) {
      // Es padre con hijos → mostrarlo expandido
      _expandedId = sel.id;
    } else {
      _expandedId = null;
    }
  }

  void _tapParent(Category cat) {
    if (cat.hasSubcategories) {
      final alreadyOpen = _expandedId == cat.id;
      setState(() => _expandedId = alreadyOpen ? null : cat.id);
      // Auto-seleccionar el padre cuando se abre el panel
      if (!alreadyOpen) widget.onSelected(cat);
    } else {
      setState(() => _expandedId = null);
      widget.onSelected(cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: Text(
            'Sin categorías.\nAgrégalas en tu tabla "categorias" de Supabase.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final expandedCat = _expandedId == null
        ? null
        : widget.categories.where((c) => c.id == _expandedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grid de categorías padre ───────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 76,
          ),
          itemCount: widget.categories.length,
          itemBuilder: (_, i) {
            final cat = widget.categories[i];
            final isSelected = widget.selected?.id == cat.id ||
                widget.selected?.parentId == cat.id;
            return _ParentChip(
              category:          cat,
              isSelected:        isSelected,
              isExpanded:        _expandedId == cat.id,
              onTap:             () => _tapParent(cat),
            );
          },
        ),

        // ── Panel de subcategorías (animado) ───────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: expandedCat != null && expandedCat.hasSubcategories
              ? _SubcategoryPanel(
                  parent:         expandedCat,
                  selected:       widget.selected,
                  onSelectParent: () => widget.onSelected(expandedCat),
                  onSelectSub:    (sub) {
                    widget.onSelected(sub);
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Chip de categoría padre ────────────────────────────────────
class _ParentChip extends StatelessWidget {
  const _ParentChip({
    required this.category,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final Category category;
  final bool     isSelected;
  final bool     isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentLime.withValues(alpha: 0.12)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentLime
                : isExpanded
                    ? AppTheme.accentLime.withValues(alpha: 0.40)
                    : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentLime.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Contenido principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(category.icono,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 5),
                  Text(
                    category.nombre,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.accentLime
                          : AppTheme.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Indicador de subcategorías
            if (category.hasSubcategories)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentLime
                        : const Color(0xFF444444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Panel de subcategorías ─────────────────────────────────────
class _SubcategoryPanel extends StatelessWidget {
  const _SubcategoryPanel({
    required this.parent,
    required this.selected,
    required this.onSelectParent,
    required this.onSelectSub,
  });

  final Category parent;
  final Category? selected;
  final VoidCallback onSelectParent;
  final ValueChanged<Category> onSelectSub;

  @override
  Widget build(BuildContext context) {
    final parentSelected = selected?.id == parent.id;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.accentLime.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del panel
          Row(children: [
            Text(parent.icono,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              parent.nombre.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Chips de subcategorías
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Opción "Solo [padre]" — sin subcategoría
              _SubChip(
                icono:      parent.icono,
                label:      'Solo ${parent.nombre}',
                isSelected: parentSelected,
                isParent:   true,
                onTap:      onSelectParent,
              ),
              // Subcategorías
              ...parent.subcategorias.map((sub) => _SubChip(
                    icono:      sub.icono,
                    label:      sub.nombre,
                    isSelected: selected?.id == sub.id,
                    isParent:   false,
                    onTap:      () => onSelectSub(sub),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chip individual de subcategoría ───────────────────────────
class _SubChip extends StatelessWidget {
  const _SubChip({
    required this.icono,
    required this.label,
    required this.isSelected,
    required this.isParent,
    required this.onTap,
  });

  final String icono;
  final String label;
  final bool   isSelected;
  final bool   isParent;    // true = chip "Solo [padre]"
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentLime.withValues(alpha: 0.15)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentLime
                : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icono,
                style: TextStyle(
                    fontSize: isParent ? 12 : 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.accentLime
                    : AppTheme.textMuted,
                fontSize: isParent ? 11 : 12,
                fontWeight: isParent
                    ? FontWeight.w600
                    : FontWeight.w500,
                fontStyle: isParent
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

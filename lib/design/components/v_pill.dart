import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The `.pill` recipe: a translucent status tint, a 6px coloured dot, bold
/// 11.5px label.
///
/// This is the single place 🟢 ready / 🟡 warning / 🔴 critical is rendered, so
/// the three states cannot drift between the dashboard, the matrix, the coverage
/// list and the alerts screen — the SRS is explicit that they must be identical
/// everywhere.
class VPill extends StatelessWidget {
  const VPill({
    super.key,
    required this.label,
    this.status = VStatus.neutral,
    this.icon,
    this.showDot = true,
    this.compact = false,
    this.color,
    this.background,
  });

  /// Named constructors for the three canonical states.
  const VPill.ready({super.key, this.label = 'Ready', this.icon, this.compact = false})
      : status = VStatus.ready,
        showDot = true,
        color = null,
        background = null;

  const VPill.warning({super.key, this.label = 'Warning', this.icon, this.compact = false})
      : status = VStatus.warning,
        showDot = true,
        color = null,
        background = null;

  const VPill.critical({super.key, this.label = 'Critical', this.icon, this.compact = false})
      : status = VStatus.critical,
        showDot = true,
        color = null,
        background = null;

  final String label;
  final VStatus status;
  final IconData? icon;
  final bool showDot;
  final bool compact;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final fg = color ?? v.forStatus(status);
    final bg = background ?? v.tintFor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: VRadius.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 12.5, color: fg),
            const SizedBox(width: 5),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "on" role chip from the login screen and the filter chips on list
/// screens. When selected it wears the ribbon; when not, the surface scale.
class VChip extends StatelessWidget {
  const VChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final fg = selected ? Colors.white : v.txt2;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: AnimatedContainer(
          duration: VMotion.fast,
          curve: VMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? VRibbon.gradient : null,
            color: selected ? null : v.surface2,
            borderRadius: VRadius.allPill,
            border: Border.all(color: selected ? Colors.transparent : v.line),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: VRibbon.pink.withValues(alpha: 0.35),
                      offset: const Offset(0, 6),
                      blurRadius: 16,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.22) : v.surface3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: context.text.labelSmall?.copyWith(
                      color: fg,
                      fontSize: 10.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A segmented toggle — used for the matrix's level filter and the theme switch.
class VSegmented<T> extends StatelessWidget {
  const VSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expand = false,
  });

  final List<({T value, String label, IconData? icon})> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: v.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final s in segments)
            if (expand)
              Expanded(
                child: _Segment(
                  segment: s,
                  selected: s.value == value,
                  onTap: () => onChanged(s.value),
                ),
              )
            else
              _Segment(
                segment: s,
                selected: s.value == value,
                onTap: () => onChanged(s.value),
              ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.segment, required this.selected, required this.onTap});

  final ({T value, String label, IconData? icon}) segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: VMotion.fast,
          curve: VMotion.enter,
          padding: EdgeInsets.symmetric(
            horizontal: segment.label.isEmpty ? 10 : 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? v.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? v.line2 : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 15, color: selected ? v.txt : v.txt3),
                if (segment.label.isNotEmpty) const SizedBox(width: 6),
              ],
              if (segment.label.isNotEmpty)
                Text(
                  segment.label,
                  style: context.text.labelMedium?.copyWith(
                    color: selected ? v.txt : v.txt3,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square avatar with the ribbon background and initials — the sidebar
/// footer and every "entered by" byline.
class VAvatar extends StatelessWidget {
  const VAvatar({super.key, required this.name, this.size = 36, this.radius = 11});

  final String name;
  final double size;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: VRibbon.gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: context.text.labelLarge?.copyWith(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

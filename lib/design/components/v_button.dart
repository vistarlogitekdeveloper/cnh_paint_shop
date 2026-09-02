import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'loaders.dart';

enum VButtonVariant {
  /// `.btn-grad` — the ribbon gradient. ONE per screen region: it is the
  /// primary action, and two of them means neither is.
  gradient,

  /// `.btn-ghost` — surface fill, hairline border.
  ghost,

  /// Text-only, for tertiary actions and links.
  quiet,

  /// Destructive. Not in the original recipe list, but a shop app has real
  /// destructive actions (reverse an entry, deactivate a user) and they must not
  /// wear the brand gradient.
  danger,
}

enum VButtonSize { small, medium, large }

/// The button family.
///
/// Sizing note: [VButtonSize.large] exists specifically for the operator entry
/// screens. The SRS calls for "big, glove-friendly buttons", and a 44pt target
/// is not glove-friendly — large is 56pt tall with generous horizontal padding.
class VButton extends StatefulWidget {
  const VButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = VButtonVariant.gradient,
    this.size = VButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
  });

  /// Convenience constructors so call sites read as intent.
  const VButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = VButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
  }) : variant = VButtonVariant.ghost;

  const VButton.quiet({
    super.key,
    required this.label,
    this.onPressed,
    this.size = VButtonSize.small,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
  }) : variant = VButtonVariant.quiet;

  const VButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = VButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
  }) : variant = VButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final VButtonVariant variant;
  final VButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Swaps the leading icon for a spinner and blocks taps. The label stays, so
  /// the button does not change width mid-action and shift the layout.
  final bool loading;

  final bool expand;
  final String? tooltip;

  @override
  State<VButton> createState() => _VButtonState();
}

class _VButtonState extends State<VButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  ({double h, double px, double fs, double radius, double gap}) get _metrics =>
      switch (widget.size) {
        VButtonSize.small => (h: 36, px: 14, fs: 13, radius: 10, gap: 7),
        VButtonSize.medium => (h: 46, px: 18, fs: 14, radius: VRadius.sm, gap: 9),
        // Glove-friendly.
        VButtonSize.large => (h: 56, px: 26, fs: 16, radius: 14, gap: 11),
      };

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final m = _metrics;

    final (Color fg, Color? bg, Gradient? gradient, Border? border) = switch (widget.variant) {
      VButtonVariant.gradient => (Colors.white, null, VRibbon.gradient, null),
      VButtonVariant.ghost => (v.txt, _hovered ? v.surface3 : v.surface2, null, Border.all(color: _hovered ? v.line2 : v.line)),
      VButtonVariant.quiet => (v.accent, _hovered ? v.accentTint : Colors.transparent, null, null),
      VButtonVariant.danger => (v.bad, _hovered ? v.badTint : v.badTint.withValues(alpha: 0.5), null, Border.all(color: v.bad.withValues(alpha: 0.4))),
    };

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          VSpinner(size: m.fs + 3, strokeWidth: 2, color: fg)
        else if (widget.icon != null)
          Icon(widget.icon, size: m.fs + 4, color: fg),
        if (widget.loading || widget.icon != null) SizedBox(width: m.gap),
        Flexible(
          child: Text(
            widget.label,
            style: context.text.labelLarge?.copyWith(
              fontSize: m.fs,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          SizedBox(width: m.gap),
          Icon(widget.trailingIcon, size: m.fs + 4, color: fg),
        ],
      ],
    );

    Widget button = AnimatedContainer(
      duration: VMotion.fast,
      curve: VMotion.enter,
      height: m.h,
      padding: EdgeInsets.symmetric(horizontal: m.px),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(m.radius),
        border: border,
        boxShadow: widget.variant == VButtonVariant.gradient && _enabled
            ? [
                BoxShadow(
                  color: VRibbon.pink.withValues(alpha: _hovered ? 0.55 : 0.42),
                  offset: const Offset(0, 12),
                  blurRadius: _hovered ? 30 : 24,
                  spreadRadius: -10,
                ),
              ]
            : null,
      ),
      child: Center(child: content),
    );

    // The gradient variant shifts its background-position on hover, which reads
    // as the ribbon sliding rather than the button merely lightening.
    if (widget.variant == VButtonVariant.gradient) {
      button = AnimatedScale(
        scale: _pressed ? 0.985 : (_hovered ? 1.0 : 1.0),
        duration: VMotion.instant,
        child: AnimatedSlide(
          offset: _hovered && _enabled ? const Offset(0, -0.02) : Offset.zero,
          duration: VMotion.fast,
          child: button,
        ),
      );
    } else {
      button = AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: VMotion.instant,
        child: button,
      );
    }

    if (!_enabled) {
      button = Opacity(opacity: widget.loading ? 0.85 : 0.45, child: button);
    }

    button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: button,
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: button,
    );
  }
}

/// A square icon button on the surface scale — app-bar actions, row actions.
class VIconButton extends StatefulWidget {
  const VIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize = 19,
    this.color,
    this.badgeCount,
    this.showDot = false,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;

  /// A count badge. Rendered as "9+" past nine so the pill keeps its shape.
  final int? badgeCount;

  /// The notification dot from the design system's topbar icons.
  final bool showDot;

  final bool filled;

  @override
  State<VIconButton> createState() => _VIconButtonState();
}

class _VIconButtonState extends State<VIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final enabled = widget.onPressed != null;

    Widget button = AnimatedContainer(
      duration: VMotion.fast,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.filled ? (_hovered ? v.surface3 : v.surface2) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: widget.filled ? Border.all(color: _hovered ? v.line2 : v.line) : null,
      ),
      child: Icon(
        widget.icon,
        size: widget.iconSize,
        color: widget.color ?? (_hovered ? v.txt : v.txt2),
      ),
    );

    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: v.bad,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: v.bg, width: 1.5),
              ),
              child: Text(
                widget.badgeCount! > 9 ? '9+' : '${widget.badgeCount}',
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (widget.showDot) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: 1,
            right: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: v.accent,
                shape: BoxShape.circle,
                border: Border.all(color: v.bg, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: widget.onPressed, child: button),
    );

    if (!enabled) button = Opacity(opacity: 0.45, child: button);

    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;
  }
}

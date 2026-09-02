import 'package:flutter/material.dart';

import '../brand_assets.dart';
import '../theme.dart';
import '../tokens.dart';

/// The `.card` recipe: a subtle vertical wash, a 1px hairline, radius 16, and
/// optionally the S mark bleeding off the bottom-right corner at 5%.
///
/// `glow: true` adds the hover lift (`translateY(-2px)` + the pink glow shadow).
/// Hover only fires on pointer devices, which is correct — on the shop-floor
/// tablet there is no hover state to speak of and the lift would never show.
class VCard extends StatefulWidget {
  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VSpace.lg),
    this.glow = false,
    this.cornerMark = false,
    this.onTap,
    this.borderColor,
    this.radius = VRadius.md,
    this.gradient,
    this.width,
    this.height,
    this.accentEdge,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Lift + ribbon glow on hover. Use on cards that are actually actionable.
  final bool glow;

  /// The S corner accent. Reserved for feature cards; on a grid of twelve KPI
  /// tiles it becomes wallpaper.
  final bool cornerMark;

  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;
  final Gradient? gradient;
  final double? width;
  final double? height;

  /// A 3px status stripe down the leading edge. Used by alert and coverage
  /// cards so the state is readable before any text is.
  final Color? accentEdge;

  @override
  State<VCard> createState() => _VCardState();
}

class _VCardState extends State<VCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final lifted = widget.glow && _hovered;

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: widget.gradient ?? v.cardGradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.borderColor ?? (lifted ? v.line2 : v.line)),
        boxShadow: lifted
            ? [
                for (final s in v.glow)
                  BoxShadow(color: s.color, offset: s.offset, blurRadius: s.blurRadius),
              ]
            : null,
      ),
      child: widget.child,
    );

    if (widget.cornerMark) {
      content = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ClipRRect so the mark is trimmed by the card's radius rather than
          // spilling past the rounded corner.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Stack(
                children: [
                  Positioned(
                    right: -26,
                    bottom: -30,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: v.isDark ? 0.05 : 0.035,
                        child: Image.asset(VBrand.mark, width: 120, height: 120),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          content,
        ],
      );
    }

    if (widget.accentEdge != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: VSpace.md,
            bottom: VSpace.md,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: widget.accentEdge,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      );
    }

    // A 2px lift is enough to read as "this responds" without shifting the grid.
    content = AnimatedSlide(
      offset: lifted ? const Offset(0, -0.006) : Offset.zero,
      duration: VMotion.fast,
      curve: VMotion.enter,
      child: content,
    );

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.radius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.radius),
          child: content,
        ),
      );
    }

    if (widget.glow || widget.onTap != null) {
      content = MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: content,
      );
    }

    return content;
  }
}

/// A KPI tile: icon chip, label, big display number, optional delta line.
///
/// The number uses the ribbon as a `background-clip: text` gradient when
/// [gradientValue] is set — the design system's signature treatment for the
/// figure that matters most on a screen. Used sparingly: one per card at most.
class VKpiCard extends StatelessWidget {
  const VKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.caption,
    this.captionColor,
    this.onTap,
    this.gradientValue = false,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String? caption;
  final Color? captionColor;
  final VoidCallback? onTap;
  final bool gradientValue;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    final numberStyle = context.text.displaySmall!.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1,
      color: gradientValue ? Colors.white : (valueColor ?? v.txt),
    );

    Widget number = Text(value, style: numberStyle, maxLines: 1);
    if (gradientValue) {
      number = ShaderMask(
        // srcIn keeps only the glyph coverage, so the ribbon shows through the
        // letterforms — the Flutter equivalent of background-clip: text.
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => VRibbon.gradient.createShader(bounds),
        child: number,
      );
    }

    return VCard(
      glow: onTap != null,
      onTap: onTap,
      cornerMark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBackground ?? v.accentTint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: iconColor ?? v.accent),
                ),
              if (icon != null) const SizedBox(width: VSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(color: v.txt2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: VSpace.md),
          number,
          if (caption != null) ...[
            const SizedBox(height: VSpace.xs),
            Text(
              caption!,
              style: context.text.bodySmall?.copyWith(color: captionColor ?? v.txt3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// The `.sect-ttl` recipe: a 5×16 ribbon bar, then the title, then optional
/// trailing actions.
class VSectionTitle extends StatelessWidget {
  const VSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.only(bottom: VSpace.md),
  });

  final String title;
  final Widget? trailing;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 16,
            decoration: const BoxDecoration(
              gradient: VRibbon.bar,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          const SizedBox(width: VSpace.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: v.txt,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: context.text.bodySmall?.copyWith(color: v.txt3)),
              ],
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

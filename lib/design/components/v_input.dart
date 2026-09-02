import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';

/// The `.inp` recipe, including the part the InputDecorationTheme cannot express:
/// the OUTER pink halo on focus (`box-shadow: 0 0 0 4px rgba(224,33,138,.12)`).
///
/// Flutter draws an InputBorder inside the field's bounds, so the halo is a real
/// box-shadow on a wrapper that animates in with focus. Without it the focus
/// state is a 1px colour change, which on a bright shop floor is close to
/// invisible — and this app's whole entry flow is keyboard-driven.
class VInput extends StatefulWidget {
  const VInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.large = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  /// Taller field + bigger type, for the operator entry screens.
  final bool large;

  final TextCapitalization textCapitalization;
  final TextAlign textAlign;

  @override
  State<VInput> createState() => _VInputState();
}

class _VInputState extends State<VInput> {
  FocusNode? _internalNode;
  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _internalNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final ringColor = hasError ? v.bad : v.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: context.text.labelMedium?.copyWith(
              color: _focused ? ringColor : v.txt2,
              fontWeight: FontWeight.w700,
              fontSize: widget.large ? 13.5 : 12.5,
            ),
          ),
          const SizedBox(height: VSpace.xs),
        ],
        AnimatedContainer(
          duration: VMotion.fast,
          curve: VMotion.enter,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.large ? 14 : VRadius.sm),
            boxShadow: (_focused || hasError)
                ? [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.12),
                      // spreadRadius with zero blur reproduces the CSS's crisp
                      // 4px ring rather than a soft glow.
                      spreadRadius: 4,
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _node,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            textAlign: widget.textAlign,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            style: context.text.bodyLarge?.copyWith(
              color: v.txt,
              fontSize: widget.large ? 17 : 14,
              fontWeight: widget.large ? FontWeight.w600 : FontWeight.w500,
            ),
            cursorColor: v.accent,
            cursorWidth: 1.8,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: null, // rendered below, so the ring geometry stays stable
              counterText: '',
              filled: true,
              fillColor: _focused ? v.surface2 : v.surface,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: widget.large ? 22 : 18)
                  : null,
              prefixIconConstraints: BoxConstraints(minWidth: widget.large ? 48 : 42),
              suffixIcon: widget.suffix,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: widget.large ? 18 : 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.large ? 14 : VRadius.sm),
                borderSide: BorderSide(color: v.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.large ? 14 : VRadius.sm),
                borderSide: BorderSide(color: hasError ? v.bad.withValues(alpha: 0.7) : v.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.large ? 14 : VRadius.sm),
                borderSide: BorderSide(color: ringColor.withValues(alpha: 0.6), width: 1.4),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: VSpace.xs),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 13, color: v.bad),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: context.text.bodySmall?.copyWith(
                    color: v.bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: VSpace.xs),
          Text(widget.helper!, style: context.text.bodySmall?.copyWith(color: v.txt3)),
        ],
      ],
    );
  }
}

/// A styled dropdown that matches [VInput]'s geometry, so a form row mixing a
/// field and a select does not look like two different widgets stapled together.
class VDropdown<T> extends StatelessWidget {
  const VDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.itemLabel,
    this.prefixIcon,
    this.large = false,
    this.enabled = true,
    this.errorText,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final String Function(T)? itemLabel;
  final IconData? prefixIcon;
  final bool large;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final radius = large ? 14.0 : VRadius.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.text.labelMedium?.copyWith(
              color: v.txt2,
              fontWeight: FontWeight.w700,
              fontSize: large ? 13.5 : 12.5,
            ),
          ),
          const SizedBox(height: VSpace.xs),
        ],
        Container(
          decoration: BoxDecoration(
            color: v.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: hasError ? v.bad.withValues(alpha: 0.7) : v.line),
          ),
          padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: large ? 22 : 18, color: v.txt3),
                const SizedBox(width: VSpace.sm),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    isDense: false,
                    // The dropdown draws its own chevron; matching the design
                    // system's compact arrow keeps it from looking Material-y.
                    icon: Icon(Icons.expand_more_rounded, size: large ? 22 : 19, color: v.txt3),
                    dropdownColor: v.surface2,
                    borderRadius: VRadius.allMd,
                    padding: EdgeInsets.symmetric(vertical: large ? 12 : 7),
                    hint: hint != null
                        ? Text(hint!, style: context.text.bodyMedium?.copyWith(color: v.txt3))
                        : null,
                    style: context.text.bodyLarge?.copyWith(
                      color: v.txt,
                      fontSize: large ? 17 : 14,
                      fontWeight: large ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onChanged: enabled ? onChanged : null,
                    items: [
                      for (final item in items)
                        DropdownMenuItem<T>(
                          value: item,
                          child: Text(
                            itemLabel?.call(item) ?? item.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: VSpace.xs),
          Text(
            errorText!,
            style: context.text.bodySmall?.copyWith(color: v.bad, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// The search field used in the topbar and on every list screen.
///
/// Debouncing is the caller's job (see `Debouncer`); this widget only owns the
/// clear affordance and the focus ring, because different screens want
/// different debounce windows.
class VSearchField extends StatefulWidget {
  const VSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.controller,
    this.autofocus = false,
    this.width,
    this.large = false,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;
  final bool autofocus;
  final double? width;
  final bool large;

  @override
  State<VSearchField> createState() => _VSearchFieldState();
}

class _VSearchFieldState extends State<VSearchField> {
  TextEditingController? _internal;
  TextEditingController get _controller => widget.controller ?? (_internal ??= TextEditingController());

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return SizedBox(
      width: widget.width,
      child: VInput(
        controller: _controller,
        hint: widget.hint,
        prefixIcon: Icons.search_rounded,
        autofocus: widget.autofocus,
        large: widget.large,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {}); // reveal / hide the clear button
        },
        suffix: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, size: 17, color: v.txt3),
                splashRadius: 16,
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}

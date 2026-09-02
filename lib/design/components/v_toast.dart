import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The slide-in confirmation toast.
///
/// Used instead of a bare SnackBar because operator feedback here has to carry
/// STATE, not just text: a save is green, a queued-offline save is amber, a
/// refused save is red. On the nesting screen the toast is often the only
/// confirmation the operator gets before moving to the next part, so it has to
/// be unambiguous at a glance and from arm's length.
abstract final class VToast {
  static void show(
    BuildContext context, {
    required String message,
    VStatus status = VStatus.ready,
    String? detail,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final v = Theme.of(context).extension<VColors>() ?? VColors.dark;
    final fg = v.forStatus(status);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // One toast at a time. A burst of saves should show the latest result, not
    // stack four overlapping cards over the entry form.
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(VSpace.lg),
        padding: EdgeInsets.zero,
        content: _ToastCard(
          message: message,
          detail: detail,
          status: status,
          fg: fg,
          icon: icon ?? _iconFor(status),
          colors: v,
          action: action,
        ),
      ),
    );
  }

  static void success(BuildContext context, String message, {String? detail}) =>
      show(context, message: message, detail: detail, status: VStatus.ready);

  static void warning(BuildContext context, String message, {String? detail}) =>
      show(context, message: message, detail: detail, status: VStatus.warning);

  static void error(BuildContext context, String message, {String? detail}) => show(
        context,
        message: message,
        detail: detail,
        status: VStatus.critical,
        // Errors linger: the operator may need to read a validation message
        // like "pattern is awaiting Planner approval" before it disappears.
        duration: const Duration(seconds: 5),
      );

  static void info(BuildContext context, String message, {String? detail}) =>
      show(context, message: message, detail: detail, status: VStatus.info);

  /// Queued-offline confirmation. Amber, because the entry is SAVED but not yet
  /// synced — telling the operator it succeeded outright would be a lie.
  static void queued(BuildContext context, {int pending = 1}) => show(
        context,
        message: 'Saved on this device',
        detail: pending > 1
            ? '$pending entries waiting to sync — they will upload automatically.'
            : 'It will upload automatically when the connection returns.',
        status: VStatus.warning,
        icon: Icons.cloud_off_rounded,
        duration: const Duration(seconds: 4),
      );

  static IconData _iconFor(VStatus s) => switch (s) {
        VStatus.ready => Icons.check_circle_rounded,
        VStatus.warning => Icons.warning_amber_rounded,
        VStatus.critical => Icons.error_rounded,
        VStatus.info => Icons.info_rounded,
        VStatus.neutral => Icons.notifications_rounded,
      };
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.detail,
    required this.status,
    required this.fg,
    required this.icon,
    required this.colors,
    required this.action,
  });

  final String message;
  final String? detail;
  final VStatus status;
  final Color fg;
  final IconData icon;
  final VColors colors;
  final SnackBarAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.md),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: VRadius.allMd,
        border: Border.all(color: colors.line2),
        boxShadow: [
          for (final s in colors.shadow)
            BoxShadow(color: s.color, offset: s.offset, blurRadius: s.blurRadius),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.tintFor(status),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: context.text.titleSmall?.copyWith(color: colors.txt, fontSize: 14),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: context.text.bodySmall?.copyWith(color: colors.txt3, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: VSpace.sm),
            TextButton(
              onPressed: action!.onPressed,
              child: Text(
                action!.label,
                style: context.text.labelMedium?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

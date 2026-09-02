import 'package:flutter/material.dart';

import '../brand_assets.dart';
import '../theme.dart';
import '../tokens.dart';
import 'v_button.dart';

/// Empty / error / offline states.
///
/// Every list screen in this app has all three, and they are worth getting right
/// because they are what the operator sees when something has gone wrong on a
/// shop floor with no one to ask. Each one says WHAT happened, and offers the
/// single most useful next action — never just a shrug and an icon.
class VEmptyState extends StatelessWidget {
  const VEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? VSpace.lg : VSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 52 : 68,
                height: compact ? 52 : 68,
                decoration: BoxDecoration(
                  color: v.surface2,
                  borderRadius: BorderRadius.circular(compact ? 16 : 20),
                  border: Border.all(color: v.line),
                ),
                child: Icon(icon, size: compact ? 24 : 30, color: v.txt3),
              ),
              SizedBox(height: compact ? VSpace.md : VSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(color: v.txt),
              ),
              if (message != null) ...[
                const SizedBox(height: VSpace.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: v.txt3),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? VSpace.md : VSpace.lg),
                VButton.ghost(label: actionLabel!, onPressed: onAction, icon: Icons.refresh_rounded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The error state. Shows the message the server actually sent — an operator
/// reporting "it says the pattern is awaiting approval" gets help far faster
/// than one reporting "it says something went wrong".
class VErrorState extends StatelessWidget {
  const VErrorState({
    super.key,
    required this.message,
    this.title = 'Could not load this',
    this.onRetry,
    this.code,
    this.compact = false,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String? code;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? VSpace.lg : VSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 52 : 68,
                height: compact ? 52 : 68,
                decoration: BoxDecoration(
                  color: v.badTint,
                  borderRadius: BorderRadius.circular(compact ? 16 : 20),
                ),
                child: Icon(
                  Icons.wifi_tethering_error_rounded,
                  size: compact ? 24 : 30,
                  color: v.bad,
                ),
              ),
              SizedBox(height: compact ? VSpace.md : VSpace.lg),
              Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
              const SizedBox(height: VSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: v.txt3),
              ),
              if (code != null) ...[
                const SizedBox(height: VSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: v.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: v.line),
                  ),
                  child: Text(
                    code!,
                    style: context.text.labelSmall?.copyWith(color: v.txt3, letterSpacing: 0.4),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(height: compact ? VSpace.md : VSpace.lg),
                VButton.ghost(label: 'Try again', onPressed: onRetry, icon: Icons.refresh_rounded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The offline banner. Pinned under the topbar whenever connectivity drops, with
/// the unsynced count — so an operator can keep working and can see that nothing
/// has been lost.
class VOfflineBanner extends StatelessWidget {
  const VOfflineBanner({
    super.key,
    required this.pendingCount,
    this.onSyncNow,
    this.syncing = false,
  });

  final int pendingCount;
  final VoidCallback? onSyncNow;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.lg, vertical: VSpace.sm),
      decoration: BoxDecoration(
        color: v.warnTint,
        border: Border(bottom: BorderSide(color: v.warn.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 17, color: v.warn),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? 'Working offline — $pendingCount ${pendingCount == 1 ? 'entry' : 'entries'} saved on this device, waiting to sync.'
                  : 'Working offline. Entries are saved on this device and will sync automatically.',
              style: context.text.bodySmall?.copyWith(
                color: v.warn,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onSyncNow != null && pendingCount > 0) ...[
            const SizedBox(width: VSpace.sm),
            VButton.quiet(
              label: syncing ? 'Syncing…' : 'Sync now',
              onPressed: syncing ? null : onSyncNow,
              loading: syncing,
              size: VButtonSize.small,
            ),
          ],
        ],
      ),
    );
  }
}

/// A full-screen "no data yet" state that leans on the brand mark. Used for the
/// dashboard before any line is set up, where a bare icon would feel unfinished.
class VBrandedEmptyState extends StatelessWidget {
  const VBrandedEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: v.isDark ? 0.30 : 0.22,
                child: Image.asset(VBrand.mark, width: 104, height: 104),
              ),
              const SizedBox(height: VSpace.lg),
              Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              const SizedBox(height: VSpace.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: v.txt3, height: 1.55),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: VSpace.xl),
                VButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

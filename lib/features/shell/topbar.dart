import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';

/// The 64px blurred topbar.
///
/// Carries what the CNH prototype's header carried — user name, shift, login
/// time — plus the line selector, because every screen in this app is scoped to
/// a production line and switching it is the single most frequent action after
/// entering data.
class AppTopbar extends ConsumerWidget {
  const AppTopbar({super.key, this.showMenuButton = false});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < VBreak.tablet;

    final badges = ref.watch(badgeCountsProvider).valueOrNull;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: VSpace.lg),
          decoration: BoxDecoration(
            color: v.bg.withValues(alpha: 0.72),
            border: Border(bottom: BorderSide(color: v.line)),
          ),
          child: Row(
            children: [
              if (showMenuButton) ...[
                VIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: VSpace.sm),
              ],

              // The line selector. First, because it changes what every other
              // number on screen means.
              const _LineSelector(),

              if (!compact) ...[
                const SizedBox(width: VSpace.md),
                Container(width: 1, height: 26, color: v.line),
                const SizedBox(width: VSpace.md),
                Expanded(child: _ShiftInfo(user: user)),
              ] else
                const Spacer(),

              // Quick "can I build machine N?" — the SRS's step 7, reachable
              // from anywhere rather than only from its own screen.
              if (!compact && (user?.can(Perm.coverageView) ?? false)) ...[
                VIconButton(
                  icon: Icons.fact_check_rounded,
                  tooltip: 'Can I build machine…?',
                  onPressed: () => context.go(Routes.canBuild),
                ),
                const SizedBox(width: VSpace.xs),
              ],

              // Theme toggle. Cycles system → light → dark.
              const _ThemeToggle(),
              const SizedBox(width: VSpace.xs),

              if (user?.can(Perm.alertView) ?? false) ...[
                VIconButton(
                  icon: Icons.notifications_rounded,
                  tooltip: badges == null
                      ? 'Alerts'
                      : '${badges.redAlerts} critical · ${badges.yellowAlerts} warning',
                  badgeCount: badges?.totalAlerts,
                  onPressed: () => context.go(Routes.alerts),
                ),
                const SizedBox(width: VSpace.xs),
              ],

              if (user?.can(Perm.requestApprove) ?? false) ...[
                VIconButton(
                  icon: Icons.approval_rounded,
                  tooltip: 'Approvals waiting',
                  badgeCount: badges?.pendingApprovals,
                  onPressed: () => context.go(Routes.approvals),
                ),
                const SizedBox(width: VSpace.xs),
              ],

              const _SyncIndicator(),

              if (compact && user != null) ...[
                const SizedBox(width: VSpace.sm),
                VAvatar(name: user.fullName, size: 34),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The production-line picker.
class _LineSelector extends ConsumerWidget {
  const _LineSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final linesAsync = ref.watch(linesProvider);
    final selectedId = ref.watch(selectedLineIdProvider);

    return linesAsync.when(
      loading: () => const VShimmerScope(child: VSkeleton(width: 148, height: 38, radius: 11)),
      error: (_, _) => VPill(
        label: 'Lines unavailable',
        status: VStatus.critical,
        icon: Icons.error_outline_rounded,
      ),
      data: (lines) {
        if (lines.isEmpty) {
          return const VPill(label: 'No lines set up', status: VStatus.warning);
        }
        final selected = lines.firstWhere(
          (l) => l.id == selectedId,
          orElse: () => lines.first,
        );

        return Container(
          height: 38,
          padding: const EdgeInsets.only(left: VSpace.md, right: VSpace.xs),
          decoration: BoxDecoration(
            color: v.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: v.line),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: const BoxDecoration(
                  gradient: VRibbon.bar,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selected.id,
                  isDense: true,
                  icon: Icon(Icons.expand_more_rounded, size: 18, color: v.txt3),
                  dropdownColor: v.surface2,
                  borderRadius: VRadius.allMd,
                  style: context.text.titleSmall?.copyWith(color: v.txt, fontSize: 13.5),
                  onChanged: (id) => ref.read(selectedLineIdProvider.notifier).select(id),
                  items: [
                    for (final line in lines)
                      DropdownMenuItem(
                        value: line.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(line.code, style: context.text.titleSmall?.copyWith(fontSize: 13.5)),
                            const SizedBox(width: VSpace.xs),
                            Text(
                              line.name,
                              style: context.text.bodySmall?.copyWith(color: v.txt3),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// User name, role, shift and login time — the prototype's header line.
class _ShiftInfo extends StatelessWidget {
  const _ShiftInfo({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    if (user == null) return const SizedBox.shrink();

    final login = user!.lastLoginAt;
    final loginText = login == null
        ? null
        : '${login.day.toString().padLeft(2, '0')}-${login.month.toString().padLeft(2, '0')}-${login.year} '
            '${login.hour.toString().padLeft(2, '0')}:${login.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        _MetaChip(label: 'User', value: user!.fullName),
        if (user!.shift != null) _MetaChip(label: 'Shift', value: '${user!.shift}'),
        if (loginText != null) _MetaChip(label: 'Login', value: loginText),
        // Next process is always Painting for this shop — shown because the
        // prototype's operators are used to reading it there.
        _MetaChip(label: 'Next process', value: 'Painting', color: v.info),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Padding(
      padding: const EdgeInsets.only(right: VSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: color ?? v.txt2,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (icon, tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'Theme: follows device'),
      ThemeMode.light => (Icons.light_mode_rounded, 'Theme: light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'Theme: dark'),
    };

    return VIconButton(
      icon: icon,
      tooltip: '$tooltip — tap to change',
      onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
    );
  }
}

/// Connection + queue state, in one glanceable control.
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    if (status == null) return const SizedBox.shrink();

    if (status.syncing) {
      return Tooltip(
        message: 'Syncing…',
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: v.surface2,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: v.line),
          ),
          child: Center(child: VSpinner(size: 17, color: v.accent)),
        ),
      );
    }

    if (!status.online) {
      return VIconButton(
        icon: Icons.cloud_off_rounded,
        color: v.warn,
        tooltip: pending > 0
            ? 'Offline — $pending waiting on this device'
            : 'Offline. Entries are saved on this device.',
        badgeCount: pending > 0 ? pending : null,
        onPressed: () => context.go(Routes.syncQueue),
      );
    }

    if (pending > 0) {
      return VIconButton(
        icon: Icons.cloud_upload_rounded,
        color: v.warn,
        tooltip: '$pending waiting to sync — tap to review',
        badgeCount: pending,
        onPressed: () => context.go(Routes.syncQueue),
      );
    }

    final last = status.lastSyncAt;
    return VIconButton(
      icon: Icons.cloud_done_rounded,
      color: v.ok,
      tooltip: last == null
          ? 'Everything is synced'
          : 'Everything is synced · last at ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
      onPressed: () => ref.read(syncServiceProvider).flush(force: true),
    );
  }
}

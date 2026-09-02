import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Admin & Setup.
///
/// Six sections, each gated on its own permission rather than on one blanket
/// admin check — a Planner holds THRESHOLD_MANAGE but not USER_MANAGE, and the
/// screen should reflect that instead of being all-or-nothing.
///
/// Structured as several small private widgets because this is by far the
/// largest screen in the app and one build method would be unreadable.
/// ---------------------------------------------------------------------------

enum _Section { users, thresholds, racks, parts, import, maintenance }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  _Section _section = _Section.thresholds;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final available = <(_Section, String, IconData)>[
      if (user.can(Perm.userManage)) (_Section.users, 'Users', Icons.people_rounded),
      if (user.canAny([Perm.thresholdManage, Perm.masterManage]))
        (_Section.thresholds, 'Thresholds', Icons.tune_rounded),
      if (user.can(Perm.masterManage)) (_Section.racks, 'Racks', Icons.shelves),
      if (user.can(Perm.masterManage)) (_Section.parts, 'Parts', Icons.inventory_2_rounded),
      if (user.can(Perm.importManage)) (_Section.import, 'Excel import', Icons.upload_file_rounded),
      if (user.canAny([Perm.masterManage, Perm.thresholdManage]))
        (_Section.maintenance, 'Maintenance', Icons.build_rounded),
    ];

    if (available.isEmpty) {
      return const VEmptyState(
        title: 'Nothing to set up here',
        message: 'Your role does not manage users, masters or imports.',
        icon: Icons.lock_outline_rounded,
      );
    }

    // The initial section must be one the user can actually see.
    if (!available.any((s) => s.$1 == _section)) {
      _section = available.first.$1;
    }

    return VPageBody(
      children: [
        const VPageHeader(
          breadcrumb: ['Records', 'Admin & Setup'],
          title: 'Admin & Setup',
          description: 'Users, alert thresholds, racks, parts and the go-live Excel import.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: VSegmented<_Section>(
            value: _section,
            onChanged: (next) => setState(() => _section = next),
            segments: [
              for (final (section, label, icon) in available)
                (value: section, label: label, icon: icon),
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),
        switch (_section) {
          _Section.users => const _UsersSection(),
          _Section.thresholds => const _ThresholdsSection(),
          _Section.racks => const _RacksSection(),
          _Section.parts => const _PartsSection(),
          _Section.import => const _ImportSection(),
          _Section.maintenance => const _MaintenanceSection(),
        },
      ],
    );
  }
}

// ===========================================================================
// 1. Users
// ===========================================================================
class _UsersSection extends ConsumerWidget {
  const _UsersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final async = ref.watch(usersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSectionTitle(
          title: 'Users & roles',
          subtitle: 'Login is by employee code. A role decides which screens open.',
          trailing: VButton(
            label: 'Add user',
            icon: Icons.person_add_rounded,
            size: VButtonSize.small,
            onPressed: () => _openUserSheet(context, ref, null),
          ),
        ),
        async.when(
          loading: () => const VSkeletonList(rows: 5, height: 64),
          error: (error, _) => VErrorState(
            message: describeError(error),
            compact: true,
            onRetry: () => ref.invalidate(usersProvider),
          ),
          data: (users) => Column(
            children: [
              for (final user in users)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.xs),
                  child: VCard(
                    onTap: () => _openUserSheet(context, ref, user),
                    padding: const EdgeInsets.all(VSpace.md),
                    child: Row(
                      children: [
                        VAvatar(name: user.fullName, size: 36),
                        const SizedBox(width: VSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleSmall?.copyWith(fontSize: 14),
                                    ),
                                  ),
                                  if (!user.isActive) ...[
                                    const SizedBox(width: VSpace.xs),
                                    const VPill(
                                      label: 'Inactive',
                                      status: VStatus.neutral,
                                      compact: true,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${user.empCode} · ${user.role.label}'
                                '${user.shift != null ? ' · Shift ${user.shift}' : ''}',
                                style: context.text.bodySmall?.copyWith(
                                  color: v.txt3,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: v.txt3),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static void _openUserSheet(BuildContext context, WidgetRef ref, AppUser? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _UserSheet(existing: existing),
    );
  }
}

class _UserSheet extends ConsumerStatefulWidget {
  const _UserSheet({this.existing});

  final AppUser? existing;

  @override
  ConsumerState<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends ConsumerState<_UserSheet> {
  late final TextEditingController _code =
      TextEditingController(text: widget.existing?.empCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.fullName ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _shift =
      TextEditingController(text: widget.existing?.shift?.toString() ?? '');
  final _password = TextEditingController();

  late UserRole _role = widget.existing?.role ?? UserRole.nestingOperator;
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _shift.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Padding(
      padding: EdgeInsets.only(
        left: VSpace.xl,
        right: VSpace.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + VSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'Add a user' : 'Edit ${widget.existing!.fullName}',
                style: context.text.headlineSmall),
            const SizedBox(height: VSpace.lg),

            VInput(
              controller: _code,
              label: 'Employee code',
              hint: 'e.g. NES01',
              // The code is the login identity; changing it after the fact would
              // orphan the audit trail's attribution in people's heads.
              enabled: _isNew,
              helper: _isNew ? null : 'The employee code cannot be changed.',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            ),
            const SizedBox(height: VSpace.md),
            VInput(controller: _name, label: 'Full name', hint: 'As it should appear on entries'),
            const SizedBox(height: VSpace.md),
            VDropdown<UserRole>(
              label: 'Role',
              items: UserRole.values,
              value: _role,
              itemLabel: (r) => r.label,
              onChanged: (next) => setState(() => _role = next ?? _role),
            ),
            const SizedBox(height: VSpace.md),
            Row(
              children: [
                Expanded(child: VInput(controller: _phone, label: 'Phone', hint: 'For push')),
                const SizedBox(width: VSpace.md),
                SizedBox(
                  width: 100,
                  child: VInput(
                    controller: _shift,
                    label: 'Shift',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),
            VInput(controller: _email, label: 'E-mail', hint: 'Optional'),
            const SizedBox(height: VSpace.md),
            VInput(
              controller: _password,
              label: _isNew ? 'Password' : 'Reset password',
              hint: _isNew ? 'At least 6 characters' : 'Leave blank to keep the current one',
              obscureText: true,
              helper: _isNew
                  ? null
                  // Worth saying out loud: the server revokes every refresh
                  // token for that user, so all their devices sign out.
                  : 'Setting a password signs the user out of every device.',
            ),

            if (!_isNew) ...[
              const SizedBox(height: VSpace.md),
              SwitchListTile(
                value: _active,
                onChanged: (next) => setState(() => _active = next),
                title: const Text('Active'),
                subtitle: Text(
                  _active ? 'Can sign in' : 'Cannot sign in; existing sessions are revoked',
                  style: context.text.bodySmall?.copyWith(color: v.txt3),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: VSpace.md),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(color: v.bad, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: VSpace.xl),
            VButton(
              label: _isNew ? 'Create user' : 'Save changes',
              icon: Icons.check_rounded,
              size: VButtonSize.large,
              expand: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A full name is required.');
      return;
    }
    if (_isNew && (_code.text.trim().isEmpty || _password.text.length < 6)) {
      setState(() => _error = 'An employee code and a password of at least 6 characters '
          'are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      final shift = int.tryParse(_shift.text.trim());

      if (_isNew) {
        await repo.create({
          'emp_code': _code.text.trim(),
          'full_name': _name.text.trim(),
          'role': _role.wire,
          'password': _password.text,
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          if (shift != null) 'shift': shift,
        });
      } else {
        await repo.update(widget.existing!.id, {
          'full_name': _name.text.trim(),
          'role': _role.wire,
          'is_active': _active,
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          if (shift != null) 'shift': shift,
          if (_password.text.isNotEmpty) 'password': _password.text,
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      VToast.success(context, _isNew ? 'User created' : 'User updated');
      ref.invalidate(usersProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ===========================================================================
// 2. Thresholds
// ===========================================================================
class _ThresholdsSection extends ConsumerWidget {
  const _ThresholdsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VSectionTitle(
          title: 'Alert thresholds',
          subtitle: 'Machines of coverage at which a part turns amber, then red. '
              'Saving re-evaluates the whole line immediately.',
        ),
        async.when(
          loading: () => const VSkeletonList(rows: 4, height: 92),
          error: (error, _) => VErrorState(
            message: describeError(error),
            compact: true,
            onRetry: () => ref.invalidate(linesProvider),
          ),
          data: (lines) => Column(
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _ThresholdCard(line: line),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThresholdCard extends ConsumerStatefulWidget {
  const _ThresholdCard({required this.line});

  final ProductionLine line;

  @override
  ConsumerState<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends ConsumerState<_ThresholdCard> {
  late final TextEditingController _yellow =
      TextEditingController(text: '${widget.line.yellowThreshold}');
  late final TextEditingController _red =
      TextEditingController(text: '${widget.line.redThreshold}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _yellow.dispose();
    _red.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return VCard(
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: VRibbon.gradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.line.code,
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(child: Text(widget.line.name, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: VSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VInput(
                  controller: _yellow,
                  label: 'Warning at (amber)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.warning_amber_rounded,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: VInput(
                  controller: _red,
                  label: 'Critical at (red)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.error_outline_rounded,
                  errorText: _error,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(width: VSpace.md),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: VButton(
                  label: 'Save',
                  size: VButtonSize.medium,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.xs),
          Text(
            'A part covering ${_yellow.text} more machines turns amber; '
            '${_red.text} or fewer turns red and pushes the Supervisor and Planner.',
            style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final yellow = int.tryParse(_yellow.text.trim()) ?? -1;
    final red = int.tryParse(_red.text.trim()) ?? -1;

    if (yellow < 0 || red < 0) {
      setState(() => _error = 'Both thresholds are required.');
      return;
    }
    // Enforced here, by the API, and by a table CHECK — all three, because a
    // red threshold above the amber one would make the amber band unreachable.
    if (red > yellow) {
      setState(() => _error = 'Critical must be at or below the warning threshold.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(masterRepositoryProvider).updateThresholds(
            widget.line.id,
            yellow: yellow,
            red: red,
          );
      if (!mounted) return;
      VToast.success(
        context,
        '${widget.line.code} thresholds saved',
        detail: 'Coverage for this line has been re-evaluated.',
      );
      ref
        ..invalidate(linesProvider)
        ..invalidate(coverageProvider)
        ..invalidate(alertsProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(badgeCountsProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ===========================================================================
// 3. Racks
// ===========================================================================
class _RacksSection extends ConsumerWidget {
  const _RacksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final async = ref.watch(racksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSectionTitle(
          title: 'Racks',
          subtitle: 'Where parts are kept. This is what answers "where is this part?"',
          trailing: VButton(
            label: 'Add rack',
            icon: Icons.add_rounded,
            size: VButtonSize.small,
            onPressed: () => _openRackSheet(context, ref),
          ),
        ),
        async.when(
          loading: () => const VSkeletonList(rows: 4, height: 56),
          error: (error, _) => VErrorState(
            message: describeError(error),
            compact: true,
            onRetry: () => ref.invalidate(racksProvider),
          ),
          data: (racks) => racks.isEmpty
              ? const VEmptyState(
                  title: 'No racks yet',
                  message: 'Add the rack locations so operators can find parts.',
                  icon: Icons.shelves,
                  compact: true,
                )
              : VCardGrid(
                  minTileWidth: 240,
                  children: [
                    for (final rack in racks)
                      VCard(
                        padding: const EdgeInsets.all(VSpace.md),
                        child: Row(
                          children: [
                            Icon(Icons.shelves, size: 18, color: v.txt3),
                            const SizedBox(width: VSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(rack.code, style: context.text.titleSmall?.copyWith(fontSize: 13.5)),
                                  if (rack.zone != null || rack.description != null)
                                    Text(
                                      [rack.zone, rack.description]
                                          .whereType<String>()
                                          .join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall
                                          ?.copyWith(color: v.txt3, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static void _openRackSheet(BuildContext context, WidgetRef ref) {
    final code = TextEditingController();
    final zone = TextEditingController();
    final description = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: VSpace.xl,
          right: VSpace.xl,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + VSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a rack', style: sheetContext.text.headlineSmall),
            const SizedBox(height: VSpace.lg),
            VInput(controller: code, label: 'Rack code', hint: 'e.g. R-A-01', autofocus: true),
            const SizedBox(height: VSpace.md),
            VInput(controller: zone, label: 'Zone', hint: 'e.g. Zone A'),
            const SizedBox(height: VSpace.md),
            VInput(controller: description, label: 'Description', hint: 'What is kept here'),
            const SizedBox(height: VSpace.xl),
            VButton(
              label: 'Create rack',
              size: VButtonSize.large,
              expand: true,
              onPressed: () async {
                if (code.text.trim().isEmpty) return;
                try {
                  await ref.read(masterRepositoryProvider).createRack(
                        code: code.text.trim(),
                        zone: zone.text.trim().isEmpty ? null : zone.text.trim(),
                        description:
                            description.text.trim().isEmpty ? null : description.text.trim(),
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  VToast.success(context, 'Rack created');
                  ref.invalidate(racksProvider);
                } on ApiException catch (e) {
                  if (sheetContext.mounted) {
                    VToast.error(sheetContext, 'Could not create the rack', detail: e.message);
                  }
                }
              },
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 4. Parts
// ===========================================================================
final _adminPartsSearchProvider = StateProvider<String>((ref) => '');

final _adminPartsProvider = FutureProvider.autoDispose<List<Part>>((ref) async {
  final search = ref.watch(_adminPartsSearchProvider);
  final result = await ref.watch(masterRepositoryProvider).parts(
        search: search.isEmpty ? null : search,
        limit: 100,
      );
  return result.rows;
});

class _PartsSection extends ConsumerWidget {
  const _PartsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final async = ref.watch(_adminPartsProvider);
    final canAdjust = ref.watch(canProvider(Perm.stockAdjust));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VSectionTitle(
          title: 'Parts',
          subtitle: 'The part master. Opening stock is set once, at creation — afterwards a '
              'physical count is the way to correct a number, so the ledger keeps its history.',
        ),
        VSearchField(
          hint: 'Search by part number or description',
          onChanged: (value) => ref.read(_adminPartsSearchProvider.notifier).state = value,
        ),
        const SizedBox(height: VSpace.md),
        async.when(
          loading: () => const VSkeletonList(rows: 5, height: 62),
          error: (error, _) => VErrorState(
            message: describeError(error),
            compact: true,
            onRetry: () => ref.invalidate(_adminPartsProvider),
          ),
          data: (parts) => parts.isEmpty
              ? const VEmptyState(
                  title: 'No parts match',
                  message: 'Import the part master, or adjust the search.',
                  icon: Icons.inventory_2_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final part in parts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: VSpace.xs),
                        child: VCard(
                          padding: const EdgeInsets.all(VSpace.md),
                          child: Row(
                            children: [
                              Expanded(child: PartIdentity(part: part)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    fmtQty(part.availableStock),
                                    style: context.text.titleSmall?.copyWith(
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  Text(
                                    'opening ${fmtQty(part.openingStock)}',
                                    style: context.text.labelSmall
                                        ?.copyWith(color: v.txt3, fontSize: 10),
                                  ),
                                ],
                              ),
                              if (canAdjust) ...[
                                const SizedBox(width: VSpace.sm),
                                VIconButton(
                                  icon: Icons.checklist_rounded,
                                  size: 34,
                                  iconSize: 16,
                                  tooltip: 'Record a physical count',
                                  onPressed: () => _openCountSheet(context, ref, part),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static void _openCountSheet(BuildContext context, WidgetRef ref, Part part) {
    final counted = TextEditingController(text: fmtQty(part.availableStock));
    final note = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: VSpace.xl,
          right: VSpace.xl,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + VSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Physical count', style: sheetContext.text.headlineSmall),
            const SizedBox(height: VSpace.xs),
            Text(
              'The app appends the adjustment that makes its number match the rack. '
              'Nothing is overwritten — the difference itself becomes the record of how far '
              'the book had drifted.',
              style: sheetContext.text.bodySmall
                  ?.copyWith(color: sheetContext.v.txt3, height: 1.5),
            ),
            const SizedBox(height: VSpace.lg),
            PartIdentity(part: part),
            const SizedBox(height: VSpace.md),
            VInput(
              controller: counted,
              label: 'Counted on the rack',
              large: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: VSpace.md),
            VInput(controller: note, label: 'Note', hint: 'Who counted, and when'),
            const SizedBox(height: VSpace.xl),
            VButton(
              label: 'Apply the count',
              size: VButtonSize.large,
              expand: true,
              onPressed: () async {
                final value = double.tryParse(counted.text.trim());
                if (value == null || value < 0) return;
                try {
                  final balance = await ref.read(masterRepositoryProvider).applyStockCount(
                        part.id,
                        countedQty: value,
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  VToast.success(
                    context,
                    'Count applied',
                    detail: '${part.description} is now ${fmtQty(balance)} pieces.',
                  );
                  ref
                    ..invalidate(_adminPartsProvider)
                    ..invalidate(coverageProvider)
                    ..invalidate(alertsProvider)
                    ..invalidate(dashboardProvider);
                } on ApiException catch (e) {
                  if (sheetContext.mounted) {
                    VToast.error(sheetContext, 'Could not apply the count', detail: e.message);
                  }
                }
              },
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 5. Excel import — the two-step wizard
// ===========================================================================
class _ImportSection extends ConsumerStatefulWidget {
  const _ImportSection();

  @override
  ConsumerState<_ImportSection> createState() => _ImportSectionState();
}

class _ImportSectionState extends ConsumerState<_ImportSection> {
  ImportTarget? _target;
  ProductionLine? _line;
  bool _replace = false;

  /// The dry-run result awaiting confirmation. Until this is committed, NOTHING
  /// has been written to the masters — the whole point of the two-step flow.
  ImportBatch? _batch;

  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final targets = ref.watch(importTargetsProvider);
    final lines = ref.watch(linesProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VSectionTitle(
          title: 'Excel import',
          subtitle: 'Upload, review the checking report, then confirm. Nothing is written '
              'until you confirm.',
        ),

        targets.when(
          loading: () => const VSkeletonList(rows: 3, height: 72),
          error: (error, _) => VErrorState(
            message: describeError(error),
            compact: true,
            onRetry: () => ref.invalidate(importTargetsProvider),
          ),
          data: (available) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VDropdown<ImportTarget>(
                label: 'What are you importing?',
                hint: 'Choose a target',
                items: available,
                value: _target,
                itemLabel: (t) => t.title,
                large: true,
                onChanged: (next) => setState(() {
                  _target = next;
                  _batch = null;
                  _error = null;
                }),
              ),

              if (_target != null) ...[
                const SizedBox(height: VSpace.md),
                Container(
                  padding: const EdgeInsets.all(VSpace.md),
                  decoration: BoxDecoration(
                    color: v.infoTint,
                    borderRadius: VRadius.allSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPECTED COLUMNS',
                        style: context.text.labelSmall?.copyWith(color: v.info, fontSize: 9.5),
                      ),
                      const SizedBox(height: VSpace.xs),
                      Text(
                        _target!.columns.join('  ·  '),
                        style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.5),
                      ),
                      if (_target!.note != null) ...[
                        const SizedBox(height: VSpace.sm),
                        Text(
                          _target!.note!,
                          style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: VSpace.sm),
                      Text(
                        'Header matching is forgiving — merged title rows, extra spaces and the '
                        'usual spelling variations are all handled.',
                        style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),

                if (_target!.needsLine) ...[
                  const SizedBox(height: VSpace.md),
                  VDropdown<ProductionLine>(
                    label: 'Production line',
                    hint: 'Which line does this file belong to?',
                    items: lines,
                    value: _line,
                    itemLabel: (l) => '${l.code} · ${l.name}',
                    onChanged: (next) => setState(() => _line = next),
                  ),
                ],

                const SizedBox(height: VSpace.lg),
                VButton(
                  label: _batch == null ? 'Choose an Excel file' : 'Choose a different file',
                  icon: Icons.upload_file_rounded,
                  size: VButtonSize.large,
                  expand: true,
                  loading: _busy && _batch == null,
                  onPressed: _busy ? null : _pickAndUpload,
                ),
              ],
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: VSpace.md),
          Container(
            padding: const EdgeInsets.all(VSpace.md),
            decoration: BoxDecoration(
              color: v.badTint,
              borderRadius: VRadius.allSm,
              border: Border.all(color: v.bad.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: v.bad),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Text(
                    _error!,
                    style: context.text.bodySmall
                        ?.copyWith(color: v.bad, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_batch != null) ...[
          const SizedBox(height: VSpace.lg),
          _CheckingReport(
            batch: _batch!,
            replace: _replace,
            busy: _busy,
            showReplace: _target?.target == 'bom',
            onReplaceChanged: (next) => setState(() => _replace = next),
            onCommit: _commit,
            onCancel: _cancelBatch,
          ),
        ],

        const SizedBox(height: VSpace.xl),
        const _ImportHistory(),
      ],
    );
  }

  Future<void> _pickAndUpload() async {
    if (_target == null) return;
    if (_target!.needsLine && _line == null) {
      setState(() => _error = 'Choose the production line this file belongs to.');
      return;
    }

    // file_picker 11 moved pickFiles to a static on FilePicker itself
    // (it was FilePicker.platform.pickFiles in v8 and earlier).
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose the ${_target!.title} sheet',
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      // Without this the picker returns only a path, which the web build cannot
      // read at all and the desktop builds would have to re-open themselves.
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read that file. Try choosing it again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _batch = null;
    });

    try {
      final batch = await ref.read(importRepositoryProvider).dryRun(
            target: _target!.target,
            bytes: bytes,
            filename: file.name,
            lineId: _target!.needsLine ? _line!.id : null,
          );
      if (mounted) setState(() => _batch = batch);
    } on ApiException catch (e) {
      // The server's message here is genuinely useful — it names the missing
      // column or the sheet it could not find.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final batch = _batch;
    if (batch == null) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(importRepositoryProvider).commit(batch.id, replace: _replace);

      if (!mounted) return;
      setState(() => _batch = null);
      VToast.success(
        context,
        'Import committed',
        detail: result.result.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
      );
      ref
        ..invalidate(importHistoryProvider)
        ..invalidate(_adminPartsProvider)
        ..invalidate(racksProvider)
        ..invalidate(linesProvider)
        ..invalidate(coverageProvider)
        ..invalidate(alertsProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(machinePlanProvider)
        ..invalidate(patternsProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelBatch() async {
    final batch = _batch;
    if (batch == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(importRepositoryProvider).cancel(batch.id);
      if (!mounted) return;
      setState(() => _batch = null);
      VToast.info(context, 'Import discarded', detail: 'Nothing was written.');
      ref.invalidate(importHistoryProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The per-row checking report, and the confirm/discard decision.
class _CheckingReport extends StatelessWidget {
  const _CheckingReport({
    required this.batch,
    required this.replace,
    required this.busy,
    required this.showReplace,
    required this.onReplaceChanged,
    required this.onCommit,
    required this.onCancel,
  });

  final ImportBatch batch;
  final bool replace;
  final bool busy;
  final bool showReplace;
  final ValueChanged<bool> onReplaceChanged;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final rows = batch.reportRows;

    return VCard(
      accentEdge: batch.hasErrors ? v.warn : v.ok,
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Checking report', style: context.text.titleMedium),
                    Text(
                      batch.sourceFile,
                      style: context.text.bodySmall?.copyWith(color: v.txt3),
                    ),
                  ],
                ),
              ),
              const VPill(
                label: 'Nothing written yet',
                status: VStatus.info,
                icon: Icons.pause_circle_outline_rounded,
              ),
            ],
          ),

          const SizedBox(height: VSpace.md),
          Row(
            children: [
              Expanded(
                child: _ReportStat(label: 'Rows read', value: '${batch.rowCount}'),
              ),
              Expanded(
                child: _ReportStat(
                  label: 'Will apply',
                  value: '${batch.okCount}',
                  color: v.ok,
                ),
              ),
              Expanded(
                child: _ReportStat(
                  label: 'Problems',
                  value: '${batch.errorCount}',
                  color: batch.errorCount > 0 ? v.bad : v.txt3,
                ),
              ),
            ],
          ),

          if (rows.isNotEmpty) ...[
            const SizedBox(height: VSpace.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final row in rows.take(200)) _ReportRow(row: row),
                  ],
                ),
              ),
            ),
            if (rows.length > 200)
              Padding(
                padding: const EdgeInsets.only(top: VSpace.xs),
                child: Text(
                  'Showing the first 200 of ${rows.length} checked rows.',
                  style: context.text.labelSmall?.copyWith(color: v.txt3),
                ),
              ),
          ],

          if (showReplace) ...[
            const SizedBox(height: VSpace.md),
            SwitchListTile(
              value: replace,
              onChanged: onReplaceChanged,
              title: const Text('Replace the existing BOM first'),
              subtitle: Text(
                'Wipes this line/variant\'s current QPV rows before applying. The go-live '
                'path when a whole sheet is being re-imported.',
                style: context.text.bodySmall?.copyWith(color: v.txt3),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: VSpace.md),
          Row(
            children: [
              Expanded(
                child: VButton(
                  label: 'Confirm and apply ${batch.okCount} row(s)',
                  icon: Icons.check_rounded,
                  size: VButtonSize.large,
                  loading: busy,
                  onPressed: busy || batch.okCount == 0 ? null : onCommit,
                ),
              ),
              const SizedBox(width: VSpace.md),
              VButton.ghost(
                label: 'Discard',
                size: VButtonSize.large,
                onPressed: busy ? null : onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
        ),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final status = row['status']?.toString() ?? 'ok';
    final messages = (row['messages'] as List? ?? const []).map((m) => m.toString()).toList();

    final (Color color, Color tint, IconData icon) = switch (status) {
      'error' => (v.bad, v.badTint, Icons.error_rounded),
      'skip' => (v.warn, v.warnTint, Icons.skip_next_rounded),
      'update' => (v.info, v.infoTint, Icons.edit_rounded),
      'adjust' => (v.info, v.infoTint, Icons.swap_vert_rounded),
      _ => (v.ok, v.okTint, Icons.check_rounded),
    };

    // The label carries whatever the parser identified the row by — a part
    // number, a pattern code, a serial — so a problem row is findable in Excel.
    final label = [
      row['part'],
      row['pattern'],
      row['serial'],
      row['description'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: VSpace.xs),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(7)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: VSpace.xs),
          SizedBox(
            width: 46,
            child: Text(
              'row ${row['row'] ?? '?'}',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(color: v.txt, fontSize: 11.5),
                  ),
                if (messages.isNotEmpty)
                  Text(
                    messages.join(' · '),
                    style: context.text.bodySmall?.copyWith(color: color, fontSize: 11),
                  ),
                if (row['delta'] != null)
                  Text(
                    'book ${row['book_stock']} → counted ${row['counted_qty']} '
                    '(${(row['delta'] as num) > 0 ? '+' : ''}${row['delta']})',
                    style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportHistory extends ConsumerWidget {
  const _ImportHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final async = ref.watch(importHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VSectionTitle(title: 'Past imports'),
        async.when(
          loading: () => const VSkeletonList(rows: 3, height: 54),
          error: (_, _) => const SizedBox.shrink(),
          data: (batches) => batches.isEmpty
              ? const VEmptyState(
                  title: 'No imports yet',
                  icon: Icons.history_rounded,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final batch in batches.take(10))
                      Padding(
                        padding: const EdgeInsets.only(bottom: VSpace.xs),
                        child: VCard(
                          padding: const EdgeInsets.all(VSpace.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      batch.sourceFile,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleSmall?.copyWith(fontSize: 13),
                                    ),
                                    Text(
                                      '${batch.target} · ${batch.okCount} applied'
                                      '${batch.errorCount > 0 ? ', ${batch.errorCount} problems' : ''}'
                                      '${batch.createdAt != null ? ' · ${fmtRelative(batch.createdAt!)}' : ''}',
                                      style: context.text.bodySmall
                                          ?.copyWith(color: v.txt3, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              VPill(
                                label: batch.isCommitted
                                    ? 'Applied'
                                    : (batch.status == 'cancelled' ? 'Discarded' : 'Not applied'),
                                status: batch.isCommitted
                                    ? VStatus.ready
                                    : (batch.status == 'cancelled'
                                        ? VStatus.neutral
                                        : VStatus.warning),
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 6. Maintenance
// ===========================================================================
class _MaintenanceSection extends ConsumerStatefulWidget {
  const _MaintenanceSection();

  @override
  ConsumerState<_MaintenanceSection> createState() => _MaintenanceSectionState();
}

class _MaintenanceSectionState extends ConsumerState<_MaintenanceSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VSectionTitle(title: 'Maintenance'),
        VCard(
          padding: const EdgeInsets.all(VSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 19, color: v.accent),
                  const SizedBox(width: VSpace.sm),
                  Text('Recompute all coverage', style: context.text.titleSmall),
                ],
              ),
              const SizedBox(height: VSpace.xs),
              Text(
                'Walks every line\'s plan again and rebuilds the alert list. Coverage is '
                'normally recalculated by whatever changed the stock, so this is only needed '
                'after a bulk import or a direct database edit. Push notifications are '
                'suppressed — a go-live import would otherwise fire hundreds at once.',
                style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.55),
              ),
              const SizedBox(height: VSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: VButton.ghost(
                  label: 'Recompute now',
                  icon: Icons.calculate_rounded,
                  loading: _busy,
                  onPressed: _busy ? null : _reevaluate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reevaluate() async {
    setState(() => _busy = true);
    try {
      await ref.read(alertRepositoryProvider).reevaluate(push: false);
      if (!mounted) return;
      VToast.success(context, 'Coverage recomputed', detail: 'Alerts have been rebuilt.');
      ref
        ..invalidate(alertsProvider)
        ..invalidate(coverageProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(badgeCountsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      VToast.error(context, 'Could not recompute', detail: e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

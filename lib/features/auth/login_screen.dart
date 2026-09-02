import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import 'role_screens.dart';

/// Login: employee code + password — the SRS's "code + password".
///
/// Split layout on desktop (`1.05fr .95fr`): an art panel with the wordmark, a
/// ribbon-accented pitch line and three stat figures, then the form. On a phone
/// the art panel collapses to a compact header, because a shop-floor phone user
/// wants the two fields immediately, not a brand experience.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  String? _codeError;
  String? _passwordError;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Errors clear as the operator corrects them — "Enter your password" has
  /// nothing left to say once there is a password in the field.
  ///
  /// Hooked to `onChanged` rather than a controller listener on purpose: the
  /// failed-login path below clears the password field programmatically, and a
  /// listener would read that as a correction and wipe the server's reason for
  /// refusing the attempt in the same frame it appeared. `onChanged` does not
  /// fire for a programmatic `clear()`, which is exactly the wanted semantics.
  void _onCodeChanged() {
    if (_codeError != null) setState(() => _codeError = null);
    _clearServerError();
  }

  void _onPasswordChanged() {
    if (_passwordError != null) setState(() => _passwordError = null);
    _clearServerError();
  }

  /// The banner explains the last attempt. Once the operator changes what they
  /// are about to send, it is describing something they no longer typed.
  ///
  /// Guarded: unguarded this publishes a new AuthState on every keystroke, and
  /// the screen watches that state.
  void _clearServerError() {
    if (ref.read(authControllerProvider).error != null) {
      ref.read(authControllerProvider.notifier).clearError();
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    // A fresh attempt supersedes the last one's banner, even when it never
    // reaches the server because a field is empty and we return below.
    _clearServerError();

    setState(() {
      _codeError = code.isEmpty ? 'Enter your employee code' : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_codeError != null || _passwordError != null) return;

    FocusScope.of(context).unfocus();
    final ok = await ref.read(authControllerProvider.notifier).login(
          empCode: code,
          password: password,
        );

    if (!mounted) return;
    if (ok) {
      // The router's redirect takes over from here; no explicit navigation.
      VToast.success(context, 'Signed in', detail: 'Loading your screens…');
    } else {
      // Clear only the password: an operator who mistyped their password should
      // not have to retype their code as well.
      _passwordController.clear();
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 940;

    return Scaffold(
      body: AmbientBackground(
        showWatermark: !wide, // the art panel carries the mark on wide layouts
        child: SafeArea(
          child: wide
              ? Row(
                  children: [
                    const Expanded(flex: 105, child: _ArtPanel()),
                    Expanded(
                      flex: 95,
                      child: _FormPanel(
                        codeController: _codeController,
                        passwordController: _passwordController,
                        codeFocus: _codeFocus,
                        passwordFocus: _passwordFocus,
                        obscure: _obscure,
                        onToggleObscure: () => setState(() => _obscure = !_obscure),
                        codeError: _codeError,
                        passwordError: _passwordError,
                        onCodeChanged: _onCodeChanged,
                        onPasswordChanged: _onPasswordChanged,
                        serverError: auth.error,
                        busy: auth.busy,
                        onSubmit: _submit,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const _CompactHeader(),
                      _FormPanel(
                        codeController: _codeController,
                        passwordController: _passwordController,
                        codeFocus: _codeFocus,
                        passwordFocus: _passwordFocus,
                        obscure: _obscure,
                        onToggleObscure: () => setState(() => _obscure = !_obscure),
                        codeError: _codeError,
                        passwordError: _passwordError,
                        onCodeChanged: _onCodeChanged,
                        onPasswordChanged: _onPasswordChanged,
                        serverError: auth.error,
                        busy: auth.busy,
                        onSubmit: _submit,
                        boxed: false,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The left art panel: brand glows, a huge faint rotated S, the wordmark, a pitch
/// headline with ONE ribbon-gradient word, and three stat figures.
class _ArtPanel extends StatelessWidget {
  const _ArtPanel();

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.7),
              radius: 1.3,
              colors: [
                VRibbon.purple.withValues(alpha: v.isDark ? 0.30 : 0.14),
                VRibbon.pink.withValues(alpha: v.isDark ? 0.12 : 0.06),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // The huge rotated S at 16% — a fixed placement from the design system.
        Positioned(
          right: -140,
          bottom: -110,
          child: Transform.rotate(
            angle: -0.22,
            child: Opacity(
              opacity: v.isDark ? 0.16 : 0.09,
              child: Image.asset(VBrand.mark, width: 520, height: 520),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(VSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(VBrand.wordmark, width: 190, fit: BoxFit.contain),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PitchHeadline(),
                    const SizedBox(height: VSpace.lg),
                    Text(
                      'The same tracker your team reads today — but automatic, always up to '
                      'date, and in everyone’s pocket. Every part is watched continuously, '
                      'and the alert arrives before the line ever stops.',
                      style: context.text.bodyLarge?.copyWith(color: v.txt2, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.section),
              const Row(
                children: [
                  _StatFigure(value: '10', label: 'machines of\nadvance warning'),
                  SizedBox(width: VSpace.xxl),
                  _StatFigure(value: '4', label: 'taps to record\na receipt'),
                  SizedBox(width: VSpace.xxl),
                  _StatFigure(value: '0', label: 'formulas left\nto break'),
                ],
              ),
              const Spacer(),
              Text(
                'Vistar Logitek Pvt. Ltd. · VLPL-CNH-SRS-001',
                style: context.text.labelSmall?.copyWith(color: v.txt3, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The headline, with exactly one word masked by the ribbon.
class _PitchHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final style = VType.display(size: 40, weight: FontWeight.w800, color: v.txt, height: 1.12);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Know which machine ', style: style),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => VRibbon.gradient.createShader(bounds),
          child: Text('stops', style: style.copyWith(color: Colors.white)),
        ),
        Text(' first.', style: style),
      ],
    );
  }
}

class _StatFigure extends StatelessWidget {
  const _StatFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => VRibbon.gradient.createShader(bounds),
          child: Text(
            value,
            style: VType.display(size: 40, weight: FontWeight.w800, color: Colors.white, height: 1),
          ),
        ),
        const SizedBox(height: VSpace.xs),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.35, fontSize: 11.5),
        ),
      ],
    );
  }
}

/// The phone header: mark + wordmark, nothing else. The fields are what matter.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader();

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, VSpace.xxl, VSpace.xl, VSpace.lg),
      child: Column(
        children: [
          Image.asset(VBrand.markSmall, width: 54, height: 54),
          const SizedBox(height: VSpace.md),
          Image.asset(VBrand.wordmark, width: 158, fit: BoxFit.contain),
          const SizedBox(height: VSpace.sm),
          Text(
            'PAINT SHOP OPERATIONS',
            style: context.text.labelSmall?.copyWith(
              color: v.txt3,
              letterSpacing: 2.4,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.codeController,
    required this.passwordController,
    required this.codeFocus,
    required this.passwordFocus,
    required this.obscure,
    required this.onToggleObscure,
    required this.codeError,
    required this.passwordError,
    required this.onCodeChanged,
    required this.onPasswordChanged,
    required this.serverError,
    required this.busy,
    required this.onSubmit,
    this.boxed = true,
  });

  final TextEditingController codeController;
  final TextEditingController passwordController;
  final FocusNode codeFocus;
  final FocusNode passwordFocus;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? codeError;
  final String? passwordError;
  final VoidCallback onCodeChanged;
  final VoidCallback onPasswordChanged;
  final String? serverError;
  final bool busy;
  final VoidCallback onSubmit;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (boxed) ...[
            Image.asset(VBrand.markSmall, width: 40, height: 40),
            const SizedBox(height: VSpace.lg),
          ],
          Text(
            'Sign in',
            style: VType.display(size: 30, weight: FontWeight.w800, color: v.txt),
          ),
          const SizedBox(height: VSpace.xs),
          Text(
            'Use the employee code and password issued by your plant admin.',
            style: context.text.bodyMedium?.copyWith(color: v.txt3),
          ),
          const SizedBox(height: VSpace.xl),

          VInput(
            controller: codeController,
            focusNode: codeFocus,
            label: 'Employee code',
            hint: 'e.g. NES01',
            prefixIcon: Icons.badge_rounded,
            errorText: codeError,
            onChanged: (_) => onCodeChanged(),
            large: true,
            autofocus: true,
            // Codes are uppercase on the plant's badges; the server matches
            // case-insensitively but showing them uppercase avoids confusion.
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              LengthLimitingTextInputFormatter(40),
            ],
            onSubmitted: (_) => passwordFocus.requestFocus(),
          ),
          const SizedBox(height: VSpace.lg),

          VInput(
            controller: passwordController,
            focusNode: passwordFocus,
            label: 'Password',
            hint: '••••••••',
            prefixIcon: Icons.lock_rounded,
            obscureText: obscure,
            errorText: passwordError,
            onChanged: (_) => onPasswordChanged(),
            large: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => onSubmit(),
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 19,
                color: v.txt3,
              ),
              tooltip: obscure ? 'Show password' : 'Hide password',
              onPressed: onToggleObscure,
            ),
          ),

          if (serverError != null) ...[
            const SizedBox(height: VSpace.lg),
            Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: v.badTint,
                borderRadius: VRadius.allSm,
                border: Border.all(color: v.bad.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 17, color: v.bad),
                  const SizedBox(width: VSpace.sm),
                  Expanded(
                    child: Text(
                      serverError!,
                      style: context.text.bodySmall?.copyWith(
                        color: v.bad,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: VSpace.xl),
          VButton(
            label: busy ? 'Signing in…' : 'Sign in',
            icon: busy ? null : Icons.arrow_forward_rounded,
            loading: busy,
            size: VButtonSize.large,
            expand: true,
            onPressed: busy ? null : onSubmit,
          ),

          const SizedBox(height: VSpace.xl),
          const _RoleLegend(),
        ],
      ),
    );

    if (!boxed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.section),
        child: Center(child: form),
      );
    }

    return ColoredBox(
      color: v.bg2,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VSpace.section),
          child: Center(child: form),
        ),
      ),
    );
  }
}

/// The role legend: six chips, and — once one is tapped — the screens that role
/// opens.
///
/// Still not a role picker. Roles come from the server with the employee code,
/// and nothing chosen here changes that; tapping *previews* what a job sees, and
/// the panel says so outright. Untouched, the legend looks exactly as before: a
/// row of chips and no panel, so the two fields stay the loudest thing on the
/// screen for an operator who just wants to sign in.
class _RoleLegend extends StatefulWidget {
  const _RoleLegend();

  @override
  State<_RoleLegend> createState() => _RoleLegendState();
}

class _RoleLegendState extends State<_RoleLegend> {
  UserRole? _selected;

  /// Short chip labels, because "Nesting Operator" and "Viewer (Mgmt / CNH)" do
  /// not fit six-across. The panel shows each role's full name.
  static const List<(UserRole, String, IconData)> _chips = [
    (UserRole.nestingOperator, 'Nesting', Icons.move_to_inbox_rounded),
    (UserRole.loadingOperator, 'Loading', Icons.dynamic_feed_rounded),
    (UserRole.supervisor, 'Supervisor', Icons.shield_rounded),
    (UserRole.planner, 'Planner', Icons.timeline_rounded),
    (UserRole.admin, 'Admin', Icons.settings_rounded),
    (UserRole.viewer, 'Viewer', Icons.visibility_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ROLE OPENS YOUR SCREENS',
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5, letterSpacing: 1.4),
        ),
        const SizedBox(height: VSpace.sm),
        Wrap(
          spacing: VSpace.xs,
          runSpacing: VSpace.xs,
          children: [
            for (final (role, label, icon) in _chips)
              Semantics(
                button: true,
                selected: role == selected,
                label: '$label role — show the screens it opens',
                child: VChip(
                  label: label,
                  icon: icon,
                  selected: role == selected,
                  // Tapping the open one closes it, so the legend can always be
                  // put back the way it was found.
                  onTap: () => setState(() => _selected = role == selected ? null : role),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: VMotion.base,
          curve: VMotion.enter,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: VMotion.fast,
            switchInCurve: VMotion.enter,
            switchOutCurve: VMotion.exit,
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(selected),
                    padding: const EdgeInsets.only(top: VSpace.md),
                    child: _RolePreview(role: selected),
                  ),
          ),
        ),
      ],
    );
  }
}

/// What one role opens, read out of the same nav model the sidebar uses.
class _RolePreview extends StatelessWidget {
  const _RolePreview({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final screens = RoleScreens.screensFor(role);
    final landing = RoleScreens.landingFor(role);
    final writes = RoleScreens.writesFor(role);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role.label,
                  style: context.text.labelMedium?.copyWith(
                    color: v.txt,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Text(
                screens.length == 1 ? '1 screen' : '${screens.length} screens',
                style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.md,
            runSpacing: VSpace.xs,
            children: [
              for (final item in screens)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 12, color: v.txt3),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 11.5),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: VSpace.md),
          Container(height: 1, color: v.line),
          const SizedBox(height: VSpace.sm),
          if (landing != null)
            _PreviewNote(
              icon: Icons.login_rounded,
              text: 'Signs in straight to ${landing.label}',
            ),
          _PreviewNote(
            icon: writes == null ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
            text: writes ?? 'Reads everything, changes nothing',
          ),
          const SizedBox(height: VSpace.xs),
          Text(
            'Your own role comes from your employee code — this is only a preview.',
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PreviewNote extends StatelessWidget {
  const _PreviewNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 12, color: v.txt3),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

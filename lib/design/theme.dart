import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// ---------------------------------------------------------------------------
/// ThemeData for both modes, built from the same [VColors] tokens.
///
/// Everything Material draws for us — dialogs, snackbars, dropdown menus, the
/// text-selection handles — is styled here, so a screen never has to fight a
/// stock widget's default blue. The app's own components read tokens directly
/// via `context.v`.
/// ---------------------------------------------------------------------------
abstract final class VTheme {
  static ThemeData dark() => _build(VColors.dark);
  static ThemeData light() => _build(VColors.light);

  static ThemeData _build(VColors c) {
    final text = VType.themeFor(c);
    final isDark = c.isDark;

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      primaryContainer: c.accentTint,
      onPrimaryContainer: c.accent,
      secondary: VRibbon.violet,
      onSecondary: Colors.white,
      secondaryContainer: c.surface3,
      onSecondaryContainer: c.txt,
      tertiary: VRibbon.orange,
      onTertiary: Colors.white,
      error: c.bad,
      onError: Colors.white,
      errorContainer: c.badTint,
      onErrorContainer: c.bad,
      surface: c.surface,
      onSurface: c.txt,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg2,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface3,
      onSurfaceVariant: c.txt2,
      outline: c.line2,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: isDark ? c.txt : c.bg,
      onInverseSurface: isDark ? c.bg : c.txt,
      inversePrimary: c.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: text,
      extensions: [c],

      // The ambient background paints the page; a Scaffold that also paints a
      // colour would hide it.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: VType.display(size: 18, weight: FontWeight.w700, color: c.txt),
        iconTheme: IconThemeData(color: c.txt2, size: 20),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: c.txt2, size: 20),

      // ---- inputs: the `.inp` recipe, with the pink focus ring ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hoverColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: VType.body(size: 14, color: c.txt3),
        labelStyle: VType.body(size: 13, weight: FontWeight.w600, color: c.txt2),
        floatingLabelStyle: VType.body(size: 12.5, weight: FontWeight.w700, color: c.accent),
        errorStyle: VType.body(size: 12, weight: FontWeight.w600, color: c.bad),
        prefixIconColor: c.txt3,
        suffixIconColor: c.txt3,
        border: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.line),
        ),
        // The focus ring is the design system's signature: a pink border plus a
        // wide, very soft pink halo. Flutter cannot draw an outer box-shadow on
        // a border, so components that need the full effect wrap the field (see
        // VInput); this keeps the border half correct everywhere else.
        focusedBorder: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.accent.withValues(alpha: 0.6), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.bad.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.bad, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: VRadius.allSm,
          borderSide: BorderSide(color: c.line.withValues(alpha: 0.5)),
        ),
      ),

      // ---- buttons ----
      // The gradient primary lives in VButton (a gradient is not expressible as
      // a ButtonStyle background). These cover the stock buttons so a dialog
      // action still looks like it belongs.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: VRadius.allSm),
          textStyle: VType.body(size: 14, weight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.txt,
          backgroundColor: c.surface2,
          side: BorderSide(color: c.line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: VRadius.allSm),
          textStyle: VType.body(size: 14, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: VType.body(size: 14, weight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: VRadius.allSm),
        ),
      ),

      // ---- surfaces ----
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VRadius.allMd,
          side: BorderSide(color: c.line),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: VRadius.allLg,
          side: BorderSide(color: c.line2),
        ),
        titleTextStyle: VType.display(size: 19, weight: FontWeight.w700, color: c.txt),
        contentTextStyle: VType.body(size: 14, color: c.txt2, height: 1.5),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.lg)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: VRadius.allMd,
          side: BorderSide(color: c.line2),
        ),
        textStyle: VType.body(size: 14, color: c.txt),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: VRadius.allMd,
              side: BorderSide(color: c.line2),
            ),
          ),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: VType.body(size: 14, color: c.txt),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: VRadius.allMd,
              side: BorderSide(color: c.line2),
            ),
          ),
        ),
      ),

      // ---- feedback ----
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface3,
        contentTextStyle: VType.body(size: 13.5, weight: FontWeight.w600, color: c.txt),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: VRadius.allSm,
          side: BorderSide(color: c.line2),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surface3 : c.txt,
          borderRadius: VRadius.allSm,
          border: Border.all(color: c.line2),
        ),
        textStyle: VType.body(size: 12, weight: FontWeight.w600, color: isDark ? c.txt : c.bg),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        waitDuration: const Duration(milliseconds: 400),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surface3,
        circularTrackColor: c.surface3,
        linearMinHeight: 4,
      ),

      // ---- selection controls ----
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: c.line2, width: 1.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.txt3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surface3,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.line2,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.txt3,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        selectedColor: c.accentTint,
        side: BorderSide(color: c.line),
        labelStyle: VType.body(size: 12.5, weight: FontWeight.w700, color: c.txt2),
        secondaryLabelStyle: VType.body(size: 12.5, weight: FontWeight.w700, color: c.accent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: VRadius.allPill),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.txt,
        unselectedLabelColor: c.txt3,
        labelStyle: VType.body(size: 13.5, weight: FontWeight.w700),
        unselectedLabelStyle: VType.body(size: 13.5, weight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.accent, width: 2.5),
          insets: const EdgeInsets.only(bottom: -1),
        ),
        dividerColor: c.line,
      ),

      // ---- data grids (the matrix and the registers) ----
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(c.surface2),
        headingTextStyle: VType.overline(color: c.txt3),
        dataTextStyle: VType.body(size: 13, color: c.txt2),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 22,
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
      ),

      // A translucent violet thumb that brightens to pink on hover, per the
      // design system's custom scrollbar.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) return c.accent;
          if (states.contains(WidgetState.hovered)) {
            return c.accent.withValues(alpha: 0.7);
          }
          return VRibbon.violet.withValues(alpha: isDark ? 0.35 : 0.28);
        }),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        interactive: true,
      ),

      // ::selection — translucent pink.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.28),
        selectionHandleColor: c.accent,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.txt3,
        textColor: c.txt,
        titleTextStyle: VType.body(size: 14.5, weight: FontWeight.w600, color: c.txt),
        subtitleTextStyle: VType.body(size: 12.5, color: c.txt3),
        shape: const RoundedRectangleBorder(borderRadius: VRadius.allSm),
      ),

      splashFactory: InkSparkle.splashFactory,
      highlightColor: c.accent.withValues(alpha: 0.06),
      splashColor: c.accent.withValues(alpha: 0.10),
      hoverColor: c.accent.withValues(alpha: 0.05),
      focusColor: c.accent.withValues(alpha: 0.12),
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Shorthand for the palette. `context.v.bad` reads better at a call site than
/// `Theme.of(context).extension<VColors>()!.bad`, and this is fetched on almost
/// every build in the app.
extension VThemeContext on BuildContext {
  VColors get v => Theme.of(this).extension<VColors>() ?? VColors.dark;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDarkMode => v.isDark;
}

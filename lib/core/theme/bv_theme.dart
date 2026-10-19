// The app theme. Built only from bv_tokens.dart: no raw colours, sizes or
// font values here. Light mode only in V1.

import 'package:flutter/material.dart';

import '../design/bv_specs.dart';
import '../design/bv_icons.dart';
import '../design/bv_tokens.dart';

abstract final class BvTheme {
  /// The theme for the app language. Arabic and Latin use different type
  /// sets, so the theme is rebuilt when the language changes.
  static ThemeData forLocale(Locale locale) =>
      light(locale.languageCode == 'ar' ? BvType.arabic : BvType.latin);

  static ThemeData light(BvTypeSet type) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BvColors.actionPrimary,
      onPrimary: BvColors.actionPrimaryForeground,
      primaryContainer: BvColors.surfaceBrandSoft,
      onPrimaryContainer: BvColors.textAction,
      secondary: BvColors.brandInk,
      onSecondary: BvColors.textInverse,
      error: BvColors.feedbackError,
      onError: BvColors.textInverse,
      surface: BvColors.surfaceElevated,
      onSurface: BvColors.textPrimary,
      onSurfaceVariant: BvColors.textSecondary,
      surfaceContainerLowest: BvColors.surfaceElevated,
      surfaceContainerLow: BvColors.surfaceApp,
      surfaceContainer: BvColors.surfaceSubtle,
      surfaceContainerHigh: BvColors.surfaceSubtle,
      surfaceContainerHighest: BvColors.surfaceSubtle,
      outline: BvColors.borderInput,
      outlineVariant: BvColors.borderDefault,
      scrim: BvColors.overlayScrim,
      shadow: BvColors.brandInk,
      surfaceTint: BvColors.surfaceElevated,
    );

    final textTheme = TextTheme(
      // Two sizes on working screens (review 53 Part C): Material's large
      // slots get the main bold size; the entry screens use BvType directly.
      displaySmall: type.headingMd,
      headlineLarge: type.headingMd,
      headlineMedium: type.headingMd,
      headlineSmall: type.headingMd,
      titleLarge: type.titleLg,
      titleMedium: type.titleMd,
      titleSmall: type.labelLg,
      bodyLarge: type.bodyLg,
      bodyMedium: type.bodyMd,
      bodySmall: type.bodySm,
      labelLarge: type.button,
      labelMedium: type.labelMd,
      labelSmall: type.labelSm,
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BvRadius.controlAll,
    );
    const buttonSize = Size(BvSize.touchMin, BvSize.controlLg);
    const buttonPadding = EdgeInsetsDirectional.symmetric(
      horizontal: BvSpace.s20,
    );

    OutlineInputBorder inputBorder(Color color, [double? width]) =>
        OutlineInputBorder(
          borderRadius: BvRadius.controlAll,
          borderSide: BorderSide(
            color: color,
            width: width ?? BvSpace.borderWidth,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: type.bodyMd.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: BvColors.surfaceApp,
      canvasColor: BvColors.surfaceApp,
      dividerColor: BvColors.borderSubtle,
      disabledColor: BvColors.actionDisabled,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: const IconThemeData(
        color: BvColors.iconPrimary,
        size: BvSize.iconLg,
      ),
      // Back in app bars is Phosphor's arrow, never a Material icon; it
      // mirrors in right to left.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(BvIcons.arrowBack),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BvColors.surfaceApp,
        foregroundColor: BvColors.textPrimary,
        surfaceTintColor: BvColors.surfaceApp,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.titleLg,
        iconTheme: const IconThemeData(
          color: BvColors.iconPrimary,
          size: BvSize.iconLg,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BvColors.borderSubtle,
        thickness: BvSpace.borderWidth,
        space: BvSpace.borderWidth,
      ),
      cardTheme: const CardThemeData(
        color: BvColors.surfaceElevated,
        surfaceTintColor: BvColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BvRadius.cardAll,
          side: BorderSide(
            color: BvColors.borderDefault,
            width: BvSpace.borderWidth,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: const WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(type.button),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BvColors.actionDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return BvColors.actionPrimaryPressed;
            }
            return BvColors.actionPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BvColors.actionDisabledForeground
                : BvColors.actionPrimaryForeground,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: const WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(type.button),
          backgroundColor: const WidgetStatePropertyAll(
            BvColors.actionSecondary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BvColors.actionDisabledForeground
                : BvColors.textPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? BvColors.actionDisabled
                  : BvColors.borderDefault,
              width: BvSpace.borderWidth,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(BvSize.touchMin, BvSize.touchMin),
          ),
          shape: const WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(type.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BvColors.actionDisabledForeground
                : BvColors.textAction,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BvColors.surfaceElevated,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.s16,
          vertical: BvSpace.s12,
        ),
        labelStyle: type.labelMd.copyWith(color: BvColors.textSecondary),
        hintStyle: type.bodyMd.copyWith(color: BvColors.textSecondary),
        helperStyle: type.metadata.copyWith(color: BvColors.textSecondary),
        errorStyle: type.metadata.copyWith(color: BvColors.textDestructive),
        border: inputBorder(BvColors.borderInput),
        enabledBorder: inputBorder(BvColors.borderInput),
        focusedBorder: inputBorder(
          BvColors.borderFocus,
          BvSpace.borderWidth * 2,
        ),
        errorBorder: inputBorder(BvColors.borderDestructive),
        focusedErrorBorder: inputBorder(
          BvColors.borderDestructive,
          BvSpace.borderWidth * 2,
        ),
        disabledBorder: inputBorder(BvColors.actionDisabled),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BvColors.surfaceElevated,
        selectedColor: BvColors.surfaceBrandSoft,
        disabledColor: BvColors.actionDisabled,
        labelStyle: type.labelMd,
        side: const BorderSide(
          color: BvColors.borderDefault,
          width: BvSpace.borderWidth,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BvRadius.roundAll),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.s12,
          vertical: BvSpace.s6,
        ),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BvColors.surfaceElevated,
        surfaceTintColor: BvColors.surfaceElevated,
        modalBackgroundColor: BvColors.surfaceElevated,
        modalBarrierColor: BvColors.overlayScrim,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BvRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: BvColors.borderDefault,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BvColors.surfaceElevated,
        surfaceTintColor: BvColors.surfaceElevated,
        barrierColor: BvColors.overlayScrim,
        shape: const RoundedRectangleBorder(borderRadius: BvRadius.cardAll),
        titleTextStyle: type.headingMd,
        contentTextStyle: type.bodyMd,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BvColors.brandInk,
        contentTextStyle: type.bodyMd.copyWith(color: BvColors.textInverse),
        actionTextColor: BvColors.brandEnergySoft,
        behavior: SnackBarBehavior.floating,
        // Above bottom actions, never on top of them (review 14).
        // Equal sides, so no start or end.
        insetPadding: const EdgeInsets.fromLTRB(
          BvSpace.gutter,
          0,
          BvSpace.gutter,
          BvToastSpec.lift,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BvRadius.controlAll),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: BvColors.iconSecondary,
        textColor: BvColors.textPrimary,
        titleTextStyle: type.titleMd,
        subtitleTextStyle: type.bodySm.copyWith(color: BvColors.textSecondary),
        minVerticalPadding: BvSpace.s12,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(BvColors.surfaceElevated),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BvColors.feedbackSuccess
              : BvColors.actionDisabled,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BvColors.brandEnergy,
        linearTrackColor: BvColors.surfaceSubtle,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BvColors.surfaceElevated,
        surfaceTintColor: BvColors.surfaceElevated,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => type.labelSm.copyWith(
            color: states.contains(WidgetState.selected)
                ? BvColors.brandEnergy
                : BvColors.iconSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: BvSize.iconLg,
            color: states.contains(WidgetState.selected)
                ? BvColors.brandEnergy
                : BvColors.iconSecondary,
          ),
        ),
      ),
    );
  }
}

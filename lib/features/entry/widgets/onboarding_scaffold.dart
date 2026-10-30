import 'package:flutter/material.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The frame of onboarding v2 (review 107, OB2–OB6): the back arrow, one
/// question as the title with a short line under it, the body, and at the
/// bottom "Step n of 3" over the main button (and a link under it). The
/// bottom rises above the keyboard.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.step,
    this.button,
    this.link,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  /// "Step n of 3" over the button, when this is one of the three steps.
  final int? step;
  final Widget? button;
  final Widget? link;

  /// Defaults to going back one screen.
  final VoidCallback? onBack;

  static const steps = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null || canPop
            ? IconButton(
                key: const Key('entry-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(BvIcons.arrowBack),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s8,
                BvSpace.gutter,
                BvSpace.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: type.titleLg),
                  if (subtitle != null) ...[
                    const SizedBox(height: BvSpace.s4),
                    Text(
                      subtitle!,
                      style: type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: BvSpace.s16),
                  body,
                ],
              ),
            ),
          ),
          if (step != null || button != null || link != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvSpace.s8,
                  BvSpace.gutter,
                  BvSpace.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvSpace.s12,
                  children: [
                    if (step != null)
                      Text(
                        l10n.stepOf(step!, steps),
                        textAlign: TextAlign.center,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ?button,
                    if (link != null) Center(child: link),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

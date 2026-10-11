import 'package:flutter/material.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';

/// The frame of the entry and onboarding screens (E2p to E10): a centred
/// title with a back arrow, a scrolling body, and an optional footer with
/// the main button above a divider.
class EntryScaffold extends StatelessWidget {
  const EntryScaffold({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.actions,
    this.onBack,
    this.scroll = true,
    this.bodyPadding = const EdgeInsetsDirectional.symmetric(
      horizontal: BvSpace.gutter,
      vertical: BvSpace.s16,
    ),
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final List<Widget>? actions;

  /// Defaults to going back one screen.
  final VoidCallback? onBack;
  final bool scroll;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(title, style: BvType.of(context).titleLg),
        leading: onBack != null || canPop
            ? IconButton(
                key: const Key('entry-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(BvIcons.arrowBack),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: actions,
      ),
      // The footer is part of the body, so it rises above the keyboard.
      body: Column(
        children: [
          Expanded(
            child: scroll
                ? SingleChildScrollView(padding: bodyPadding, child: body)
                : Padding(padding: bodyPadding, child: body),
          ),
          if (footer != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BvColors.surfaceApp,
                border: Border(
                  top: BorderSide(
                    color: BvColors.borderDefault,
                    width: BvSpace.borderWidth,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.gutter,
                    vertical: BvSpace.s12,
                  ),
                  child: footer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

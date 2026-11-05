import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';

/// A page with the two-line header: the title, and under it, small, where
/// it is ("People" over the Space's name, "Phone number" over Profile).
class BvSectionScaffold extends StatelessWidget {
  const BvSectionScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.titleField,
    this.subtitle,
  });

  final String title;

  /// Under the title, small.
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  /// In the title's place (People's search).
  final Widget? titleField;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BvColors.surfaceApp,
    appBar: AppBar(
      backgroundColor: BvColors.surfaceApp,
      centerTitle: false,
      titleSpacing: 0,
      title:
          titleField ??
          (subtitle == null
              ? Text(title, style: BvType.of(context).titleLg)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BvType.of(context).titleLg,
                    ),
                    Text(
                      subtitle!,
                      key: const Key('section-subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BvType.of(
                        context,
                      ).metadata.copyWith(color: BvColors.textSecondary),
                    ),
                  ],
                )),
      actions: actions,
    ),
    body: body,
  );
}

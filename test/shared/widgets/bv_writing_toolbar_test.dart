import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Widget _bar({
  VoidCallback? onPost,
  VoidCallback? onMore,
  bool active = false,
}) => BvWritingToolbar(
  cameraLabel: 'Camera',
  onCamera: () {},
  attachLabel: 'Attach',
  onAttach: () {},
  moreLabel: 'More',
  onMore: onMore ?? () {},
  moreActive: active,
  postLabel: 'Post',
  onPost: onPost,
);

Color? _postFill(WidgetTester tester) =>
    (tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(const Key('writing-post')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration)
        .color;

void main() {
  testBoth('post is off while there is no title', (tester, lang) async {
    await pumpComponent(tester, _bar(), lang: lang, scroll: false);
    expect(
      tester.getSize(find.byType(BvWritingToolbar)).height,
      BvWritingToolbarSpec.height,
    );
    expect(_postFill(tester), BvColors.surfaceSubtle);
    expect(
      tester.widget<Icon>(find.byIcon(BvIcons.send)).color,
      BvColors.textSecondary,
    );
  });

  testBoth('post, when ready, is orange and taps', (tester, lang) async {
    var posts = 0;
    var more = 0;
    await pumpComponent(
      tester,
      _bar(onPost: () => posts++, onMore: () => more++, active: true),
      lang: lang,
      scroll: false,
    );
    expect(_postFill(tester), BvColors.actionPrimary);
    await tester.tap(find.byKey(const Key('writing-post')));
    await tester.tap(find.byIcon(BvIcons.more));
    expect((posts, more), (1, 1));

    // Tools at the start, Post at the end.
    final camera = tester.getCenter(find.byIcon(BvIcons.camera)).dx;
    final post = tester.getCenter(find.byIcon(BvIcons.send)).dx;
    expect(isRtl(lang) ? camera > post : camera < post, isTrue);
  });
}

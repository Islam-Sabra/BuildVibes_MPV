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

  testBoth('tools and Post keep their look in 48 × 48 touch areas', (
    tester,
    lang,
  ) async {
    var posts = 0;
    var more = 0;
    await pumpComponent(
      tester,
      _bar(onPost: () => posts++, onMore: () => more++),
      lang: lang,
      scroll: false,
    );
    final post = find.byKey(const Key('writing-post'));
    expect(tester.getSize(post), const Size.square(BvSize.touchMin));
    expect(
      tester.getSize(
        find.descendant(of: post, matching: find.byType(AnimatedContainer)),
      ),
      const Size.square(BvWritingToolbarSpec.post),
    );
    await tapEach(tester, touchSquareEdges(tester, post));
    expect(posts, 4);

    final tool = find.ancestor(
      of: find.byIcon(BvIcons.more),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(tool.first), const Size.square(BvSize.touchMin));
    await tapEach(tester, touchSquareEdges(tester, tool.first));
    expect(more, 4);
  });

  testBoth('Post is drawn off while it has nothing to send', (
    tester,
    lang,
  ) async {
    await pumpComponent(
      tester,
      BvWritingToolbar(
        cameraLabel: 'Camera',
        onCamera: () {},
        attachLabel: 'Attach',
        onAttach: () {},
        moreLabel: 'More',
        onMore: () {},
        postLabel: 'Post',
        onPost: null,
      ),
      lang: lang,
      scroll: false,
    );
    expect(_postFill(tester), BvColors.surfaceSubtle);
  });
}

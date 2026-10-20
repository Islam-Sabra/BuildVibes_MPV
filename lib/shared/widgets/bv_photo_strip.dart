import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import 'bv_slip.dart';

/// One photo of a [BvPhotoStrip]: the picture (null while it loads), and
/// whether it still waits to be sent ([waiting], a small mark on it).
typedef BvStripPhoto = ({ImageProvider? image, bool waiting});

/// A post's photos on its card (review 50 F51): the first large, up to two
/// more as small ones beside it, never a count (rule 3). A tap opens them
/// all ([onOpen], with the photo tapped).
class BvPhotoStrip extends StatelessWidget {
  const BvPhotoStrip({super.key, required this.photos, this.onOpen});

  final List<BvStripPhoto> photos;
  final ValueChanged<int>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    Widget tile(int i, double height) {
      final p = photos[i];
      final photo = Stack(
        fit: StackFit.passthrough,
        children: [
          BvSlipPhoto(
            key: Key('photo-strip-$i'),
            height: height,
            image: p.image,
          ),
          // Still on the phone: a still mark, not a spinner (with no
          // signal it may wait a long time; the card says so in words).
          if (p.waiting)
            const Positioned.fill(
              child: Center(
                child: DecoratedBox(
                  key: Key('photo-strip-waiting'),
                  decoration: BoxDecoration(
                    color: BvColors.overlayScrim,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: BvPhotoStripSpec.ring,
                    child: Icon(
                      BvIcons.waiting,
                      size: BvPhotoStripSpec.mark,
                      color: BvColors.iconInverse,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
      final open = onOpen;
      if (open == null) return photo;
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => open(i),
          child: photo,
        ),
      );
    }

    const height = BvSlipSpec.photoHeightCard;
    if (photos.length == 1) return tile(0, height);
    const small = (height - BvPhotoStripSpec.gap) / 2;
    return SizedBox(
      key: const Key('photo-strip'),
      height: height,
      child: Row(
        spacing: BvPhotoStripSpec.gap,
        children: [
          Expanded(flex: BvPhotoStripSpec.largeFlex, child: tile(0, height)),
          Expanded(
            child: Column(
              spacing: BvPhotoStripSpec.gap,
              children: [
                tile(1, photos.length > 2 ? small : height),
                if (photos.length > 2) tile(2, small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A post's photos full screen, one after the other (F51): swipe for the
/// next, pinch to zoom, × to close. Opens at [first].
class BvPhotoViewer extends StatefulWidget {
  const BvPhotoViewer({
    super.key,
    required this.images,
    required this.closeLabel,
    this.first = 0,
  });

  final List<ImageProvider?> images;
  final String closeLabel;
  final int first;

  @override
  State<BvPhotoViewer> createState() => _BvPhotoViewerState();
}

class _BvPhotoViewerState extends State<BvPhotoViewer> {
  late final _pages = PageController(initialPage: widget.first);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('photo-viewer'),
    backgroundColor: BvColors.brandInk,
    appBar: AppBar(
      backgroundColor: BvColors.brandInk,
      leading: IconButton(
        key: const Key('photo-viewer-close'),
        tooltip: widget.closeLabel,
        icon: const Icon(BvIcons.close, color: BvColors.iconInverse),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
    body: PageView(
      controller: _pages,
      children: [
        for (final image in widget.images)
          InteractiveViewer(
            maxScale: BvPreviewSpec.maxZoom,
            child: image == null
                ? const Center(child: CircularProgressIndicator())
                : Image(image: image, fit: BoxFit.contain),
          ),
      ],
    ),
  );
}

// Review 114b: the notification's small icon is the BuildVibes mark (the
// cube with BV cut out), white on clear, at every density. The manifest
// names it for pushes, and every local notification uses it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _res = 'android/app/src/main/res';
const _name = 'ic_stat_buildvibes';

/// Pixels per side at each density (24 dp).
const _sizes = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

img.Image _read(String path) => img.decodePng(File(path).readAsBytesSync())!;

bool _on(img.Pixel p) => p.a > 127;

void main() {
  test('every density: the right size, white only on clear', () {
    for (final MapEntry(key: density, value: side) in _sizes.entries) {
      final icon = _read('$_res/drawable-$density/$_name.png');
      expect(icon.width, side, reason: density);
      expect(icon.height, side, reason: density);
      for (final p in icon) {
        if (p.a == 0) continue;
        expect([p.r, p.g, p.b], [255, 255, 255], reason: density);
      }
    }
  });

  test("its shape is the BuildVibes mark, not Flutter's", () {
    // The brand mark, cut to the cube, on 22 of 24 dp, centred.
    final mark = _read('assets/brand/bv_icon_monochrome_1024.png');
    var (l, t, r, b) = (mark.width, mark.height, 0, 0);
    for (final p in mark) {
      if (!_on(p)) continue;
      if (p.x < l) l = p.x;
      if (p.y < t) t = p.y;
      if (p.x > r) r = p.x;
      if (p.y > b) b = p.y;
    }
    final cube = img.copyCrop(
      mark,
      x: l,
      y: t,
      width: r - l + 1,
      height: b - t + 1,
    );
    const side = 96;
    final inner = (side * 22 / 24).round();
    final scaled = img.copyResize(
      cube,
      width: (cube.width * inner / cube.height).round(),
      height: inner,
      interpolation: img.Interpolation.average,
    );
    final want = img.Image(width: side, height: side, numChannels: 4);
    img.compositeImage(
      want,
      scaled,
      dstX: (side - scaled.width) ~/ 2,
      dstY: (side - scaled.height) ~/ 2,
    );

    final icon = _read('$_res/drawable-xxxhdpi/$_name.png');
    var both = 0, either = 0;
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final a = _on(icon.getPixel(x, y));
        final w = _on(want.getPixel(x, y));
        if (a && w) both++;
        if (a || w) either++;
      }
    }
    expect(both / either, greaterThan(0.85));
  });

  test('the manifest and the local notifications name it', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains(
        'android:name="com.google.firebase.messaging.default_notification_icon"\n'
        '            android:resource="@drawable/$_name"',
      ),
    );
    final reminders = File('lib/core/push/reminders.dart').readAsStringSync();
    expect('@drawable/$_name'.allMatches(reminders), hasLength(2));
  });
}

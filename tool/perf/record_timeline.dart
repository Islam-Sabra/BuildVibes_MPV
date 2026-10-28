// Review 101 L1 (local only): records a profile build's timeline from the
// host while the phone is driven by hand or by adb, then sums it up: the
// frames over budget (build and raster), and what the raster thread spent
// its time on in the slow frames. Run from the project:
//   dart run tool/perf/record_timeline.dart <ws-uri> <out.json>
// It starts recording at once and stops when a line "stop" is typed (or
// stdin closes). Or, for a timeline already recorded (an integration
// test's traceAction, under its report key):
//   dart run tool/perf/record_timeline.dart --file <report.json> <key>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:vm_service/vm_service_io.dart';

/// A frame's budget at 60 Hz.
const _budgetMicros = 16667;

Future<void> main(List<String> args) async {
  if (args.first == '--file') {
    final report =
        jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
    _sum((report[args[2]] ?? report) as Map<String, dynamic>);
    return;
  }
  final service = await vmServiceConnectUri(args[0]);
  await service.setVMTimelineFlags(['Dart', 'Embedder', 'GC']);
  await service.clearVMTimeline();
  stdout.writeln('RECORDING');
  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere((l) => l.trim() == 'stop', orElse: () => 'stop');
  final timeline = await service.getVMTimeline();
  await service.dispose();
  final json = timeline.toJson();
  File(args[1]).writeAsStringSync(jsonEncode(json));
  _sum(json);
}

void _sum(Map<String, dynamic> json) {
  try {
    _frames(json);
  } on StateError catch (e) {
    // Recorded without the Dart stream: the raster thread's part only.
    stdout.writeln('FRAMES none (${e.message.split('.').first})');
  }
  _raster(json);
}

const _keys = [
  'frame_count',
  'missed_frame_build_budget_count',
  'missed_frame_rasterizer_budget_count',
  'average_frame_build_time_millis',
  '90th_percentile_frame_build_time_millis',
  'worst_frame_build_time_millis',
  'average_frame_rasterizer_time_millis',
  '90th_percentile_frame_rasterizer_time_millis',
  'worst_frame_rasterizer_time_millis',
];

void _frames(Map<String, dynamic> json) {
  final s = TimelineSummary.summarize(Timeline.fromJson(json)).summaryJson;
  stdout.writeln('FRAMES ${jsonEncode({for (final k in _keys) k: s[k]})}');
}

/// The raster thread's events inside its slow frames, by total time.
void _raster(Map<String, dynamic> json) {
  final events = [
    for (final e in json['traceEvents'] as List) e as Map<String, dynamic>,
  ];
  int? rasterTid;
  for (final e in events) {
    if (e['ph'] == 'M' &&
        e['name'] == 'thread_name' &&
        '${(e['args'] as Map?)?['name']}'.contains('raster')) {
      rasterTid = e['tid'] as int;
    }
  }
  if (rasterTid == null) {
    stdout.writeln('RASTER no raster thread found');
    return;
  }
  // Each complete event on the raster thread: B/E pairs or X.
  final spans = <({String name, int start, int end, int depth})>[];
  final open = <({String name, int start})>[];
  for (final e in events.where((e) => e['tid'] == rasterTid)) {
    final ts = e['ts'] as int?;
    if (ts == null) continue;
    switch (e['ph']) {
      case 'B':
        open.add((name: e['name'] as String, start: ts));
      case 'E':
        if (open.isEmpty) continue;
        final b = open.removeLast();
        spans.add((name: b.name, start: b.start, end: ts, depth: open.length));
      case 'X':
        spans.add((
          name: e['name'] as String,
          start: ts,
          end: ts + (e['dur'] as int? ?? 0),
          depth: open.length,
        ));
    }
  }
  final frames = [
    for (final s in spans)
      if (s.name == 'GPURasterizer::Draw') s,
  ];
  final slow = [
    for (final f in frames)
      if (f.end - f.start > _budgetMicros) f,
  ];
  int inside(({String name, int start, int end, int depth}) f, String name) => [
    for (final s in spans)
      if (s.name == name && s.start >= f.start && s.end <= f.end) s,
  ].length;
  if (frames.isNotEmpty) {
    final ms = [for (final f in frames) (f.end - f.start) / 1000]..sort();
    final passes = frames.fold<int>(
      0,
      (a, f) => a + inside(f, 'RenderPassGLES::EncodeCommandsInReactor'),
    );
    stdout.writeln(
      'RASTER every frame: median ${ms[ms.length ~/ 2].toStringAsFixed(1)} ms, '
      '90th ${ms[(ms.length * 9) ~/ 10].toStringAsFixed(1)} ms, '
      'render passes ${(passes / frames.length).toStringAsFixed(1)} a frame',
    );
  }
  // What a user sees: the gap from one frame to the next while it moves
  // (under 200 ms; longer is between flings). Raster time alone counts the
  // wait for the next vsync once a frame comes every vsync (review 101 L1).
  final starts = [for (final f in frames) f.start]..sort();
  final gaps = [
    for (var i = 1; i < starts.length; i++)
      if (starts[i] - starts[i - 1] < 200000)
        (starts[i] - starts[i - 1]) / 1000,
  ]..sort();
  if (gaps.isNotEmpty) {
    stdout.writeln(
      'GAPS ${gaps.length} while moving, median '
      '${gaps[gaps.length ~/ 2].toStringAsFixed(1)} ms, '
      'over 25 ms (a vsync missed) ${gaps.where((g) => g > 25).length}, '
      'over 34 ms (two missed) ${gaps.where((g) => g > 34).length}',
    );
  }
  stdout.writeln(
    'RASTER frames ${frames.length}, slow ${slow.length}, '
    'slow total ${slow.fold<int>(0, (a, f) => a + f.end - f.start) ~/ 1000} ms',
  );
  final byName = <String, ({int micros, int count})>{};
  for (final f in slow) {
    for (final s in spans) {
      if (s.start < f.start || s.end > f.end || identical(s, f)) continue;
      final was = byName[s.name] ?? (micros: 0, count: 0);
      byName[s.name] = (
        micros: was.micros + s.end - s.start,
        count: was.count + 1,
      );
    }
  }
  final top = byName.entries.toList()
    ..sort((a, b) => b.value.micros.compareTo(a.value.micros));
  for (final e in top.take(25)) {
    stdout.writeln(
      'RASTER ${(e.value.micros / 1000).toStringAsFixed(1).padLeft(8)} ms '
      '${e.value.count.toString().padLeft(6)}x  ${e.key}',
    );
  }
}

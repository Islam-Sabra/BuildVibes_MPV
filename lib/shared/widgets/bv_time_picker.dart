import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_segmented.dart';
import 'bv_time_wheel.dart';

/// How the time picker shows the time (review 104 N11).
enum BvTimeMode { clock, wheels }

/// Where the phone keeps the last mode used.
const timePickerModeKey = 'time_picker_mode';

/// The time picker of the whole app (review 104 N11, correcting review 102
/// N2), in a dialog with [title]: AM / PM as one choice above, then the
/// clock face (the default) or the wheels, and the mode switch where typed
/// input used to be; nothing is typed in either. The last mode used is
/// kept on the phone. [cancelLabel]'s button (Cancel by default, or the
/// picker's own "No time") gives back null. With [after], a time at or
/// before it, already passed today, is greyed and can't be chosen.
Future<TimeOfDay?> showBvTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  required String title,
  String? cancelLabel,
  TimeOfDay? after,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return null;
  final mode = prefs.getString(timePickerModeKey) == BvTimeMode.wheels.name
      ? BvTimeMode.wheels
      : BvTimeMode.clock;
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _TimePickerDialog(
      initial: initial,
      title: title,
      cancelLabel: cancelLabel,
      after: after,
      mode: mode,
      onMode: (m) => unawaited(prefs.setString(timePickerModeKey, m.name)),
    ),
  );
}

class _TimePickerDialog extends StatefulWidget {
  const _TimePickerDialog({
    required this.initial,
    required this.title,
    required this.cancelLabel,
    required this.after,
    required this.mode,
    required this.onMode,
  });

  final TimeOfDay initial;
  final String title;
  final String? cancelLabel;
  final TimeOfDay? after;
  final BvTimeMode mode;
  final ValueChanged<BvTimeMode> onMode;

  @override
  State<_TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<_TimePickerDialog> {
  late var _time = BvTimeWheel.opening(widget.initial, after: widget.after);
  late var _mode = widget.mode;

  void _period(DayPeriod p) {
    final next = BvTimeWheel.withPeriod(_time, p, widget.after);
    if (next != null) setState(() => _time = next);
  }

  void _switch() {
    final next = _mode == BvTimeMode.clock
        ? BvTimeMode.wheels
        : BvTimeMode.clock;
    setState(() => _mode = next);
    widget.onMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final type = BvType.of(context);
    final clock = _mode == BvTimeMode.clock;
    return Dialog(
      key: const Key('time-picker-dialog'),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: BvTimeWheelSpec.padding,
          start: BvTimeWheelSpec.padding,
          end: BvTimeWheelSpec.padding,
          bottom: BvSpace.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: type.titleMd.copyWith(color: BvColors.textPrimary),
            ),
            const SizedBox(height: BvTimeWheelSpec.padding),
            BvSegmented<DayPeriod>(
              segments: [
                BvSegment(
                  value: DayPeriod.am,
                  label: l10n.timeWheelAm,
                  key: const Key('time-wheel-am'),
                ),
                BvSegment(
                  value: DayPeriod.pm,
                  label: l10n.timeWheelPm,
                  key: const Key('time-wheel-pm'),
                ),
              ],
              value: _time.period,
              onChanged: _period,
            ),
            const SizedBox(height: BvTimeWheelSpec.padding),
            if (clock)
              BvClockFace(
                value: _time,
                after: widget.after,
                onChanged: (t) => setState(() => _time = t),
              )
            else
              BvTimeWheel(
                value: _time,
                after: widget.after,
                onChanged: (t) => setState(() => _time = t),
              ),
            const SizedBox(height: BvSpace.s8),
            Row(
              children: [
                // Where typed input used to be: the clock ⇄ the wheels.
                Semantics(
                  button: true,
                  label: clock
                      ? l10n.timePickerToWheels
                      : l10n.timePickerToClock,
                  excludeSemantics: true,
                  child: IconButton(
                    key: const Key('time-picker-mode'),
                    onPressed: _switch,
                    icon: Icon(
                      clock ? BvIcons.timeWheels : BvIcons.timeClock,
                      size: BvSize.iconMd,
                      color: BvColors.iconSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('time-picker-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.cancelLabel ?? material.cancelButtonLabel),
                ),
                TextButton(
                  key: const Key('time-picker-ok'),
                  onPressed: BvTimeWheel.allows(_time, widget.after)
                      ? () => Navigator.of(context).pop(_time)
                      : null,
                  child: Text(material.okButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The clock face (review 104 N11): the time on top, its hour and its
/// minutes each a button that shows its ring; then a round dial of the
/// hours 1–12, or the minutes in 5-minute steps. A tap or a drag round the
/// dial picks; after the hour, the minutes come by themselves. A time
/// passed today ([after]) is greyed and never taken. A clock reads the
/// same in both languages: 12 at the top, 3 on the right.
class BvClockFace extends StatefulWidget {
  const BvClockFace({
    super.key,
    required this.value,
    required this.onChanged,
    this.after,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final TimeOfDay? after;

  @override
  State<BvClockFace> createState() => _BvClockFaceState();
}

class _BvClockFaceState extends State<BvClockFace> {
  static const _step = BvTimeWheelSpec.minuteStep;
  static const _places = BvTimePickerSpec.places;

  /// The minutes' ring shows; else the hours'.
  var _minutes = false;

  TimeOfDay get _value => widget.value;

  /// The value at place [i] (0 at the top, going round): an hour 1–12, or
  /// the minutes.
  int _valueAt(int i) => _minutes ? i * _step : (i == 0 ? 12 : i);

  TimeOfDay _timeAt(int i) => _minutes
      ? BvTimeWheel.compose(
          BvTimeWheel.hourOf(_value),
          i * _step,
          _value.period,
        )
      : BvTimeWheel.compose(_valueAt(i), _value.minute, _value.period);

  /// Place [i] can be taken: an hour with a minute still to come, or a
  /// minute still to come.
  bool _open(int i) {
    final after = widget.after;
    if (after == null) return true;
    if (_minutes) return BvTimeWheel.allows(_timeAt(i), after);
    return [
      for (var m = 0; m < 60; m += _step)
        BvTimeWheel.allows(
          BvTimeWheel.compose(_valueAt(i), m, _value.period),
          after,
        ),
    ].contains(true);
  }

  int get _chosen =>
      _minutes ? _value.minute ~/ _step : BvTimeWheel.hourOf(_value) % _places;

  /// The place nearest [at], a point on the dial.
  int _placeAt(Offset at) {
    const half = BvTimePickerSpec.dial / 2;
    final d = at - const Offset(half, half);
    // Clockwise from the top.
    final angle = math.atan2(d.dx, -d.dy);
    final turn = (angle < 0 ? angle + 2 * math.pi : angle) / (2 * math.pi);
    return (turn * _places).round() % _places;
  }

  void _pick(int i, {required bool done}) {
    if (!_open(i)) return;
    var next = _timeAt(i);
    // A new hour keeps its minutes if they are still to come.
    if (!_minutes && !BvTimeWheel.allows(next, widget.after)) {
      next = BvTimeWheel.firstFrom(next, widget.after) ?? next;
    }
    if (next != _value) {
      unawaited(HapticFeedback.selectionClick());
      widget.onChanged(next);
    }
    if (done && !_minutes) setState(() => _minutes = true);
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    final chosen = _chosen;
    final hour = '${BvTimeWheel.hourOf(_value)}';
    final minute = _value.minute.toString().padLeft(2, '0');

    Widget part(String key, String text, bool on, VoidCallback onTap) =>
        Semantics(
          button: true,
          selected: on,
          child: InkWell(
            key: Key(key),
            onTap: onTap,
            borderRadius: BvRadius.controlAll,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.s8,
                vertical: BvSpace.s4,
              ),
              child: Text(
                text,
                style: type.headingMd.copyWith(
                  color: on ? BvColors.textAction : BvColors.textPrimary,
                ),
              ),
            ),
          ),
        );

    const radius = (BvTimePickerSpec.dial - BvTimePickerSpec.number) / 2;
    const half = BvTimePickerSpec.dial / 2;
    Offset centreOf(int i) {
      final a = 2 * math.pi * i / _places;
      return Offset(half + radius * math.sin(a), half - radius * math.cos(a));
    }

    // A clock reads the same way round in both languages.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        key: const Key('time-clock'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: l10n.timeWheelHour,
                child: part(
                  'time-clock-show-hour',
                  hour,
                  !_minutes,
                  () => setState(() => _minutes = false),
                ),
              ),
              Text(':', style: type.headingMd),
              Semantics(
                label: l10n.timeWheelMinutes,
                child: part(
                  'time-clock-show-minute',
                  minute,
                  _minutes,
                  () => setState(() => _minutes = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: BvTimePickerSpec.headGap),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _pick(_placeAt(d.localPosition), done: false),
            onPanEnd: (_) {
              if (!_minutes) setState(() => _minutes = true);
            },
            child: SizedBox.square(
              dimension: BvTimePickerSpec.dial,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: BvColors.surfaceSubtle,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Hand(
                        to: centreOf(chosen),
                        from: const Offset(half, half),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _places; i++)
                    Positioned(
                      left: centreOf(i).dx - BvTimePickerSpec.number / 2,
                      top: centreOf(i).dy - BvTimePickerSpec.number / 2,
                      child: _Number(
                        key: Key(
                          _minutes
                              ? 'time-clock-minute-${_valueAt(i)}'
                              : 'time-clock-hour-${_valueAt(i)}',
                        ),
                        text: _minutes
                            ? _valueAt(i).toString().padLeft(2, '0')
                            : '${_valueAt(i)}',
                        chosen: i == chosen,
                        open: _open(i),
                        onTap: () => _pick(i, done: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One number on the dial: on a filled circle when chosen, greyed when
/// passed.
class _Number extends StatelessWidget {
  const _Number({
    super.key,
    required this.text,
    required this.chosen,
    required this.open,
    required this.onTap,
  });

  final String text;
  final bool chosen;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      selected: chosen,
      enabled: open,
      label: text,
      excludeSemantics: true,
      onTap: open ? onTap : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: BvTimePickerSpec.number,
          height: BvTimePickerSpec.number,
          alignment: Alignment.center,
          decoration: chosen
              ? const BoxDecoration(
                  color: BvColors.actionPrimary,
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(
            text,
            style: type.bodyLg.copyWith(
              color: chosen
                  ? BvColors.textInverse
                  : open
                  ? BvColors.textPrimary
                  : BvColors.textSecondary.withValues(
                      alpha: BvTimeWheelSpec.passed,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hand from the dial's middle to the chosen number.
class _Hand extends CustomPainter {
  const _Hand({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BvColors.actionPrimary
      ..strokeWidth = BvTimePickerSpec.hand;
    canvas
      ..drawLine(from, to, paint)
      ..drawCircle(from, BvTimePickerSpec.centre / 2, paint);
  }

  @override
  bool shouldRepaint(_Hand old) => old.from != from || old.to != to;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';

/// Where a new time starts (review 102 N2): the next 5-minute mark after an
/// hour from [now].
DateTime nextFiveMinutesAfterAnHour(DateTime now) {
  final later = now.add(const Duration(hours: 1));
  const step = BvTimeWheelSpec.minuteStep;
  return DateTime(
    later.year,
    later.month,
    later.day,
    later.hour,
  ).add(Duration(minutes: (later.minute ~/ step + 1) * step));
}

/// The time on two wheels, the hour (1–12) and the minutes in 5-minute
/// steps (review 102 N2): the wheel mode of [showBvTimePicker], which puts
/// AM / PM above it as one choice (review 104 N11). Only a valid time can
/// be chosen; nothing is typed. With [after], a time at or before it
/// (passed today) is greyed, and a wheel turned onto one goes on to the
/// first time still to come.
class BvTimeWheel extends StatefulWidget {
  const BvTimeWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.after,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final TimeOfDay? after;

  static const _step = BvTimeWheelSpec.minuteStep;
  static const _day = 24 * 60;

  static int _of(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay _at(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  /// [time] can be chosen: not passed.
  static bool allows(TimeOfDay time, TimeOfDay? after) =>
      after == null || _of(time) > _of(after);

  /// The first step at or after [time] that can be chosen; null with none
  /// left today.
  static TimeOfDay? firstFrom(TimeOfDay time, TimeOfDay? after) {
    for (
      var m = (_of(time) + _step - 1) ~/ _step * _step;
      m < _day;
      m += _step
    ) {
      if (allows(_at(m), after)) return _at(m);
    }
    return null;
  }

  /// [time] in [period] (AM / PM), or the first time to come from there
  /// when that has passed; null with none left today.
  static TimeOfDay? withPeriod(
    TimeOfDay time,
    DayPeriod period,
    TimeOfDay? after,
  ) {
    final t = compose(hourOf(time), time.minute, period);
    return allows(t, after) ? t : firstFrom(t, after);
  }

  /// The hour as the wheel and the clock show it, 1–12.
  static int hourOf(TimeOfDay t) => t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;

  /// [hour] (1–12) and [minute] in [period].
  static TimeOfDay compose(int hour, int minute, DayPeriod period) => TimeOfDay(
    hour: hour % 12 + (period == DayPeriod.pm ? 12 : 0),
    minute: minute,
  );

  /// Where the wheels open for [initial]: on its step, or the next one,
  /// never a time passed.
  static TimeOfDay opening(TimeOfDay initial, {TimeOfDay? after}) =>
      firstFrom(initial, after) ?? _at(_day - _step);

  @override
  State<BvTimeWheel> createState() => _BvTimeWheelState();
}

class _BvTimeWheelState extends State<BvTimeWheel> {
  static const _step = BvTimeWheelSpec.minuteStep;
  static const _minutes = 60 ~/ _step;

  late final _hours = FixedExtentScrollController(
    initialItem: _hourOf(widget.value) - 1,
  );
  late final _mins = FixedExtentScrollController(
    initialItem: widget.value.minute ~/ _step,
  );

  /// The wheels are turned by the app, not the finger: no haptic, no
  /// change sent.
  var _jumping = false;

  static int _hourOf(TimeOfDay t) => BvTimeWheel.hourOf(t);

  static TimeOfDay _compose(int hour, int minute, DayPeriod period) =>
      BvTimeWheel.compose(hour, minute, period);

  TimeOfDay get _value => widget.value;

  @override
  void didUpdateWidget(BvTimeWheel old) {
    super.didUpdateWidget(old);
    _follow();
  }

  /// The wheels show [BvTimeWheel.value].
  void _follow() {
    final hour = _hourOf(_value) - 1;
    final minute = _value.minute ~/ _step;
    _jumping = true;
    if (_hours.hasClients && _hours.selectedItem != hour) {
      _hours.jumpToItem(hour);
    }
    if (_mins.hasClients && _mins.selectedItem != minute) {
      _mins.jumpToItem(minute);
    }
    _jumping = false;
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _turned(TimeOfDay t) {
    if (_jumping) return;
    HapticFeedback.selectionClick();
    widget.onChanged(t);
  }

  /// The wheel stopped: a passed time goes on to the first one to come.
  void _settle() {
    if (BvTimeWheel.allows(_value, widget.after)) return;
    final next = BvTimeWheel.firstFrom(_value, widget.after);
    if (next != null && next != _value) widget.onChanged(next);
  }

  /// A screen reader's swipe up or down: one row on.
  void _nudge(FixedExtentScrollController wheel, int by, int count) {
    final to = (wheel.selectedItem + by).clamp(0, count - 1);
    if (to == wheel.selectedItem) return;
    wheel.jumpToItem(to);
    _settle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final after = widget.after;
    final period = _value.period;
    final hour = _hourOf(_value);
    TextStyle style({required bool passed}) => type.bodyLg.copyWith(
      color: passed
          ? BvColors.textSecondary.withValues(alpha: BvTimeWheelSpec.passed)
          : BvColors.textPrimary,
    );
    bool hourPassed(int h) => ![
      for (var m = 0; m < 60; m += _step)
        BvTimeWheel.allows(_compose(h, m, period), after),
    ].contains(true);

    Widget wheel({
      required Key key,
      required String label,
      required FixedExtentScrollController controller,
      required List<(int, String, bool)> rows,
      required ValueChanged<int> onItem,
    }) {
      final i = controller.hasClients
          ? controller.selectedItem
          : controller.initialItem;
      String at(int j) => rows[j.clamp(0, rows.length - 1)].$2;
      return Semantics(
        container: true,
        label: label,
        value: at(i),
        increasedValue: i + 1 < rows.length ? at(i + 1) : null,
        decreasedValue: i > 0 ? at(i - 1) : null,
        onIncrease: i + 1 < rows.length
            ? () => _nudge(controller, 1, rows.length)
            : null,
        onDecrease: i > 0 ? () => _nudge(controller, -1, rows.length) : null,
        child: ExcludeSemantics(
          child: SizedBox(
            width: BvTimeWheelSpec.wheelWidth,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _settle();
                });
                return false;
              },
              child: ListWheelScrollView(
                key: key,
                controller: controller,
                itemExtent: BvTimeWheelSpec.rowHeight,
                physics: const FixedExtentScrollPhysics(),
                overAndUnderCenterOpacity: BvTimeWheelSpec.fade,
                onSelectedItemChanged: onItem,
                children: [
                  for (final (value, text, passed) in rows)
                    Center(
                      key: ValueKey((
                        key is ValueKey<String> ? key.value : '',
                        value,
                      )),
                      child: Text(text, style: style(passed: passed)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      key: const Key('time-wheel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: BvTimeWheelSpec.rowHeight * BvTimeWheelSpec.rows,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  key: const Key('time-wheel-lines'),
                  height: BvTimeWheelSpec.rowHeight,
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: BvColors.borderDefault),
                    ),
                  ),
                ),
              ),
              // Read as the time is: the hour, then the minutes, in both
              // languages (9:05; in Arabic, minutes then hour from the
              // right).
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: BvTimeWheelSpec.gap,
                  children: [
                    wheel(
                      key: const ValueKey('time-wheel-hour'),
                      label: l10n.timeWheelHour,
                      controller: _hours,
                      rows: [
                        for (var h = 1; h <= 12; h++) (h, '$h', hourPassed(h)),
                      ],
                      onItem: (i) =>
                          _turned(_compose(i + 1, _value.minute, period)),
                    ),
                    wheel(
                      key: const ValueKey('time-wheel-minute'),
                      label: l10n.timeWheelMinutes,
                      controller: _mins,
                      rows: [
                        for (var j = 0; j < _minutes; j++)
                          (
                            j * _step,
                            (j * _step).toString().padLeft(2, '0'),
                            !BvTimeWheel.allows(
                              _compose(hour, j * _step, period),
                              after,
                            ),
                          ),
                      ],
                      onItem: (j) => _turned(_compose(hour, j * _step, period)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

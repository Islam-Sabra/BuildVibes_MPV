import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/planning_specs.dart';
import '../../data/models/note.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import 'note_writing.dart' show gpsMetres;

/// Why there is no position: the person said no, the phone's location is
/// off, or it couldn't be found in time.
enum GpsFailure { denied, off, failed }

/// The phone's position, or why there is none.
typedef FoundPosition = ({
  double lat,
  double lng,
  double accuracyM,
  GpsFailure? failure,
});

/// Finds the phone's position (F107 NBX4), asking its permission the
/// first time. A provider so tests can stand in for the GPS.
typedef FindPosition = Future<FoundPosition> Function();

const FoundPosition _noPosition = (
  lat: 0,
  lng: 0,
  accuracyM: 0,
  failure: GpsFailure.failed,
);

final findPositionProvider = Provider<FindPosition>(
  (ref) => () async {
    FoundPosition failed(GpsFailure f) =>
        (lat: 0, lng: 0, accuracyM: 0, failure: f);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return failed(GpsFailure.off);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return failed(GpsFailure.denied);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (
        lat: p.latitude,
        lng: p.longitude,
        // Never nothing: save_note keeps an accuracy above 0.
        accuracyM: p.accuracy <= 0 ? 1.0 : p.accuracy,
        failure: null,
      );
    } on Object {
      return _noPosition;
    }
  },
);

/// "29.37594, 47.97740 · ±8 m": five decimals, Western digits.
String gpsLine(AppLocalizations l10n, NoteLocation l) => l10n.notebookGpsLine(
  l.lat!.toStringAsFixed(5),
  l.lng!.toStringAsFixed(5),
  gpsMetres(l.accuracyM),
);

/// The location sheet (F107 NBX4 2619:37151), in place of the keyboard's
/// top: "Location" and Done, the typed field ("Level 3, grid C7"), and
/// "Add my GPS position", which asks the phone the first time and shows
/// the position with its accuracy and an ×. Typed only, GPS only, or both.
class NoteLocationPanel extends ConsumerStatefulWidget {
  const NoteLocationPanel({
    super.key,
    required this.location,
    required this.onChanged,
    required this.onDone,
  });

  final NoteLocation? location;
  final ValueChanged<NoteLocation?> onChanged;
  final VoidCallback onDone;

  @override
  ConsumerState<NoteLocationPanel> createState() => _NoteLocationPanelState();
}

class _NoteLocationPanelState extends ConsumerState<NoteLocationPanel> {
  late final _typed = TextEditingController(text: widget.location?.text ?? '');
  final _focus = FocusNode();
  late NoteLocation _location = widget.location ?? const NoteLocation();
  var _finding = false;
  GpsFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _typed.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(NoteLocation l) {
    setState(() => _location = l);
    widget.onChanged(l.isEmpty ? null : l);
  }

  Future<void> _findGps() async {
    setState(() {
      _finding = true;
      _failure = null;
    });
    final found = await ref.read(findPositionProvider)();
    if (!mounted) return;
    setState(() {
      _finding = false;
      _failure = found.failure;
    });
    if (found.failure != null) return;
    _set(
      NoteLocation(
        text: _location.text,
        lat: found.lat,
        lng: found.lng,
        accuracyM: found.accuracyM,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final failure = switch (_failure) {
      GpsFailure.denied => l10n.notebookGpsDenied,
      GpsFailure.off => l10n.notebookGpsOff,
      GpsFailure.failed => l10n.notebookGpsFailed,
      null => null,
    };
    return ColoredBox(
      key: const Key('note-location-panel'),
      color: BvColors.surfaceElevated,
      child: Padding(
        padding: BvNoteBlocksSpec.locationPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvNoteBlocksSpec.locationGap,
          children: [
            Row(
              spacing: BvSpace.s8,
              children: [
                const Icon(
                  BvIcons.place,
                  size: BvNoteBlocksSpec.locationTitleIcon,
                  color: BvColors.iconAction,
                ),
                Text(
                  l10n.notebookLocation,
                  style: type.labelLg.copyWith(color: BvColors.textPrimary),
                ),
                const Spacer(),
                BvTapTarget(
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      key: const Key('note-location-done'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onDone,
                      child: Text(
                        l10n.pageDone,
                        style: type.labelLg.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: BvNoteBlocksSpec.fieldPadding,
              decoration: const BoxDecoration(
                color: BvColors.surfaceApp,
                borderRadius: BvNoteBlocksSpec.fieldRadius,
              ),
              child: TextField(
                key: const Key('note-location-typed'),
                controller: _typed,
                focusNode: _focus,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(NoteLocation.textMax),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.onDone(),
                onChanged: (t) => _set(_location.withText(t)),
                style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                cursorColor: BvColors.actionPrimary,
                cursorWidth: BvWritingCardSpec.cursorWidth,
                decoration: bvBareField(
                  hint: l10n.notebookWhereHint,
                  style: type.bodyMd,
                ),
              ),
            ),
            _GpsRow(
              location: _location,
              finding: _finding,
              onAdd: _findGps,
              onRemove: () => _set(_location.withoutGps()),
            ),
            Text(failure ?? l10n.notebookLocationHelp, style: quiet),
          ],
        ),
      ),
    );
  }
}

/// "Add my GPS position", or the position added (NBX4): the pin on an
/// action-colour circle, "My GPS position added" and "29.37594, 47.97740 ·
/// ±8 m", with × at the end.
class _GpsRow extends StatelessWidget {
  const _GpsRow({
    required this.location,
    required this.finding,
    required this.onAdd,
    required this.onRemove,
  });

  final NoteLocation location;
  final bool finding;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final added = location.hasGps;
    final row = Container(
      padding: BvNoteBlocksSpec.gpsPadding,
      decoration: BoxDecoration(
        color: added ? BvColors.surfaceBrandSoft : BvColors.surfaceApp,
        borderRadius: BvNoteBlocksSpec.fieldRadius,
      ),
      child: Row(
        spacing: BvNoteBlocksSpec.gpsGap,
        children: [
          Container(
            width: BvNoteBlocksSpec.gpsCircle,
            height: BvNoteBlocksSpec.gpsCircle,
            decoration: BoxDecoration(
              color: added ? BvColors.actionPrimary : BvColors.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              BvIcons.place,
              size: BvNoteBlocksSpec.gpsIcon,
              color: added
                  ? BvColors.actionPrimaryForeground
                  : BvColors.iconAction,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvNoteBlocksSpec.gpsLinesGap,
              children: [
                Text(
                  added
                      ? l10n.notebookGpsAdded
                      : finding
                      ? l10n.notebookGpsFinding
                      : l10n.notebookAddGps,
                  style: type.emphasis.copyWith(color: BvColors.textPrimary),
                ),
                if (added)
                  Text(
                    gpsLine(l10n, location),
                    key: const Key('note-gps-line'),
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (added)
            BvTapTarget(
              child: Semantics(
                button: true,
                label: l10n.notebookRemoveGps,
                child: GestureDetector(
                  key: const Key('note-gps-remove'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: const Icon(
                    BvIcons.close,
                    size: BvNoteBlocksSpec.remove,
                    color: BvColors.iconSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (added) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('note-gps-add'),
        behavior: HitTestBehavior.opaque,
        onTap: finding ? null : onAdd,
        child: row,
      ),
    );
  }
}

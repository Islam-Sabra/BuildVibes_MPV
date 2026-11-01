import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/location/location_reader.dart';
import '../../data/models/check_in.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/space_repository.dart' show spaceDetailProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart' show showSpaceMessage;
import 'check_in_words.dart';
import 'daybook_state.dart' show daybookCardsProvider;

/// Review 109 CI3: the person said yes to the warning on this phone. Only
/// a yes is kept: "Check in without location" brings the warning back
/// next time, until they accept.
String checkInConsentKey(String userId) => 'check_in_location_ok:$userId';

/// Marks In or Out for one person (review 109 §3). With [share], the
/// location is read once, now (a weak signal tried again once), and its
/// point goes to mark_check_in and nowhere else: never kept on the phone,
/// never logged. Refused, off or weak marks "location not shared", with
/// no error.
class CheckInMarker {
  CheckInMarker({
    required this.repository,
    required this.reader,
    required this.prefs,
    required this.userId,
  });

  final CheckInRepository repository;
  final LocationReader reader;
  final SharedPreferences prefs;
  final String userId;

  bool get accepted => prefs.getBool(checkInConsentKey(userId)) ?? false;

  Future<void> accept() => prefs.setBool(checkInConsentKey(userId), true);

  Future<CheckInResult> mark(
    String postId,
    CheckInMarkKind kind, {
    required bool share,
  }) async {
    final read = share ? await readForCheckIn(reader) : null;
    final point = read != null && read.hasPoint;
    return repository.mark(
      postId,
      kind,
      lat: point ? read.lat : null,
      lng: point ? read.lng : null,
    );
  }
}

final checkInMarkerProvider = Provider.autoDispose<CheckInMarker?>((ref) {
  final userId = ref.watch(authUserIdProvider).value;
  if (userId == null) return null;
  return CheckInMarker(
    repository: ref.watch(checkInRepositoryProvider),
    reader: ref.watch(locationReaderProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    userId: userId,
  );
});

/// The warning's answer (CI3).
enum CheckInConsent { accept, without }

/// CI3 (2706:39486): before the location is first read. Accept, or Check
/// in (out) without location. Null when put down.
Future<CheckInConsent?> showCheckInWarning(
  BuildContext context, {
  required CheckInMarkKind kind,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<CheckInConsent>(
    context: context,
    builder: (sheet) {
      final type = BvType.of(sheet);
      return Column(
        key: const Key('check-in-warning'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s12,
        children: [
          Container(
            width: BvSize.avatarLg,
            height: BvSize.avatarLg,
            decoration: const BoxDecoration(
              color: BvColors.surfaceBrandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              BvIcons.place,
              size: BvSize.iconLg,
              color: BvColors.iconAction,
            ),
          ),
          Text(
            l10n.checkInWarnTitle,
            style: type.titleMd.copyWith(color: BvColors.textPrimary),
          ),
          Text(
            l10n.checkInWarnBody,
            style: type.bodyMd.copyWith(color: BvColors.textSecondary),
          ),
          BvButton(
            key: const Key('check-in-accept'),
            label: l10n.checkInAccept,
            icon: BvIcons.check,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(CheckInConsent.accept),
          ),
          BvButton(
            key: const Key('check-in-without'),
            label: kind == CheckInMarkKind.checkIn
                ? l10n.checkInWithout
                : l10n.checkOutWithout,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(CheckInConsent.without),
          ),
        ],
      );
    },
  );
}

/// A tap on Check in, Try again or Check out (CI4): the warning the first
/// time, then the mark, then one line with the result ("Checked in 6:58 ·
/// on site") or why it was refused. The cards read again. True when it
/// was marked.
Future<bool> checkInFromCard(
  BuildContext context,
  WidgetRef ref, {
  required String postId,
  required String? spaceId,
  required CheckInMarkKind kind,
}) async {
  final marker = ref.read(checkInMarkerProvider);
  if (marker == null) return false;
  final l10n = AppLocalizations.of(context);
  final time = BvTime.of(context);
  var share = marker.accepted;
  if (!share) {
    final answer = await showCheckInWarning(context, kind: kind);
    if (answer == null || !context.mounted) return false;
    share = answer == CheckInConsent.accept;
    // Accept: the phone asks its own permission next, once.
    if (share) await marker.accept();
  }
  final zone = spaceId == null
      ? null
      : ref.read(spaceDetailProvider(spaceId)).value?.timeZone;
  try {
    final result = await marker.mark(postId, kind, share: share);
    if (context.mounted) {
      showSpaceMessage(context, checkInResultText(l10n, time, zone, result));
    }
    return true;
  } on SpaceException catch (e) {
    if (context.mounted) {
      showSpaceMessage(context, checkInRefusalText(l10n, CheckInRefusal.of(e)));
    }
    return false;
  } finally {
    ref.invalidate(daybookCardsProvider);
  }
}

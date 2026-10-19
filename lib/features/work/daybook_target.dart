import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';

/// The card a Space's daybook opens at (F20): a work item, and the line of
/// its history an event is about.
@immutable
class DaybookTarget {
  const DaybookTarget(this.postId, {this.eventId});

  /// From the Space route's query (`?card=<post>&event=<event>`).
  static DaybookTarget? fromQuery(Map<String, String> query) {
    final card = query[AppRoutes.spaceCardParam];
    if (card == null || card.isEmpty) return null;
    final event = query[AppRoutes.spaceEventParam];
    return DaybookTarget(
      card,
      eventId: event == null || event.isEmpty ? null : event,
    );
  }

  /// The work item's id (its post's).
  final String postId;
  final String? eventId;

  @override
  bool operator ==(Object other) =>
      other is DaybookTarget &&
      other.postId == postId &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(postId, eventId);
}

/// Opens a work item where it lives: its Space's daybook, at its card,
/// highlighted, with its history open at [eventId]'s line. The one way an
/// Activity row, a Needs you card and a push (through the same route,
/// [AppRoutes.spaceCard]) open a work item (F20).
void openWorkCard(
  BuildContext context, {
  required String spaceId,
  required String postId,
  String? eventId,
}) {
  context.push(AppRoutes.spaceCard(spaceId, postId, eventId: eventId));
}

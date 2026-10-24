import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// F105: every way into a chat opens it the same way, so Back always
/// lands in the same place: from a Space thread on that Space's Chat tab,
/// from a direct message on Messages, and then where the person came
/// from.
///
/// Two pushes in a row are applied in the same frame (go_router reads its
/// routes synchronously), so only the thread slides in.

/// A Space thread, at [message] when given; [extra] is Share in chat's
/// file (F77). On the Space already, only the thread opens over it;
/// anywhere else the Space opens on its Chat tab under the thread.
Future<void> openSpaceThread(
  GoRouter router,
  String spaceId,
  String threadId, {
  String? message,
  Object? extra,
}) {
  if (router.state.matchedLocation != AppRoutes.space(spaceId)) {
    router.push(AppRoutes.spaceChat(spaceId));
  }
  return router.push(
    AppRoutes.spaceThread(spaceId, threadId, message: message),
    extra: extra,
  );
}

/// A direct message [location]: a thread (`/messages/<thread>`) or a new
/// conversation with a person (`/messages/with/<person>`). It opens over
/// Messages, which opens first unless it is the page underneath; from New
/// message it takes that search's place.
Future<void> openDmThread(GoRouter router, String location, {Object? extra}) {
  switch (router.state.matchedLocation) {
    case AppRoutes.messages:
      break;
    case AppRoutes.messagesNew:
      return router.pushReplacement(location, extra: extra);
    default:
      router.push(AppRoutes.messages);
  }
  return router.push(location, extra: extra);
}

/// A route the app was handed (a notification, the message banner): a
/// chat opens as above, anything else over the page showing.
Future<void> openRoute(GoRouter router, String route, {Object? extra}) {
  final uri = Uri.parse(route);
  final space = RegExp(r'^/spaces/([^/]+)/chat/([^/]+)$').firstMatch(uri.path);
  if (space != null) {
    return openSpaceThread(
      router,
      space.group(1)!,
      space.group(2)!,
      message: uri.queryParameters[AppRoutes.threadMessageParam],
      extra: extra,
    );
  }
  final dm = RegExp(r'^/messages/(with/)?([^/]+)$').firstMatch(uri.path);
  if (dm != null &&
      uri.path != AppRoutes.messagesNew &&
      uri.path != AppRoutes.messagesRequests) {
    return openDmThread(router, route, extra: extra);
  }
  return router.push(route, extra: extra);
}

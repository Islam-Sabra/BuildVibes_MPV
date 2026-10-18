import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feed/feed_state.dart';
import 'work_outbox.dart';

/// Sends what waits on the phone when the app opens signed in: a work
/// item, sign-off or Home post made with no signal, and a check or cancel
/// whose undo bar was cut short by closing the app (review 44, answer 4).
class OutboxHost extends ConsumerStatefulWidget {
  const OutboxHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OutboxHost> createState() => _OutboxHostState();
}

class _OutboxHostState extends ConsumerState<OutboxHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(workOutboxProvider.notifier).flushAll());
        unawaited(ref.read(postOutboxProvider.notifier).flushAll());
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

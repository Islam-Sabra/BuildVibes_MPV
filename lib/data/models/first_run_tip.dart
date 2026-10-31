/// The first-run tips in Work (review 107 OB7), in the order they show.
/// Each is kept as seen per account, on the server (profile_tips_seen).
enum FirstRunTip {
  /// "Tap the camera to post a photo of your work."
  camera('camera'),

  /// "Hold a card to share or delete it."
  hold('hold'),

  /// "Sign as done when your work is finished": the first time an item is
  /// given to me.
  signDone('sign_done');

  const FirstRunTip(this.json);

  final String json;

  static FirstRunTip? fromJson(Object? value) =>
      values.where((t) => t.json == value).firstOrNull;
}

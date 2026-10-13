import '../../l10n/gen/app_localizations.dart';

/// A person in a Space record (a message, work item, event or file) whose
/// profile can't be read any more: their account is hidden for deletion,
/// or gone. The record stays, by "Former member" (review 26).
String personName(AppLocalizations l10n, String? name) =>
    name == null || name.trim().isEmpty ? l10n.formerMember : name;

/// The first name, or "Former member" in full.
String personFirstName(AppLocalizations l10n, String? name) =>
    name == null || name.trim().isEmpty
    ? l10n.formerMember
    : name.trim().split(' ').first;

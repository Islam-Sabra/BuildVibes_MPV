import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_pass_card.dart';

/// "Lead" / "مسؤول".
String passName(AppLocalizations l10n, SpacePass pass) => switch (pass) {
  SpacePass.lead => l10n.spacesPassLead,
  SpacePass.crew => l10n.spacesPassCrew,
  SpacePass.viewer => l10n.spacesPassViewer,
};

/// "CREW PASS", the stamp text.
String passStamp(AppLocalizations l10n, SpacePass pass) => switch (pass) {
  SpacePass.lead => l10n.passLead,
  SpacePass.crew => l10n.passCrew,
  SpacePass.viewer => l10n.passViewer,
};

BvPassKind passKind(SpacePass pass) => switch (pass) {
  SpacePass.lead => BvPassKind.lead,
  SpacePass.crew => BvPassKind.crew,
  SpacePass.viewer => BvPassKind.viewer,
};

/// The "Opens: …" line of a pass card. Words only: what each pass opens is
/// decided on the server.
String passOpens(AppLocalizations l10n, SpacePass pass) => switch (pass) {
  SpacePass.lead => l10n.spacesLeadOpens,
  SpacePass.crew => l10n.spacesCrewOpens,
  SpacePass.viewer => l10n.spacesViewerOpens,
};

String passFor(AppLocalizations l10n, SpacePass pass) => switch (pass) {
  SpacePass.lead => l10n.spacesLeadFor,
  SpacePass.crew => l10n.spacesCrewFor,
  SpacePass.viewer => l10n.spacesViewerFor,
};

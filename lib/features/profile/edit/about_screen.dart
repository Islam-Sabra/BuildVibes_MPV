import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../entry/widgets/entry_scaffold.dart';
import 'edit_common.dart';

/// About: a few lines, in the person's own words.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  static const maxLength = 600;

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final _about = TextEditingController();
  var _filled = false;
  var _saving = false;

  @override
  void dispose() {
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final me = myId(ref);
    if (me == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(profilePageRepositoryProvider).saveAbout(me, _about.text);
      if (!mounted) return;
      afterSave(context, ref);
      context.pop();
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = myId(ref);
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;
    if (p != null && !_filled) {
      _filled = true;
      _about.text = p.about ?? '';
    }
    return EntryScaffold(
      title: l10n.profileAbout,
      footer: BvButton(
        key: const Key('about-save'),
        label: l10n.save,
        expand: true,
        onPressed: _saving ? null : _save,
      ),
      body: BvTextField(
        key: const Key('about-field'),
        controller: _about,
        placeholder: l10n.aboutHint,
        maxLines: 8,
        maxLength: AboutScreen.maxLength,
      ),
    );
  }
}

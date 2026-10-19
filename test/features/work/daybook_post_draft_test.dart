import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 15, 10, 30);

void main() {
  group('what each kind needs before Post sends (create_space_post)', () {
    test('a work item: a title of 2 or more, then someone to do it', () {
      const d = DaybookPostDraft(id: 'd', title: 'A');
      expect(d.readyToTry, isFalse);
      final titled = d.copyWith(title: 'Cable trays');
      expect(titled.readyToTry, isTrue);
      expect(titled.missing(_now), DaybookMissing.owner);
      expect(titled.copyWith(ownerId: 'p-omar').canPost(_now), isTrue);
    });

    test('a checklist: a title and a point with words, then its people', () {
      const d = DaybookPostDraft(
        id: 'd',
        kind: DaybookKind.checklist,
        title: 'Handover check',
        points: [(id: 'p1', text: '  ')],
      );
      // A blank line is not a point.
      expect(d.writtenPoints, isEmpty);
      expect(d.readyToTry, isFalse);
      final pointed = d.copyWith(points: [(id: 'p1', text: 'Doors')]);
      expect(pointed.readyToTry, isTrue);
      expect(pointed.missing(_now), DaybookMissing.people);
      expect(
        pointed.copyWith(people: [(id: 'p-sara', name: 'Sara')]).canPost(_now),
        isTrue,
      );
    });

    test('an announcement: a title of one letter is enough; no pin is '
        'fine', () {
      const d = DaybookPostDraft(
        id: 'd',
        kind: DaybookKind.announcement,
        title: 'X',
      );
      expect(d.canPost(_now), isTrue);
    });

    test('an activity: a start that has not come yet', () {
      const d = DaybookPostDraft(
        id: 'd',
        kind: DaybookKind.activity,
        title: 'Site walk',
      );
      expect(d.readyToTry, isTrue);
      expect(d.missing(_now), DaybookMissing.start);
      final past = d.copyWith(startsAt: () => _now);
      expect(past.missing(_now), DaybookMissing.start);
      final later = d.copyWith(
        startsAt: () => _now.add(const Duration(hours: 20)),
      );
      expect(later.canPost(_now), isTrue);
    });

    test('a file: the file; its title may stay empty (the file\'s name)', () {
      const d = DaybookPostDraft(id: 'd', kind: DaybookKind.file);
      expect(d.readyToTry, isFalse);
      final f = d.copyWith(
        files: const [
          DraftFile(
            libraryId: 'lf1',
            name: 'M-201.pdf',
            mime: 'application/pdf',
          ),
        ],
      );
      expect(f.canPost(_now), isTrue);
      // The title box takes the server's 200 for these kinds, 140 for a
      // work item.
      expect(f.titleLimit, DaybookPostDraft.postTitleMax);
      expect(
        const DaybookPostDraft(id: 'w').titleLimit,
        DaybookPostDraft.titleMax,
      );
    });
  });

  test('a draft keeps every kind\'s fields on the phone, and reads a '
      'slice 1 draft\'s one photo', () {
    final d = DaybookPostDraft(
      id: 'd',
      kind: DaybookKind.activity,
      title: 'Site walk',
      place: 'Gate office',
      people: const [(id: 'p-omar', name: 'Omar Haddad')],
      startsAt: DateTime(2026, 10, 16, 7),
      endsAt: DateTime(2026, 10, 16, 8),
      pinnedUntil: DateTime(2026, 10, 17),
      points: const [(id: 'p1', text: 'Doors')],
      photos: const ['a.jpg', 'b.jpg'],
      files: const [
        DraftFile(
          libraryId: 'lf2',
          name: 'M-201.pdf',
          mime: 'application/pdf',
          local: 'kept.pdf',
          supersedesId: 'lf1',
          supersedesRev: 'Rev C',
        ),
      ],
    );
    final back = DaybookPostDraft.fromJson(d.toJson());
    expect(back.kind, DaybookKind.activity);
    expect(back.people.single.name, 'Omar Haddad');
    expect(back.startsAt, DateTime(2026, 10, 16, 7));
    expect(back.endsAt, DateTime(2026, 10, 16, 8));
    expect(back.pinnedUntil, DateTime(2026, 10, 17));
    expect(back.points.single.text, 'Doors');
    expect(back.photos, ['a.jpg', 'b.jpg']);
    expect(back.files.single.supersedesId, 'lf1');
    expect(back.files.single.isNew, isTrue);
    final old = DaybookPostDraft.fromJson({
      'id': 'old',
      'title': 'Trays',
      'photo': 'kept.jpg',
    });
    expect(old.kind, DaybookKind.workItem);
    expect(old.photos, ['kept.jpg']);
  });

  test('a refused post of another kind comes back as the Draft it was', () {
    const draft = DaybookPostDraft(
      id: 'c1',
      kind: DaybookKind.checklist,
      title: 'Handover check',
      people: [(id: 'p-sara', name: 'Sara')],
      points: [(id: 'p1', text: 'Doors')],
    );
    final item = PendingItem(
      kind: PendingKind.post,
      id: 'c1',
      spaceId: 's',
      title: 'Handover check',
      ownerId: '',
      ownerName: '',
      draft: draft,
      photos: [PendingPhoto(local: 'kept.jpg', takenAt: _now)],
    );
    // Kept on the phone and read back, as the outbox does.
    final again = PendingItem.fromJson(item.toJson());
    final back = DaybookPostDraft.refused(again);
    expect(back.kind, DaybookKind.checklist);
    expect(back.points.single.text, 'Doors');
    expect(back.photos, ['kept.jpg']);
    expect(back.couldNotSend, isTrue);
  });
}

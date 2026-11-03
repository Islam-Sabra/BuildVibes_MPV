// Review 111, bug on build 987: two foreign keys join teams and
// team_members (team_members_team_id_fkey, and review 111's
// teams_admin_in_team_fkey), so PostgREST refuses an embed that doesn't
// name one (PGRST201, HTTP 300) and People showed "Something went wrong".
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Teams read names the members relationship', () {
    expect(
      teamsSelect,
      contains('members:team_members!team_members_team_id_fkey(profile_id)'),
    );
    expect(
      RegExp(r'team_members\(').hasMatch(teamsSelect),
      isFalse,
      reason: 'an embed without the relationship is ambiguous',
    );
  });
}

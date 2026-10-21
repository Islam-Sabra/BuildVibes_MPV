// The store reviewer's sign-in (review 69 §6, D4): only the build's
// reviewer email goes to the review-sign-in function.
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the reviewer email, in any case, uses the fixed code', () {
    expect(
      isReviewerEmail('Reviewer@Example.com ', 'reviewer@example.com'),
      isTrue,
    );
    expect(
      isReviewerEmail('omar@example.com', 'reviewer@example.com'),
      isFalse,
    );
  });

  test('no reviewer email in the build: everyone signs in by email code', () {
    expect(isReviewerEmail('reviewer@example.com', ''), isFalse);
    expect(isReviewerEmail('', ''), isFalse);
  });

  test('the function\'s answer, in the code screen\'s words', () {
    expect(reviewFailure(401), AuthFailure.wrongCode);
    expect(reviewFailure(429), AuthFailure.tooManyRequests);
    expect(reviewFailure(500), AuthFailure.unknown);
  });
}

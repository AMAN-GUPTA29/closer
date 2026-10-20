import 'package:closer/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalises like the server', () {
    expect(Validators.normalizeUsername('  @Alex.Kim '), 'alex.kim');
    expect(Validators.normalizeUsername('SAM_1'), 'sam_1');
  });

  test('accepts good usernames', () {
    for (final v in [
      'abc',
      'alex.kim',
      'sam_1',
      '@Mia_',
      'a1b2c3d4e5f6g7h8i9j0',
    ]) {
      expect(Validators.username(v), isNull, reason: v);
    }
  });

  test('rejects bad usernames with a reason', () {
    expect(Validators.username(''), 'Choose a username.');
    expect(Validators.username('ab'), contains('at least 3'));
    expect(Validators.username('a' * 21), contains('20'));
    expect(Validators.username('bad name'), contains('letters, numbers'));
    expect(Validators.username('émile'), contains('letters, numbers'));
    expect(Validators.username('.abc'), contains('Start with'));
    expect(Validators.username('abc.'), contains('Start with'));
    expect(Validators.username('a..b'), contains('two in a row'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ally_mobile_app/core/validation/uuid_validator.dart';
import 'support/fixtures.dart';

void main() {
  test('accepts UUID case, whitespace and supported variants', () {
    expect(UuidValidator.isValid(agentId), isTrue);
    expect(
      UuidValidator.isValid('  D41079C8-3976-4683-9424-E93BF191652B  '),
      isTrue,
    );
    expect(
      UuidValidator.isValid('11111111-1111-7111-b111-111111111111'),
      isTrue,
    );
  });
  test('rejects empty, truncated, non-hex, bad version and bad variant', () {
    for (final value in [
      '',
      'agent-123',
      agentId.substring(1),
      'z1111111-1111-4111-8111-111111111111',
      '11111111-1111-0111-8111-111111111111',
      '11111111-1111-4111-7111-111111111111',
    ]) {
      expect(UuidValidator.validate(value), isNotNull, reason: value);
    }
    expect(UuidValidator.validate(null), isNotNull);
  });
}

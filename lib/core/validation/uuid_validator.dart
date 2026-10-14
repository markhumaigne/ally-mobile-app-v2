abstract final class UuidValidator {
  // RFC UUID variants and versions 1–8, plus nil/max UUIDs, as accepted by
  // the backend's class-validator isUUID(value, 'all').
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValid(String value) {
    final id = value.trim().toLowerCase();
    return _uuid.hasMatch(id) ||
        id == '00000000-0000-0000-0000-000000000000' ||
        id == 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your Agent UUID.';
    if (!isValid(value)) {
      return 'Enter a valid UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).';
    }
    return null;
  }
}

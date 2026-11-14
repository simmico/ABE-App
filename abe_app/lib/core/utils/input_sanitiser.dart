/// Security and input sanitisation utilities for Aqeelah's Beauty Empire (ABE).
///
/// Enforces:
/// 1. XSS and HTML/script tag stripping on all user-supplied text.
/// 2. Zero em-dashes in user-facing or stored strings.
/// 3. Non-negative and positive numeric invariants for prices (ZAR), durations (minutes),
///    modifier fees, and store credits.
/// 4. Launch city validation (`CPT` or `JHB`).
abstract final class InputSanitiser {
  static final RegExp _scriptBlockPattern = RegExp(
    r'<\s*script[^>]*>.*?<\s*/\s*script\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _styleBlockPattern = RegExp(
    r'<\s*style[^>]*>.*?<\s*/\s*style\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _htmlTagPattern = RegExp(
    r'<[^>]*>',
    multiLine: true,
  );

  static final RegExp _inlineEventPattern = RegExp(
    r'\bon[a-z]+\s*=\s*("[^"]*"|' "'" r"[^']*'" r'|[^\s>]+)',
    caseSensitive: false,
  );

  static final RegExp _dangerousProtocolPattern = RegExp(
    r'(javascript|vbscript|data)\s*:',
    caseSensitive: false,
  );

  /// Strips HTML/script blocks, inline event handlers, dangerous URI schemes,
  /// and replaces any forbidden em-dashes with standard hyphens or spaces.
  static String sanitiseText(String rawInput, {int maxLength = 1000}) {
    var cleaned = rawInput
        .replaceAll(_scriptBlockPattern, '')
        .replaceAll(_styleBlockPattern, '')
        .replaceAll(_inlineEventPattern, '')
        .replaceAll(_htmlTagPattern, '')
        .replaceAll(_dangerousProtocolPattern, '')
        .replaceAll('\u2014', '-') // Zero em-dash rule
        .replaceAll('&lt;', '')
        .replaceAll('&gt;', '')
        .trim();

    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// Sanitises a promotional voucher code into uppercase alphanumeric characters and hyphens.
  static String sanitiseVoucherCode(String rawCode) {
    final cleaned = sanitiseText(rawCode, maxLength: 40)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
    if (cleaned.isEmpty) {
      throw ArgumentError.value(
        rawCode,
        'rawCode',
        'Voucher code cannot be empty after sanitisation.',
      );
    }
    return cleaned;
  }

  /// Validates and normalises a launch city code (`CPT` or `JHB`).
  static String validateCityCode(String rawCity) {
    final normalised = sanitiseText(rawCity, maxLength: 10).toUpperCase();
    if (normalised != 'CPT' && normalised != 'JHB') {
      throw ArgumentError.value(
        rawCity,
        'rawCity',
        'City must be either CPT (Cape Town) or JHB (Johannesburg).',
      );
    }
    return normalised;
  }

  /// Validates that an integer value (such as price in ZAR or duration in minutes)
  /// is strictly non-negative (`>= 0`) or strictly positive (`> 0`).
  static int requireNonNegativeInt(
    num value, {
    required String fieldName,
    bool strictlyPositive = false,
  }) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName must be a finite number.',
      );
    }
    final intVal = value.round();
    if (strictlyPositive && intVal <= 0) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName must be greater than zero.',
      );
    }
    if (!strictlyPositive && intVal < 0) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName cannot be negative.',
      );
    }
    return intVal;
  }

  /// Validates that a double value (such as ZAR credit or price) is non-negative.
  static double requireNonNegativeDouble(
    num value, {
    required String fieldName,
    bool strictlyPositive = false,
  }) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName must be a finite number.',
      );
    }
    final doubleVal = value.toDouble();
    if (strictlyPositive && doubleVal <= 0) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName must be greater than zero.',
      );
    }
    if (!strictlyPositive && doubleVal < 0) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName cannot be negative.',
      );
    }
    return doubleVal;
  }
}

class ColumnValidationRule {
  const ColumnValidationRule({
    required this.type,
    this.required = false,
    this.numberMin,
    this.numberMax,
    this.enumValues = const <String>[],
    this.regexPattern,
  });

  final String type;
  final bool required;
  final double? numberMin;
  final double? numberMax;
  final List<String> enumValues;
  final String? regexPattern;

  String? validate(
    String raw, {
    DateTime? Function(String value)? parseDate,
    double? Function(String value)? parseNumber,
  }) {
    final value = raw.trim();
    if (required && value.isEmpty) {
      return 'Campo requerido';
    }
    if (value.isEmpty) return null;

    switch (type) {
      case 'number':
        final parsed =
            parseNumber != null ? parseNumber(value) : _parseNumber(value);
        if (parsed == null) return 'Numero invalido';
        if (numberMin != null && parsed < numberMin!) {
          return 'Numero menor al minimo (${_fmtNumber(numberMin!)})';
        }
        if (numberMax != null && parsed > numberMax!) {
          return 'Numero mayor al maximo (${_fmtNumber(numberMax!)})';
        }
        break;
      case 'date':
        final parsed = parseDate != null ? parseDate(value) : _parseDate(value);
        if (parsed == null) return 'Fecha invalida (usa dd/MM/yyyy)';
        break;
      case 'status':
      case 'enum':
        if (enumValues.isNotEmpty) {
          final ok =
              enumValues.any((it) => it.toLowerCase() == value.toLowerCase());
          if (!ok) {
            return 'Valor no permitido. Opciones: ${enumValues.join(', ')}';
          }
        }
        break;
      default:
        break;
    }

    final regex = (regexPattern ?? '').trim();
    if (regex.isNotEmpty) {
      try {
        if (!RegExp(regex).hasMatch(value)) {
          return 'Formato invalido';
        }
      } catch (_) {
        return 'Regex invalida';
      }
    }

    return null;
  }

  static DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final slash = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(text);
    if (slash != null) {
      final d = int.tryParse(slash.group(1) ?? '');
      final m = int.tryParse(slash.group(2) ?? '');
      final y = int.tryParse(slash.group(3) ?? '');
      final hh = int.tryParse(slash.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(slash.group(5) ?? '0') ?? 0;
      if (y != null && m != null && d != null) {
        final date = DateTime(y, m, d, hh, mm);
        if (date.year == y && date.month == m && date.day == d) {
          return date;
        }
        return null;
      }
    }
    final iso = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(text);
    if (iso != null) {
      final y = int.tryParse(iso.group(1) ?? '');
      final m = int.tryParse(iso.group(2) ?? '');
      final d = int.tryParse(iso.group(3) ?? '');
      final hh = int.tryParse(iso.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(iso.group(5) ?? '0') ?? 0;
      if (y != null && m != null && d != null) {
        final date = DateTime(y, m, d, hh, mm);
        if (date.year == y && date.month == m && date.day == d) {
          return date;
        }
        return null;
      }
    }
    return DateTime.tryParse(text);
  }

  static double? _parseNumber(String raw) {
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static String _fmtNumber(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0000001) {
      return rounded.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

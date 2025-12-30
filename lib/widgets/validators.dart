class Validators {
  /// Heurística simple: detecta columnas numéricas por nombre o índice típico.
  static bool isNumericColumn(String header, int index) {
    final h = header.toLowerCase();
    if (h.contains('ω') ||
        h.contains('ohm') ||
        h.contains('resist') ||
        h.contains('@1m') ||
        h.contains('@3m')) return true;
    if (h.contains('1m') ||
        h.contains('3m') ||
        h.contains('valor') ||
        h.contains('número')) return true;
    // Por defecto, si el header está vacío, asumimos numérico en columnas 2/3 típicas.
    if (h.trim().isEmpty && (index == 2 || index == 3)) return true;
    return false;
  }
}

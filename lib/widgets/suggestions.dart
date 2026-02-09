/// Sugerencias simples al crear una fila nueva.
class Suggestions {
  /// Si existe 'Progresiva' incrementa el último valor numérico. Resetea demás.
  static List<dynamic>? suggestRow(
      List<List<dynamic>> rows, List<String> headers) {
    if (rows.isEmpty) return null;
    final last = rows.last;
    final out = List<dynamic>.filled(headers.length, '');
    final idxProg =
        headers.indexWhere((h) => h.toLowerCase().contains('progres'));
    if (idxProg >= 0 && idxProg < last.length) {
      final prev = _parseNum(last[idxProg]);
      out[idxProg] = (prev ?? 0) + 3; // Paso típico de progresiva.
    }
    // Copiamos fecha si existe.
    final idxFecha =
        headers.indexWhere((h) => h.toLowerCase().contains('fecha'));
    if (idxFecha >= 0 && idxFecha < last.length) {
      out[idxFecha] = last[idxFecha];
    }
    return out;
  }

  static num? _parseNum(dynamic v) {
    if (v == null) return null;
    return num.tryParse(v.toString().replaceAll(',', '.'));
  }
}

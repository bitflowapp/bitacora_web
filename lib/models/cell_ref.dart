// lib/models/cell_ref.dart
// Identificador estable de celda: sheetId + rowId + colId.

class CellRef {
  const CellRef({
    required this.sheetId,
    required this.rowId,
    required this.colId,
  });

  final String sheetId;
  final String rowId;
  final String colId;

  /// Key completo, estable y serializable.
  String get key => '$sheetId|$rowId|$colId';

  /// Key compacto (sin sheetId) para storage cuando el sheetId ya es contexto.
  String get compactKey => '$rowId|$colId';

  CellRef withSheet(String sheetId) =>
      CellRef(sheetId: sheetId, rowId: rowId, colId: colId);

  static CellRef? fromKey(String raw, {String? defaultSheetId}) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parts = t.split('|');
    if (parts.length == 3) {
      final sheetId = parts[0].trim();
      final rowId = parts[1].trim();
      final colId = parts[2].trim();
      if (sheetId.isEmpty || rowId.isEmpty || colId.isEmpty) return null;
      return CellRef(sheetId: sheetId, rowId: rowId, colId: colId);
    }
    if (parts.length == 2 && defaultSheetId != null) {
      final rowId = parts[0].trim();
      final colId = parts[1].trim();
      if (rowId.isEmpty || colId.isEmpty) return null;
      return CellRef(sheetId: defaultSheetId, rowId: rowId, colId: colId);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CellRef &&
      other.sheetId == sheetId &&
      other.rowId == rowId &&
      other.colId == colId;

  @override
  int get hashCode => Object.hash(sheetId, rowId, colId);

  @override
  String toString() => 'CellRef($sheetId|$rowId|$colId)';
}

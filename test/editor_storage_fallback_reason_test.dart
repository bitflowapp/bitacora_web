import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyEditorStorageFallbackReason', () {
    test('maps quota_exceeded to quota variants', () {
      final result = classifyEditorStorageFallbackReason('quota_exceeded');

      expect(result.storageVariant, 'quota_exceeded');
      expect(result.snackVariant, 'quota_exceeded');
    });

    test('maps storage_session_only to session variants', () {
      final result =
          classifyEditorStorageFallbackReason('storage_session_only');

      expect(result.storageVariant, 'storage_session_only');
      expect(result.snackVariant, 'storage_session_only');
    });

    test('maps storage_blocked to blocked variants', () {
      final result = classifyEditorStorageFallbackReason('storage_blocked');

      expect(result.storageVariant, 'storage_blocked');
      expect(result.snackVariant, 'storage_blocked');
    });

    test('normalizes reason code with whitespace/case', () {
      final result = classifyEditorStorageFallbackReason('  QuOtA_ExCeEdEd  ');

      expect(result.storageVariant, 'quota_exceeded');
      expect(result.snackVariant, 'quota_exceeded');
    });
  });
}

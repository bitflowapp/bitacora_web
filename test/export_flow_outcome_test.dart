import 'package:bitacora_web/services/export_flow_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyExportFlowOutcome', () {
    test('treats user cancel as cancelled', () {
      final outcome = classifyExportFlowOutcome(
        Exception('Share cancelled by user'),
      );

      expect(outcome, ExportFlowOutcome.cancelled);
    });

    test('treats unsupported platform as unsupported', () {
      final outcome = classifyExportFlowOutcome(
        UnsupportedError('share not supported'),
      );

      expect(outcome, ExportFlowOutcome.unsupported);
    });

    test('treats backup export picker cancel as cancelled', () {
      final outcome = classifyExportFlowOutcome(
        Exception('backup_zip save dialog canceled'),
      );

      expect(outcome, ExportFlowOutcome.cancelled);
    });

    test('treats image picker no image selected as cancelled', () {
      final outcome = classifyExportFlowOutcome(Exception('No image selected'));

      expect(outcome, ExportFlowOutcome.cancelled);
    });

    test('treats image picker selection cancelled string as cancelled', () {
      final outcome = classifyExportFlowOutcome(
        Exception('image selection cancelled'),
      );

      expect(outcome, ExportFlowOutcome.cancelled);
    });

    test('treats audio picker selection cancelled string as cancelled', () {
      final outcome = classifyExportFlowOutcome(
        Exception('audio selection cancelled'),
      );

      expect(outcome, ExportFlowOutcome.cancelled);
    });

    test('treats html export unsupported string as unsupported', () {
      final outcome = classifyExportFlowOutcome(
        Exception('export_html unsupported platform'),
      );

      expect(outcome, ExportFlowOutcome.unsupported);
    });

    test('cancelled and unsupported helpers stay mutually exclusive', () {
      final cancelled = Exception('share canceled by user');
      final unsupported = UnsupportedError('backup_zip unsupported');

      expect(isExportFlowCancelled(cancelled), isTrue);
      expect(isExportFlowUnsupported(cancelled), isFalse);
      expect(isExportFlowUnsupported(unsupported), isTrue);
      expect(isExportFlowCancelled(unsupported), isFalse);
    });

    test('cancel markers win even with success-like wording in message', () {
      final outcome = classifyExportFlowOutcome(
        Exception('share success callback but user canceled sheet'),
      );

      expect(outcome, ExportFlowOutcome.cancelled);
      expect(outcome, isNot(ExportFlowOutcome.failed));
    });
  });
}

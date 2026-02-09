import 'package:bitacora_web/services/attachment_pipeline.dart';
import 'package:bitacora_web/services/diagnostics_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DiagnosticsLog.I.debugResetAttachmentTraces();
  });

  test('photo normalize failure does not abort persistence', () async {
    var persisted = false;
    var bound = false;

    final result = await AttachmentPipeline().run<String>(
      AttachmentPipelineRequest<String>(
        kind: AttachmentKind.photo,
        source: AttachmentSource.gallery,
        cellRef: 'sheet:r1:c1',
        pick: () => 'raw-bytes',
        normalize: (_) => throw Exception('decoder_failed: heic decode'),
        persist: (value) async {
          expect(value, 'raw-bytes');
          persisted = true;
          return 'mem:test-photo';
        },
        bindToCell: (_, __) async {
          bound = true;
        },
      ),
    );

    expect(result.ok, isTrue);
    expect(persisted, isTrue);
    expect(bound, isTrue);
  });

  test('storage failure is classified with storage_blocked reason', () async {
    final result = await AttachmentPipeline().run<String>(
      AttachmentPipelineRequest<String>(
        kind: AttachmentKind.doc,
        source: AttachmentSource.files,
        cellRef: 'sheet:r2:c3',
        pick: () => 'file-bytes',
        persist: (_) async {
          throw Exception('storage_blocked: indexeddb write failed');
        },
        bindToCell: (_, __) async {},
      ),
    );

    expect(result.ok, isFalse);
    expect(result.failure, isNotNull);
    expect(result.failure!.error.code, 'storage_blocked');
  });

  test('pipeline traces keep deterministic step ordering', () async {
    final result = await AttachmentPipeline().run<String>(
      AttachmentPipelineRequest<String>(
        kind: AttachmentKind.audio,
        source: AttachmentSource.record,
        cellRef: 'sheet:r3:c2',
        pick: () => 'audio-bytes',
        persist: (_) async => 'mem:test-audio',
        bindToCell: (_, __) async {},
      ),
    );

    expect(result.ok, isTrue);

    final traces = DiagnosticsLog.I.recentAttachmentTraces(limit: 20);
    expect(traces, isNotEmpty);
    final steps = traces.map((e) => e.step).toList(growable: false);
    expect(
      steps,
      containsAllInOrder(<AttachmentPipelineStep>[
        AttachmentPipelineStep.capability,
        AttachmentPipelineStep.pick,
        AttachmentPipelineStep.normalize,
        AttachmentPipelineStep.persist,
        AttachmentPipelineStep.bind,
        AttachmentPipelineStep.preview,
      ]),
    );
  });
}

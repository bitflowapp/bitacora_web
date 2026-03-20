import 'package:bitacora_web/features/editor/export/editor_export_result_controller.dart';
import 'package:bitacora_web/features/editor/export/editor_export_result_mapper.dart';
import 'package:bitacora_web/features/editor/export/editor_export_result_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publish stores mapped state and emits feedback once', () {
    EditorExportCloseoutState? currentState;
    String? feedbackMessage;
    bool? feedbackIsError;
    IconData? feedbackIcon;

    final controller = EditorExportResultController(
      mapper: const EditorExportResultMapper(),
      onStateChanged: (state) => currentState = state,
      showFeedback: (message, {required isError, icon}) {
        feedbackMessage = message;
        feedbackIsError = isError;
        feedbackIcon = icon;
      },
      retryExport: ({
        required String format,
        required bool includeAttachments,
        required bool share,
      }) async {},
      openExternalPath: (_) async => true,
      closeEditor: () async {},
      resolveCapabilities: (_) => const EditorExportResultCapabilities(),
    );

    final outcome = EditorExportOutcomeFactory.shareOpened(
      name: 'control_diario.pdf',
      includeAttachments: true,
    );

    controller.publish(outcome);

    expect(currentState?.outcome.kind, EditorExportOutcomeKind.shareOpened);
    expect(currentState?.banner.title, 'Compartir abierto');
    expect(feedbackMessage, outcome.message);
    expect(feedbackIsError, isFalse);
    expect(feedbackIcon, Icons.ios_share_rounded);
  });

  test('retryShare dismisses current state and dispatches share export',
      () async {
    EditorExportCloseoutState? currentState;
    ({String format, bool includeAttachments, bool share})? retryRequest;

    final controller = EditorExportResultController(
      mapper: const EditorExportResultMapper(),
      onStateChanged: (state) => currentState = state,
      showFeedback: (message, {required isError, icon}) {},
      retryExport: ({
        required String format,
        required bool includeAttachments,
        required bool share,
      }) async {
        retryRequest = (
          format: format,
          includeAttachments: includeAttachments,
          share: share,
        );
      },
      openExternalPath: (_) async => true,
      closeEditor: () async {},
      resolveCapabilities: (_) => const EditorExportResultCapabilities(),
    );

    controller.publish(
      EditorExportOutcomeFactory.systemSheetOpened(
        name: 'control_diario.xlsx',
        includeAttachments: true,
      ),
      showSnack: false,
    );

    await controller.handleAction(EditorExportResultAction.retryShare);

    expect(currentState, isNull);
    expect(retryRequest?.format, 'xlsx');
    expect(retryRequest?.includeAttachments, isTrue);
    expect(retryRequest?.share, isTrue);
  });

  test('openLocation failure emits an honest error feedback', () async {
    EditorExportCloseoutState? currentState;
    final feedbackMessages = <String>[];
    final feedbackErrors = <bool>[];

    final controller = EditorExportResultController(
      mapper: const EditorExportResultMapper(),
      onStateChanged: (state) => currentState = state,
      showFeedback: (message, {required isError, icon}) {
        feedbackMessages.add(message);
        feedbackErrors.add(isError);
      },
      retryExport: ({
        required String format,
        required bool includeAttachments,
        required bool share,
      }) async {},
      openExternalPath: (_) async => false,
      closeEditor: () async {},
      resolveCapabilities: (_) => const EditorExportResultCapabilities(
        canOpenFile: true,
        canOpenLocation: true,
      ),
    );

    controller.publish(
      EditorExportOutcomeFactory.saved(
        name: 'control_diario.xlsx',
        shareRequested: false,
        includeAttachments: false,
        savedPath: '/tmp/cierre/control_diario.xlsx',
      ),
      showSnack: false,
    );

    await controller.handleAction(EditorExportResultAction.openLocation);

    expect(currentState?.outcome.kind, EditorExportOutcomeKind.saved);
    expect(feedbackMessages.last, 'No pudimos abrir la carpeta del archivo.');
    expect(feedbackErrors.last, isTrue);
  });

  test('dismiss clears the persistent closeout state', () {
    EditorExportCloseoutState? currentState;

    final controller = EditorExportResultController(
      mapper: const EditorExportResultMapper(),
      onStateChanged: (state) => currentState = state,
      showFeedback: (message, {required isError, icon}) {},
      retryExport: ({
        required String format,
        required bool includeAttachments,
        required bool share,
      }) async {},
      openExternalPath: (_) async => true,
      closeEditor: () async {},
      resolveCapabilities: (_) => const EditorExportResultCapabilities(),
    );

    controller.publish(
      EditorExportOutcomeFactory.downloadStarted(
        name: 'control_diario.xlsx',
        shareRequested: false,
        includeAttachments: false,
      ),
      showSnack: false,
    );
    expect(currentState, isNotNull);

    controller.dismiss();

    expect(currentState, isNull);
    expect(controller.state, isNull);
  });
}

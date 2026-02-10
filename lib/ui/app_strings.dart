import 'package:flutter/foundation.dart';

@immutable
class AppStrings {
  const AppStrings._();

  // Generic
  static const close = 'Cerrar';
  static const cancel = 'Cancelar';
  static const save = 'Guardar';
  static const delete = 'Eliminar';
  static const rename = 'Renombrar';
  static const open = 'Abrir';
  static const actions = 'Acciones';

  // Sheets
  static const sheetsTitle = 'BitFlow';
  static const sheetsSearchHint = 'Buscar por nombre o ID... (Ctrl/Cmd+K o /)';
  static const newSheet = 'Crear planilla';
  static const templates = 'Plantillas';
  static const openLast = 'Abrir ultima';
  static const clearSearch = 'Limpiar busqueda';
  static const emptySheetsTitle = 'Todavia no hay planillas';
  static const emptySheetsBody =
      'Crea tu primera planilla o arranca desde una plantilla para tus relevamientos.';
  static const noResultsTitle = 'Sin resultados';
  static const deletedSheetToast = 'Planilla eliminada';
  static const renameSheetTitle = 'Renombrar planilla';
  static const renameSheetNameLabel = 'Nombre';
  static const renameSheetNameHint = 'Ej: Relevamiento Pozo 12';
  static const deleteSheetTitle = 'Eliminar planilla';

  static String deleteSheetMessage(String title) {
    return 'Eliminar "$title"? Esta accion no se puede deshacer.';
  }

  static String noResultsBody(String query) {
    return 'No encontramos planillas para "$query".';
  }

  // Editor
  static const editorSheetNameHint = 'Nombre de planilla';
  static const editorSave = 'Guardar';
  static const editorSearch = 'Buscar';
  static const editorExport = 'Exportar';
  static const editorBatchActions = 'Acciones';
  static const editorDiagnostics = 'Diagnostico';
  static const editorCompute = 'Calcular';
  static const editorOptions = 'Opciones';
  static const editorDensity = 'Densidad';
  static const editorGpsMode = 'Modo GPS';
  static const editorShortcuts = 'Atajos';
  static const editorExportShare = 'Exportar / Compartir';
  static const editorExportXlsx = 'Exportar XLSX';
  static const editorExportZip = 'Exportar paquete (.bitflow.zip)';
  static const editorShareZip = 'Compartir paquete';
  static const editorBackupZip = 'Exportar backup legacy (ZIP)';
  static const editorReportHtml = 'Reporte HTML (imprimible)';
  static const progressSaving = 'Guardando cambios...';
  static const progressImportingBackup = 'Importando backup...';
  static const progressImportingAssets = 'Importando adjuntos...';
  static const progressExportingSheet = 'Exportando planilla...';
  static const progressPreparingExport = 'Preparando exportacion...';
  static const progressGeneratingFile = 'Generando archivo...';
  static const progressPackagingAssets = 'Empaquetando adjuntos...';
  static const progressWritingFile = 'Guardando archivo...';
  static const progressCancelling = 'Cancelando...';
  static const infoSaveInProgress = 'Guardado en curso...';
  static const infoOperationCancelling = 'Cancelando operacion...';
  static const infoExportCancelled = 'Exportacion cancelada.';
  static const infoImportCancelled = 'Importacion cancelada.';

  // Diagnostics / Support
  static const diagnosticsTitle = 'Diagnostico / Soporte';
  static const diagnosticsSummary = 'Resumen';
  static const diagnosticsReport = 'Informe';
  static const diagnosticsRecentErrors = 'Errores recientes';
  static const diagnosticsCopyReport = 'Copiar informe';
  static const diagnosticsExportReport = 'Exportar informe';
  static const diagnosticsNoRecentErrors = 'Sin errores recientes';
  static const diagnosticsVersionBuild = 'Version/Build';
  static const diagnosticsVersion = 'Version';
  static const diagnosticsBuildNumber = 'Build number';
  static const diagnosticsAppId = 'App ID';
  static const diagnosticsPlatform = 'Plataforma';
  static const diagnosticsLocale = 'Locale';
  static const diagnosticsRuntime = 'Runtime';
  static const diagnosticsTextScale = 'Text scale';
  static const diagnosticsErrorStorage = 'Persistencia errores';
  static const diagnosticsStorageMemoryFallback = 'memoria (fallback)';
  static const diagnosticsStorageLocal = 'local';
  static const diagnosticsReportCopied = 'Informe copiado al portapapeles.';
  static const diagnosticsReportCopyFailed = 'No se pudo copiar el informe.';
  static const diagnosticsExportSheetTitle = 'Exportar informe';
  static const diagnosticsExportTxtOption = 'TXT (.txt)';
  static const diagnosticsExportJsonOption = 'JSON (.json)';
  static const diagnosticsShareSaved = 'Informe compartido/guardado.';
  static const diagnosticsReportExportedPrefix = 'Informe exportado: ';
  static const diagnosticsShareUnavailableCopied =
      'Compartir no disponible. Informe copiado.';
  static const diagnosticsSaveUnavailableCopied =
      'No se pudo guardar. Informe copiado.';
  static const diagnosticsDetailsShow = 'Ver detalles';
  static const diagnosticsDetailsHide = 'Ocultar detalles';
  static const diagnosticsFlowLabel = 'Flujo';
  static const diagnosticsDateLabel = 'Fecha';

  // Accessibility labels
  static const semAddSheet = 'Crear nueva planilla';
  static const semTemplates = 'Abrir plantillas de planillas';
  static const semOpenLastSheet = 'Abrir ultima planilla editada';
  static const semToggleTheme = 'Cambiar tema';
  static const semOpenSheetActions = 'Abrir acciones de la planilla';
  static const semTogglePin = 'Fijar o desfijar planilla';
  static const semEditorExport = 'Exportar planilla';
  static const semEditorSave = 'Guardar planilla';
  static const semEditorSearch = 'Buscar en planilla';
  static const semEditorGps = 'Capturar ubicacion GPS';
  static const semEditorPhoto = 'Agregar foto';
  static const semEditorAudio = 'Grabar audio';
}

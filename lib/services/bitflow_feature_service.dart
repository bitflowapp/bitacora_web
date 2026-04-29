import 'package:flutter/foundation.dart';

import 'bitflow_product_models.dart';

class BitFlowFeatureService {
  BitFlowFeatureService._();

  static final BitFlowFeatureService I = BitFlowFeatureService._();

  static const Set<String> _basicFormulaFunctions = <String>{
    'SUM',
    'AVERAGE',
  };

  static const Set<String> _advancedFormulaFunctions = <String>{
    'IF',
    'ROUND',
    'MIN',
    'MAX',
    'COUNT',
    'DATE',
    'NOW',
  };

  final ValueNotifier<BitFlowEntitlement> entitlement =
      ValueNotifier<BitFlowEntitlement>(BitFlowEntitlement.free);

  bool _enforcementEnabled = false;

  bool get enforcementEnabled => _enforcementEnabled;
  BitFlowEntitlement get current => entitlement.value;

  Future<void> init({bool enforcePaidFeatures = false}) async {
    _enforcementEnabled = enforcePaidFeatures;
  }

  void updateEntitlement(BitFlowEntitlement next) {
    entitlement.value = next;
  }

  bool isEnabled(BitFlowFeature feature) {
    if (!_enforcementEnabled) return true;
    return current.has(feature);
  }

  bool canCreateSheet(int currentSheetCount) {
    if (!_enforcementEnabled) return true;
    final maxSheets = current.maxSheets;
    if (maxSheets == null) return true;
    return currentSheetCount < maxSheets;
  }

  String? creationLimitReason(int currentSheetCount) {
    if (canCreateSheet(currentSheetCount)) return null;
    final maxSheets = current.maxSheets ?? 0;
    return 'Free incluye hasta $maxSheets hojas. Actualiza a Pro para crear sin limite.';
  }

  String? featureBlockedReason(BitFlowFeature feature) {
    if (isEnabled(feature)) return null;
    switch (feature) {
      case BitFlowFeature.templates:
        return 'Templates es una capacidad Pro.';
      case BitFlowFeature.automationTools:
        return 'Automatizaciones inteligentes es una capacidad Pro.';
      case BitFlowFeature.sharing:
        return 'Compartir por link es una capacidad Pro.';
      case BitFlowFeature.advancedFormulas:
        return 'Formulas avanzadas son una capacidad Pro.';
      case BitFlowFeature.basicFormulas:
      case BitFlowFeature.exportXlsx:
        return null;
    }
  }

  bool isFormulaAllowed(String rawFormula) {
    if (!_enforcementEnabled) return true;
    final requiresPro = formulaRequiresPro(rawFormula);
    if (!requiresPro) return true;
    return current.has(BitFlowFeature.advancedFormulas);
  }

  bool formulaRequiresPro(String rawFormula) {
    final functions = extractFormulaFunctions(rawFormula);
    if (functions.isEmpty) return false;
    for (final fn in functions) {
      if (_advancedFormulaFunctions.contains(fn)) return true;
      if (!_basicFormulaFunctions.contains(fn)) return true;
    }
    return false;
  }

  String? formulaBlockedReason(String rawFormula) {
    if (isFormulaAllowed(rawFormula)) return null;
    final functions = extractFormulaFunctions(rawFormula).join(', ');
    if (functions.isEmpty) {
      return 'La formula requiere funciones Pro.';
    }
    return 'La formula usa funciones Pro: $functions.';
  }

  Set<String> extractFormulaFunctions(String rawFormula) {
    final matches = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(')
        .allMatches(rawFormula)
        .map((match) => (match.group(1) ?? '').trim().toUpperCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    return matches;
  }
}

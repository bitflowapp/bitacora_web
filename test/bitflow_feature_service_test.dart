import 'package:bitacora_web/services/bitflow_feature_service.dart';
import 'package:bitacora_web/services/bitflow_product_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitacora_web/services/runtime_flags.dart';

void main() {
  group('BitFlowFeatureService', () {
    setUp(() {
      RuntimeFlags.setMonetizationEnabledForTest(true);
    });

    tearDown(() {
      BitFlowFeatureService.I.updateEntitlement(BitFlowEntitlement.free);
      RuntimeFlags.resetMonetizationFlagForTest();
    });

    test('free tier enforces sheet limit and advanced formula lock', () async {
      await BitFlowFeatureService.I.init(enforcePaidFeatures: true);
      BitFlowFeatureService.I.updateEntitlement(BitFlowEntitlement.free);

      expect(BitFlowFeatureService.I.canCreateSheet(4), isTrue);
      expect(BitFlowFeatureService.I.canCreateSheet(5), isFalse);
      expect(BitFlowFeatureService.I.isFormulaAllowed('=SUM(A1:A3)'), isTrue);
      expect(
          BitFlowFeatureService.I.isFormulaAllowed('=IF(A1>0, 1, 0)'), isFalse);
      expect(
        BitFlowFeatureService.I.featureBlockedReason(BitFlowFeature.sharing),
        isNotNull,
      );
    });

    test('pro tier unlocks premium capabilities', () async {
      await BitFlowFeatureService.I.init(enforcePaidFeatures: true);
      BitFlowFeatureService.I.updateEntitlement(BitFlowEntitlement.pro);

      expect(BitFlowFeatureService.I.canCreateSheet(999), isTrue);
      expect(
          BitFlowFeatureService.I.isFormulaAllowed('=IF(A1>0, 1, 0)'), isTrue);
      expect(
        BitFlowFeatureService.I.isEnabled(BitFlowFeature.sharing),
        isTrue,
      );
      expect(
        BitFlowFeatureService.I.featureBlockedReason(BitFlowFeature.templates),
        isNull,
      );
    });

    test('free-only mode disables monetization gating globally', () async {
      RuntimeFlags.setMonetizationEnabledForTest(false);
      await BitFlowFeatureService.I.init(enforcePaidFeatures: true);
      BitFlowFeatureService.I.updateEntitlement(BitFlowEntitlement.free);

      expect(BitFlowFeatureService.I.enforcementEnabled, isFalse);
      expect(BitFlowFeatureService.I.canCreateSheet(999), isTrue);
      expect(
        BitFlowFeatureService.I.isEnabled(BitFlowFeature.sharing),
        isTrue,
      );
      expect(
        BitFlowFeatureService.I.featureBlockedReason(BitFlowFeature.templates),
        isNull,
      );
    });
  });
}

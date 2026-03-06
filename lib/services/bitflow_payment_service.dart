import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bitflow_product_models.dart';
import 'premium_config.dart';

class BitFlowPaymentService {
  BitFlowPaymentService._();

  static final BitFlowPaymentService I = BitFlowPaymentService._();

  static const String _stripeProMonthlyUrl = String.fromEnvironment(
    'STRIPE_PRO_MONTHLY_URL',
    defaultValue: '',
  );
  static const String _stripeProAnnualUrl = String.fromEnvironment(
    'STRIPE_PRO_ANNUAL_URL',
    defaultValue: '',
  );
  static const String _mercadoPagoProMonthlyUrl = String.fromEnvironment(
    'MERCADOPAGO_PRO_MONTHLY_URL',
    defaultValue: '',
  );
  static const String _mercadoPagoProAnnualUrl = String.fromEnvironment(
    'MERCADOPAGO_PRO_ANNUAL_URL',
    defaultValue: '',
  );

  String? checkoutUrl({
    required BitFlowPaymentProvider provider,
    required BitFlowPaymentPlan plan,
  }) {
    switch (provider) {
      case BitFlowPaymentProvider.stripe:
        switch (plan) {
          case BitFlowPaymentPlan.proMonthly:
            return _normalize(_stripeProMonthlyUrl);
          case BitFlowPaymentPlan.proAnnual:
            return _normalize(_stripeProAnnualUrl);
        }
      case BitFlowPaymentProvider.mercadoPago:
        switch (plan) {
          case BitFlowPaymentPlan.proMonthly:
            return _normalize(
              _mercadoPagoProMonthlyUrl.isNotEmpty
                  ? _mercadoPagoProMonthlyUrl
                  : PremiumConfig.proMonthlyUrl,
            );
          case BitFlowPaymentPlan.proAnnual:
            return _normalize(
              _mercadoPagoProAnnualUrl.isNotEmpty
                  ? _mercadoPagoProAnnualUrl
                  : PremiumConfig.proAnnualUrl,
            );
        }
    }
  }

  bool hasCheckout({
    required BitFlowPaymentProvider provider,
    required BitFlowPaymentPlan plan,
  }) {
    final url = checkoutUrl(provider: provider, plan: plan);
    return (url ?? '').isNotEmpty;
  }

  Future<bool> launchCheckout({
    required BitFlowPaymentProvider provider,
    required BitFlowPaymentPlan plan,
  }) async {
    final url = checkoutUrl(provider: provider, plan: plan);
    if ((url ?? '').isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(url!);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> handleCheckoutReturn(Uri uri) async {
    final status = _normalizedToken(
      uri.queryParameters['bitflow_payment'] ??
          uri.queryParameters['payment_status'] ??
          uri.queryParameters['status'],
    );
    if (status != 'success' && status != 'paid' && status != 'approved') {
      return false;
    }

    final provider = _parseProvider(
      uri.queryParameters['billing_provider'] ??
          uri.queryParameters['provider'],
    );
    final plan = _parsePlan(
      uri.queryParameters['billing_plan'] ?? uri.queryParameters['plan'],
    );
    if (provider == null || plan == null) {
      return false;
    }

    await markProActivated(
      provider: provider,
      plan: plan,
      status: status,
      paymentReference: (uri.queryParameters['payment_reference'] ??
              uri.queryParameters['ref'])
          ?.trim(),
    );
    return true;
  }

  Future<void> markProActivated({
    required BitFlowPaymentProvider provider,
    required BitFlowPaymentPlan plan,
    String status = 'paid',
    String? paymentReference,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('auth_required');
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'isPremium': true,
        'premiumSource': provider.name,
        'billingProvider': provider.name,
        'billingPlan': plan.name,
        'billingStatus': status,
        'paymentReference': paymentReference,
        'premiumActivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _normalize(String raw) {
    final trimmed = raw.trim();
    return trimmed;
  }

  BitFlowPaymentProvider? _parseProvider(String? raw) {
    final normalized = _normalizedToken(raw);
    switch (normalized) {
      case 'stripe':
        return BitFlowPaymentProvider.stripe;
      case 'mercadopago':
      case 'mercado-pago':
        return BitFlowPaymentProvider.mercadoPago;
      default:
        return null;
    }
  }

  BitFlowPaymentPlan? _parsePlan(String? raw) {
    final normalized = _normalizedToken(raw);
    switch (normalized) {
      case 'promonthly':
      case 'monthly':
      case 'pro-monthly':
        return BitFlowPaymentPlan.proMonthly;
      case 'proannual':
      case 'annual':
      case 'pro-annual':
        return BitFlowPaymentPlan.proAnnual;
      default:
        return null;
    }
  }

  String _normalizedToken(String? raw) {
    return (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '');
  }
}

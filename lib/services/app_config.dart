import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  const AppConfig({
    required this.brandName,
    required this.brandTagline,
    required this.contactEmail,
    required this.contactWhatsApp,
    required this.whatsappMessage,
    required this.pricingBasic,
    required this.pricingPro,
    required this.pricingEnterprise,
    required this.pricingNote,
  });

  final String brandName;
  final String brandTagline;
  final String contactEmail;
  final String contactWhatsApp;
  final String whatsappMessage;
  final String pricingBasic;
  final String pricingPro;
  final String pricingEnterprise;
  final String pricingNote;

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      brandName: (map['brandName'] ?? '').toString().trim(),
      brandTagline: (map['brandTagline'] ?? '').toString().trim(),
      contactEmail: (map['contactEmail'] ?? '').toString().trim(),
      contactWhatsApp: (map['contactWhatsApp'] ?? '').toString().trim(),
      whatsappMessage: (map['whatsappMessage'] ?? '').toString().trim(),
      pricingBasic: (map['pricingBasic'] ?? '').toString().trim(),
      pricingPro: (map['pricingPro'] ?? '').toString().trim(),
      pricingEnterprise: (map['pricingEnterprise'] ?? '').toString().trim(),
      pricingNote: (map['pricingNote'] ?? '').toString().trim(),
    );
  }

  AppConfig copyWith({
    String? brandName,
    String? brandTagline,
    String? contactEmail,
    String? contactWhatsApp,
    String? whatsappMessage,
    String? pricingBasic,
    String? pricingPro,
    String? pricingEnterprise,
    String? pricingNote,
  }) {
    return AppConfig(
      brandName: brandName ?? this.brandName,
      brandTagline: brandTagline ?? this.brandTagline,
      contactEmail: contactEmail ?? this.contactEmail,
      contactWhatsApp: contactWhatsApp ?? this.contactWhatsApp,
      whatsappMessage: whatsappMessage ?? this.whatsappMessage,
      pricingBasic: pricingBasic ?? this.pricingBasic,
      pricingPro: pricingPro ?? this.pricingPro,
      pricingEnterprise: pricingEnterprise ?? this.pricingEnterprise,
      pricingNote: pricingNote ?? this.pricingNote,
    );
  }

  static AppConfig defaults() {
    return const AppConfig(
      brandName: 'Bitácora Pro',
      brandTagline: 'Bitácora operativa con evidencias en 1 lugar.',
      contactEmail: '',
      contactWhatsApp: '+5491122334455',
      whatsappMessage: 'Hola! Quiero una demo de Bitácora Pro.',
      pricingBasic: 'USD 19 / mes',
      pricingPro: 'USD 49 / mes',
      pricingEnterprise: 'A medida',
      pricingNote:
          'Licencia local sin servidor. Soporte y actualizaciones opcionales.',
    );
  }

  static AppConfig envOverrides() {
    const brandName = String.fromEnvironment('BRAND_NAME', defaultValue: '');
    const brandTagline =
        String.fromEnvironment('BRAND_TAGLINE', defaultValue: '');
    const contactEmail =
        String.fromEnvironment('CONTACT_EMAIL', defaultValue: '');
    const contactWhatsApp =
        String.fromEnvironment('CONTACT_WHATSAPP', defaultValue: '');
    const whatsappMessage =
        String.fromEnvironment('WHATSAPP_MESSAGE', defaultValue: '');
    const pricingBasic =
        String.fromEnvironment('PRICING_BASIC', defaultValue: '');
    const pricingPro = String.fromEnvironment('PRICING_PRO', defaultValue: '');
    const pricingEnterprise =
        String.fromEnvironment('PRICING_ENTERPRISE', defaultValue: '');
    const pricingNote =
        String.fromEnvironment('PRICING_NOTE', defaultValue: '');

    return AppConfig(
      brandName: brandName,
      brandTagline: brandTagline,
      contactEmail: contactEmail,
      contactWhatsApp: contactWhatsApp,
      whatsappMessage: whatsappMessage,
      pricingBasic: pricingBasic,
      pricingPro: pricingPro,
      pricingEnterprise: pricingEnterprise,
      pricingNote: pricingNote,
    );
  }

  AppConfig applyOverrides(AppConfig overrides) {
    String pick(String base, String over) =>
        over.trim().isNotEmpty ? over : base;
    return AppConfig(
      brandName: pick(brandName, overrides.brandName),
      brandTagline: pick(brandTagline, overrides.brandTagline),
      contactEmail: pick(contactEmail, overrides.contactEmail),
      contactWhatsApp: pick(contactWhatsApp, overrides.contactWhatsApp),
      whatsappMessage: pick(whatsappMessage, overrides.whatsappMessage),
      pricingBasic: pick(pricingBasic, overrides.pricingBasic),
      pricingPro: pick(pricingPro, overrides.pricingPro),
      pricingEnterprise: pick(pricingEnterprise, overrides.pricingEnterprise),
      pricingNote: pick(pricingNote, overrides.pricingNote),
    );
  }

  static Future<AppConfig> load() async {
    Map<String, dynamic> data = {};

    if (kIsWeb) {
      try {
        final uri = Uri.base.resolve('config.json');
        final resp = await http.get(uri).timeout(const Duration(seconds: 2));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
          if (decoded is Map<String, dynamic>) data = decoded;
        }
      } catch (_) {}
    }

    if (data.isEmpty) {
      try {
        final raw = await rootBundle.loadString('assets/config.json');
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
    }

    final base = data.isEmpty
        ? defaults()
        : defaults().applyOverrides(
            AppConfig.fromMap(data),
          );
    return base.applyOverrides(envOverrides());
  }
}

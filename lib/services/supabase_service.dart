import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService I = SupabaseService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  bool _initialized = false;
  Object? _initError;

  bool get isConfigured => _url.trim().isNotEmpty && _anonKey.trim().isNotEmpty;
  bool get isInitialized => _initialized;
  Object? get initError => _initError;

  SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  User? get currentUser => client?.auth.currentUser;

  Future<void> init() async {
    if (_initialized || !isConfigured) return;
    try {
      await Supabase.initialize(
        url: _url.trim(),
        anonKey: _anonKey.trim(),
        debug: kDebugMode,
      );
      _initialized = true;
      _initError = null;
    } catch (e) {
      _initError = e;
      if (kDebugMode) {
        debugPrint('[supabase] init failed: $e');
      }
    }
  }
}

import '../services/supabase_service.dart';
import 'corporate_repository.dart';
import 'local_corporate_repository.dart';
import 'supabase_corporate_repository.dart';

CorporateRepository createCorporateRepository() {
  final client = SupabaseService.I.client;
  if (client != null) {
    return SupabaseCorporateRepository(client);
  }
  return const LocalCorporateRepository();
}

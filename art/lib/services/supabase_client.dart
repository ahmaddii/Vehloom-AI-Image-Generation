import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static SupabaseClient get client => Supabase.instance.client;
  
  static GoTrueClient get auth => client.auth;
  
  static SupabaseStorageClient get storage => client.storage;
}

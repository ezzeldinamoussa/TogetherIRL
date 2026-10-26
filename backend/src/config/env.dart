import 'package:dotenv/dotenv.dart';

class Env {
  static late DotEnv _env;

  static void load() {
    _env = DotEnv(includePlatformEnvironment: true)..load();
  }

  // Server
  static String get port => _env['PORT'] ?? '3000';

  // Supabase
  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');
  static String get supabaseServiceRoleKey => _required('SUPABASE_SERVICE_ROLE_KEY');

  // OCR
  static String get ocrSpaceApiKey => _required('OCR_SPACE_API_KEY');

  // Gemini
  static String get geminiApiKey => _required('GEMINI_API_KEY');

  /// Optional comma-separated list in .env, tried in order:
  /// GEMINI_MODELS=gemini-3.8-flash,gemini-3.7-flash
  static List<String>? get geminiModels {
    final raw = _env['GEMINI_MODELS'];
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
  }

  static String _required(String key) {
    final value = _env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env variable: $key\nCopy .env.example to .env and fill in your values.');
    }
    return value;
  }
}
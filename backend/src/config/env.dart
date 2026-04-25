import 'package:dotenv/dotenv.dart';

/// Loads and exposes all environment variables.
/// Access anywhere via: Env.supabaseUrl, Env.livekitKey, etc.
class Env {
  static late DotEnv _env;

  static void load() {
    _env = DotEnv(includePlatformEnvironment: true)..load();
  }

  static String get port => _env['PORT'] ?? '3000';
}

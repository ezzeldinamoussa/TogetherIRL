// Supabase project credentials.
// The anon key is safe to include in client code — it's the public key.
// Never put the service role key here.
class AppConfig {
  static const supabaseUrl = 'https://fnroykdoqjbnripyatum.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZucm95a2RvcWpibnJpcHlhdHVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0NjkyNDIsImV4cCI6MjA5NDA0NTI0Mn0.YjRWt6rkBkF9glJ6AWJ8FoPtKoNJXcxqDNwimUe0io8';

  // Base URL for the Dart backend server
  static const apiBaseUrl = 'http://localhost:3000';
}

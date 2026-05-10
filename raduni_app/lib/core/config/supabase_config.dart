class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dblkwbgkfrugetjlfrfb.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRibGt3YmdrZnJ1Z2V0amxmcmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxODE5OTgsImV4cCI6MjA5Mzc1Nzk5OH0.xEldtNGzTdIBH3mJGQbsEsrx7ATnLLYtm1wKNVEhxWo',
  );

  static bool get isValid => url.isNotEmpty && anonKey.isNotEmpty;
}

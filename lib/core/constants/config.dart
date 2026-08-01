import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration constants.
///
/// Supabase credentials are loaded from a gitignored `.env` file at runtime
/// (see [AppConfig.supabaseUrl] and [AppConfig.supabaseAnonKey]). Copy
/// `.env.example` to `.env` and fill in your values before running.
///
/// Note: the Supabase anon/publishable key is public by design — it ships in
/// the client binary. Data security relies on Supabase RLS / storage policies,
/// not on keeping the key secret.
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // Search — Algolia (search-only API key)
  // ──────────────────────────────────────────────
  static const String algoliaAppId = 'SLV39AYAB8';
  static const String algoliaApiKey = '349e79b533a91ad8b5c1790485696240';
  static const String algoliaUsersIndex = 'users_index';

  // ──────────────────────────────────────────────
  // Supabase (storage backend — free tier: 1 GB)
  // Loaded from the gitignored `.env` file (see `.env.example`).
  // ──────────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static const String storageBucket = 'vcroad';

  // ──────────────────────────────────────────────
  // App info
  // ──────────────────────────────────────────────
  static const String appName = 'VCRoad';
  static const String appVersion = 'v2.0.0';
}

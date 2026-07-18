/// App-wide configuration constants.
///
/// Move sensitive values to environment variables or Firebase Remote Config
/// before deploying to production.
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // Search — Algolia (search-only API key)
  // ──────────────────────────────────────────────
  static const String algoliaAppId = 'SLV39AYAB8';
  static const String algoliaApiKey = '349e79b533a91ad8b5c1790485696240';
  static const String algoliaUsersIndex = 'users_index';
}

/// Storage abstraction used by [ApiClient] to persist the auth token.
///
/// Mobile uses flutter_secure_storage; desktop can use a JSON file on disk.
/// Implementations are injected per app so the shared package has no Flutter
/// plugin dependency.
abstract class TokenStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

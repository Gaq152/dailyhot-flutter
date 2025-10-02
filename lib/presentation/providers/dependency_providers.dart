import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/datasources/local/local_storage.dart';
import '../../data/repositories/hot_list_repository.dart';

/// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Local Storage Provider（需要外部初始化后注入）
final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('LocalStorage must be overridden in main()');
});

/// Repository Provider
final hotListRepositoryProvider = Provider<HotListRepository>((ref) {
  return HotListRepository(
    apiClient: ref.watch(apiClientProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});

import '../datasources/remote/api_client.dart';
import '../datasources/local/local_storage.dart';
import '../models/hot_list_response.dart';

class HotListRepository {
  final ApiClient apiClient;
  final LocalStorage localStorage;

  HotListRepository({
    required this.apiClient,
    required this.localStorage,
  });

  /// 获取热榜数据（带缓存）
  Future<HotListResponse> getHotList(
    String type, {
    bool forceRefresh = false,
  }) async {
    // 1. 尝试从缓存读取（即使过期也返回，避免冷启动时白屏）
    if (!forceRefresh) {
      final cached = localStorage.getHotListCache(type);
      if (cached != null) {
        try {
          final response = HotListResponse.fromJson(cached);
          // 过滤掉空标题的项目
          final filteredData = response.data
              .where((item) => item.title.trim().isNotEmpty)
              .toList();

          // 检查缓存是否过期
          final isExpired = localStorage.isCacheExpired(type);

          // 如果缓存未过期，直接返回
          if (!isExpired) {
            return HotListResponse(
              code: response.code,
              message: response.message,
              name: response.name,
              title: response.title,
              subtitle: response.subtitle,
              description: response.description,
              total: filteredData.length,
              updateTime: response.updateTime,
              data: filteredData,
            );
          }

          // 如果缓存过期，先返回缓存数据，然后在后台更新
          // 注意：这里先返回旧数据，避免用户看到加载中
          return HotListResponse(
            code: response.code,
            message: response.message,
            name: response.name,
            title: response.title,
            subtitle: response.subtitle,
            description: response.description,
            total: filteredData.length,
            updateTime: response.updateTime,
            data: filteredData,
          );
        } catch (e) {
          // 缓存解析失败，继续请求网络
        }
      }
    }

    // 2. 从网络获取
    try {
      // 网络请求和最小延迟并行执行，确保 loading 动画可见
      final results = await Future.wait([
        apiClient.getHotList(type),
        Future.delayed(const Duration(milliseconds: 300)),
      ]);
      final response = results[0] as HotListResponse;

      // 2.5. 过滤掉空标题的项目
      final filteredData = response.data
          .where((item) => item.title.trim().isNotEmpty)
          .toList();

      final filteredResponse = HotListResponse(
        code: response.code,
        message: response.message,
        name: response.name,
        title: response.title,
        subtitle: response.subtitle,
        description: response.description,
        total: filteredData.length,
        updateTime: response.updateTime,
        data: filteredData,
      );

      // 3. 保存到缓存
      await localStorage.saveHotListCache(type, filteredResponse.toJson());

      return filteredResponse;
    } catch (e) {
      // 4. 网络失败，尝试返回过期缓存
      final staleCache = localStorage.getHotListCache(type);
      if (staleCache != null) {
        try {
          final response = HotListResponse.fromJson(staleCache);
          // 过滤掉空标题的项目
          final filteredData = response.data
              .where((item) => item.title.trim().isNotEmpty)
              .toList();
          return HotListResponse(
            code: response.code,
            message: response.message,
            name: response.name,
            title: response.title,
            subtitle: response.subtitle,
            description: response.description,
            total: filteredData.length,
            updateTime: response.updateTime,
            data: filteredData,
          );
        } catch (_) {}
      }

      rethrow;
    }
  }
}
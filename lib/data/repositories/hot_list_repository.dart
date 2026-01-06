import 'package:dio/dio.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/local/local_storage.dart';
import '../models/hot_list_response.dart';
import '../models/data_result.dart';

class HotListRepository {
  final ApiClient apiClient;
  final LocalStorage localStorage;

  HotListRepository({
    required this.apiClient,
    required this.localStorage,
  });

  /// 过滤空标题并创建新的响应对象
  HotListResponse _filterResponse(HotListResponse response) {
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
  }

  /// 将异常转换为错误类型
  DataErrorType _getErrorType(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return DataErrorType.timeoutError;
        case DioExceptionType.connectionError:
          return DataErrorType.networkError;
        case DioExceptionType.badResponse:
          return DataErrorType.serverError;
        default:
          return DataErrorType.networkError;
      }
    }
    if (error is FormatException || error.toString().contains('type')) {
      return DataErrorType.parseError;
    }
    return DataErrorType.unknownError;
  }

  /// 获取热榜数据（带缓存）
  /// 返回 DataResult，包含数据来源和错误信息
  Future<DataResult<HotListResponse>> getHotList(
    String type, {
    bool forceRefresh = false,
  }) async {
    // 1. 非强制刷新时，检查缓存
    if (!forceRefresh) {
      final cached = localStorage.getHotListCache(type);
      if (cached != null) {
        try {
          final response = HotListResponse.fromJson(cached);
          final filteredResponse = _filterResponse(response);
          final isExpired = localStorage.isCacheExpired(type);

          // 缓存未过期，直接返回
          if (!isExpired) {
            return DataResult.fromFreshCache(filteredResponse);
          }

          // 缓存已过期，尝试从网络获取新数据
          // 如果网络失败，会在 catch 中返回过期缓存
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
      final filteredResponse = _filterResponse(response);

      // 3. 保存到缓存
      await localStorage.saveHotListCache(type, filteredResponse.toJson());

      return DataResult.success(filteredResponse);
    } catch (e) {
      // 4. 网络失败，判断错误类型
      final errorType = _getErrorType(e);
      final errorMessage = e.toString();

      // 5. 尝试返回过期缓存（带错误标记）
      final staleCache = localStorage.getHotListCache(type);
      if (staleCache != null) {
        try {
          final response = HotListResponse.fromJson(staleCache);
          final filteredResponse = _filterResponse(response);

          // 返回过期缓存，但标记有错误发生
          return DataResult.fromStaleCache(
            filteredResponse,
            errorType: errorType,
            errorMessage: errorMessage,
          );
        } catch (_) {
          // 缓存解析也失败了
          return DataResult.failure(
            errorType: DataErrorType.parseError,
            errorMessage: '缓存数据损坏',
          );
        }
      }

      // 6. 完全失败：无网络且无缓存
      return DataResult.failure(
        errorType: errorType,
        errorMessage: errorMessage,
      );
    }
  }
}
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../models/hot_list_response.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 配置 HTTP 客户端
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();

      // 禁用证书验证（调试模式）
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) => true;
      }

      // 网络配置优化
      client.connectionTimeout = const Duration(seconds: 10);
      client.idleTimeout = const Duration(seconds: 15);

      // 不设置 findProxy，让它使用系统代理设置
      // 这样手机上的 VPN/Clash 代理就会自动生效

      return client;
    };

    // 添加重试拦截器（Deno Deploy 无冷启动，减少重试次数）
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          // 对于连接错误和超时错误，尝试重试
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.unknown) {
            // 最多重试2次（Deno Deploy 无冷启动，不需要太多重试）
            if (error.requestOptions.extra['retryCount'] == null) {
              error.requestOptions.extra['retryCount'] = 0;
            }

            final retryCount = error.requestOptions.extra['retryCount'] as int;
            if (retryCount < 2) {
              error.requestOptions.extra['retryCount'] = retryCount + 1;

              // 等待时间：1秒、2秒
              await Future.delayed(Duration(seconds: retryCount + 1));

              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (e) {
                // 重试失败，继续传递错误
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    // 添加拦截器（日志）- 仅在开发模式下显示详细日志
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) {
            // 限制日志长度，避免500错误时打印过多HTML
            final message = obj.toString();
            if (message.length > 500) {
              debugPrint('${message.substring(0, 500)}... (truncated)');
            } else {
              debugPrint(message);
            }
          },
        ),
      );
    }
  }

  /// 获取热榜数据
  /// [forceRefresh] 为 true 时，添加 cache=false 参数绕过 API 服务的 Redis 缓存
  Future<HotListResponse> getHotList(String type, {bool forceRefresh = false}) async {
    try {
      final queryParams = forceRefresh ? {'cache': 'false'} : null;
      final response = await _dio.get('/$type', queryParameters: queryParams);
      try {
        return HotListResponse.fromJson(response.data);
      } catch (e, stackTrace) {
        debugPrint('解析 $type 数据失败: $e');
        debugPrint('原始数据: ${response.data}');
        debugPrint('堆栈: $stackTrace');
        rethrow;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('网络请求超时，请检查网络连接');
      case DioExceptionType.badResponse:
        return Exception('服务器错误：${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('请求已取消');
      default:
        return Exception('网络错误：${error.message}');
    }
  }
}
/// 数据来源类型
enum DataSource {
  /// 来自网络（最新数据）
  network,

  /// 来自新鲜缓存（未过期）
  freshCache,

  /// 来自过期缓存（网络失败时的降级）
  staleCache,
}

/// 错误类型
enum DataErrorType {
  /// 无错误
  none,

  /// 网络连接错误
  networkError,

  /// 服务器错误
  serverError,

  /// 数据解析错误
  parseError,

  /// 超时错误
  timeoutError,

  /// 未知错误
  unknownError,
}

/// 数据结果封装类
/// 包含数据、来源、错误信息，让UI层能够感知数据状态
class DataResult<T> {
  /// 实际数据（可能为null，当完全失败时）
  final T? data;

  /// 数据来源
  final DataSource source;

  /// 错误类型
  final DataErrorType errorType;

  /// 错误消息（用于日志或调试）
  final String? errorMessage;

  /// 是否有数据可用
  bool get hasData => data != null;

  /// 是否来自缓存
  bool get isFromCache =>
      source == DataSource.freshCache || source == DataSource.staleCache;

  /// 是否使用了过期缓存（需要提示用户）
  bool get isStaleData => source == DataSource.staleCache;

  /// 是否有错误发生（但可能仍有缓存数据可用）
  bool get hasError => errorType != DataErrorType.none;

  /// 是否完全失败（无数据可用）
  bool get isFailed => !hasData && hasError;

  const DataResult({
    this.data,
    required this.source,
    this.errorType = DataErrorType.none,
    this.errorMessage,
  });

  /// 创建成功结果（来自网络）
  factory DataResult.success(T data) {
    return DataResult(
      data: data,
      source: DataSource.network,
    );
  }

  /// 创建新鲜缓存结果
  factory DataResult.fromFreshCache(T data) {
    return DataResult(
      data: data,
      source: DataSource.freshCache,
    );
  }

  /// 创建过期缓存结果（网络失败时的降级）
  factory DataResult.fromStaleCache(
    T data, {
    required DataErrorType errorType,
    String? errorMessage,
  }) {
    return DataResult(
      data: data,
      source: DataSource.staleCache,
      errorType: errorType,
      errorMessage: errorMessage,
    );
  }

  /// 创建失败结果（无数据可用）
  factory DataResult.failure({
    required DataErrorType errorType,
    String? errorMessage,
  }) {
    return DataResult(
      data: null,
      source: DataSource.network,
      errorType: errorType,
      errorMessage: errorMessage,
    );
  }

  /// 获取用户友好的错误提示消息
  String get userFriendlyMessage {
    switch (errorType) {
      case DataErrorType.none:
        return '';
      case DataErrorType.networkError:
        return '网络连接失败，显示的是缓存数据';
      case DataErrorType.serverError:
        return '服务器异常，显示的是缓存数据';
      case DataErrorType.parseError:
        return '数据解析失败，显示的是缓存数据';
      case DataErrorType.timeoutError:
        return '网络请求超时，显示的是缓存数据';
      case DataErrorType.unknownError:
        return '加载失败，显示的是缓存数据';
    }
  }

  /// 获取完全失败时的用户提示
  String get failureMessage {
    switch (errorType) {
      case DataErrorType.none:
        return '';
      case DataErrorType.networkError:
        return '网络连接失败，请检查网络设置';
      case DataErrorType.serverError:
        return '服务器暂时不可用，请稍后重试';
      case DataErrorType.parseError:
        return '数据格式异常，请稍后重试';
      case DataErrorType.timeoutError:
        return '网络请求超时，请稍后重试';
      case DataErrorType.unknownError:
        return '加载失败，请稍后重试';
    }
  }
}

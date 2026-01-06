import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/hot_list_response.dart';
import '../../data/models/data_result.dart';
import 'dependency_providers.dart';

/// 热榜数据请求参数
class HotListParams {
  final String type;
  final bool forceRefresh;

  const HotListParams({
    required this.type,
    this.forceRefresh = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HotListParams &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          forceRefresh == other.forceRefresh;

  @override
  int get hashCode => type.hashCode ^ forceRefresh.hashCode;
}

/// 热榜数据 Provider（使用 family 支持不同类型）
/// 返回 DataResult 包含数据、来源和错误信息
final hotListProvider = FutureProvider.family<DataResult<HotListResponse>, HotListParams>(
  (ref, params) async {
    final repository = ref.watch(hotListRepositoryProvider);
    final queueService = ref.watch(requestQueueServiceProvider);

    // 使用请求队列来控制并发数，避免首次启动时大量请求导致超时
    return queueService.enqueue(() {
      return repository.getHotList(params.type, forceRefresh: params.forceRefresh);
    });
  },
);

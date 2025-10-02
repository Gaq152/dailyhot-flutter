import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/hot_list_response.dart';
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
final hotListProvider = FutureProvider.family<HotListResponse, HotListParams>(
  (ref, params) async {
    final repository = ref.watch(hotListRepositoryProvider);
    return repository.getHotList(params.type, forceRefresh: params.forceRefresh);
  },
);

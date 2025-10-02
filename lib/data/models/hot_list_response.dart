import 'package:json_annotation/json_annotation.dart';
import 'hot_list_item.dart';

part 'hot_list_response.g.dart';

@JsonSerializable()
class HotListResponse {
  final int code;
  final String? message;
  final String name;
  final String title;
  final String? subtitle;
  final String? description;
  final int total;
  final String? updateTime;
  final List<HotListItem> data;

  HotListResponse({
    required this.code,
    this.message,
    required this.name,
    required this.title,
    this.subtitle,
    this.description,
    required this.total,
    this.updateTime,
    required this.data,
  });

  factory HotListResponse.fromJson(Map<String, dynamic> json) =>
      _$HotListResponseFromJson(json);

  Map<String, dynamic> toJson() {
    final json = _$HotListResponseToJson(this);
    // 确保 data 字段正确序列化为 JSON 列表
    json['data'] = data.map((item) => item.toJson()).toList();
    return json;
  }
}
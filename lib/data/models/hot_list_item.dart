import 'package:json_annotation/json_annotation.dart';
import '../../core/utils/html_utils.dart';

part 'hot_list_item.g.dart';

@JsonSerializable(createFactory: false)
class HotListItem {
  final String id;
  final String title;
  final String? desc;
  final String? cover;
  final String? author;
  final int? timestamp;
  final int? hot;
  final String url;
  final String? mobileUrl;

  HotListItem({
    required this.id,
    required this.title,
    this.desc,
    this.cover,
    this.author,
    this.timestamp,
    this.hot,
    required this.url,
    this.mobileUrl,
  });

  factory HotListItem.fromJson(Map<String, dynamic> json) {
    // 处理 id 字段可能是数字或字符串的情况
    final id = json['id'];
    final idString = id is String ? id : id.toString();

    // 安全获取 title，使用空字符串作为默认值，并清理 HTML 标签
    final rawTitle = json['title']?.toString() ?? '';
    final title = HtmlUtils.removeHtmlTags(rawTitle);

    // 安全获取 url，某些接口可能不返回url字段
    final url = json['url']?.toString() ?? json['mobileUrl']?.toString() ?? '';

    // 安全获取 desc，并清理 HTML 标签
    final rawDesc = json['desc']?.toString();
    final desc = rawDesc != null ? HtmlUtils.removeHtmlTags(rawDesc) : null;

    // 安全转换 timestamp
    int? timestamp;
    final timestampValue = json['timestamp'];
    if (timestampValue != null) {
      if (timestampValue is num) {
        timestamp = timestampValue.toInt();
      } else if (timestampValue is String) {
        timestamp = int.tryParse(timestampValue);
      }
    }

    // 安全转换 hot
    int? hot;
    final hotValue = json['hot'];
    if (hotValue != null) {
      if (hotValue is num) {
        hot = hotValue.toInt();
      } else if (hotValue is String) {
        hot = int.tryParse(hotValue);
      }
    }

    return HotListItem(
      id: idString,
      title: title,
      desc: desc,
      cover: json['cover']?.toString(),
      author: json['author']?.toString(),
      timestamp: timestamp,
      hot: hot,
      url: url,
      mobileUrl: json['mobileUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => _$HotListItemToJson(this);

  /// 格式化热度显示
  @JsonKey(includeToJson: false)
  String get hotText {
    if (hot == null) return '';
    if (hot! > 100000000) {
      return '${(hot! / 100000000).toStringAsFixed(1)}亿';
    } else if (hot! > 10000) {
      return '${(hot! / 10000).toStringAsFixed(1)}万';
    }
    return hot!.toString();
  }
}
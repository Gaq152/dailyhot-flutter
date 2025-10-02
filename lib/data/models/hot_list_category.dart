import 'package:json_annotation/json_annotation.dart';

part 'hot_list_category.g.dart';

@JsonSerializable()
class HotListCategory {
  final String name;
  final String label;
  final String icon;
  final int color;
  final int order;
  final bool show;

  HotListCategory({
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
    required this.order,
    this.show = true,
  });

  factory HotListCategory.fromJson(Map<String, dynamic> json) =>
      _$HotListCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$HotListCategoryToJson(this);

  HotListCategory copyWith({
    String? name,
    String? label,
    String? icon,
    int? color,
    int? order,
    bool? show,
  }) {
    return HotListCategory(
      name: name ?? this.name,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      show: show ?? this.show,
    );
  }
}
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hot_list_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotListCategory _$HotListCategoryFromJson(Map<String, dynamic> json) =>
    HotListCategory(
      name: json['name'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String,
      color: (json['color'] as num).toInt(),
      order: (json['order'] as num).toInt(),
      show: json['show'] as bool? ?? true,
    );

Map<String, dynamic> _$HotListCategoryToJson(HotListCategory instance) =>
    <String, dynamic>{
      'name': instance.name,
      'label': instance.label,
      'icon': instance.icon,
      'color': instance.color,
      'order': instance.order,
      'show': instance.show,
    };

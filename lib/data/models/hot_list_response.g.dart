// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hot_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotListResponse _$HotListResponseFromJson(Map<String, dynamic> json) =>
    HotListResponse(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String?,
      name: json['name'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      total: (json['total'] as num).toInt(),
      updateTime: json['updateTime'] as String?,
      data: (json['data'] as List<dynamic>)
          .map((e) => HotListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$HotListResponseToJson(HotListResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'name': instance.name,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'description': instance.description,
      'total': instance.total,
      'updateTime': instance.updateTime,
      'data': instance.data,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auto_rotate_config_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutoRotateConfigEntity {

 bool get isEnabled; AutoRotateSourceType get sourceType; String? get collectionName; String? get categoryName; aw.WallpaperTarget get target; int get intervalMinutes; bool get chargingTrigger; AutoRotateOrder get order;
/// Create a copy of AutoRotateConfigEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutoRotateConfigEntityCopyWith<AutoRotateConfigEntity> get copyWith => _$AutoRotateConfigEntityCopyWithImpl<AutoRotateConfigEntity>(this as AutoRotateConfigEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateConfigEntity&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.target, target) || other.target == target)&&(identical(other.intervalMinutes, intervalMinutes) || other.intervalMinutes == intervalMinutes)&&(identical(other.chargingTrigger, chargingTrigger) || other.chargingTrigger == chargingTrigger)&&(identical(other.order, order) || other.order == order));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,sourceType,collectionName,categoryName,target,intervalMinutes,chargingTrigger,order);

@override
String toString() {
  return 'AutoRotateConfigEntity(isEnabled: $isEnabled, sourceType: $sourceType, collectionName: $collectionName, categoryName: $categoryName, target: $target, intervalMinutes: $intervalMinutes, chargingTrigger: $chargingTrigger, order: $order)';
}


}

/// @nodoc
abstract mixin class $AutoRotateConfigEntityCopyWith<$Res>  {
  factory $AutoRotateConfigEntityCopyWith(AutoRotateConfigEntity value, $Res Function(AutoRotateConfigEntity) _then) = _$AutoRotateConfigEntityCopyWithImpl;
@useResult
$Res call({
 bool isEnabled, AutoRotateSourceType sourceType, String? collectionName, String? categoryName, aw.WallpaperTarget target, int intervalMinutes, bool chargingTrigger, AutoRotateOrder order
});




}
/// @nodoc
class _$AutoRotateConfigEntityCopyWithImpl<$Res>
    implements $AutoRotateConfigEntityCopyWith<$Res> {
  _$AutoRotateConfigEntityCopyWithImpl(this._self, this._then);

  final AutoRotateConfigEntity _self;
  final $Res Function(AutoRotateConfigEntity) _then;

/// Create a copy of AutoRotateConfigEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isEnabled = null,Object? sourceType = null,Object? collectionName = freezed,Object? categoryName = freezed,Object? target = null,Object? intervalMinutes = null,Object? chargingTrigger = null,Object? order = null,}) {
  return _then(_self.copyWith(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as AutoRotateSourceType,collectionName: freezed == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as aw.WallpaperTarget,intervalMinutes: null == intervalMinutes ? _self.intervalMinutes : intervalMinutes // ignore: cast_nullable_to_non_nullable
as int,chargingTrigger: null == chargingTrigger ? _self.chargingTrigger : chargingTrigger // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as AutoRotateOrder,
  ));
}

}


/// Adds pattern-matching-related methods to [AutoRotateConfigEntity].
extension AutoRotateConfigEntityPatterns on AutoRotateConfigEntity {
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutoRotateConfigEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutoRotateConfigEntity() when $default != null:
return $default(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutoRotateConfigEntity value)  $default,){
final _that = this;
switch (_that) {
case _AutoRotateConfigEntity():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutoRotateConfigEntity value)?  $default,){
final _that = this;
switch (_that) {
case _AutoRotateConfigEntity() when $default != null:
return $default(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isEnabled,  AutoRotateSourceType sourceType,  String? collectionName,  String? categoryName,  aw.WallpaperTarget target,  int intervalMinutes,  bool chargingTrigger,  AutoRotateOrder order)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutoRotateConfigEntity() when $default != null:
return $default(_that.isEnabled,_that.sourceType,_that.collectionName,_that.categoryName,_that.target,_that.intervalMinutes,_that.chargingTrigger,_that.order);case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isEnabled,  AutoRotateSourceType sourceType,  String? collectionName,  String? categoryName,  aw.WallpaperTarget target,  int intervalMinutes,  bool chargingTrigger,  AutoRotateOrder order)  $default,) {final _that = this;
switch (_that) {
case _AutoRotateConfigEntity():
return $default(_that.isEnabled,_that.sourceType,_that.collectionName,_that.categoryName,_that.target,_that.intervalMinutes,_that.chargingTrigger,_that.order);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isEnabled,  AutoRotateSourceType sourceType,  String? collectionName,  String? categoryName,  aw.WallpaperTarget target,  int intervalMinutes,  bool chargingTrigger,  AutoRotateOrder order)?  $default,) {final _that = this;
switch (_that) {
case _AutoRotateConfigEntity() when $default != null:
return $default(_that.isEnabled,_that.sourceType,_that.collectionName,_that.categoryName,_that.target,_that.intervalMinutes,_that.chargingTrigger,_that.order);case _:
  return null;

}
}

}

/// @nodoc


class _AutoRotateConfigEntity implements AutoRotateConfigEntity {
  const _AutoRotateConfigEntity({required this.isEnabled, required this.sourceType, this.collectionName, this.categoryName, required this.target, required this.intervalMinutes, required this.chargingTrigger, required this.order});


@override final  bool isEnabled;
@override final  AutoRotateSourceType sourceType;
@override final  String? collectionName;
@override final  String? categoryName;
@override final  aw.WallpaperTarget target;
@override final  int intervalMinutes;
@override final  bool chargingTrigger;
@override final  AutoRotateOrder order;

/// Create a copy of AutoRotateConfigEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutoRotateConfigEntityCopyWith<_AutoRotateConfigEntity> get copyWith => __$AutoRotateConfigEntityCopyWithImpl<_AutoRotateConfigEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutoRotateConfigEntity&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.target, target) || other.target == target)&&(identical(other.intervalMinutes, intervalMinutes) || other.intervalMinutes == intervalMinutes)&&(identical(other.chargingTrigger, chargingTrigger) || other.chargingTrigger == chargingTrigger)&&(identical(other.order, order) || other.order == order));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,sourceType,collectionName,categoryName,target,intervalMinutes,chargingTrigger,order);

@override
String toString() {
  return 'AutoRotateConfigEntity(isEnabled: $isEnabled, sourceType: $sourceType, collectionName: $collectionName, categoryName: $categoryName, target: $target, intervalMinutes: $intervalMinutes, chargingTrigger: $chargingTrigger, order: $order)';
}


}

/// @nodoc
abstract mixin class _$AutoRotateConfigEntityCopyWith<$Res> implements $AutoRotateConfigEntityCopyWith<$Res> {
  factory _$AutoRotateConfigEntityCopyWith(_AutoRotateConfigEntity value, $Res Function(_AutoRotateConfigEntity) _then) = __$AutoRotateConfigEntityCopyWithImpl;
@override @useResult
$Res call({
 bool isEnabled, AutoRotateSourceType sourceType, String? collectionName, String? categoryName, aw.WallpaperTarget target, int intervalMinutes, bool chargingTrigger, AutoRotateOrder order
});




}
/// @nodoc
class __$AutoRotateConfigEntityCopyWithImpl<$Res>
    implements _$AutoRotateConfigEntityCopyWith<$Res> {
  __$AutoRotateConfigEntityCopyWithImpl(this._self, this._then);

  final _AutoRotateConfigEntity _self;
  final $Res Function(_AutoRotateConfigEntity) _then;

/// Create a copy of AutoRotateConfigEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isEnabled = null,Object? sourceType = null,Object? collectionName = freezed,Object? categoryName = freezed,Object? target = null,Object? intervalMinutes = null,Object? chargingTrigger = null,Object? order = null,}) {
  return _then(_AutoRotateConfigEntity(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as AutoRotateSourceType,collectionName: freezed == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as aw.WallpaperTarget,intervalMinutes: null == intervalMinutes ? _self.intervalMinutes : intervalMinutes // ignore: cast_nullable_to_non_nullable
as int,chargingTrigger: null == chargingTrigger ? _self.chargingTrigger : chargingTrigger // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as AutoRotateOrder,
  ));
}


}

// dart format on

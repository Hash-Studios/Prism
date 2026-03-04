// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeedItemEntity {

 String get id; Object get wallpaper;
/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedItemEntityCopyWith<FeedItemEntity> get copyWith => _$FeedItemEntityCopyWithImpl<FeedItemEntity>(this as FeedItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedItemEntity&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.wallpaper, wallpaper));
}


@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(wallpaper));

@override
String toString() {
  return 'FeedItemEntity(id: $id, wallpaper: $wallpaper)';
}


}

/// @nodoc
abstract mixin class $FeedItemEntityCopyWith<$Res>  {
  factory $FeedItemEntityCopyWith(FeedItemEntity value, $Res Function(FeedItemEntity) _then) = _$FeedItemEntityCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$FeedItemEntityCopyWithImpl<$Res>
    implements $FeedItemEntityCopyWith<$Res> {
  _$FeedItemEntityCopyWithImpl(this._self, this._then);

  final FeedItemEntity _self;
  final $Res Function(FeedItemEntity) _then;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedItemEntity].
extension FeedItemEntityPatterns on FeedItemEntity {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PrismFeedItem value)?  prism,TResult Function( WallhavenFeedItem value)?  wallhaven,TResult Function( PexelsFeedItem value)?  pexels,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PrismFeedItem() when prism != null:
return prism(_that);case WallhavenFeedItem() when wallhaven != null:
return wallhaven(_that);case PexelsFeedItem() when pexels != null:
return pexels(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PrismFeedItem value)  prism,required TResult Function( WallhavenFeedItem value)  wallhaven,required TResult Function( PexelsFeedItem value)  pexels,}){
final _that = this;
switch (_that) {
case PrismFeedItem():
return prism(_that);case WallhavenFeedItem():
return wallhaven(_that);case PexelsFeedItem():
return pexels(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PrismFeedItem value)?  prism,TResult? Function( WallhavenFeedItem value)?  wallhaven,TResult? Function( PexelsFeedItem value)?  pexels,}){
final _that = this;
switch (_that) {
case PrismFeedItem() when prism != null:
return prism(_that);case WallhavenFeedItem() when wallhaven != null:
return wallhaven(_that);case PexelsFeedItem() when pexels != null:
return pexels(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  PrismWallpaper wallpaper)?  prism,TResult Function( String id,  WallhavenWallpaper wallpaper)?  wallhaven,TResult Function( String id,  PexelsWallpaper wallpaper)?  pexels,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PrismFeedItem() when prism != null:
return prism(_that.id,_that.wallpaper);case WallhavenFeedItem() when wallhaven != null:
return wallhaven(_that.id,_that.wallpaper);case PexelsFeedItem() when pexels != null:
return pexels(_that.id,_that.wallpaper);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  PrismWallpaper wallpaper)  prism,required TResult Function( String id,  WallhavenWallpaper wallpaper)  wallhaven,required TResult Function( String id,  PexelsWallpaper wallpaper)  pexels,}) {final _that = this;
switch (_that) {
case PrismFeedItem():
return prism(_that.id,_that.wallpaper);case WallhavenFeedItem():
return wallhaven(_that.id,_that.wallpaper);case PexelsFeedItem():
return pexels(_that.id,_that.wallpaper);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  PrismWallpaper wallpaper)?  prism,TResult? Function( String id,  WallhavenWallpaper wallpaper)?  wallhaven,TResult? Function( String id,  PexelsWallpaper wallpaper)?  pexels,}) {final _that = this;
switch (_that) {
case PrismFeedItem() when prism != null:
return prism(_that.id,_that.wallpaper);case WallhavenFeedItem() when wallhaven != null:
return wallhaven(_that.id,_that.wallpaper);case PexelsFeedItem() when pexels != null:
return pexels(_that.id,_that.wallpaper);case _:
  return null;

}
}

}

/// @nodoc


class PrismFeedItem extends FeedItemEntity {
  const PrismFeedItem({required this.id, required this.wallpaper}): super._();
  

@override final  String id;
@override final  PrismWallpaper wallpaper;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrismFeedItemCopyWith<PrismFeedItem> get copyWith => _$PrismFeedItemCopyWithImpl<PrismFeedItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrismFeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.wallpaper, wallpaper) || other.wallpaper == wallpaper));
}


@override
int get hashCode => Object.hash(runtimeType,id,wallpaper);

@override
String toString() {
  return 'FeedItemEntity.prism(id: $id, wallpaper: $wallpaper)';
}


}

/// @nodoc
abstract mixin class $PrismFeedItemCopyWith<$Res> implements $FeedItemEntityCopyWith<$Res> {
  factory $PrismFeedItemCopyWith(PrismFeedItem value, $Res Function(PrismFeedItem) _then) = _$PrismFeedItemCopyWithImpl;
@override @useResult
$Res call({
 String id, PrismWallpaper wallpaper
});




}
/// @nodoc
class _$PrismFeedItemCopyWithImpl<$Res>
    implements $PrismFeedItemCopyWith<$Res> {
  _$PrismFeedItemCopyWithImpl(this._self, this._then);

  final PrismFeedItem _self;
  final $Res Function(PrismFeedItem) _then;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? wallpaper = null,}) {
  return _then(PrismFeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallpaper: null == wallpaper ? _self.wallpaper : wallpaper // ignore: cast_nullable_to_non_nullable
as PrismWallpaper,
  ));
}


}

/// @nodoc


class WallhavenFeedItem extends FeedItemEntity {
  const WallhavenFeedItem({required this.id, required this.wallpaper}): super._();
  

@override final  String id;
@override final  WallhavenWallpaper wallpaper;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenFeedItemCopyWith<WallhavenFeedItem> get copyWith => _$WallhavenFeedItemCopyWithImpl<WallhavenFeedItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenFeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.wallpaper, wallpaper) || other.wallpaper == wallpaper));
}


@override
int get hashCode => Object.hash(runtimeType,id,wallpaper);

@override
String toString() {
  return 'FeedItemEntity.wallhaven(id: $id, wallpaper: $wallpaper)';
}


}

/// @nodoc
abstract mixin class $WallhavenFeedItemCopyWith<$Res> implements $FeedItemEntityCopyWith<$Res> {
  factory $WallhavenFeedItemCopyWith(WallhavenFeedItem value, $Res Function(WallhavenFeedItem) _then) = _$WallhavenFeedItemCopyWithImpl;
@override @useResult
$Res call({
 String id, WallhavenWallpaper wallpaper
});




}
/// @nodoc
class _$WallhavenFeedItemCopyWithImpl<$Res>
    implements $WallhavenFeedItemCopyWith<$Res> {
  _$WallhavenFeedItemCopyWithImpl(this._self, this._then);

  final WallhavenFeedItem _self;
  final $Res Function(WallhavenFeedItem) _then;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? wallpaper = null,}) {
  return _then(WallhavenFeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallpaper: null == wallpaper ? _self.wallpaper : wallpaper // ignore: cast_nullable_to_non_nullable
as WallhavenWallpaper,
  ));
}


}

/// @nodoc


class PexelsFeedItem extends FeedItemEntity {
  const PexelsFeedItem({required this.id, required this.wallpaper}): super._();
  

@override final  String id;
@override final  PexelsWallpaper wallpaper;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PexelsFeedItemCopyWith<PexelsFeedItem> get copyWith => _$PexelsFeedItemCopyWithImpl<PexelsFeedItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PexelsFeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.wallpaper, wallpaper) || other.wallpaper == wallpaper));
}


@override
int get hashCode => Object.hash(runtimeType,id,wallpaper);

@override
String toString() {
  return 'FeedItemEntity.pexels(id: $id, wallpaper: $wallpaper)';
}


}

/// @nodoc
abstract mixin class $PexelsFeedItemCopyWith<$Res> implements $FeedItemEntityCopyWith<$Res> {
  factory $PexelsFeedItemCopyWith(PexelsFeedItem value, $Res Function(PexelsFeedItem) _then) = _$PexelsFeedItemCopyWithImpl;
@override @useResult
$Res call({
 String id, PexelsWallpaper wallpaper
});




}
/// @nodoc
class _$PexelsFeedItemCopyWithImpl<$Res>
    implements $PexelsFeedItemCopyWith<$Res> {
  _$PexelsFeedItemCopyWithImpl(this._self, this._then);

  final PexelsFeedItem _self;
  final $Res Function(PexelsFeedItem) _then;

/// Create a copy of FeedItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? wallpaper = null,}) {
  return _then(PexelsFeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallpaper: null == wallpaper ? _self.wallpaper : wallpaper // ignore: cast_nullable_to_non_nullable
as PexelsWallpaper,
  ));
}


}

// dart format on

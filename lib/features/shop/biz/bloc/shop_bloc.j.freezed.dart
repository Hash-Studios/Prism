// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shop_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShopEvent implements DiagnosticableTreeMixin {




@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShopEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent()';
}


}

/// @nodoc
class $ShopEventCopyWith<$Res>  {
$ShopEventCopyWith(ShopEvent _, $Res Function(ShopEvent) __);
}


/// Adds pattern-matching-related methods to [ShopEvent].
extension ShopEventPatterns on ShopEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _KindChanged value)?  kindChanged,TResult Function( _Synced value)?  synced,TResult Function( _PurchaseRequested value)?  purchaseRequested,TResult Function( _EquipRequested value)?  equipRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _KindChanged() when kindChanged != null:
return kindChanged(_that);case _Synced() when synced != null:
return synced(_that);case _PurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that);case _EquipRequested() when equipRequested != null:
return equipRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _KindChanged value)  kindChanged,required TResult Function( _Synced value)  synced,required TResult Function( _PurchaseRequested value)  purchaseRequested,required TResult Function( _EquipRequested value)  equipRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _KindChanged():
return kindChanged(_that);case _Synced():
return synced(_that);case _PurchaseRequested():
return purchaseRequested(_that);case _EquipRequested():
return equipRequested(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _KindChanged value)?  kindChanged,TResult? Function( _Synced value)?  synced,TResult? Function( _PurchaseRequested value)?  purchaseRequested,TResult? Function( _EquipRequested value)?  equipRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _KindChanged() when kindChanged != null:
return kindChanged(_that);case _Synced() when synced != null:
return synced(_that);case _PurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that);case _EquipRequested() when equipRequested != null:
return equipRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( ShopItemKind kind)?  kindChanged,TResult Function()?  synced,TResult Function( String itemId)?  purchaseRequested,TResult Function( String itemId,  bool equip)?  equipRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _KindChanged() when kindChanged != null:
return kindChanged(_that.kind);case _Synced() when synced != null:
return synced();case _PurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that.itemId);case _EquipRequested() when equipRequested != null:
return equipRequested(_that.itemId,_that.equip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( ShopItemKind kind)  kindChanged,required TResult Function()  synced,required TResult Function( String itemId)  purchaseRequested,required TResult Function( String itemId,  bool equip)  equipRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _KindChanged():
return kindChanged(_that.kind);case _Synced():
return synced();case _PurchaseRequested():
return purchaseRequested(_that.itemId);case _EquipRequested():
return equipRequested(_that.itemId,_that.equip);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( ShopItemKind kind)?  kindChanged,TResult? Function()?  synced,TResult? Function( String itemId)?  purchaseRequested,TResult? Function( String itemId,  bool equip)?  equipRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _KindChanged() when kindChanged != null:
return kindChanged(_that.kind);case _Synced() when synced != null:
return synced();case _PurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that.itemId);case _EquipRequested() when equipRequested != null:
return equipRequested(_that.itemId,_that.equip);case _:
  return null;

}
}

}

/// @nodoc


class _Started with DiagnosticableTreeMixin implements ShopEvent {
  const _Started();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent.started'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent.started()';
}


}




/// @nodoc


class _KindChanged with DiagnosticableTreeMixin implements ShopEvent {
  const _KindChanged(this.kind);
  

 final  ShopItemKind kind;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KindChangedCopyWith<_KindChanged> get copyWith => __$KindChangedCopyWithImpl<_KindChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent.kindChanged'))
    ..add(DiagnosticsProperty('kind', kind));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KindChanged&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,kind);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent.kindChanged(kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$KindChangedCopyWith<$Res> implements $ShopEventCopyWith<$Res> {
  factory _$KindChangedCopyWith(_KindChanged value, $Res Function(_KindChanged) _then) = __$KindChangedCopyWithImpl;
@useResult
$Res call({
 ShopItemKind kind
});




}
/// @nodoc
class __$KindChangedCopyWithImpl<$Res>
    implements _$KindChangedCopyWith<$Res> {
  __$KindChangedCopyWithImpl(this._self, this._then);

  final _KindChanged _self;
  final $Res Function(_KindChanged) _then;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(_KindChanged(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShopItemKind,
  ));
}


}

/// @nodoc


class _Synced with DiagnosticableTreeMixin implements ShopEvent {
  const _Synced();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent.synced'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Synced);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent.synced()';
}


}




/// @nodoc


class _PurchaseRequested with DiagnosticableTreeMixin implements ShopEvent {
  const _PurchaseRequested(this.itemId);
  

 final  String itemId;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PurchaseRequestedCopyWith<_PurchaseRequested> get copyWith => __$PurchaseRequestedCopyWithImpl<_PurchaseRequested>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent.purchaseRequested'))
    ..add(DiagnosticsProperty('itemId', itemId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PurchaseRequested&&(identical(other.itemId, itemId) || other.itemId == itemId));
}


@override
int get hashCode => Object.hash(runtimeType,itemId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent.purchaseRequested(itemId: $itemId)';
}


}

/// @nodoc
abstract mixin class _$PurchaseRequestedCopyWith<$Res> implements $ShopEventCopyWith<$Res> {
  factory _$PurchaseRequestedCopyWith(_PurchaseRequested value, $Res Function(_PurchaseRequested) _then) = __$PurchaseRequestedCopyWithImpl;
@useResult
$Res call({
 String itemId
});




}
/// @nodoc
class __$PurchaseRequestedCopyWithImpl<$Res>
    implements _$PurchaseRequestedCopyWith<$Res> {
  __$PurchaseRequestedCopyWithImpl(this._self, this._then);

  final _PurchaseRequested _self;
  final $Res Function(_PurchaseRequested) _then;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? itemId = null,}) {
  return _then(_PurchaseRequested(
null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _EquipRequested with DiagnosticableTreeMixin implements ShopEvent {
  const _EquipRequested({required this.itemId, required this.equip});
  

 final  String itemId;
 final  bool equip;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EquipRequestedCopyWith<_EquipRequested> get copyWith => __$EquipRequestedCopyWithImpl<_EquipRequested>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopEvent.equipRequested'))
    ..add(DiagnosticsProperty('itemId', itemId))..add(DiagnosticsProperty('equip', equip));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EquipRequested&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.equip, equip) || other.equip == equip));
}


@override
int get hashCode => Object.hash(runtimeType,itemId,equip);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopEvent.equipRequested(itemId: $itemId, equip: $equip)';
}


}

/// @nodoc
abstract mixin class _$EquipRequestedCopyWith<$Res> implements $ShopEventCopyWith<$Res> {
  factory _$EquipRequestedCopyWith(_EquipRequested value, $Res Function(_EquipRequested) _then) = __$EquipRequestedCopyWithImpl;
@useResult
$Res call({
 String itemId, bool equip
});




}
/// @nodoc
class __$EquipRequestedCopyWithImpl<$Res>
    implements _$EquipRequestedCopyWith<$Res> {
  __$EquipRequestedCopyWithImpl(this._self, this._then);

  final _EquipRequested _self;
  final $Res Function(_EquipRequested) _then;

/// Create a copy of ShopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? itemId = null,Object? equip = null,}) {
  return _then(_EquipRequested(
itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,equip: null == equip ? _self.equip : equip // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ShopState implements DiagnosticableTreeMixin {

 ShopItemKind get kind; Set<String> get owned; Set<String> get legacyThemes; String? get equippedFrame; String? get equippedNameGlow; int get balance; String get rankId; bool get premium; String? get loadingItemId; ShopNotice? get notice;
/// Create a copy of ShopState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShopStateCopyWith<ShopState> get copyWith => _$ShopStateCopyWithImpl<ShopState>(this as ShopState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopState'))
    ..add(DiagnosticsProperty('kind', kind))..add(DiagnosticsProperty('owned', owned))..add(DiagnosticsProperty('legacyThemes', legacyThemes))..add(DiagnosticsProperty('equippedFrame', equippedFrame))..add(DiagnosticsProperty('equippedNameGlow', equippedNameGlow))..add(DiagnosticsProperty('balance', balance))..add(DiagnosticsProperty('rankId', rankId))..add(DiagnosticsProperty('premium', premium))..add(DiagnosticsProperty('loadingItemId', loadingItemId))..add(DiagnosticsProperty('notice', notice));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShopState&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.owned, owned)&&const DeepCollectionEquality().equals(other.legacyThemes, legacyThemes)&&(identical(other.equippedFrame, equippedFrame) || other.equippedFrame == equippedFrame)&&(identical(other.equippedNameGlow, equippedNameGlow) || other.equippedNameGlow == equippedNameGlow)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.rankId, rankId) || other.rankId == rankId)&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.loadingItemId, loadingItemId) || other.loadingItemId == loadingItemId)&&(identical(other.notice, notice) || other.notice == notice));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(owned),const DeepCollectionEquality().hash(legacyThemes),equippedFrame,equippedNameGlow,balance,rankId,premium,loadingItemId,notice);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopState(kind: $kind, owned: $owned, legacyThemes: $legacyThemes, equippedFrame: $equippedFrame, equippedNameGlow: $equippedNameGlow, balance: $balance, rankId: $rankId, premium: $premium, loadingItemId: $loadingItemId, notice: $notice)';
}


}

/// @nodoc
abstract mixin class $ShopStateCopyWith<$Res>  {
  factory $ShopStateCopyWith(ShopState value, $Res Function(ShopState) _then) = _$ShopStateCopyWithImpl;
@useResult
$Res call({
 ShopItemKind kind, Set<String> owned, Set<String> legacyThemes, String? equippedFrame, String? equippedNameGlow, int balance, String rankId, bool premium, String? loadingItemId, ShopNotice? notice
});




}
/// @nodoc
class _$ShopStateCopyWithImpl<$Res>
    implements $ShopStateCopyWith<$Res> {
  _$ShopStateCopyWithImpl(this._self, this._then);

  final ShopState _self;
  final $Res Function(ShopState) _then;

/// Create a copy of ShopState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? owned = null,Object? legacyThemes = null,Object? equippedFrame = freezed,Object? equippedNameGlow = freezed,Object? balance = null,Object? rankId = null,Object? premium = null,Object? loadingItemId = freezed,Object? notice = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShopItemKind,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as Set<String>,legacyThemes: null == legacyThemes ? _self.legacyThemes : legacyThemes // ignore: cast_nullable_to_non_nullable
as Set<String>,equippedFrame: freezed == equippedFrame ? _self.equippedFrame : equippedFrame // ignore: cast_nullable_to_non_nullable
as String?,equippedNameGlow: freezed == equippedNameGlow ? _self.equippedNameGlow : equippedNameGlow // ignore: cast_nullable_to_non_nullable
as String?,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,rankId: null == rankId ? _self.rankId : rankId // ignore: cast_nullable_to_non_nullable
as String,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,loadingItemId: freezed == loadingItemId ? _self.loadingItemId : loadingItemId // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ShopNotice?,
  ));
}

}


/// Adds pattern-matching-related methods to [ShopState].
extension ShopStatePatterns on ShopState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShopState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShopState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShopState value)  $default,){
final _that = this;
switch (_that) {
case _ShopState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShopState value)?  $default,){
final _that = this;
switch (_that) {
case _ShopState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ShopItemKind kind,  Set<String> owned,  Set<String> legacyThemes,  String? equippedFrame,  String? equippedNameGlow,  int balance,  String rankId,  bool premium,  String? loadingItemId,  ShopNotice? notice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShopState() when $default != null:
return $default(_that.kind,_that.owned,_that.legacyThemes,_that.equippedFrame,_that.equippedNameGlow,_that.balance,_that.rankId,_that.premium,_that.loadingItemId,_that.notice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ShopItemKind kind,  Set<String> owned,  Set<String> legacyThemes,  String? equippedFrame,  String? equippedNameGlow,  int balance,  String rankId,  bool premium,  String? loadingItemId,  ShopNotice? notice)  $default,) {final _that = this;
switch (_that) {
case _ShopState():
return $default(_that.kind,_that.owned,_that.legacyThemes,_that.equippedFrame,_that.equippedNameGlow,_that.balance,_that.rankId,_that.premium,_that.loadingItemId,_that.notice);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ShopItemKind kind,  Set<String> owned,  Set<String> legacyThemes,  String? equippedFrame,  String? equippedNameGlow,  int balance,  String rankId,  bool premium,  String? loadingItemId,  ShopNotice? notice)?  $default,) {final _that = this;
switch (_that) {
case _ShopState() when $default != null:
return $default(_that.kind,_that.owned,_that.legacyThemes,_that.equippedFrame,_that.equippedNameGlow,_that.balance,_that.rankId,_that.premium,_that.loadingItemId,_that.notice);case _:
  return null;

}
}

}

/// @nodoc


class _ShopState extends ShopState with DiagnosticableTreeMixin {
  const _ShopState({this.kind = ShopItemKind.theme, final  Set<String> owned = const <String>{}, final  Set<String> legacyThemes = const <String>{}, this.equippedFrame, this.equippedNameGlow, this.balance = 0, this.rankId = 'bronze', this.premium = false, this.loadingItemId, this.notice}): _owned = owned,_legacyThemes = legacyThemes,super._();
  

@override@JsonKey() final  ShopItemKind kind;
 final  Set<String> _owned;
@override@JsonKey() Set<String> get owned {
  if (_owned is EqualUnmodifiableSetView) return _owned;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_owned);
}

 final  Set<String> _legacyThemes;
@override@JsonKey() Set<String> get legacyThemes {
  if (_legacyThemes is EqualUnmodifiableSetView) return _legacyThemes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_legacyThemes);
}

@override final  String? equippedFrame;
@override final  String? equippedNameGlow;
@override@JsonKey() final  int balance;
@override@JsonKey() final  String rankId;
@override@JsonKey() final  bool premium;
@override final  String? loadingItemId;
@override final  ShopNotice? notice;

/// Create a copy of ShopState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShopStateCopyWith<_ShopState> get copyWith => __$ShopStateCopyWithImpl<_ShopState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShopState'))
    ..add(DiagnosticsProperty('kind', kind))..add(DiagnosticsProperty('owned', owned))..add(DiagnosticsProperty('legacyThemes', legacyThemes))..add(DiagnosticsProperty('equippedFrame', equippedFrame))..add(DiagnosticsProperty('equippedNameGlow', equippedNameGlow))..add(DiagnosticsProperty('balance', balance))..add(DiagnosticsProperty('rankId', rankId))..add(DiagnosticsProperty('premium', premium))..add(DiagnosticsProperty('loadingItemId', loadingItemId))..add(DiagnosticsProperty('notice', notice));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShopState&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._owned, _owned)&&const DeepCollectionEquality().equals(other._legacyThemes, _legacyThemes)&&(identical(other.equippedFrame, equippedFrame) || other.equippedFrame == equippedFrame)&&(identical(other.equippedNameGlow, equippedNameGlow) || other.equippedNameGlow == equippedNameGlow)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.rankId, rankId) || other.rankId == rankId)&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.loadingItemId, loadingItemId) || other.loadingItemId == loadingItemId)&&(identical(other.notice, notice) || other.notice == notice));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_owned),const DeepCollectionEquality().hash(_legacyThemes),equippedFrame,equippedNameGlow,balance,rankId,premium,loadingItemId,notice);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShopState(kind: $kind, owned: $owned, legacyThemes: $legacyThemes, equippedFrame: $equippedFrame, equippedNameGlow: $equippedNameGlow, balance: $balance, rankId: $rankId, premium: $premium, loadingItemId: $loadingItemId, notice: $notice)';
}


}

/// @nodoc
abstract mixin class _$ShopStateCopyWith<$Res> implements $ShopStateCopyWith<$Res> {
  factory _$ShopStateCopyWith(_ShopState value, $Res Function(_ShopState) _then) = __$ShopStateCopyWithImpl;
@override @useResult
$Res call({
 ShopItemKind kind, Set<String> owned, Set<String> legacyThemes, String? equippedFrame, String? equippedNameGlow, int balance, String rankId, bool premium, String? loadingItemId, ShopNotice? notice
});




}
/// @nodoc
class __$ShopStateCopyWithImpl<$Res>
    implements _$ShopStateCopyWith<$Res> {
  __$ShopStateCopyWithImpl(this._self, this._then);

  final _ShopState _self;
  final $Res Function(_ShopState) _then;

/// Create a copy of ShopState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? owned = null,Object? legacyThemes = null,Object? equippedFrame = freezed,Object? equippedNameGlow = freezed,Object? balance = null,Object? rankId = null,Object? premium = null,Object? loadingItemId = freezed,Object? notice = freezed,}) {
  return _then(_ShopState(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShopItemKind,owned: null == owned ? _self._owned : owned // ignore: cast_nullable_to_non_nullable
as Set<String>,legacyThemes: null == legacyThemes ? _self._legacyThemes : legacyThemes // ignore: cast_nullable_to_non_nullable
as Set<String>,equippedFrame: freezed == equippedFrame ? _self.equippedFrame : equippedFrame // ignore: cast_nullable_to_non_nullable
as String?,equippedNameGlow: freezed == equippedNameGlow ? _self.equippedNameGlow : equippedNameGlow // ignore: cast_nullable_to_non_nullable
as String?,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,rankId: null == rankId ? _self.rankId : rankId // ignore: cast_nullable_to_non_nullable
as String,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,loadingItemId: freezed == loadingItemId ? _self.loadingItemId : loadingItemId // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ShopNotice?,
  ));
}


}

// dart format on

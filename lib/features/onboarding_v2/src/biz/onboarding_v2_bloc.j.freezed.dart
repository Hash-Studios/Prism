// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_v2_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnboardingV2Event {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingV2Event);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event()';
}


}

/// @nodoc
class $OnboardingV2EventCopyWith<$Res>  {
$OnboardingV2EventCopyWith(OnboardingV2Event _, $Res Function(OnboardingV2Event) __);
}


/// Adds pattern-matching-related methods to [OnboardingV2Event].
extension OnboardingV2EventPatterns on OnboardingV2Event {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _AuthCompleted value)?  authCompleted,TResult Function( _AuthLoadingChanged value)?  authLoadingChanged,TResult Function( _InterestToggled value)?  interestToggled,TResult Function( _InterestsConfirmed value)?  interestsConfirmed,TResult Function( _CreatorFollowToggled value)?  creatorFollowToggled,TResult Function( _StarterPackConfirmed value)?  starterPackConfirmed,TResult Function( _FirstWallpaperActionRequested value)?  firstWallpaperActionRequested,TResult Function( _FirstWallpaperActionCompleted value)?  firstWallpaperActionCompleted,TResult Function( _FirstWallpaperStepContinued value)?  firstWallpaperStepContinued,TResult Function( _PaywallResultReceived value)?  paywallResultReceived,TResult Function( _StepBack value)?  stepBack,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _AuthCompleted() when authCompleted != null:
return authCompleted(_that);case _AuthLoadingChanged() when authLoadingChanged != null:
return authLoadingChanged(_that);case _InterestToggled() when interestToggled != null:
return interestToggled(_that);case _InterestsConfirmed() when interestsConfirmed != null:
return interestsConfirmed(_that);case _CreatorFollowToggled() when creatorFollowToggled != null:
return creatorFollowToggled(_that);case _StarterPackConfirmed() when starterPackConfirmed != null:
return starterPackConfirmed(_that);case _FirstWallpaperActionRequested() when firstWallpaperActionRequested != null:
return firstWallpaperActionRequested(_that);case _FirstWallpaperActionCompleted() when firstWallpaperActionCompleted != null:
return firstWallpaperActionCompleted(_that);case _FirstWallpaperStepContinued() when firstWallpaperStepContinued != null:
return firstWallpaperStepContinued(_that);case _PaywallResultReceived() when paywallResultReceived != null:
return paywallResultReceived(_that);case _StepBack() when stepBack != null:
return stepBack(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _AuthCompleted value)  authCompleted,required TResult Function( _AuthLoadingChanged value)  authLoadingChanged,required TResult Function( _InterestToggled value)  interestToggled,required TResult Function( _InterestsConfirmed value)  interestsConfirmed,required TResult Function( _CreatorFollowToggled value)  creatorFollowToggled,required TResult Function( _StarterPackConfirmed value)  starterPackConfirmed,required TResult Function( _FirstWallpaperActionRequested value)  firstWallpaperActionRequested,required TResult Function( _FirstWallpaperActionCompleted value)  firstWallpaperActionCompleted,required TResult Function( _FirstWallpaperStepContinued value)  firstWallpaperStepContinued,required TResult Function( _PaywallResultReceived value)  paywallResultReceived,required TResult Function( _StepBack value)  stepBack,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _AuthCompleted():
return authCompleted(_that);case _AuthLoadingChanged():
return authLoadingChanged(_that);case _InterestToggled():
return interestToggled(_that);case _InterestsConfirmed():
return interestsConfirmed(_that);case _CreatorFollowToggled():
return creatorFollowToggled(_that);case _StarterPackConfirmed():
return starterPackConfirmed(_that);case _FirstWallpaperActionRequested():
return firstWallpaperActionRequested(_that);case _FirstWallpaperActionCompleted():
return firstWallpaperActionCompleted(_that);case _FirstWallpaperStepContinued():
return firstWallpaperStepContinued(_that);case _PaywallResultReceived():
return paywallResultReceived(_that);case _StepBack():
return stepBack(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _AuthCompleted value)?  authCompleted,TResult? Function( _AuthLoadingChanged value)?  authLoadingChanged,TResult? Function( _InterestToggled value)?  interestToggled,TResult? Function( _InterestsConfirmed value)?  interestsConfirmed,TResult? Function( _CreatorFollowToggled value)?  creatorFollowToggled,TResult? Function( _StarterPackConfirmed value)?  starterPackConfirmed,TResult? Function( _FirstWallpaperActionRequested value)?  firstWallpaperActionRequested,TResult? Function( _FirstWallpaperActionCompleted value)?  firstWallpaperActionCompleted,TResult? Function( _FirstWallpaperStepContinued value)?  firstWallpaperStepContinued,TResult? Function( _PaywallResultReceived value)?  paywallResultReceived,TResult? Function( _StepBack value)?  stepBack,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _AuthCompleted() when authCompleted != null:
return authCompleted(_that);case _AuthLoadingChanged() when authLoadingChanged != null:
return authLoadingChanged(_that);case _InterestToggled() when interestToggled != null:
return interestToggled(_that);case _InterestsConfirmed() when interestsConfirmed != null:
return interestsConfirmed(_that);case _CreatorFollowToggled() when creatorFollowToggled != null:
return creatorFollowToggled(_that);case _StarterPackConfirmed() when starterPackConfirmed != null:
return starterPackConfirmed(_that);case _FirstWallpaperActionRequested() when firstWallpaperActionRequested != null:
return firstWallpaperActionRequested(_that);case _FirstWallpaperActionCompleted() when firstWallpaperActionCompleted != null:
return firstWallpaperActionCompleted(_that);case _FirstWallpaperStepContinued() when firstWallpaperStepContinued != null:
return firstWallpaperStepContinued(_that);case _PaywallResultReceived() when paywallResultReceived != null:
return paywallResultReceived(_that);case _StepBack() when stepBack != null:
return stepBack(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  authCompleted,TResult Function( bool isLoading)?  authLoadingChanged,TResult Function( String categoryName)?  interestToggled,TResult Function()?  interestsConfirmed,TResult Function( String creatorEmail)?  creatorFollowToggled,TResult Function()?  starterPackConfirmed,TResult Function()?  firstWallpaperActionRequested,TResult Function( bool success,  int elapsedMs)?  firstWallpaperActionCompleted,TResult Function()?  firstWallpaperStepContinued,TResult Function( bool didPurchase)?  paywallResultReceived,TResult Function()?  stepBack,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _AuthCompleted() when authCompleted != null:
return authCompleted();case _AuthLoadingChanged() when authLoadingChanged != null:
return authLoadingChanged(_that.isLoading);case _InterestToggled() when interestToggled != null:
return interestToggled(_that.categoryName);case _InterestsConfirmed() when interestsConfirmed != null:
return interestsConfirmed();case _CreatorFollowToggled() when creatorFollowToggled != null:
return creatorFollowToggled(_that.creatorEmail);case _StarterPackConfirmed() when starterPackConfirmed != null:
return starterPackConfirmed();case _FirstWallpaperActionRequested() when firstWallpaperActionRequested != null:
return firstWallpaperActionRequested();case _FirstWallpaperActionCompleted() when firstWallpaperActionCompleted != null:
return firstWallpaperActionCompleted(_that.success,_that.elapsedMs);case _FirstWallpaperStepContinued() when firstWallpaperStepContinued != null:
return firstWallpaperStepContinued();case _PaywallResultReceived() when paywallResultReceived != null:
return paywallResultReceived(_that.didPurchase);case _StepBack() when stepBack != null:
return stepBack();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  authCompleted,required TResult Function( bool isLoading)  authLoadingChanged,required TResult Function( String categoryName)  interestToggled,required TResult Function()  interestsConfirmed,required TResult Function( String creatorEmail)  creatorFollowToggled,required TResult Function()  starterPackConfirmed,required TResult Function()  firstWallpaperActionRequested,required TResult Function( bool success,  int elapsedMs)  firstWallpaperActionCompleted,required TResult Function()  firstWallpaperStepContinued,required TResult Function( bool didPurchase)  paywallResultReceived,required TResult Function()  stepBack,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _AuthCompleted():
return authCompleted();case _AuthLoadingChanged():
return authLoadingChanged(_that.isLoading);case _InterestToggled():
return interestToggled(_that.categoryName);case _InterestsConfirmed():
return interestsConfirmed();case _CreatorFollowToggled():
return creatorFollowToggled(_that.creatorEmail);case _StarterPackConfirmed():
return starterPackConfirmed();case _FirstWallpaperActionRequested():
return firstWallpaperActionRequested();case _FirstWallpaperActionCompleted():
return firstWallpaperActionCompleted(_that.success,_that.elapsedMs);case _FirstWallpaperStepContinued():
return firstWallpaperStepContinued();case _PaywallResultReceived():
return paywallResultReceived(_that.didPurchase);case _StepBack():
return stepBack();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  authCompleted,TResult? Function( bool isLoading)?  authLoadingChanged,TResult? Function( String categoryName)?  interestToggled,TResult? Function()?  interestsConfirmed,TResult? Function( String creatorEmail)?  creatorFollowToggled,TResult? Function()?  starterPackConfirmed,TResult? Function()?  firstWallpaperActionRequested,TResult? Function( bool success,  int elapsedMs)?  firstWallpaperActionCompleted,TResult? Function()?  firstWallpaperStepContinued,TResult? Function( bool didPurchase)?  paywallResultReceived,TResult? Function()?  stepBack,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _AuthCompleted() when authCompleted != null:
return authCompleted();case _AuthLoadingChanged() when authLoadingChanged != null:
return authLoadingChanged(_that.isLoading);case _InterestToggled() when interestToggled != null:
return interestToggled(_that.categoryName);case _InterestsConfirmed() when interestsConfirmed != null:
return interestsConfirmed();case _CreatorFollowToggled() when creatorFollowToggled != null:
return creatorFollowToggled(_that.creatorEmail);case _StarterPackConfirmed() when starterPackConfirmed != null:
return starterPackConfirmed();case _FirstWallpaperActionRequested() when firstWallpaperActionRequested != null:
return firstWallpaperActionRequested();case _FirstWallpaperActionCompleted() when firstWallpaperActionCompleted != null:
return firstWallpaperActionCompleted(_that.success,_that.elapsedMs);case _FirstWallpaperStepContinued() when firstWallpaperStepContinued != null:
return firstWallpaperStepContinued();case _PaywallResultReceived() when paywallResultReceived != null:
return paywallResultReceived(_that.didPurchase);case _StepBack() when stepBack != null:
return stepBack();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements OnboardingV2Event {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.started()';
}


}




/// @nodoc


class _AuthCompleted implements OnboardingV2Event {
  const _AuthCompleted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthCompleted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.authCompleted()';
}


}




/// @nodoc


class _AuthLoadingChanged implements OnboardingV2Event {
  const _AuthLoadingChanged({required this.isLoading});
  

 final  bool isLoading;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthLoadingChangedCopyWith<_AuthLoadingChanged> get copyWith => __$AuthLoadingChangedCopyWithImpl<_AuthLoadingChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthLoadingChanged&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,isLoading);

@override
String toString() {
  return 'OnboardingV2Event.authLoadingChanged(isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class _$AuthLoadingChangedCopyWith<$Res> implements $OnboardingV2EventCopyWith<$Res> {
  factory _$AuthLoadingChangedCopyWith(_AuthLoadingChanged value, $Res Function(_AuthLoadingChanged) _then) = __$AuthLoadingChangedCopyWithImpl;
@useResult
$Res call({
 bool isLoading
});




}
/// @nodoc
class __$AuthLoadingChangedCopyWithImpl<$Res>
    implements _$AuthLoadingChangedCopyWith<$Res> {
  __$AuthLoadingChangedCopyWithImpl(this._self, this._then);

  final _AuthLoadingChanged _self;
  final $Res Function(_AuthLoadingChanged) _then;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isLoading = null,}) {
  return _then(_AuthLoadingChanged(
isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _InterestToggled implements OnboardingV2Event {
  const _InterestToggled(this.categoryName);
  

 final  String categoryName;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InterestToggledCopyWith<_InterestToggled> get copyWith => __$InterestToggledCopyWithImpl<_InterestToggled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InterestToggled&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName));
}


@override
int get hashCode => Object.hash(runtimeType,categoryName);

@override
String toString() {
  return 'OnboardingV2Event.interestToggled(categoryName: $categoryName)';
}


}

/// @nodoc
abstract mixin class _$InterestToggledCopyWith<$Res> implements $OnboardingV2EventCopyWith<$Res> {
  factory _$InterestToggledCopyWith(_InterestToggled value, $Res Function(_InterestToggled) _then) = __$InterestToggledCopyWithImpl;
@useResult
$Res call({
 String categoryName
});




}
/// @nodoc
class __$InterestToggledCopyWithImpl<$Res>
    implements _$InterestToggledCopyWith<$Res> {
  __$InterestToggledCopyWithImpl(this._self, this._then);

  final _InterestToggled _self;
  final $Res Function(_InterestToggled) _then;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? categoryName = null,}) {
  return _then(_InterestToggled(
null == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _InterestsConfirmed implements OnboardingV2Event {
  const _InterestsConfirmed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InterestsConfirmed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.interestsConfirmed()';
}


}




/// @nodoc


class _CreatorFollowToggled implements OnboardingV2Event {
  const _CreatorFollowToggled(this.creatorEmail);
  

 final  String creatorEmail;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreatorFollowToggledCopyWith<_CreatorFollowToggled> get copyWith => __$CreatorFollowToggledCopyWithImpl<_CreatorFollowToggled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreatorFollowToggled&&(identical(other.creatorEmail, creatorEmail) || other.creatorEmail == creatorEmail));
}


@override
int get hashCode => Object.hash(runtimeType,creatorEmail);

@override
String toString() {
  return 'OnboardingV2Event.creatorFollowToggled(creatorEmail: $creatorEmail)';
}


}

/// @nodoc
abstract mixin class _$CreatorFollowToggledCopyWith<$Res> implements $OnboardingV2EventCopyWith<$Res> {
  factory _$CreatorFollowToggledCopyWith(_CreatorFollowToggled value, $Res Function(_CreatorFollowToggled) _then) = __$CreatorFollowToggledCopyWithImpl;
@useResult
$Res call({
 String creatorEmail
});




}
/// @nodoc
class __$CreatorFollowToggledCopyWithImpl<$Res>
    implements _$CreatorFollowToggledCopyWith<$Res> {
  __$CreatorFollowToggledCopyWithImpl(this._self, this._then);

  final _CreatorFollowToggled _self;
  final $Res Function(_CreatorFollowToggled) _then;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? creatorEmail = null,}) {
  return _then(_CreatorFollowToggled(
null == creatorEmail ? _self.creatorEmail : creatorEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _StarterPackConfirmed implements OnboardingV2Event {
  const _StarterPackConfirmed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StarterPackConfirmed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.starterPackConfirmed()';
}


}




/// @nodoc


class _FirstWallpaperActionRequested implements OnboardingV2Event {
  const _FirstWallpaperActionRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirstWallpaperActionRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.firstWallpaperActionRequested()';
}


}




/// @nodoc


class _FirstWallpaperActionCompleted implements OnboardingV2Event {
  const _FirstWallpaperActionCompleted({required this.success, required this.elapsedMs});
  

 final  bool success;
 final  int elapsedMs;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirstWallpaperActionCompletedCopyWith<_FirstWallpaperActionCompleted> get copyWith => __$FirstWallpaperActionCompletedCopyWithImpl<_FirstWallpaperActionCompleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirstWallpaperActionCompleted&&(identical(other.success, success) || other.success == success)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}


@override
int get hashCode => Object.hash(runtimeType,success,elapsedMs);

@override
String toString() {
  return 'OnboardingV2Event.firstWallpaperActionCompleted(success: $success, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class _$FirstWallpaperActionCompletedCopyWith<$Res> implements $OnboardingV2EventCopyWith<$Res> {
  factory _$FirstWallpaperActionCompletedCopyWith(_FirstWallpaperActionCompleted value, $Res Function(_FirstWallpaperActionCompleted) _then) = __$FirstWallpaperActionCompletedCopyWithImpl;
@useResult
$Res call({
 bool success, int elapsedMs
});




}
/// @nodoc
class __$FirstWallpaperActionCompletedCopyWithImpl<$Res>
    implements _$FirstWallpaperActionCompletedCopyWith<$Res> {
  __$FirstWallpaperActionCompletedCopyWithImpl(this._self, this._then);

  final _FirstWallpaperActionCompleted _self;
  final $Res Function(_FirstWallpaperActionCompleted) _then;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? success = null,Object? elapsedMs = null,}) {
  return _then(_FirstWallpaperActionCompleted(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _FirstWallpaperStepContinued implements OnboardingV2Event {
  const _FirstWallpaperStepContinued();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirstWallpaperStepContinued);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.firstWallpaperStepContinued()';
}


}




/// @nodoc


class _PaywallResultReceived implements OnboardingV2Event {
  const _PaywallResultReceived({required this.didPurchase});
  

 final  bool didPurchase;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaywallResultReceivedCopyWith<_PaywallResultReceived> get copyWith => __$PaywallResultReceivedCopyWithImpl<_PaywallResultReceived>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaywallResultReceived&&(identical(other.didPurchase, didPurchase) || other.didPurchase == didPurchase));
}


@override
int get hashCode => Object.hash(runtimeType,didPurchase);

@override
String toString() {
  return 'OnboardingV2Event.paywallResultReceived(didPurchase: $didPurchase)';
}


}

/// @nodoc
abstract mixin class _$PaywallResultReceivedCopyWith<$Res> implements $OnboardingV2EventCopyWith<$Res> {
  factory _$PaywallResultReceivedCopyWith(_PaywallResultReceived value, $Res Function(_PaywallResultReceived) _then) = __$PaywallResultReceivedCopyWithImpl;
@useResult
$Res call({
 bool didPurchase
});




}
/// @nodoc
class __$PaywallResultReceivedCopyWithImpl<$Res>
    implements _$PaywallResultReceivedCopyWith<$Res> {
  __$PaywallResultReceivedCopyWithImpl(this._self, this._then);

  final _PaywallResultReceived _self;
  final $Res Function(_PaywallResultReceived) _then;

/// Create a copy of OnboardingV2Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? didPurchase = null,}) {
  return _then(_PaywallResultReceived(
didPurchase: null == didPurchase ? _self.didPurchase : didPurchase // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _StepBack implements OnboardingV2Event {
  const _StepBack();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StepBack);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OnboardingV2Event.stepBack()';
}


}




/// @nodoc
mixin _$OnboardingInterestsData {

 List<String> get available; List<String> get selected; Map<String, String> get categoryImages;
/// Create a copy of OnboardingInterestsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingInterestsDataCopyWith<OnboardingInterestsData> get copyWith => _$OnboardingInterestsDataCopyWithImpl<OnboardingInterestsData>(this as OnboardingInterestsData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingInterestsData&&const DeepCollectionEquality().equals(other.available, available)&&const DeepCollectionEquality().equals(other.selected, selected)&&const DeepCollectionEquality().equals(other.categoryImages, categoryImages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(available),const DeepCollectionEquality().hash(selected),const DeepCollectionEquality().hash(categoryImages));

@override
String toString() {
  return 'OnboardingInterestsData(available: $available, selected: $selected, categoryImages: $categoryImages)';
}


}

/// @nodoc
abstract mixin class $OnboardingInterestsDataCopyWith<$Res>  {
  factory $OnboardingInterestsDataCopyWith(OnboardingInterestsData value, $Res Function(OnboardingInterestsData) _then) = _$OnboardingInterestsDataCopyWithImpl;
@useResult
$Res call({
 List<String> available, List<String> selected, Map<String, String> categoryImages
});




}
/// @nodoc
class _$OnboardingInterestsDataCopyWithImpl<$Res>
    implements $OnboardingInterestsDataCopyWith<$Res> {
  _$OnboardingInterestsDataCopyWithImpl(this._self, this._then);

  final OnboardingInterestsData _self;
  final $Res Function(OnboardingInterestsData) _then;

/// Create a copy of OnboardingInterestsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? available = null,Object? selected = null,Object? categoryImages = null,}) {
  return _then(_self.copyWith(
available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as List<String>,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as List<String>,categoryImages: null == categoryImages ? _self.categoryImages : categoryImages // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnboardingInterestsData].
extension OnboardingInterestsDataPatterns on OnboardingInterestsData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingInterestsData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingInterestsData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingInterestsData value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingInterestsData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingInterestsData value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingInterestsData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> available,  List<String> selected,  Map<String, String> categoryImages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingInterestsData() when $default != null:
return $default(_that.available,_that.selected,_that.categoryImages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> available,  List<String> selected,  Map<String, String> categoryImages)  $default,) {final _that = this;
switch (_that) {
case _OnboardingInterestsData():
return $default(_that.available,_that.selected,_that.categoryImages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> available,  List<String> selected,  Map<String, String> categoryImages)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingInterestsData() when $default != null:
return $default(_that.available,_that.selected,_that.categoryImages);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingInterestsData extends OnboardingInterestsData {
  const _OnboardingInterestsData({required final  List<String> available, required final  List<String> selected, required final  Map<String, String> categoryImages}): _available = available,_selected = selected,_categoryImages = categoryImages,super._();
  

 final  List<String> _available;
@override List<String> get available {
  if (_available is EqualUnmodifiableListView) return _available;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_available);
}

 final  List<String> _selected;
@override List<String> get selected {
  if (_selected is EqualUnmodifiableListView) return _selected;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selected);
}

 final  Map<String, String> _categoryImages;
@override Map<String, String> get categoryImages {
  if (_categoryImages is EqualUnmodifiableMapView) return _categoryImages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_categoryImages);
}


/// Create a copy of OnboardingInterestsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingInterestsDataCopyWith<_OnboardingInterestsData> get copyWith => __$OnboardingInterestsDataCopyWithImpl<_OnboardingInterestsData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingInterestsData&&const DeepCollectionEquality().equals(other._available, _available)&&const DeepCollectionEquality().equals(other._selected, _selected)&&const DeepCollectionEquality().equals(other._categoryImages, _categoryImages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_available),const DeepCollectionEquality().hash(_selected),const DeepCollectionEquality().hash(_categoryImages));

@override
String toString() {
  return 'OnboardingInterestsData(available: $available, selected: $selected, categoryImages: $categoryImages)';
}


}

/// @nodoc
abstract mixin class _$OnboardingInterestsDataCopyWith<$Res> implements $OnboardingInterestsDataCopyWith<$Res> {
  factory _$OnboardingInterestsDataCopyWith(_OnboardingInterestsData value, $Res Function(_OnboardingInterestsData) _then) = __$OnboardingInterestsDataCopyWithImpl;
@override @useResult
$Res call({
 List<String> available, List<String> selected, Map<String, String> categoryImages
});




}
/// @nodoc
class __$OnboardingInterestsDataCopyWithImpl<$Res>
    implements _$OnboardingInterestsDataCopyWith<$Res> {
  __$OnboardingInterestsDataCopyWithImpl(this._self, this._then);

  final _OnboardingInterestsData _self;
  final $Res Function(_OnboardingInterestsData) _then;

/// Create a copy of OnboardingInterestsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? available = null,Object? selected = null,Object? categoryImages = null,}) {
  return _then(_OnboardingInterestsData(
available: null == available ? _self._available : available // ignore: cast_nullable_to_non_nullable
as List<String>,selected: null == selected ? _self._selected : selected // ignore: cast_nullable_to_non_nullable
as List<String>,categoryImages: null == categoryImages ? _self._categoryImages : categoryImages // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc
mixin _$OnboardingStarterPackData {

 List<OnboardingCreatorVm> get creators; List<String> get selectedEmails;
/// Create a copy of OnboardingStarterPackData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingStarterPackDataCopyWith<OnboardingStarterPackData> get copyWith => _$OnboardingStarterPackDataCopyWithImpl<OnboardingStarterPackData>(this as OnboardingStarterPackData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingStarterPackData&&const DeepCollectionEquality().equals(other.creators, creators)&&const DeepCollectionEquality().equals(other.selectedEmails, selectedEmails));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(creators),const DeepCollectionEquality().hash(selectedEmails));

@override
String toString() {
  return 'OnboardingStarterPackData(creators: $creators, selectedEmails: $selectedEmails)';
}


}

/// @nodoc
abstract mixin class $OnboardingStarterPackDataCopyWith<$Res>  {
  factory $OnboardingStarterPackDataCopyWith(OnboardingStarterPackData value, $Res Function(OnboardingStarterPackData) _then) = _$OnboardingStarterPackDataCopyWithImpl;
@useResult
$Res call({
 List<OnboardingCreatorVm> creators, List<String> selectedEmails
});




}
/// @nodoc
class _$OnboardingStarterPackDataCopyWithImpl<$Res>
    implements $OnboardingStarterPackDataCopyWith<$Res> {
  _$OnboardingStarterPackDataCopyWithImpl(this._self, this._then);

  final OnboardingStarterPackData _self;
  final $Res Function(OnboardingStarterPackData) _then;

/// Create a copy of OnboardingStarterPackData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? creators = null,Object? selectedEmails = null,}) {
  return _then(_self.copyWith(
creators: null == creators ? _self.creators : creators // ignore: cast_nullable_to_non_nullable
as List<OnboardingCreatorVm>,selectedEmails: null == selectedEmails ? _self.selectedEmails : selectedEmails // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnboardingStarterPackData].
extension OnboardingStarterPackDataPatterns on OnboardingStarterPackData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingStarterPackData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingStarterPackData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingStarterPackData value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingStarterPackData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingStarterPackData value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingStarterPackData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<OnboardingCreatorVm> creators,  List<String> selectedEmails)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingStarterPackData() when $default != null:
return $default(_that.creators,_that.selectedEmails);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<OnboardingCreatorVm> creators,  List<String> selectedEmails)  $default,) {final _that = this;
switch (_that) {
case _OnboardingStarterPackData():
return $default(_that.creators,_that.selectedEmails);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<OnboardingCreatorVm> creators,  List<String> selectedEmails)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingStarterPackData() when $default != null:
return $default(_that.creators,_that.selectedEmails);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingStarterPackData extends OnboardingStarterPackData {
  const _OnboardingStarterPackData({required final  List<OnboardingCreatorVm> creators, required final  List<String> selectedEmails}): _creators = creators,_selectedEmails = selectedEmails,super._();
  

 final  List<OnboardingCreatorVm> _creators;
@override List<OnboardingCreatorVm> get creators {
  if (_creators is EqualUnmodifiableListView) return _creators;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_creators);
}

 final  List<String> _selectedEmails;
@override List<String> get selectedEmails {
  if (_selectedEmails is EqualUnmodifiableListView) return _selectedEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedEmails);
}


/// Create a copy of OnboardingStarterPackData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingStarterPackDataCopyWith<_OnboardingStarterPackData> get copyWith => __$OnboardingStarterPackDataCopyWithImpl<_OnboardingStarterPackData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingStarterPackData&&const DeepCollectionEquality().equals(other._creators, _creators)&&const DeepCollectionEquality().equals(other._selectedEmails, _selectedEmails));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_creators),const DeepCollectionEquality().hash(_selectedEmails));

@override
String toString() {
  return 'OnboardingStarterPackData(creators: $creators, selectedEmails: $selectedEmails)';
}


}

/// @nodoc
abstract mixin class _$OnboardingStarterPackDataCopyWith<$Res> implements $OnboardingStarterPackDataCopyWith<$Res> {
  factory _$OnboardingStarterPackDataCopyWith(_OnboardingStarterPackData value, $Res Function(_OnboardingStarterPackData) _then) = __$OnboardingStarterPackDataCopyWithImpl;
@override @useResult
$Res call({
 List<OnboardingCreatorVm> creators, List<String> selectedEmails
});




}
/// @nodoc
class __$OnboardingStarterPackDataCopyWithImpl<$Res>
    implements _$OnboardingStarterPackDataCopyWith<$Res> {
  __$OnboardingStarterPackDataCopyWithImpl(this._self, this._then);

  final _OnboardingStarterPackData _self;
  final $Res Function(_OnboardingStarterPackData) _then;

/// Create a copy of OnboardingStarterPackData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? creators = null,Object? selectedEmails = null,}) {
  return _then(_OnboardingStarterPackData(
creators: null == creators ? _self._creators : creators // ignore: cast_nullable_to_non_nullable
as List<OnboardingCreatorVm>,selectedEmails: null == selectedEmails ? _self._selectedEmails : selectedEmails // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$OnboardingWallpaperData {

 OnboardingWallpaperVm? get wallpaper; FirstWallpaperStatus get status; int? get elapsedMs;
/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingWallpaperDataCopyWith<OnboardingWallpaperData> get copyWith => _$OnboardingWallpaperDataCopyWithImpl<OnboardingWallpaperData>(this as OnboardingWallpaperData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingWallpaperData&&(identical(other.wallpaper, wallpaper) || other.wallpaper == wallpaper)&&(identical(other.status, status) || other.status == status)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}


@override
int get hashCode => Object.hash(runtimeType,wallpaper,status,elapsedMs);

@override
String toString() {
  return 'OnboardingWallpaperData(wallpaper: $wallpaper, status: $status, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class $OnboardingWallpaperDataCopyWith<$Res>  {
  factory $OnboardingWallpaperDataCopyWith(OnboardingWallpaperData value, $Res Function(OnboardingWallpaperData) _then) = _$OnboardingWallpaperDataCopyWithImpl;
@useResult
$Res call({
 OnboardingWallpaperVm? wallpaper, FirstWallpaperStatus status, int? elapsedMs
});


$OnboardingWallpaperVmCopyWith<$Res>? get wallpaper;

}
/// @nodoc
class _$OnboardingWallpaperDataCopyWithImpl<$Res>
    implements $OnboardingWallpaperDataCopyWith<$Res> {
  _$OnboardingWallpaperDataCopyWithImpl(this._self, this._then);

  final OnboardingWallpaperData _self;
  final $Res Function(OnboardingWallpaperData) _then;

/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wallpaper = freezed,Object? status = null,Object? elapsedMs = freezed,}) {
  return _then(_self.copyWith(
wallpaper: freezed == wallpaper ? _self.wallpaper : wallpaper // ignore: cast_nullable_to_non_nullable
as OnboardingWallpaperVm?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FirstWallpaperStatus,elapsedMs: freezed == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingWallpaperVmCopyWith<$Res>? get wallpaper {
    if (_self.wallpaper == null) {
    return null;
  }

  return $OnboardingWallpaperVmCopyWith<$Res>(_self.wallpaper!, (value) {
    return _then(_self.copyWith(wallpaper: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnboardingWallpaperData].
extension OnboardingWallpaperDataPatterns on OnboardingWallpaperData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingWallpaperData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingWallpaperData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingWallpaperData value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingWallpaperData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingWallpaperData value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingWallpaperData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OnboardingWallpaperVm? wallpaper,  FirstWallpaperStatus status,  int? elapsedMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingWallpaperData() when $default != null:
return $default(_that.wallpaper,_that.status,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OnboardingWallpaperVm? wallpaper,  FirstWallpaperStatus status,  int? elapsedMs)  $default,) {final _that = this;
switch (_that) {
case _OnboardingWallpaperData():
return $default(_that.wallpaper,_that.status,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OnboardingWallpaperVm? wallpaper,  FirstWallpaperStatus status,  int? elapsedMs)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingWallpaperData() when $default != null:
return $default(_that.wallpaper,_that.status,_that.elapsedMs);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingWallpaperData implements OnboardingWallpaperData {
  const _OnboardingWallpaperData({this.wallpaper, required this.status, this.elapsedMs});
  

@override final  OnboardingWallpaperVm? wallpaper;
@override final  FirstWallpaperStatus status;
@override final  int? elapsedMs;

/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingWallpaperDataCopyWith<_OnboardingWallpaperData> get copyWith => __$OnboardingWallpaperDataCopyWithImpl<_OnboardingWallpaperData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingWallpaperData&&(identical(other.wallpaper, wallpaper) || other.wallpaper == wallpaper)&&(identical(other.status, status) || other.status == status)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}


@override
int get hashCode => Object.hash(runtimeType,wallpaper,status,elapsedMs);

@override
String toString() {
  return 'OnboardingWallpaperData(wallpaper: $wallpaper, status: $status, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class _$OnboardingWallpaperDataCopyWith<$Res> implements $OnboardingWallpaperDataCopyWith<$Res> {
  factory _$OnboardingWallpaperDataCopyWith(_OnboardingWallpaperData value, $Res Function(_OnboardingWallpaperData) _then) = __$OnboardingWallpaperDataCopyWithImpl;
@override @useResult
$Res call({
 OnboardingWallpaperVm? wallpaper, FirstWallpaperStatus status, int? elapsedMs
});


@override $OnboardingWallpaperVmCopyWith<$Res>? get wallpaper;

}
/// @nodoc
class __$OnboardingWallpaperDataCopyWithImpl<$Res>
    implements _$OnboardingWallpaperDataCopyWith<$Res> {
  __$OnboardingWallpaperDataCopyWithImpl(this._self, this._then);

  final _OnboardingWallpaperData _self;
  final $Res Function(_OnboardingWallpaperData) _then;

/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wallpaper = freezed,Object? status = null,Object? elapsedMs = freezed,}) {
  return _then(_OnboardingWallpaperData(
wallpaper: freezed == wallpaper ? _self.wallpaper : wallpaper // ignore: cast_nullable_to_non_nullable
as OnboardingWallpaperVm?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FirstWallpaperStatus,elapsedMs: freezed == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of OnboardingWallpaperData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingWallpaperVmCopyWith<$Res>? get wallpaper {
    if (_self.wallpaper == null) {
    return null;
  }

  return $OnboardingWallpaperVmCopyWith<$Res>(_self.wallpaper!, (value) {
    return _then(_self.copyWith(wallpaper: value));
  });
}
}

/// @nodoc
mixin _$OnboardingV2State {

 OnboardingV2Step get step; LoadStatus get loadStatus; ActionStatus get actionStatus; bool get isAuthLoading; OnboardingInterestsData get interestsData; OnboardingStarterPackData get starterPackData; OnboardingWallpaperData get wallpaperData; bool get skipInterests; bool get skipStarterPack; OnboardingV2NavRequest? get navRequest; Failure? get failure;
/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingV2StateCopyWith<OnboardingV2State> get copyWith => _$OnboardingV2StateCopyWithImpl<OnboardingV2State>(this as OnboardingV2State, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingV2State&&(identical(other.step, step) || other.step == step)&&(identical(other.loadStatus, loadStatus) || other.loadStatus == loadStatus)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.isAuthLoading, isAuthLoading) || other.isAuthLoading == isAuthLoading)&&(identical(other.interestsData, interestsData) || other.interestsData == interestsData)&&(identical(other.starterPackData, starterPackData) || other.starterPackData == starterPackData)&&(identical(other.wallpaperData, wallpaperData) || other.wallpaperData == wallpaperData)&&(identical(other.skipInterests, skipInterests) || other.skipInterests == skipInterests)&&(identical(other.skipStarterPack, skipStarterPack) || other.skipStarterPack == skipStarterPack)&&(identical(other.navRequest, navRequest) || other.navRequest == navRequest)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,step,loadStatus,actionStatus,isAuthLoading,interestsData,starterPackData,wallpaperData,skipInterests,skipStarterPack,navRequest,failure);

@override
String toString() {
  return 'OnboardingV2State(step: $step, loadStatus: $loadStatus, actionStatus: $actionStatus, isAuthLoading: $isAuthLoading, interestsData: $interestsData, starterPackData: $starterPackData, wallpaperData: $wallpaperData, skipInterests: $skipInterests, skipStarterPack: $skipStarterPack, navRequest: $navRequest, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $OnboardingV2StateCopyWith<$Res>  {
  factory $OnboardingV2StateCopyWith(OnboardingV2State value, $Res Function(OnboardingV2State) _then) = _$OnboardingV2StateCopyWithImpl;
@useResult
$Res call({
 OnboardingV2Step step, LoadStatus loadStatus, ActionStatus actionStatus, bool isAuthLoading, OnboardingInterestsData interestsData, OnboardingStarterPackData starterPackData, OnboardingWallpaperData wallpaperData, bool skipInterests, bool skipStarterPack, OnboardingV2NavRequest? navRequest, Failure? failure
});


$OnboardingInterestsDataCopyWith<$Res> get interestsData;$OnboardingStarterPackDataCopyWith<$Res> get starterPackData;$OnboardingWallpaperDataCopyWith<$Res> get wallpaperData;

}
/// @nodoc
class _$OnboardingV2StateCopyWithImpl<$Res>
    implements $OnboardingV2StateCopyWith<$Res> {
  _$OnboardingV2StateCopyWithImpl(this._self, this._then);

  final OnboardingV2State _self;
  final $Res Function(OnboardingV2State) _then;

/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? step = null,Object? loadStatus = null,Object? actionStatus = null,Object? isAuthLoading = null,Object? interestsData = null,Object? starterPackData = null,Object? wallpaperData = null,Object? skipInterests = null,Object? skipStarterPack = null,Object? navRequest = freezed,Object? failure = freezed,}) {
  return _then(_self.copyWith(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingV2Step,loadStatus: null == loadStatus ? _self.loadStatus : loadStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,isAuthLoading: null == isAuthLoading ? _self.isAuthLoading : isAuthLoading // ignore: cast_nullable_to_non_nullable
as bool,interestsData: null == interestsData ? _self.interestsData : interestsData // ignore: cast_nullable_to_non_nullable
as OnboardingInterestsData,starterPackData: null == starterPackData ? _self.starterPackData : starterPackData // ignore: cast_nullable_to_non_nullable
as OnboardingStarterPackData,wallpaperData: null == wallpaperData ? _self.wallpaperData : wallpaperData // ignore: cast_nullable_to_non_nullable
as OnboardingWallpaperData,skipInterests: null == skipInterests ? _self.skipInterests : skipInterests // ignore: cast_nullable_to_non_nullable
as bool,skipStarterPack: null == skipStarterPack ? _self.skipStarterPack : skipStarterPack // ignore: cast_nullable_to_non_nullable
as bool,navRequest: freezed == navRequest ? _self.navRequest : navRequest // ignore: cast_nullable_to_non_nullable
as OnboardingV2NavRequest?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}
/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingInterestsDataCopyWith<$Res> get interestsData {
  
  return $OnboardingInterestsDataCopyWith<$Res>(_self.interestsData, (value) {
    return _then(_self.copyWith(interestsData: value));
  });
}/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingStarterPackDataCopyWith<$Res> get starterPackData {
  
  return $OnboardingStarterPackDataCopyWith<$Res>(_self.starterPackData, (value) {
    return _then(_self.copyWith(starterPackData: value));
  });
}/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingWallpaperDataCopyWith<$Res> get wallpaperData {
  
  return $OnboardingWallpaperDataCopyWith<$Res>(_self.wallpaperData, (value) {
    return _then(_self.copyWith(wallpaperData: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnboardingV2State].
extension OnboardingV2StatePatterns on OnboardingV2State {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingV2State value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingV2State() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingV2State value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingV2State():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingV2State value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingV2State() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OnboardingV2Step step,  LoadStatus loadStatus,  ActionStatus actionStatus,  bool isAuthLoading,  OnboardingInterestsData interestsData,  OnboardingStarterPackData starterPackData,  OnboardingWallpaperData wallpaperData,  bool skipInterests,  bool skipStarterPack,  OnboardingV2NavRequest? navRequest,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingV2State() when $default != null:
return $default(_that.step,_that.loadStatus,_that.actionStatus,_that.isAuthLoading,_that.interestsData,_that.starterPackData,_that.wallpaperData,_that.skipInterests,_that.skipStarterPack,_that.navRequest,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OnboardingV2Step step,  LoadStatus loadStatus,  ActionStatus actionStatus,  bool isAuthLoading,  OnboardingInterestsData interestsData,  OnboardingStarterPackData starterPackData,  OnboardingWallpaperData wallpaperData,  bool skipInterests,  bool skipStarterPack,  OnboardingV2NavRequest? navRequest,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _OnboardingV2State():
return $default(_that.step,_that.loadStatus,_that.actionStatus,_that.isAuthLoading,_that.interestsData,_that.starterPackData,_that.wallpaperData,_that.skipInterests,_that.skipStarterPack,_that.navRequest,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OnboardingV2Step step,  LoadStatus loadStatus,  ActionStatus actionStatus,  bool isAuthLoading,  OnboardingInterestsData interestsData,  OnboardingStarterPackData starterPackData,  OnboardingWallpaperData wallpaperData,  bool skipInterests,  bool skipStarterPack,  OnboardingV2NavRequest? navRequest,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingV2State() when $default != null:
return $default(_that.step,_that.loadStatus,_that.actionStatus,_that.isAuthLoading,_that.interestsData,_that.starterPackData,_that.wallpaperData,_that.skipInterests,_that.skipStarterPack,_that.navRequest,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingV2State implements OnboardingV2State {
  const _OnboardingV2State({required this.step, required this.loadStatus, required this.actionStatus, required this.isAuthLoading, required this.interestsData, required this.starterPackData, required this.wallpaperData, required this.skipInterests, required this.skipStarterPack, this.navRequest, this.failure});
  

@override final  OnboardingV2Step step;
@override final  LoadStatus loadStatus;
@override final  ActionStatus actionStatus;
@override final  bool isAuthLoading;
@override final  OnboardingInterestsData interestsData;
@override final  OnboardingStarterPackData starterPackData;
@override final  OnboardingWallpaperData wallpaperData;
@override final  bool skipInterests;
@override final  bool skipStarterPack;
@override final  OnboardingV2NavRequest? navRequest;
@override final  Failure? failure;

/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingV2StateCopyWith<_OnboardingV2State> get copyWith => __$OnboardingV2StateCopyWithImpl<_OnboardingV2State>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingV2State&&(identical(other.step, step) || other.step == step)&&(identical(other.loadStatus, loadStatus) || other.loadStatus == loadStatus)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.isAuthLoading, isAuthLoading) || other.isAuthLoading == isAuthLoading)&&(identical(other.interestsData, interestsData) || other.interestsData == interestsData)&&(identical(other.starterPackData, starterPackData) || other.starterPackData == starterPackData)&&(identical(other.wallpaperData, wallpaperData) || other.wallpaperData == wallpaperData)&&(identical(other.skipInterests, skipInterests) || other.skipInterests == skipInterests)&&(identical(other.skipStarterPack, skipStarterPack) || other.skipStarterPack == skipStarterPack)&&(identical(other.navRequest, navRequest) || other.navRequest == navRequest)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,step,loadStatus,actionStatus,isAuthLoading,interestsData,starterPackData,wallpaperData,skipInterests,skipStarterPack,navRequest,failure);

@override
String toString() {
  return 'OnboardingV2State(step: $step, loadStatus: $loadStatus, actionStatus: $actionStatus, isAuthLoading: $isAuthLoading, interestsData: $interestsData, starterPackData: $starterPackData, wallpaperData: $wallpaperData, skipInterests: $skipInterests, skipStarterPack: $skipStarterPack, navRequest: $navRequest, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$OnboardingV2StateCopyWith<$Res> implements $OnboardingV2StateCopyWith<$Res> {
  factory _$OnboardingV2StateCopyWith(_OnboardingV2State value, $Res Function(_OnboardingV2State) _then) = __$OnboardingV2StateCopyWithImpl;
@override @useResult
$Res call({
 OnboardingV2Step step, LoadStatus loadStatus, ActionStatus actionStatus, bool isAuthLoading, OnboardingInterestsData interestsData, OnboardingStarterPackData starterPackData, OnboardingWallpaperData wallpaperData, bool skipInterests, bool skipStarterPack, OnboardingV2NavRequest? navRequest, Failure? failure
});


@override $OnboardingInterestsDataCopyWith<$Res> get interestsData;@override $OnboardingStarterPackDataCopyWith<$Res> get starterPackData;@override $OnboardingWallpaperDataCopyWith<$Res> get wallpaperData;

}
/// @nodoc
class __$OnboardingV2StateCopyWithImpl<$Res>
    implements _$OnboardingV2StateCopyWith<$Res> {
  __$OnboardingV2StateCopyWithImpl(this._self, this._then);

  final _OnboardingV2State _self;
  final $Res Function(_OnboardingV2State) _then;

/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? step = null,Object? loadStatus = null,Object? actionStatus = null,Object? isAuthLoading = null,Object? interestsData = null,Object? starterPackData = null,Object? wallpaperData = null,Object? skipInterests = null,Object? skipStarterPack = null,Object? navRequest = freezed,Object? failure = freezed,}) {
  return _then(_OnboardingV2State(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingV2Step,loadStatus: null == loadStatus ? _self.loadStatus : loadStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,isAuthLoading: null == isAuthLoading ? _self.isAuthLoading : isAuthLoading // ignore: cast_nullable_to_non_nullable
as bool,interestsData: null == interestsData ? _self.interestsData : interestsData // ignore: cast_nullable_to_non_nullable
as OnboardingInterestsData,starterPackData: null == starterPackData ? _self.starterPackData : starterPackData // ignore: cast_nullable_to_non_nullable
as OnboardingStarterPackData,wallpaperData: null == wallpaperData ? _self.wallpaperData : wallpaperData // ignore: cast_nullable_to_non_nullable
as OnboardingWallpaperData,skipInterests: null == skipInterests ? _self.skipInterests : skipInterests // ignore: cast_nullable_to_non_nullable
as bool,skipStarterPack: null == skipStarterPack ? _self.skipStarterPack : skipStarterPack // ignore: cast_nullable_to_non_nullable
as bool,navRequest: freezed == navRequest ? _self.navRequest : navRequest // ignore: cast_nullable_to_non_nullable
as OnboardingV2NavRequest?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingInterestsDataCopyWith<$Res> get interestsData {
  
  return $OnboardingInterestsDataCopyWith<$Res>(_self.interestsData, (value) {
    return _then(_self.copyWith(interestsData: value));
  });
}/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingStarterPackDataCopyWith<$Res> get starterPackData {
  
  return $OnboardingStarterPackDataCopyWith<$Res>(_self.starterPackData, (value) {
    return _then(_self.copyWith(starterPackData: value));
  });
}/// Create a copy of OnboardingV2State
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingWallpaperDataCopyWith<$Res> get wallpaperData {
  
  return $OnboardingWallpaperDataCopyWith<$Res>(_self.wallpaperData, (value) {
    return _then(_self.copyWith(wallpaperData: value));
  });
}
}

// dart format on

import 'package:Prism/core/error/failure.dart';

class Result<T> {
  const Result._({this.data, this.failure});

  final T? data;
  final Failure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;

  static Result<T> success<T>(T data) => Result<T>._(data: data);

  static Result<T> error<T>(Failure failure) => Result<T>._(failure: failure);

  R fold<R>({required R Function(T data) onSuccess, required R Function(Failure failure) onFailure}) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    }
    return onFailure(failure ?? const UnknownFailure('Unknown failure'));
  }
}

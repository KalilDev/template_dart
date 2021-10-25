import '../object.dart';
import 'dart:core' hide Type;

class DerivationException implements Exception {
  final Exception e;

  DerivationException(this.e);

  @override
  String toString() => e.toString();
}

class CompileTimeException implements Exception {
  final MetaException exception;

  CompileTimeException(this.exception);
  @override
  String toString() => exception.toString();
}

import '../object.dart';
import '../grammar.dart';
import '../syntax.dart';
import '../derivation.dart';
import 'package:tuple/tuple.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

class DerivationException implements Exception {
  final Exception e;

  DerivationException(this.e);

  String toString() => e.toString();
}

class CompileTimeException implements Exception {
  final MetaException exception;

  CompileTimeException(this.exception);
  @override
  String toString() => exception.toString();
}

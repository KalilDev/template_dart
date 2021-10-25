import '../object.dart';
import 'dart:core' hide Type;

import '../syntax.dart';

abstract class DeriverSignature<T> {
  bool areArgsValid(List<MetaObject> arguments);
  MetaException buildException(List<MetaObject> arguments) =>
      InvalidArgumentsException(arguments, this);
  T instantiateConfiguration(List<MetaObject> arguments);
}

class NoArgumentsDeriverSignature extends DeriverSignature<void> {
  @override
  bool areArgsValid(List<MetaObject> arguments) => arguments.isEmpty;

  @override
  void instantiateConfiguration(List<MetaObject> arguments) {}

  @override
  String toString() => 'Ø';
}

class InvalidArgumentsException extends MetaException {
  final List<MetaObject> arguments;
  final DeriverSignature signature;

  InvalidArgumentsException(this.arguments, this.signature);

  @override
  String toString() => 'InvalidArgumentsException: the arguments '
      '[${arguments.join(',')}] cannot be assigned to the signature $signature';
}

abstract class UnorderedArgumentsSignature<T> extends DeriverSignature<T> {
  Set<Type> get argumentTypes;

  @override
  bool areArgsValid(List<MetaObject> arguments) {
    for (final argument in arguments) {
      final assignable =
          argumentTypes.any((type) => isTypeAssignable(argument.type, type));
      if (!assignable) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'unordered{${argumentTypes.map(printer).join(',')}}';
}

abstract class OrderedArgumentsSignature<T> extends DeriverSignature<T> {
  List<Type> get argumentTypes;

  @override
  bool areArgsValid(List<MetaObject> arguments) {
    if (arguments.length > argumentTypes.length) {
      return false;
    }
    for (var i = 0; i < argumentTypes.length; i++) {
      final type = argumentTypes[i];
      if (i >= arguments.length) {
        if (!isTypeAssignable(MetaType.$Null.dartValue, type)) {
          return false;
        }
        continue;
      }
      if (!isTypeAssignable(arguments[i].type, type)) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => '[${argumentTypes.map(printer).join(',')}]';
}

class PositionalArgumentsSignature
    extends OrderedArgumentsSignature<Map<String, MetaObject>> {
  final Map<String, Type> arguments;

  PositionalArgumentsSignature(this.arguments);

  @override
  late final List<Type> argumentTypes = arguments.values.toList();

  @override
  Map<String, MetaObject> instantiateConfiguration(List<MetaObject> arguments) {
    final argNames = this.arguments.keys.toList();
    return {
      for (var i = 0; i < argNames.length; i++)
        argNames[i]: arguments.length > i ? arguments[i] : MetaObject.$null
    };
  }

  @override
  String toString() =>
      '[${arguments.entries.map((e) => '${e.key} :: ${printer(e.value)}').join(',')}]';
}

abstract class UncheckedArgumentsSignature<T> extends DeriverSignature<T> {
  @override
  bool areArgsValid(List<MetaObject> arguments) => true;
}

class RawArgumentsSignature
    extends UncheckedArgumentsSignature<List<MetaObject>> {
  @override
  List<MetaObject> instantiateConfiguration(List<MetaObject> arguments) =>
      arguments;
}

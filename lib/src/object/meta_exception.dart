import '../syntax.dart';
import 'meta_object.dart';
import 'dart:core' hide Type;

class MetaException extends MetaObject {
  @override
  String toString() => '$runtimeType';
  @override
  MetaObject access(String name) => throw UnimplementedError();

  @override
  MetaObject call(List<MetaObject> args) => throw UnimplementedError();

  @override
  get dartValue => throw UnimplementedError();

  @override
  Type get type => throw UnimplementedError();
}

class NullCallException extends MetaException {
  final String name;
  final List<MetaObject> args;

  NullCallException(this.name, this.args);
  @override
  String toString() => '$runtimeType: with name: $name and args: $args';
}

class NullAccessException extends MetaException {
  final String name;

  NullAccessException(this.name);
  @override
  String toString() => '$runtimeType: with name: $name';
}

class NoSuchThing extends MetaException {
  final Identifier name;

  NoSuchThing(this.name);

  @override
  String toString() => '$runtimeType: with name: ${name.contents}';
}

class TypeException extends MetaException {}

class NoSuchFieldException extends MetaException {
  final String name;

  NoSuchFieldException(this.name);
  @override
  String toString() => '$runtimeType: with $name';
}

class NotCallableException extends MetaException {
  @override
  final Type type;
  NotCallableException(this.type);
  @override
  String toString() => '$runtimeType: ${printer(type)}';
}

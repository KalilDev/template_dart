import '../compilation.dart';
import '../syntax.dart';
import 'meta_exception.dart';
import 'meta_type.dart';
import 'dart:core' hide Type;

abstract class MetaObject {
  const MetaObject();
  Type get type;

  MetaObject access(String name);
  MetaObject call(List<MetaObject> args);
  dynamic get dartValue;
  static final MetaObject $null = MetaNull._();
  static final MetaObject $true = MetaBool._(true);
  static final MetaObject $false = MetaBool._(false);
  String toString() =>
      'MetaObject(${dartValue != this ? 'dartValue: $dartValue, ' : ''}type: ${printer(type)})';
}

class MetaBool extends MetaObject {
  MetaBool._(this.dartValue);

  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  MetaObject call(List<MetaObject> args) => NullCallException(toString(), args);

  @override
  final Type type = MetaType.$bool.dartValue;

  @override
  final bool dartValue;
}

class MetaNull extends MetaObject {
  MetaNull._();
  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  MetaObject call(List<MetaObject> args) => NullCallException(toString(), args);

  @override
  final Type type = MetaType.$Null.dartValue;

  @override
  final dartValue = null;
}

class MetaString extends MetaObject {
  final String dartValue;

  MetaString(this.dartValue);
  @override
  MetaObject access(String name) => throw UnimplementedError();

  @override
  MetaObject call(List<MetaObject> args) => throw UnimplementedError();

  @override
  final Type type = MetaType.$String.dartValue;
}

class MetaDouble extends MetaObject {
  final double dartValue;

  MetaDouble(this.dartValue);
  @override
  MetaObject access(String name) => throw UnimplementedError();

  @override
  MetaObject call(List<MetaObject> args) => throw UnimplementedError();

  @override
  final Type type = MetaType.$double.dartValue;
}

class MetaInt extends MetaObject {
  final int dartValue;

  MetaInt(this.dartValue);
  @override
  MetaObject access(String name) => throw UnimplementedError();

  @override
  MetaObject call(List<MetaObject> args) => throw UnimplementedError();

  @override
  final Type type = MetaType.$int.dartValue;
}

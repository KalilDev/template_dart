import 'dart:core' hide Type;

import '../syntax.dart';
import 'meta_exception.dart';
import 'meta_object.dart';
import 'meta_type.dart';

class _Field extends MetaObject {
  final MetaObject Function() getter;

  _Field(this.getter);
  @override
  MetaObject access(String name) => getter().access(name);

  @override
  MetaObject call(List<MetaObject> args) => getter().call(args);

  @override
  get dartValue => getter().dartValue;

  @override
  Type get type => getter().dartValue;
}

abstract class InteropObject<Self> extends MetaObject {
  @override
  MetaObject access(String name) {
    if (methods.containsKey(name)) {
      return methods[name]!;
    }
    if (acessors.containsKey(name)) {
      return _Field(acessors[name]!);
    }
    return NullAccessException(name);
  }

  @override
  MetaObject call(List<MetaObject> args) {
    final method = methods['call'];
    if (method == null) {
      return NullCallException(toString(), args);
    }
    return method.call(args);
  }

  @override
  Self get dartValue => this as Self;

  Map<String, InteropMethod> get methods;
  Map<String, MetaObject Function()> get acessors;
}

class InteropMethod extends MetaObject {
  InteropMethod(this.dartValue);

  MetaObject call(List<MetaObject> args) => dartValue.call(args);

  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  final MetaObject Function(List<MetaObject>) dartValue;

  @override
  Type get type => _0t('Function');
}

class CheckedInteropMethod extends InteropMethod {
  final List<Type> argumentTypes;

  CheckedInteropMethod(
      this.argumentTypes, MetaObject Function(List<MetaObject> args) function)
      : super(function);

  @override
  MetaObject call(List<MetaObject> args) {
    for (final argAndType in zip(argumentTypes, args)) {
      final type = argAndType.item1;
      final arg = argAndType.item2;
      if (!isTypeAssignable(arg.type, type)) {
        return TypeException();
      }
    }
    return dartValue(args);
  }
}

class MetaMarker<Self extends MetaMarker<Self>> extends MetaObject {
  const MetaMarker();

  @override
  MetaObject access(String name) => NoSuchFieldException(name);

  @override
  MetaObject call(List<MetaObject> args) => NotCallableException(type);

  @override
  Self get dartValue => this as Self;

  @override
  Type get type => _Nt('MetaMarker', [_0t('$Self')]);
}

abstract class MetaMarkerOrGroupMarker<
    Self extends MetaMarkerOrGroupMarker<Self>> extends MetaObject {
  final List<MetaObject>? args;
  const MetaMarkerOrGroupMarker([this.args]);

  Self withArgs(List<MetaObject> args);

  @override
  MetaObject access(String name) => NoSuchFieldException(name);

  @override
  MetaObject call(List<MetaObject> args) =>
      this.args == null ? withArgs(args) : NotCallableException(type);

  @override
  Self get dartValue => this as Self;

  @override
  Type get type => _Nt('MetaMarkerOrGroupMarker', [_0t('$Self')]);
}

class MetaGroupMarker<Self extends MetaGroupMarker<Self>> extends MetaObject {
  final List<MetaObject> args;
  const MetaGroupMarker(this.args);

  @override
  MetaObject access(String name) => NoSuchFieldException(name);

  @override
  MetaObject call(List<MetaObject> args) => NotCallableException(type);

  @override
  Self get dartValue => this as Self;

  @override
  Type get type => _Nt('MetaGroupMarker', [_0t('$Self')]);
}

InstantiatedType _0t(String name, [bool nullable = false]) =>
    _Nt(name, [], nullable);
InstantiatedType _Nt(String name, List<Type> args, [bool nullable = false]) =>
    InstantiatedType(Identifier(name), args, nullable);

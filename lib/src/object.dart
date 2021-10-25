import 'ast.dart';
import 'compilation.dart';
import 'token.dart';
import 'package:tuple/tuple.dart';
import 'dart:core' hide Type;

abstract class MetaObject {
  const MetaObject();
  Type get type;

  MetaObject access(String name);
  MetaObject call(List<MetaObject> args);
  dynamic get dartValue;
  static final MetaObject $null = _MetaNull();
  static final MetaObject $true = _MetaBool(true);
  static final MetaObject $false = _MetaBool(false);
  String toString() =>
      'MetaObject(${dartValue != this ? 'dartValue: $dartValue, ' : ''}type: ${printer(type)})';
}

class NoSuchFieldException extends MetaException {
  final String name;

  NoSuchFieldException(this.name);
  @override
  String toString() => '$runtimeType: with $name';
}

class NotCallableException extends MetaException {
  final Type type;
  NotCallableException(this.type);
  @override
  String toString() => '$runtimeType: ${printer(type)}';
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

class MetaLangInterpreter {
  static final Map<String, MetaObject> initialEnviroment = {
    'null': MetaObject.$null,
    'true': MetaObject.$true,
    'false': MetaObject.$false,
    'void': MetaType.$void,
    'dynamic': MetaType.$dynamic,
    'Never': MetaType.$Never,
    'int': MetaType.$int,
    'bool': MetaType.$bool,
    'double': MetaType.$double,
    'String': MetaType.$String,
    'Null': MetaType.$Null,
    'Type': MetaType.$Type,
    'Object': MetaType.$Object,
    'runtimeType': InteropMethod((args) => MetaType(args.single.type)),
  };
  MetaObject eval(Expression exp, Map<String, MetaObject> enviroment) {
    if (exp is Identifier) {
      return enviroment[exp.contents] ?? NoSuchThing(exp);
    }
    if (exp is Call) {
      final args = exp.arguments.map((e) => eval(e, enviroment)).toList();
      final argExceptions = args.whereType<MetaException>();
      if (argExceptions.isNotEmpty) {
        return argExceptions.first;
      }
      final calee = eval(exp.calee, enviroment);
      if (calee is MetaException) {
        return calee;
      }
      return calee.call(args);
    }
    if (exp is Access) {
      final target = eval(exp.target, enviroment);
      if (target is MetaException) {
        return target;
      }
      return target.access(exp.accessed.contents);
    }
    if (exp is Literal) {
      switch (exp.token.kind) {
        case TokenKind.StringLiteral:
          return MetaString(exp.token.content);
        case TokenKind.DoubleLiteral:
          return MetaDouble(double.parse(exp.token.content));
        case TokenKind.IntLiteral:
          return MetaInt(int.parse(exp.token.content));
        default:
          throw StateError('');
      }
    }
    if (exp is Type) {
      return MetaType(exp);
    }
    throw TypeError();
  }
}

class CompileTimeException implements Exception {
  final MetaException exception;

  CompileTimeException(this.exception);
  @override
  String toString() => exception.toString();
}

class InvalidDeriveSpecExpressionTypeException extends MetaException {}

class DeriveSpec extends InteropObject<DeriveSpec> {
  final String name;
  final List<MetaObject>? args;

  DeriveSpec(this.name, this.args);

  @override
  Map<String, MetaObject Function()> get acessors => const {};

  @override
  Map<String, InteropMethod> get methods => {
        'call': InteropMethod((args) => this.args != null
            ? TypeException()
            : DeriveSpec(
                name,
                args,
              ))
      };

  @override
  Type get type => _Nt('DeriveSpec', [_0t(name)]);
}

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

class MetaType extends MetaObject {
  MetaType(this.dartValue);

  static final MetaType $void = MetaType(_0t('void'));
  static final MetaType $dynamic = MetaType(_0t('dynamic'));
  static final MetaType $Never = MetaType(_0t('Never'));
  static final MetaType $int = MetaType(_0t('int'));
  static final MetaType $bool = MetaType(_0t('bool'));
  static final MetaType $double = MetaType(_0t('double'));
  static final MetaType $String = MetaType(_0t('String'));
  static final MetaType $Null = MetaType(_0t('Null'));
  static final MetaType $Type = MetaType(_0t('Type'));
  static final MetaType $Object = MetaType(_0t('Object'));

  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  MetaObject call(List<MetaObject> args) => NullCallException(toString(), args);

  @override
  final Type dartValue;

  @override
  Type get type => _0t('Type');
  String toString() => printer(dartValue);
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

Iterable<Tuple2<A, B>> zip<A, B>(Iterable<A> as, Iterable<B> bs) sync* {
  final ia = as.iterator, ib = bs.iterator;
  while (ia.moveNext() && ib.moveNext()) {
    yield Tuple2(ia.current, ib.current);
  }
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

bool isTypeAssignable(Type type, Type to) {
  if (type is InstantiatedType && to is InstantiatedType) {
    if (!to.isNullable && type.isNullable) {
      return false;
    }
    if (to.name.contents != type.name.contents) {
      return false;
    }
    if (to.typeParameters.length != type.typeParameters.length) {
      return false;
    }
    return zip(type.typeParameters, to.typeParameters)
        .every((ts) => isTypeAssignable(ts.item1, ts.item2));
  }
  return false;
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

class _MetaBool extends MetaObject {
  _MetaBool(this.dartValue);

  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  MetaObject call(List<MetaObject> args) => NullCallException(toString(), args);

  @override
  final Type type = MetaType.$bool.dartValue;

  @override
  final bool dartValue;
}

class _MetaNull extends MetaObject {
  @override
  MetaObject access(String name) => NullAccessException(name);

  @override
  MetaObject call(List<MetaObject> args) => NullCallException(toString(), args);

  @override
  final Type type = MetaType.$Null.dartValue;

  @override
  final dartValue = null;
}

class MetaException extends MetaObject {
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
  String toString() => '$runtimeType: with name: $name and args: $args';
}

class NullAccessException extends MetaException {
  final String name;

  NullAccessException(this.name);
  String toString() => '$runtimeType: with name: $name';
}

class NoSuchThing extends MetaException {
  final Identifier name;

  NoSuchThing(this.name);

  String toString() => '$runtimeType: with name: ${name.contents}';
}

class TypeException extends MetaException {}

InstantiatedType _0t(String name, [bool nullable = false]) =>
    _Nt(name, [], nullable);
InstantiatedType _Nt(String name, List<Type> args, [bool nullable = false]) =>
    InstantiatedType(Identifier(name), args, nullable);

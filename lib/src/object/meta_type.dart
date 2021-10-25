import 'package:tuple/tuple.dart';

import 'meta_object.dart';
import 'meta_exception.dart';
import '../syntax.dart';

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
  @override
  String toString() => printer(dartValue);
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

Iterable<Tuple2<A, B>> zip<A, B>(Iterable<A> as, Iterable<B> bs) sync* {
  final ia = as.iterator, ib = bs.iterator;
  while (ia.moveNext() && ib.moveNext()) {
    yield Tuple2(ia.current, ib.current);
  }
}

// ignore: non_constant_identifier_names
InstantiatedType _0t(String name, [bool nullable = false]) =>
    _Nt(name, [], nullable);
// ignore: non_constant_identifier_names
InstantiatedType _Nt(String name, List<Type> args, [bool nullable = false]) =>
    InstantiatedType(Identifier(name), args, nullable);

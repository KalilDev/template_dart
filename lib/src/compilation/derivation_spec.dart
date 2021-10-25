import '../object.dart';
import '../syntax.dart';

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

InstantiatedType _0t(String name, [bool nullable = false]) =>
    _Nt(name, [], nullable);
InstantiatedType _Nt(String name, List<Type> args, [bool nullable = false]) =>
    InstantiatedType(Identifier(name), args, nullable);

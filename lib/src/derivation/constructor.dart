part of 'derivation.dart';

class _Named extends MetaMarkerOrGroupMarker<_Named> {
  const _Named([List<MetaObject>? args]) : super(args);
  static const instance = _Named(null);

  @override
  _Named withArgs(List<MetaObject> args) => _Named(args);
}

class _Positional extends MetaMarkerOrGroupMarker<_Positional> {
  const _Positional([List<MetaObject>? args]) : super(args);
  static const instance = _Positional(null);

  @override
  _Positional withArgs(List<MetaObject> args) => _Positional(args);
}

class _Auto extends MetaMarkerOrGroupMarker<_Auto> {
  const _Auto([List<MetaObject>? args]) : super(args);
  static const instance = _Auto(null);

  @override
  _Auto withArgs(List<MetaObject> args) => _Auto(args);
}

class ConstructorDeriver extends SimpleDeriver<ConstructorConfiguration> {
  ConstructorDeriver() : super('Constructor');
  @override
  final DeriverSignature<ConstructorConfiguration> signature =
      ConstructorDeriverSignature();

  @override
  late final Map<String, MetaObject> additionalEnviroment = {
    ...super.additionalEnviroment,
    'Named': _Named.instance,
    'Positional': _Positional.instance,
    'Auto': _Auto.instance,
  };

  @override
  void deriveDataClass(
    DataClass klass,
    DartClassBuilder bdr,
    ProgramContext ctx,
    ConstructorConfiguration args,
  ) {
    super.deriveDataClass(klass, bdr, ctx, args);
    bdr.builder.constructors.clear();
    final constant = bdr.builder.fields.build().every((field) =>
        field.modifier == FieldModifier.final$ ||
        field.modifier == FieldModifier.constant ||
        (field.modifier == FieldModifier.var$ && field.static));
    if (bdr.builder.constructors.isNotEmpty) {
      throw StateError('');
    }
    if (klass.isSupertype) {
      // Add the '_' const constructor so that subclasses can be constant.
      bdr.builder.constructors.add(Constructor((b) => b
        ..constant = constant
        ..name = '_'));
      return;
    }
    final refs = (klass.body?.refs ?? []);
    final defs = args.defs.map((def) => def.kind == ConstructorKind.auto
        ? ConstructorDef(
            def.name,
            (klass.body?.refs.length ?? 0) > 2
                ? ConstructorKind.named
                : ConstructorKind.positional)
        : def);
    for (final constructorDef in defs) {
      final isNamed = constructorDef.kind == ConstructorKind.named;
      final parameters = refs.map(
        (e) => Parameter(
          (b) {
            final name = e.name.contents;
            final isPrivate = name.startsWith('_');
            b
              ..name = withoutUnderlines(name)
              ..toThis = !isPrivate
              ..named = isNamed
              ..type = isPrivate ? refer(dartPrinter(e.type)) : null
              ..required = isNamed && !e.type.isNullable;
          },
        ),
      );
      bdr.builder.constructors.add(
        Constructor(
          (bdr) => bdr
            ..constant = constant
            ..name = constructorDef.name
            ..optionalParameters.addAll(isNamed ? parameters : [])
            ..requiredParameters.addAll(!isNamed ? parameters : [])
            ..initializers.addAll(refs
                .map((ref) => ref.name.contents)
                .where(hasUnderline)
                .map((e) => Code('$e = ${withoutUnderlines(e)}')))
            ..initializers.add(b.Code('super._()')),
        ),
      );
    }
  }
}

enum ConstructorKind {
  auto,
  positional,
  named,
}

class ConstructorDef {
  final String? name;
  final ConstructorKind kind;

  ConstructorDef(this.name, this.kind);
}

class ConstructorConfiguration {
  final List<ConstructorDef> defs;

  ConstructorConfiguration(this.defs);
}

class ConstructorDeriverSignature
    extends UnorderedArgumentsSignature<ConstructorConfiguration> {
  @override
  Set<Type> get argumentTypes => throw UnimplementedError();

  @override
  ConstructorConfiguration instantiateConfiguration(
      List<MetaObject> arguments) {
    final result = <ConstructorDef>[];
    for (final arg in arguments) {
      if (arg is _Auto) {
        result.add(ConstructorDef((arg.args?.single as MetaString?)?.dartValue,
            ConstructorKind.auto));
      }
      if (arg is _Named) {
        result.add(ConstructorDef((arg.args?.single as MetaString?)?.dartValue,
            ConstructorKind.named));
      }
      if (arg is _Positional) {
        result.add(ConstructorDef((arg.args?.single as MetaString?)?.dartValue,
            ConstructorKind.positional));
      }
    }
    if (result.isEmpty) {
      result.add(ConstructorDef(null, ConstructorKind.auto));
    }
    return ConstructorConfiguration(result);
  }
}

abstract class Maybe<T extends Object> {
  const Maybe._();

  R visit<R>({required R Function(T _value) just, required R Function() none});
  Maybe<R> map<R extends Object>(
      R Function(
    T v,
  )
          fn) {
    return visit(just: (v) => Just(fn(v)), none: () => None());
  }

  Maybe<R> bind<R extends Object>(
      Maybe<R> Function(
    T v,
  )
          fn) {
    return visit(just: (v) => fn(v), none: () => None());
  }
}

class Just<T extends Object> extends Maybe<T> {
  const Just(T value)
      : _value = value,
        super._();

  final T _value;

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      just(_value);
}

class None<T extends Object> extends Maybe<T> {
  const None() : super._();

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      none();
}

import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'package:tuple/tuple.dart';
import '../compilation.dart';
import '../syntax.dart';
import '../object.dart';
import 'derivers.dart';
import 'signature.dart';

class _Serializable extends MetaMarkerOrGroupMarker<_Serializable> {
  const _Serializable(List<MetaObject>? args) : super(args);
  static _Serializable constructor(List<MetaObject> args) =>
      _Serializable(args);
  static const instance = _Serializable(null);

  @override
  _Serializable withArgs(List<MetaObject> args) => constructor(args);
}

class _WithoutWireTypeInfo extends MetaMarker<_WithoutWireTypeInfo> {
  const _WithoutWireTypeInfo();
  static const instance = _WithoutWireTypeInfo();
}

class _PreserveGenerics extends MetaMarker<_PreserveGenerics> {
  const _PreserveGenerics();
  static const instance = _PreserveGenerics();
}

class _WithWireTypeInfo extends MetaMarker<_WithWireTypeInfo> {
  const _WithWireTypeInfo();
  static const instance = _WithWireTypeInfo();
}

class _Builder extends MetaMarkerOrGroupMarker<_Builder> {
  const _Builder(List<MetaObject>? args) : super(args);
  static _Builder constructor(List<MetaObject> args) => _Builder(args);
  static const instance = _Builder(null);

  @override
  _Builder withArgs(List<MetaObject> args) => constructor(args);
}

class _Constructor extends MetaGroupMarker<_Constructor> {
  _Constructor(List<MetaObject> args) : super(args);
  static _Constructor constructor(List<MetaObject> args) => _Constructor(args);
}

class _Named extends MetaMarker<_Named> {
  const _Named();
  static const instance = _Named();
}

class _Positional extends MetaMarker<_Positional> {
  const _Positional();
  static const instance = _Positional();
}

class _Auto extends MetaMarker<_Auto> {
  const _Auto();
  static const instance = _Auto();
}

enum _SerializationKind {
  none,
  auto,
  withWireInfo,
  withoutWireInfo,
}

enum BuiltConstructorKind {
  auto,
  positional,
  named,
  builder,
}

class BuiltConstructor {
  final String? name;
  final BuiltConstructorKind kind;

  BuiltConstructor(this.name, this.kind);
}

class BuiltConfiguration {
  final Type? builderType;
  final _SerializationKind serializationKind;
  final bool serializablePreserveGenerics;
  final List<BuiltConstructor> builtConstructor;

  const BuiltConfiguration(
    this.builderType,
    this.serializationKind,
    this.serializablePreserveGenerics,
    this.builtConstructor,
  );
}

class BuiltDeriverSignature
    extends UnorderedArgumentsSignature<BuiltConfiguration> {
  @override
  final Set<Type> argumentTypes = {
    _Serializable.instance.type,
    _Builder.instance.type,
    _Constructor([]).type,
  };

  @override
  BuiltConfiguration instantiateConfiguration(List<MetaObject> arguments) {
    final builderType = arguments
        .maybeSingleOfType<_Builder>()
        ?.args!
        .single
        .as<MetaType>()
        .dartValue;
    final serializable = arguments.maybeSingleOfType<_Serializable>();
    _SerializationKind? type;
    if (serializable == null) {
      type = _SerializationKind.none;
    } else {
      final args = serializable.args ?? [_Auto.instance];
      if (args.maybeSingleOfType<_WithWireTypeInfo>() != null) {
        type = _SerializationKind.withWireInfo;
      }
      if (args.maybeSingleOfType<_WithoutWireTypeInfo>() != null) {
        type = _SerializationKind.withoutWireInfo;
      }
      type ??= _SerializationKind.auto;
    }
    final preserveGenerics =
        serializable?.args?.maybeSingleOfType<_PreserveGenerics>() != null;
    final constructors = <BuiltConstructor>[];
    for (final e in arguments.whereType<_Constructor>()) {
      final name = e.args.maybeSingleOfType<MetaString>()?.dartValue;
      BuiltConstructorKind kind;
      if (e.args.maybeSingleOfType<_Named>() != null) {
        kind = BuiltConstructorKind.named;
      } else if (e.args.maybeSingleOfType<_Positional>() != null) {
        kind = BuiltConstructorKind.positional;
      } else if (e.args.maybeSingleOfType<_Builder>() != null) {
        kind = BuiltConstructorKind.builder;
      } else {
        kind = BuiltConstructorKind.auto;
      }
      constructors.add(BuiltConstructor(name, kind));
    }
    if (constructors.isEmpty) {
      constructors.add(BuiltConstructor(null, BuiltConstructorKind.auto));
    }
    return BuiltConfiguration(
      builderType,
      type,
      preserveGenerics,
      constructors,
    );
  }
}

class BuiltDeriver extends SimpleDeriver<BuiltConfiguration> {
  BuiltDeriver() : super('Built');

  @override
  Map<String, MetaObject> get additionalEnviroment => {
        ...super.additionalEnviroment,
        'Serializable': _Serializable.instance,
        'WithWireTypeInfo': _WithWireTypeInfo.instance,
        'WithoutWireTypeInfo': _WithoutWireTypeInfo.instance,
        'PreserveGenerics': _PreserveGenerics.instance,
        'Constructor': InteropMethod(_Constructor.constructor),
        'Builder': _Builder.instance,
        'Named': _Named.instance,
        'Positional': _Positional.instance,
        'Auto': _Auto.instance,
      };

  @override
  void deriveDataClass(DataClass klass, DartClassBuilder bdr,
      ProgramContext context, BuiltConfiguration args) {
    bdr.builder.abstract = true;
    final builderType = args.builderType ?? _builderTypeFromBuilt(klass);
    final builtType = InstantiatedType(
      Identifier('Built'),
      [klass.type, builderType],
      false,
    );
    final syntheticBuiltType = InstantiatedType(
        Identifier('_\$' + klass.type.name.contents),
        klass.type.typeParameters,
        false);
    final isSupertypeOfUnion = klass.isSupertype && klass.isUnion;

    if (klass.isUnion) {
      if (!isSupertypeOfUnion) {
        // Do not extend the union type, implement it instead.
        final supertype = bdr.builder.extend!;
        bdr.builder.extend = null;
        bdr.builder.implements.add(supertype);
        // Add the mixins to the subtypes too, because they wont be inherited
        final mixins = bdr.klass.parentDeclaration.typeDeclaration.mixed ?? [];
        bdr.builder.mixins.addAll(mixins.map(dartPrinter).map(b.refer));
      }
    }

    if (!isSupertypeOfUnion) {
      bdr.builder.implements.add(b.refer(dartPrinter(builtType)));
    }

    // Field to abstract getter conversion
    final fields = bdr.builder.fields.build();
    final fieldDatas = {
      for (final field in fields)
        field.name: Tuple2(field.docs, field.annotations),
    };
    final refs = klass.body?.refs ?? [];
    final refNames = refs.map((e) => e.name.contents).toSet();
    bdr.builder.fields.where((field) => !refNames.contains(field.name));
    bdr.builder.methods.addAll(refs.map((e) => b.Method((bdr) => bdr
      ..name = e.name.contents
      ..docs.replace(fieldDatas[e.name]?.item1 ?? <String>[])
      ..annotations.replace(fieldDatas[e.name]?.item2 ?? <b.Expression>[])
      ..type = MethodType.getter
      ..annotations.addAll((e.annotations ?? [])
          .map((e) => dartPrinter(e.expression))
          .map((e) => CodeExpression(b.Code(e))))
      ..returns = refer(dartPrinter(e.type)))));

    if (bdr.builder.constructors.length != 1) {
      bdr.builder.constructors.add(b.Constructor((b) => b.name = '_'));
    } else {
      throw StateError('');
    }

    final refCount = refs.length;
    final constructors = args.builtConstructor.map(
      (e) => e.kind == BuiltConstructorKind.auto
          ? BuiltConstructor(
              e.name,
              refCount <= 2
                  ? BuiltConstructorKind.positional
                  : refCount >= 10
                      ? BuiltConstructorKind.builder
                      : BuiltConstructorKind.named)
          : e,
    );

    if (!isSupertypeOfUnion) {
      var hadBuilder = false;
      for (final e in constructors) {
        final isBuilder = e.kind == BuiltConstructorKind.builder;
        hadBuilder = isBuilder || hadBuilder;
        switch (e.kind) {
          case BuiltConstructorKind.builder:
            bdr.builder.constructors.add(
              _builderConstructor(
                e.name,
                klass,
                builderType,
                syntheticBuiltType,
              ),
            );
            break;
          case BuiltConstructorKind.positional:
            bdr.builder.constructors.add(_positionalOrNamedConstructor(
              e.name,
              syntheticBuiltType,
              refs,
              false,
            ));
            break;
          case BuiltConstructorKind.named:
            bdr.builder.constructors.add(_positionalOrNamedConstructor(
              e.name,
              syntheticBuiltType,
              refs,
              true,
            ));
            break;
          default:
        }
      }
      if (!hadBuilder) {
        bdr.builder.constructors.add(
          _builderConstructor(
            'builder',
            klass,
            builderType,
            syntheticBuiltType,
          ),
        );
      }
    }

    //
    // Serialization
    //
    final serialize = args.serializationKind;
    if (serialize == _SerializationKind.none) {
      return;
    }

    if (!isSupertypeOfUnion) {
      bdr.builder.methods.add(b.Method((bdr) => bdr
        ..name = 'serializer'
        ..static = true
        ..type = MethodType.getter
        ..returns = b.refer(dartPrinter(InstantiatedType(
            Identifier('Serializer'),
            [
              InstantiatedType(
                Identifier(klass.name),
                klass.parentDeclaration.typeDeclaration.type.typeParameters
                    .map((e) => e.constraint ?? MetaType.$Object.dartValue)
                    .toList(),
                false,
              )
            ],
            false)))
        ..lambda = true
        ..body = b.Code('_\$${lowerCamelCase(klass.name)}Serializer')));
    }
    var serializationKind = args.serializationKind;
    serializationKind = serializationKind == _SerializationKind.auto
        ? klass.parentDeclaration.isUnion
            ? _SerializationKind.withoutWireInfo
            : _SerializationKind.withWireInfo
        : serializationKind;

    if (serializationKind == _SerializationKind.withWireInfo) {
      bdr.builder.methods.addAll(jsonMethodsFor(
        klass,
        wireTypeInfo: true,
        preserveGenerics: args.serializablePreserveGenerics,
        isSupertypeOfUnion: isSupertypeOfUnion,
      ));
    } else if (serializationKind == _SerializationKind.withoutWireInfo) {
      bdr.builder.methods.addAll(jsonMethodsFor(
        klass,
        wireTypeInfo: false,
        preserveGenerics: args.serializablePreserveGenerics,
        isSupertypeOfUnion: isSupertypeOfUnion,
      ));
    } else {
      throw UnimplementedError();
    }
    super.deriveDataClass(klass, bdr, context, args);
  }

  Constructor _positionalOrNamedConstructor(
      String? name,
      InstantiatedType syntheticBuiltType,
      List<DataReference> refs,
      bool isNamed) {
    final params = refs.map(
      (e) => Parameter(
        (bdr) => bdr
          ..name = e.name.contents
          ..type = b.refer(dartPrinter(e.type))
          ..named = isNamed
          ..required = isNamed && !e.type.isNullable,
      ),
    );
    return Constructor(
      (bdr) => bdr
        ..name = name
        ..factory = true
        ..lambda = true
        ..body = b.refer(dartPrinter(syntheticBuiltType)).call([
          b.CodeExpression(b.Code('(__\$bdr)=>__\$bdr' +
              (refs.isEmpty ? '' : '..') +
              refs
                  .map((e) => e.name.contents)
                  .map((e) => '$e = $e')
                  .join('..')))
        ]).code
        ..requiredParameters.addAll(params),
    );
  }

  Constructor _builderConstructor(
    String? name,
    DataClass klass,
    Type builderType,
    Type syntheticBuiltType,
  ) =>
      Constructor((bdr) => bdr
        ..factory = true
        ..name = name
        ..lambda = true
        ..body = b
            .refer(dartPrinter(syntheticBuiltType))
            .call([b.refer('updates')]).code
        ..optionalParameters.add(
          Parameter(
            (bdr) => bdr
              ..name = 'updates'
              ..type = b.FunctionType(
                (bdr) => bdr
                  ..isNullable = true
                  ..returnType = b.refer('void')
                  ..requiredParameters.add(
                    b.refer(
                      dartPrinter(builderType),
                    ),
                  ),
              ),
          ),
        ));

  @override
  DeriverSignature<BuiltConfiguration> get signature => BuiltDeriverSignature();
}

String fullTypeFrom(ParameterizedType type, bool preserveGenerics) {
  String typeToFullType(Type type) {
    if (type is InstantiatedType) {
      final args = type.typeParameters.map(typeToFullType);
      return 'FullType(${type.name.contents}, [${args.join(', ')}])';
    }
    throw TypeError();
  }

  final args = type.typeParameters.map((e) => preserveGenerics
      ? 'FullType(${e.name.contents})'
      : typeToFullType(e.constraint ?? MetaType.$Object.dartValue));
  return 'FullType(${type.name.contents}, [${args.join(', ')}])';
}

Type instantiateToBounds(ParameterizedType type) => InstantiatedType(
    type.name,
    type.typeParameters
        .map((e) => e.constraint ?? MetaType.$Object.dartValue)
        .toList(),
    false);

List<b.Method> jsonMethodsFor(DataClass klass,
    {required bool wireTypeInfo,
    bool preserveGenerics = false,
    required bool isSupertypeOfUnion}) {
  final specifiedType = wireTypeInfo
      ? 'FullType.unspecified'
      : fullTypeFrom(
          klass.parentDeclaration.typeDeclaration.type, preserveGenerics);
  final returnType = preserveGenerics
      ? klass.type
      : instantiateToBounds(klass.parentDeclaration.typeDeclaration.type);
  return [
    b.Method((bdr) => bdr
      ..name = 'toJson'
      ..returns = b.refer('Map<String, dynamic>')
      ..lambda = !isSupertypeOfUnion
      ..body = isSupertypeOfUnion ? null : b.Code('''
      serializers.serialize(this, specifiedType: $specifiedType)
          as Map<String, dynamic>
          ''')),
    if (!isSupertypeOfUnion)
      b.Method((bdr) => bdr
        ..name = 'fromJson'
        ..static = true
        ..lambda = true
        ..returns = b.refer(dartPrinter(returnType))
        ..requiredParameters.add(b.Parameter((bdr) => bdr
          ..type = b.refer('Map<String, dynamic>')
          ..name = 'json'))
        ..types.addAll(preserveGenerics
            ? klass.type.typeParameters.map(dartPrinter).map(b.refer)
            : [])
        ..body = b.Code('''
      serializers.deserialize(json, specifiedType: $specifiedType)
          as ${dartPrinter(returnType)}
      '''))
  ];
}

extension on Object {
  T as<T>() => this as T;
}

extension _ItE<T> on Iterable<T> {
  T? get maybeSingle => length == 1 ? single : null;
  T? get maybeFirst => isEmpty ? null : first;
  E? maybeSingleOfType<E>() => whereType<E>().maybeSingle;
}

InstantiatedType _builderTypeFromBuilt(DataClass klass) {
  return InstantiatedType(
      Identifier(klass.name + 'Builder'),
      klass.parentDeclaration.typeDeclaration.type
          .instantiation()
          .typeParameters,
      false);
}

InstantiatedType _builtTypeFromBuilder(DataClass klass) {
  const suffix = 'Builder';
  if (!klass.name.endsWith(suffix)) {
    throw StateError('Invalid builder name!');
  }
  final name = klass.name.substring(0, klass.name.indexOf(suffix));
  return InstantiatedType(
      Identifier(name),
      klass.parentDeclaration.typeDeclaration.type
          .instantiation()
          .typeParameters,
      false);
}

void builderDataClassDeriver(
  DataClass klass,
  DartClassBuilder bdr,
  ProgramContext ctx,
  List<dynamic> args,
) {
  final builtType =
      (args.maybeFirst as MetaType?)?.dartValue ?? _builtTypeFromBuilder(klass);
  final builderType = InstantiatedType(
      Identifier('Builder'),
      [builtType, klass.parentDeclaration.typeDeclaration.type.instantiation()],
      false);
  final builtName = builtType.as<InstantiatedType>().name.contents;
  if (bdr.klass.parentDeclaration.isUnion) {
    // Implement the parent builder type
    final parentBuilder = InstantiatedType(
      Identifier(builtName + 'Builder'),
      klass.type.as<InstantiatedType>().typeParameters,
      false,
    );
    bdr.builder.implements.add(b.refer(dartPrinter(parentBuilder)));
  }
  bdr.builder
    ..fields.map((f) => f.rebuild((f) => f.modifier = FieldModifier.var$))
    ..implements.add(refer(dartPrinter(builderType)));
}

String lowerCamelCase(String s) {
  if (s[0].toLowerCase() != s[0]) {
    return '${s[0].toLowerCase()}${s.substring(1)}';
  }
  return s;
}

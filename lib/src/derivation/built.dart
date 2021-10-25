import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'package:code_builder/code_builder.dart' as b;
import '../compilation.dart';
import '../ast.dart';
import '../object.dart';
import 'derivation.dart';

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

class BuiltConfiguration {
  final Type? builderType;
  final _SerializationKind serializationKind;
  final bool serializablePreserveGenerics;

  const BuiltConfiguration(
    this.builderType,
    this.serializationKind,
    this.serializablePreserveGenerics,
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
  BuiltConfiguration instantiateConfiguration(List<MetaObject> args) {
    final builderType = args
        .maybeSingleOfType<_Builder>()
        ?.args!
        .single
        .as<MetaType>()
        .dartValue;
    final serializable = args.maybeSingleOfType<_Serializable>();
    _SerializationKind? type;
    if (serializable == null) {
      type = _SerializationKind.none;
    } else {
      final args = serializable.args!;
      if (args.maybeSingleOfType<_WithWireTypeInfo>() != null) {
        type = _SerializationKind.withWireInfo;
      }
      if (args.maybeSingleOfType<_WithoutWireTypeInfo>() != null) {
        type = _SerializationKind.withoutWireInfo;
      }
    }
    final preserveGenerics =
        serializable?.args?.maybeSingleOfType<_PreserveGenerics>() != null;
    return BuiltConfiguration(
      builderType,
      type ?? _SerializationKind.none,
      preserveGenerics,
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
    final builderType = args.builderType ?? _builderTypeFromBuilt(klass);
    final builtType = InstantiatedType(
      Identifier('Built'),
      [klass.type, builderType],
      false,
    );
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
    bdr.builder.fields.clear();
    bdr.builder.methods
        .addAll((klass.body?.refs ?? []).map((e) => b.Method((bdr) => bdr
          ..name = e.name.contents
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
    final serialize = args.serializationKind;
    if (serialize == _SerializationKind.none) {
      return;
    }

    if (!isSupertypeOfUnion) {
      bdr.builder.fields.add(b.Field((bdr) => bdr
        ..name = 'serializer'
        ..static = true
        ..type = b.refer(dartPrinter(InstantiatedType(
            Identifier('Serializer'),
            klass.parentDeclaration.typeDeclaration.type.typeParameters
                .map((e) => e.constraint ?? MetaType.$Object.dartValue)
                .toList(),
            false)))
        ..modifier = b.FieldModifier.final$
        ..assignment = b.Code('_\$${lowerCamelCase(klass.name)}Serializer')));
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

extension _<T> on Iterable<T> {
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

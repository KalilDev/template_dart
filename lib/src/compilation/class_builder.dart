import '../object.dart';
import '../grammar.dart';
import '../syntax.dart';
import '../derivation.dart';
import 'package:tuple/tuple.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

import 'utils.dart';

class DataClass {
  final DataDeclaration parentDeclaration;
  final DataRecord? body;
  final List<Annotation>? annotations;
  final List<Metadata>? metadatas;
  final Documentation? documentation;
  final InstantiatedType type;

  bool get isSupertype =>
      name == parentDeclaration.typeDeclaration.type.name.contents;
  String get name => type.name.contents;
  bool get isUnion => parentDeclaration.isUnion;

  bool get isUnionSupertype => isSupertype && isUnion;

  DataClass(
    this.parentDeclaration,
    this.body,
    this.annotations,
    this.metadatas,
    this.documentation,
    this.type,
  );
}

class DartClassBuilder {
  final DataClass klass;
  final b.ClassBuilder builder;

  DartClassBuilder._(this.klass, this.builder);
  factory DartClassBuilder(DataClass klass) {
    final builder = b.ClassBuilder();
    builder.name = klass.name;
    if (!klass.isSupertype && klass.isUnion) {
      builder.extend = b.Reference(
        dartPrinter(
          parameterizedTypeToInstantiated(
            klass.parentDeclaration.typeDeclaration.type,
          ),
        ),
      );
    }
    if (klass.isSupertype) {
      final type = klass.parentDeclaration.typeDeclaration;
      if (type.extended != null) {
        builder.extend = b.refer(dartPrinter(type.extended!));
      }
      if (type.implemented != null) {
        builder.implements
            .addAll(type.implemented!.map(dartPrinter).map(b.refer));
      }
      if (type.mixed != null) {
        builder.mixins.addAll(type.mixed!.map(dartPrinter).map(b.refer));
      }
    }
    builder.types.addAll(klass
        .parentDeclaration.typeDeclaration.type.typeParameters
        .map(dartPrinter)
        .map((e) => b.Reference(e)));
    if (klass.isUnionSupertype) {
      builder.abstract = true;
    }
    if (klass.body != null) {
      builder.fields.addAll(klass.body!.refs.map(referenceToField));
    }
    builder
      ..docs.addAll(documentationFrom(klass.documentation))
      ..annotations
          .addAll(klass.annotations?.map(annotationToExpression) ?? []);
    return DartClassBuilder._(klass, builder);
  }
}

import '../object.dart';
import '../grammar.dart';
import '../syntax.dart';
import '../derivation.dart';
import 'package:tuple/tuple.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

InstantiatedType parameterizedTypeToInstantiated(ParameterizedType type) =>
    InstantiatedType(
        type.name,
        type.typeParameters
            .map((e) => InstantiatedType(e.name, [], false))
            .toList(),
        false);

b.Parameter referenceToParameter(DataReference reference) =>
    b.Parameter((bdr) => bdr
      ..name = reference.name.contents
      ..type = b.refer(dartPrinter(reference.type)));
b.Expression annotationToExpression(Annotation ann) =>
    b.CodeExpression(b.Code(dartPrinter(ann.expression)));
Iterable<b.Expression> annotationsFrom(AnnotatedNode node) =>
    node.annotations?.map(annotationToExpression) ?? [];
Iterable<String> documentationFrom(Documentation? doc) =>
    doc?.comments.map((t) => t.content) ?? [];
Iterable<String> documentationsFrom(DocumentedNode node) =>
    documentationFrom(node.comments);

b.Field referenceToField(DataReference reference) => b.Field((bdr) => bdr
  ..name = reference.name.contents
  ..type = b.refer(dartPrinter(reference.type))
  ..docs.addAll(documentationsFrom(reference))
  ..annotations.addAll(annotationsFrom(reference)));

b.Parameter referenceToNamedParameter(DataReference reference, bool required) =>
    b.Parameter((bdr) => bdr
      ..name = reference.name.contents
      ..named = true
      ..required = required
      ..type = b.refer(dartPrinter(reference.type))
      ..docs.addAll(documentationsFrom(reference))
      ..annotations.addAll(annotationsFrom(reference)));

void applyFunctionDefinition(b.MethodBuilder bdr, FunctionDefinition def) => bdr
  ..name = def.name.contents
  ..returns =
      def.returnType == null ? null : b.refer(dartPrinter(def.returnType!))
  ..static = def.isStatic
  ..types.addAll(def.parameters.typeParameters.map(dartPrinter).map(b.refer))
  ..optionalParameters.addAll(def.parameters.positioned
      .where((e) => e.item2)
      .map((e) => e.item1)
      .map(referenceToParameter))
  ..requiredParameters.addAll(def.parameters.positioned
      .where((e) => !e.item2)
      .map((e) => e.item1)
      .map(referenceToParameter))
  ..optionalParameters.addAll(def.parameters.named.values
      .map((e) => referenceToNamedParameter(e, !e.type.isNullable)));

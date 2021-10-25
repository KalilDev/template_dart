import '../object.dart';
import '../grammar.dart';
import '../syntax.dart';
import '../derivation.dart';
import 'package:tuple/tuple.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

import 'class_builder.dart';

class CompilationEnviroment {
  final Map<String, DataDeclaration> dataDeclarations;
  final Map<String, DataClass> dataTypes;
  final Map<String, DartClassBuilder> dartClassBuilders;

  CompilationEnviroment(
    this.dataDeclarations,
    this.dataTypes,
    this.dartClassBuilders,
  );
  late final Map<String, MetaType> newTypes = {
    ...dataTypes.map((key, value) => MapEntry(
          key,
          MetaType(
              value.parentDeclaration.typeDeclaration.type.instantiation()),
        ))
  };
  late final Map<String, dynamic> enviroment = {
    'false': false,
    'true': true,
    'null': null,
    'Null': InstantiatedType(Identifier('null'), [], false),
    'Never': InstantiatedType(Identifier('Never'), [], false),
    'void': InstantiatedType(Identifier('void'), [], false),
    'int': InstantiatedType(Identifier('int'), [], false),
    'double': InstantiatedType(Identifier('double'), [], false),
    'bool': InstantiatedType(Identifier('bool'), [], false),
    ...dataTypes.map((key, value) => MapEntry(
          key,
          value.parentDeclaration.typeDeclaration.type.instantiation(),
        ))
  };
}

class InitialCompilationEnviroment {
  final Map<String, DataDeclaration> dataDeclarations;
  final Map<String, DataClass> dataTypes;

  InitialCompilationEnviroment(this.dataDeclarations, this.dataTypes);

  factory InitialCompilationEnviroment.empty() =>
      InitialCompilationEnviroment({}, {});
  DataDeclaration? _currentDeclaration;
  CompilationEnviroment build() => CompilationEnviroment(
      dataDeclarations,
      dataTypes,
      dataTypes.map((k, v) => MapEntry(k, DartClassBuilder(v)))
        ..addAll(dataDeclarations.map((k, v) {
          final body = v.body;
          return MapEntry(
              k,
              // Either the Union supertype or the class body.
              DartClassBuilder(DataClass(
                  v,
                  body is DataClassBody ? body.body : null,
                  v.annotations,
                  v.metadata,
                  v.comments,
                  v.typeDeclaration.type.instantiation())));
        })));
}

class CompilationEnviromentBuilder
    extends ASTVisitor<InitialCompilationEnviroment>
    with ThrowingASTVisitorMixin<InitialCompilationEnviroment> {
  @override
  InitialCompilationEnviroment visitDataClassBody(DataClassBody node,
      [InitialCompilationEnviroment? context]) {
    context ??= InitialCompilationEnviroment.empty();
    final parent = context._currentDeclaration!;
    final parentName = parent.typeDeclaration.type.name;
    return context
      ..dataTypes[parentName.contents] = DataClass(
        parent,
        node.body,
        parent.annotations,
        parent.metadata,
        parent.comments,
        parent.typeDeclaration.type.instantiation(),
      );
  }

  @override
  InitialCompilationEnviroment visitDataConstructor(DataConstructor node,
      [InitialCompilationEnviroment? context]) {
    context ??= InitialCompilationEnviroment.empty();
    final parent = context._currentDeclaration!;
    return context
      ..dataTypes[node.name.contents] = DataClass(
          parent,
          node.body,
          node.annotations,
          node.metadata,
          node.comments,
          InstantiatedType(
              node.name,
              parent.typeDeclaration.type.instantiation().typeParameters,
              false));
  }

  @override
  InitialCompilationEnviroment visitDataDeclaration(DataDeclaration node,
      [InitialCompilationEnviroment? context]) {
    context ??= InitialCompilationEnviroment.empty();
    context = context
      ..dataDeclarations[node.typeDeclaration.type.name.contents] = node;
    context._currentDeclaration = node;
    context = visitDataBody(node.body, context);
    context._currentDeclaration = null;
    return context;
  }

  @override
  InitialCompilationEnviroment visitDataUnionBody(DataUnionBody node,
      [InitialCompilationEnviroment? context]) {
    context ??= InitialCompilationEnviroment.empty();
    final parent = context._currentDeclaration!;
    final name = parent.typeDeclaration.type.name;
    context.dataTypes[name.contents] = DataClass(
      parent,
      null,
      parent.annotations,
      parent.metadata,
      parent.comments,
      parent.typeDeclaration.type.instantiation(),
    );
    return node.constructors
        .fold(context, (context, node) => visitDataConstructor(node, context));
  }

  @override
  InitialCompilationEnviroment visitMetaProgram(MetaProgram node,
      [InitialCompilationEnviroment? context]) {
    context ??= InitialCompilationEnviroment.empty();
    return node.declarations
        .whereType<DataDeclaration>()
        .fold(context, (context, node) => visitDataDeclaration(node, context));
  }
}

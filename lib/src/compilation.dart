import 'object.dart';
import 'token.dart';
import 'visitors.dart';

import 'ast.dart';
import 'package:tuple/tuple.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;
import 'derivation/derivation.dart';

class DataClass {
  final DataDeclaration parentDeclaration;
  final DataRecord? body;
  final List<Annotation>? annotations;
  final List<Metadata>? metadatas;
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
    this.type,
  );
}

InstantiatedType parameterizedTypeToInstantiated(ParameterizedType type) =>
    InstantiatedType(
        type.name,
        type.typeParameters
            .map((e) => InstantiatedType(e.name, [], false))
            .toList(),
        false);
final _prettyPrinter = PrettyPrintVisitor();
final _dartPrinter = DartLikePrettyPrintVisitor();
String dartPrinter(ASTNode node) => _dartPrinter.visitNode(node).toString();
String printer(ASTNode node) => _prettyPrinter.visitNode(node).toString();
String printTokens(TokenList list) {
  final buff = StringBuffer();
  PrettyPrintVisitor.writeTokenList(list, buff);
  return buff.toString();
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
      ..docs.addAll(documentationsFrom(klass.parentDeclaration))
      ..annotations
          .addAll(klass.annotations?.map(annotationToExpression) ?? []);
    return DartClassBuilder._(klass, builder);
  }
}

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
              DartClassBuilder(DataClass(
                  v,
                  body is DataClassBody ? body.body : null,
                  body is DataClassBody ? v.annotations : null,
                  body is DataClassBody ? v.metadata : null,
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

class CompilationInterpreter {
  final Map<String, Deriver> derivers;
  final Map<String, MetaObject> additionalEnviroment;
  CompilationInterpreter._(
    this.derivers,
    this.additionalEnviroment,
  );
  factory CompilationInterpreter(
    List<Deriver> derivers, [
    Map<String, MetaObject> additionalEnviroment = const {},
  ]) {
    final deriveEnv = <String, Deriver>{};
    for (final deriver in derivers) {
      if (deriveEnv.containsKey(deriver.name)) {
        throw StateError('Cannot add derivers with the same name!');
      }
      deriveEnv[deriver.name] = deriver;
    }
    return CompilationInterpreter._(deriveEnv, additionalEnviroment);
  }
  final MetaLangInterpreter interpreter = MetaLangInterpreter();

  DeriveSpec evalDerive(
    Expression exp,
    Map<String, MetaObject> initialEnviroment,
    Map<String, MetaObject> Function(String) getEnviromentForDeriver,
  ) {
    if (exp is Identifier) {
      return DeriveSpec(exp.contents, []);
    }
    if (exp is Call && exp.calee is Identifier) {
      final deriverName = (exp.calee as Identifier).contents;

      final args = exp.arguments
          .map((e) => interpreter.eval(e, {
                ...initialEnviroment,
                ...getEnviromentForDeriver(deriverName),
              }))
          .toList();
      final argExceptions = args.whereType<MetaException>();
      if (argExceptions.isNotEmpty) {
        throw CompileTimeException(argExceptions.first);
      }
      return DeriveSpec(deriverName, args);
    }
    throw CompileTimeException(InvalidDeriveSpecExpressionTypeException());
  }

  Map<String, dynamic> createContexts(ProgramContext context) =>
      derivers.map((k, v) => MapEntry(k, v.createContext(context)));
  Map<String, MetaObject> _getDeriverEnviroment(String deriver) =>
      derivers[deriver]!.additionalEnviroment;

  void deriveProgram(
    TopLevelDerive? topLevelDerive,
    ProgramContext context,
  ) {
    final env = {
      ...MetaLangInterpreter.initialEnviroment,
      ...context.enviroment.newTypes,
      ...additionalEnviroment,
    };
    final specs = topLevelDerive?.expressions
            .map((d) => evalDerive(d, env, _getDeriverEnviroment)) ??
        [];
    final specArgs = {for (final d in specs) d.name: d.args};
    derivers.forEach((key, value) {
      final wasUsed = context.usedDerivers.contains(key);
      final args = specArgs[key] ?? [];
      if (!value.signature.areArgsValid(args)) {
        throw CompileTimeException(value.signature.buildException(args));
      }
      try {
        value.deriveProgram(
          wasUsed,
          context,
          value.signature.instantiateConfiguration(args),
        );
      } on Exception catch (e) {
        throw DerivationException(e);
      }
    });
  }

  void deriveDataDecl(
    List<Expression> derivations,
    DataDeclaration declaration,
    Set<DartClassBuilder> builders,
    ProgramContext context,
    Map<String, dynamic> contexts,
  ) {
    final env = {
      ...MetaLangInterpreter.initialEnviroment,
      ...context.enviroment.newTypes,
      ...additionalEnviroment,
    };
    final specs =
        derivations.map((d) => evalDerive(d, env, _getDeriverEnviroment));
    for (final spec in specs) {
      context.usedDerivers.add(spec.name);
      final deriver = derivers[spec.name]!;
      final args = spec.args ?? [];

      if (!deriver.signature.areArgsValid(args)) {
        throw CompileTimeException(deriver.signature.buildException(args));
      }
      try {
        deriver.deriveDataDeclaration(
          declaration,
          builders,
          contexts[spec.name]!,
          deriver.signature.instantiateConfiguration(args),
        );
      } on Exception catch (e) {
        throw DerivationException(e);
      }
    }
  }

  void deriveDataClass(
    List<Expression> derivations,
    DartClassBuilder builder,
    ProgramContext context,
    Map<String, dynamic> contexts,
  ) {
    final env = {
      ...MetaLangInterpreter.initialEnviroment,
      ...context.enviroment.newTypes,
      ...additionalEnviroment,
    };
    final specs =
        derivations.map((d) => evalDerive(d, env, _getDeriverEnviroment));
    for (final spec in specs) {
      context.usedDerivers.add(spec.name);
      final deriver = derivers[spec.name]!;
      final args = spec.args ?? [];

      if (!deriver.signature.areArgsValid(args)) {
        throw CompileTimeException(deriver.signature.buildException(args));
      }

      try {
        deriver.deriveDataClass(
          builder.klass,
          builder,
          contexts[spec.name]!,
          deriver.signature.instantiateConfiguration(args),
        );
      } on Exception catch (e) {
        throw DerivationException(e);
      }
    }
  }
}

class DerivationException implements Exception {
  final Exception e;

  DerivationException(this.e);

  String toString() => e.toString();
}

b.Parameter referenceToParameter(DataReference reference) =>
    b.Parameter((bdr) => bdr
      ..name = reference.name.contents
      ..type = b.refer(dartPrinter(reference.type)));
b.Expression annotationToExpression(Annotation ann) =>
    b.CodeExpression(b.Code(dartPrinter(ann.expression)));
Iterable<b.Expression> annotationsFrom(AnnotatedNode node) =>
    node.annotations?.map(annotationToExpression) ?? [];
Iterable<String> documentationsFrom(DocumentedNode node) =>
    node.comments?.comments.map((t) => t.content) ?? [];

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

class Compiler {
  final CompilationInterpreter interpreter;

  Compiler(this.interpreter);

  void _compileDataDeclarations(
    Iterable<DataDeclaration> declarations,
    ProgramContext programContext,
    Map<String, dynamic> contexts,
  ) {
    for (final declaration
        in programContext.enviroment.dataDeclarations.values) {
      final builders = declaration.body is DataClassBody
          ? {
              programContext.enviroment.dartClassBuilders[
                  declaration.typeDeclaration.type.name.contents]!
            }
          : (declaration.body as DataUnionBody)
              .constructors
              .map((e) => e.name)
              .followedBy([declaration.typeDeclaration.type.name])
              .map((e) =>
                  programContext.enviroment.dartClassBuilders[e.contents]!)
              .toSet();
      if (declaration.deriveClause?.derivations.isNotEmpty ?? false) {
        interpreter.deriveDataDecl(
          declaration.deriveClause!.derivations,
          declaration,
          builders,
          programContext,
          contexts,
        );
      }
    }
  }

  void _compileDataClasses(
    Iterable<DartClassBuilder> builders,
    ProgramContext programContext,
    Map<String, dynamic> contexts,
  ) {
    for (final builder in builders) {
      final derives = builder.klass.parentDeclaration.deriveClause?.derivations;
      if (derives?.isNotEmpty ?? false) {
        interpreter.deriveDataClass(
          derives!,
          builder,
          programContext,
          contexts,
        );
      }
    }
  }

  void _compileRedirectMember(RedirectMember member, b.ClassBuilder bdr) {
    final method = b.Method((bdr) {
      final def = member.definition;
      final body = dartPrinter(member.target) +
          '(' +
          def.parameters.positioned
              .map((e) => e.item1.name.contents)
              .followedBy(def.parameters.named.keys
                  .map((e) => e.contents)
                  .map((e) => '$e: $e'))
              .join(',') +
          ')';
      applyFunctionDefinition(bdr, def);
      bdr
        ..body = b.Code(body)
        ..lambda = true;
    });
    bdr.methods.add(method);
  }

  void _compileFunctionMember(FunctionMember member, b.ClassBuilder bdr) {
    final method = b.Method((bdr) {
      final def = member.definition;
      final body = member.body;
      applyFunctionDefinition(bdr, def);
      if (body.qualifier != null) {
        final b.MethodModifier mod;
        switch (body.qualifier) {
          case 'sync*':
            mod = b.MethodModifier.syncStar;
            break;
          case 'async*':
            mod = b.MethodModifier.asyncStar;
            break;
          case 'async':
            mod = b.MethodModifier.async;
            break;
          default:
            throw StateError('');
        }
        bdr.modifier = mod;
      }
      bdr
        ..body = body.body != null ? b.Code(printTokens(body.body!.body)) : null
        ..lambda = body.body?.isExpression;
    });
    bdr.methods.add(method);
  }

  void _compileOnDeclarations(
    Iterable<OnDeclaration> declarations,
    ProgramContext programContext,
  ) {
    for (final onDeclaration in declarations) {
      final dbuilder = programContext
          .enviroment.dartClassBuilders[onDeclaration.typeName.contents]!;
      final bdr = dbuilder.builder;
      final klass = dbuilder.klass;
      final parentDeclaration = klass.parentDeclaration;
      for (final member in onDeclaration.members) {
        if (member is TypeModifierMember) {
          final types = member.types.map(dartPrinter).map(b.refer);
          if (member.isImplement) {
            bdr.implements.addAll(types);
          } else {
            bdr.mixins.addAll(types);
          }
        }
        if (member is FunctionMember) {
          _compileFunctionMember(member, bdr);
        }
        if (member is RedirectMember) {
          _compileRedirectMember(member, bdr);
        }
        if (member is FactoryOrConstructorMember) {
          if (parentDeclaration.deriveClause?.derivations
                  .containsCallee('Built') ??
              false) {
            assert(member.name == null || member.name?.contents == '_');
          }

          bdr.constructors
              .removeWhere((c) => (c.name ?? '') == (member.name ?? ''));
          bdr.constructors
              .add(b.Constructor((b) => b..name = member.name?.contents));
        }
      }
    }
  }

  b.Library compile(MetaProgram program) {
    final initialEnviroment =
        CompilationEnviromentBuilder().visitMetaProgram(program);
    final enviroment = initialEnviroment.build();
    final libraryBuilder = b.LibraryBuilder();
    final programContext = ProgramContext(
      libraryBuilder,
      program,
      enviroment,
      {},
      interpreter.interpreter,
    );
    final contexts = interpreter.createContexts(programContext);

    _compileDataDeclarations(
      enviroment.dataDeclarations.values,
      programContext,
      contexts,
    );
    _compileDataClasses(
      enviroment.dartClassBuilders.values,
      programContext,
      contexts,
    );
    _compileOnDeclarations(
      program.declarations.whereType(),
      programContext,
    );
    interpreter.deriveProgram(program.derive, programContext);
    libraryBuilder.body.addAll(
        enviroment.dartClassBuilders.values.map((e) => e.builder.build()));
    return libraryBuilder.build();
  }
}

extension on Iterable<Expression> {
  bool Function(Expression) _inner(String name) => (e) {
        if (e is Identifier) {
          return e.contents == name;
        }
        if (e is Call) {
          return _inner(name)(e.calee);
        }
        return false;
      };
  bool containsCallee(String name) => any(_inner(name));
}

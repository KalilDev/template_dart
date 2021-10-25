import '../syntax.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

import 'class_builder.dart';
import 'compilation_interpreter.dart';
import 'context.dart';
import 'enviroment.dart';
import 'utils.dart';

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

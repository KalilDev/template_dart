import '../object.dart';
import '../syntax.dart';
import '../derivation.dart';
import 'dart:core' hide Type;

import 'class_builder.dart';
import 'context.dart';
import 'derivation_spec.dart';
import 'exception.dart';
import 'meta_lang_interpreter.dart';

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
      if (!derivers.containsKey(spec.name)) {
        throw DerivationException(
            Exception('There is no Derivator named ${spec.name}!'));
      }
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

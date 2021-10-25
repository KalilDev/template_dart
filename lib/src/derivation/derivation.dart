import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'package:meta/meta.dart';
import 'hive.dart';
import '../compilation.dart';
import '../ast.dart';
import '../object.dart';

import 'built.dart';
part 'constructor.dart';
part 'other.dart';
part 'utils.dart';
part 'visit.dart';

abstract class Context {}

class ProgramContext extends Context {
  final b.LibraryBuilder dartLibrary;
  final MetaProgram program;
  final CompilationEnviroment enviroment;
  final Set<String> usedDerivers;
  final MetaLangInterpreter interpreter;

  ProgramContext(
    this.dartLibrary,
    this.program,
    this.enviroment,
    this.usedDerivers,
    this.interpreter,
  );
}

abstract class Deriver<T extends Context, Args> {
  final String name;

  const Deriver(this.name);

  DeriverSignature<Args> get signature;

  T createContext(ProgramContext programContext);

  @mustCallSuper

  /// Called for each data class
  void deriveDataClass(
    DataClass klass,
    DartClassBuilder bdr,
    T context,
    Args args,
  ) {}

  @mustCallSuper

  /// Called for each data declaration
  void deriveDataDeclaration(
    DataDeclaration klass,
    Set<DartClassBuilder> bdr,
    T context,
    Args args,
  ) {}

  @mustCallSuper

  /// Called for each program.
  void deriveProgram(bool wasUsedForData, T context, Args args) {}

  @mustCallSuper
  Map<String, MetaObject> get additionalEnviroment => {
        '__deriverName': MetaString(name),
      };
}

abstract class DeriverSignature<T> {
  bool areArgsValid(List<MetaObject> arguments);
  MetaException buildException(List<MetaObject> arguments) =>
      InvalidArgumentsException(arguments, this);
  T instantiateConfiguration(List<MetaObject> arguments);
}

class NoArgumentsDeriverSignature extends DeriverSignature<void> {
  @override
  bool areArgsValid(List<MetaObject> arguments) => arguments.isEmpty;

  @override
  void instantiateConfiguration(List<MetaObject> arguments) => null;

  @override
  String toString() => 'Ø';
}

class InvalidArgumentsException extends MetaException {
  final List<MetaObject> arguments;
  final DeriverSignature signature;

  InvalidArgumentsException(this.arguments, this.signature);

  @override
  String toString() => 'InvalidArgumentsException: the arguments '
      '[${arguments.join(',')}] cannot be assigned to the signature $signature';
}

abstract class UnorderedArgumentsSignature<T> extends DeriverSignature<T> {
  Set<Type> get argumentTypes;

  @override
  bool areArgsValid(List<MetaObject> arguments) {
    for (final argument in arguments) {
      final assignable =
          argumentTypes.any((type) => isTypeAssignable(argument.type, type));
      if (!assignable) {
        return false;
      }
    }
    return true;
  }

  String toString() => 'unordered{${argumentTypes.map(printer).join(',')}}';
}

abstract class OrderedArgumentsSignature<T> extends DeriverSignature<T> {
  List<Type> get argumentTypes;

  @override
  bool areArgsValid(List<MetaObject> arguments) {
    if (arguments.length > argumentTypes.length) {
      return false;
    }
    for (var i = 0; i < argumentTypes.length; i++) {
      final type = argumentTypes[i];
      if (i >= arguments.length) {
        if (!isTypeAssignable(MetaType.$Null.dartValue, type)) {
          return false;
        }
        continue;
      }
      if (!isTypeAssignable(arguments[i].type, type)) {
        return false;
      }
    }
    return true;
  }

  String toString() => '[${argumentTypes.map(printer).join(',')}]';
}

class PositionalArgumentsSignature
    extends OrderedArgumentsSignature<Map<String, MetaObject>> {
  final Map<String, Type> arguments;

  PositionalArgumentsSignature(this.arguments);

  @override
  late final List<Type> argumentTypes = arguments.values.toList();

  @override
  Map<String, MetaObject> instantiateConfiguration(List<MetaObject> arguments) {
    final argNames = this.arguments.keys.toList();
    return {
      for (var i = 0; i < argNames.length; i++)
        argNames[i]: arguments.length > i ? arguments[i] : MetaObject.$null
    };
  }

  String toString() =>
      '[${arguments.entries.map((e) => '${e.key} :: ${printer(e.value)}').join(',')}]';
}

abstract class UncheckedArgumentsSignature<T> extends DeriverSignature<T> {
  @override
  bool areArgsValid(List<MetaObject> arguments) => true;
}

class RawArgumentsSignature
    extends UncheckedArgumentsSignature<List<MetaObject>> {
  @override
  List<MetaObject> instantiateConfiguration(List<MetaObject> arguments) =>
      arguments;
}

abstract class SimpleDeriver<Args> extends Deriver<ProgramContext, Args> {
  const SimpleDeriver(String name) : super(name);

  @override
  ProgramContext createContext(ProgramContext programContext) => programContext;
}

class NoArgsCallbacksDeriver extends SimpleDeriver<void> {
  final NoArgsDataClassDeriver? _deriveDataClass;
  final NoArgsDataDeclarationDeriver? _deriveDataDeclaration;
  final RawArgumentsSignature signature = RawArgumentsSignature();

  NoArgsCallbacksDeriver(
    String name, {
    NoArgsDataClassDeriver? deriveDataClass,
    NoArgsDataDeclarationDeriver? deriveDataDeclaration,
  })  : _deriveDataClass = deriveDataClass,
        _deriveDataDeclaration = deriveDataDeclaration,
        super(name);

  @override
  void deriveDataClass(
    DataClass klass,
    DartClassBuilder bdr,
    ProgramContext context,
    void args,
  ) {
    super.deriveDataClass(klass, bdr, context, args);
    _deriveDataClass?.call(klass, bdr, context);
  }

  @override
  void deriveDataDeclaration(
    DataDeclaration klass,
    Set<DartClassBuilder> bdr,
    ProgramContext context,
    void args,
  ) {
    super.deriveDataDeclaration(klass, bdr, context, args);
    _deriveDataDeclaration?.call(klass, bdr, context);
  }
}

class CallbacksDeriver extends SimpleDeriver<List<MetaObject>> {
  final DataClassDeriver? _deriveDataClass;
  final DataDeclarationDeriver? _deriveDataDeclaration;
  @override
  final RawArgumentsSignature signature = RawArgumentsSignature();

  CallbacksDeriver(
    String name, {
    DataClassDeriver? deriveDataClass,
    DataDeclarationDeriver? deriveDataDeclaration,
  })  : _deriveDataClass = deriveDataClass,
        _deriveDataDeclaration = deriveDataDeclaration,
        super(name);

  @override
  void deriveDataClass(
    DataClass klass,
    DartClassBuilder bdr,
    ProgramContext context,
    List<MetaObject> args,
  ) {
    super.deriveDataClass(klass, bdr, context, args);
    _deriveDataClass?.call(klass, bdr, context, args);
  }

  @override
  void deriveDataDeclaration(
    DataDeclaration klass,
    Set<DartClassBuilder> bdr,
    ProgramContext context,
    List<MetaObject> args,
  ) {
    super.deriveDataDeclaration(klass, bdr, context, args);
    _deriveDataDeclaration?.call(klass, bdr, context, args);
  }
}

typedef NoArgsDataDeclarationDeriver = void Function(
  DataDeclaration,
  Set<DartClassBuilder>,
  ProgramContext,
);
typedef NoArgsDataClassDeriver = void Function(
  DataClass,
  DartClassBuilder,
  ProgramContext,
);
typedef DataDeclarationDeriver = void Function(
  DataDeclaration,
  Set<DartClassBuilder>,
  ProgramContext,
  List<dynamic> args,
);
typedef DataClassDeriver = void Function(
  DataClass,
  DartClassBuilder,
  ProgramContext,
  List<dynamic> args,
);

CompilationInterpreter makeCompilationInterpreter(
        [Map<String, dynamic> additionalEnv = const {}]) =>
    CompilationInterpreter([
      CallbacksDeriver('DebugPrint',
          deriveDataDeclaration: debugPrintDataDeriver),
      VisitDeriver(),
      NoArgsCallbacksDeriver('Final', deriveDataClass: finalDataClassDeriver),
      ConstructorDeriver(),
      BuiltDeriver(),
      HiveDeriver(),
      CallbacksDeriver('Builder', deriveDataClass: builderDataClassDeriver),
    ]);

import 'package:meta/meta.dart';

import '../compilation.dart';
import '../object.dart';
import '../syntax.dart';
import 'signature.dart';

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

abstract class SimpleDeriver<Args> extends Deriver<ProgramContext, Args> {
  const SimpleDeriver(String name) : super(name);

  @override
  ProgramContext createContext(ProgramContext programContext) => programContext;
}

class NoArgsCallbacksDeriver extends SimpleDeriver<void> {
  final NoArgsDataClassDeriver? _deriveDataClass;
  final NoArgsDataDeclarationDeriver? _deriveDataDeclaration;
  @override
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

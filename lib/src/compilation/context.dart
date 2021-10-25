import '../syntax.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'dart:core' hide Type;

import 'enviroment.dart';
import 'meta_lang_interpreter.dart';

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

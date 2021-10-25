library template_dart;

import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'src/compilation.dart';
import 'src/token.dart';
import 'src/derivation/derivation.dart';
import 'src/object.dart';
import 'src/scanner.dart';
import 'src/parser.dart';

export 'src/compilation.dart';
export 'src/token.dart';
export 'src/object.dart';
export 'src/scanner.dart';
export 'src/derivation/derivation.dart';
export 'src/parser.dart';
export 'src/ast.dart';

enum CompileExceptionType {
  scanning,
  parsing,
  deriving,
  evaluating,
}

class MetaprogramCompileException implements Exception {
  final CompileExceptionType type;
  final SourceRange? range;
  final SourceLocation? location;
  final String message;

  MetaprogramCompileException(
    this.type,
    this.range,
    this.location,
    this.message,
  );
}

String compileMetaprogram(String input) {
  final scanner = Scanner(input);
  final tokens = scanner.parse();
  final disallowedTokens = tokens.where((e) => !Parser.isTokenAllowed(e));
  if (disallowedTokens.isNotEmpty) {
    throw MetaprogramCompileException(
      CompileExceptionType.scanning,
      disallowedTokens.first.range,
      null,
      'Unknown token',
    );
  }
  final parser = Parser(tokens);
  try {
    final program = parser.parse();
    final compiler = Compiler(makeCompilationInterpreter());
    final library = compiler.compile(program);
    return library.accept(DartEmitter()).toString();
  } on SyntaxException catch (e) {
    throw MetaprogramCompileException(
      CompileExceptionType.parsing,
      e.atToken.range,
      null,
      e.toString(),
    );
  } on DerivationException catch (e) {
    throw MetaprogramCompileException(
      CompileExceptionType.deriving,
      null,
      null,
      e.toString(),
    );
  } on CompileTimeException catch (e) {
    throw MetaprogramCompileException(
      CompileExceptionType.evaluating,
      null,
      null,
      e.toString(),
    );
  }
}

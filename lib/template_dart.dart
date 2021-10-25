library template_dart;

import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'src/grammar.dart';
import 'src/syntax.dart';
import 'src/compilation.dart';
import 'src/derivation.dart';

export 'src/compilation.dart';
export 'src/derivation.dart';
export 'src/grammar.dart';
export 'src/object.dart';
export 'src/syntax.dart';

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

  @override
  String toString() {
    final buff = StringBuffer();
    buff.write('MetaprogramCompileException:');
    if (range != null) {
      buff.write(' at range: $range');
    }
    if (location != null) {
      buff.write(' at location: $location');
    }
    buff.write(' with message $message');
    return buff.toString();
  }
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
    return library.accept(DartEmitter(useNullSafetySyntax: true)).toString();
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

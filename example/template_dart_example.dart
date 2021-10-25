import 'package:code_builder/code_builder.dart';
import 'package:template_dart/template_dart.dart';

const input = r'''
//
data Maybe<T : Object> implements Monad<T> = Just { _value :: T } | None
    derive(Visit(Cata), Final, Constructor);

on Maybe {
    map<R:Object>(fn :: Function(v :: T) -> R) -> Maybe<R> {
        return visit(just: (v) => Just(fn(v)), none: () => None());
    }
    bind<R:Object>(fn :: Function(v :: T) -> Maybe<R>) -> Maybe<R> {
        return visit(just: (v) => fn(v), none: () => None());
    }
}
''';
void main() {
  final scanner = Scanner(input);
  final tokens = scanner.parse();
  print(tokens.join(','));
  final parser = Parser(tokens);
  final program = parser.parse();

  print('\n\n\n');
  print(printer(program));
  print('\n\n\n');
  final compiler = Compiler(makeCompilationInterpreter());
  final library = compiler.compile(program);
  print(library.accept(DartEmitter()));
}

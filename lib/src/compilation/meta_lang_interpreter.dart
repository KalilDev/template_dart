import '../grammar.dart';
import '../object.dart';
import '../syntax.dart';

class MetaLangInterpreter {
  static final Map<String, MetaObject> initialEnviroment = {
    'null': MetaObject.$null,
    'true': MetaObject.$true,
    'false': MetaObject.$false,
    'void': MetaType.$void,
    'dynamic': MetaType.$dynamic,
    'Never': MetaType.$Never,
    'int': MetaType.$int,
    'bool': MetaType.$bool,
    'double': MetaType.$double,
    'String': MetaType.$String,
    'Null': MetaType.$Null,
    'Type': MetaType.$Type,
    'Object': MetaType.$Object,
    'debugPrint': InteropMethod((args) {
      print('DEBUG: ${args.join(', ')}');
      return args.single;
    }),
    'runtimeType': InteropMethod((args) => MetaType(args.single.type)),
  };
  MetaObject eval(Expression exp, Map<String, MetaObject> enviroment) {
    if (exp is Identifier) {
      return enviroment[exp.contents] ?? NoSuchThing(exp);
    }
    if (exp is Call) {
      final args = exp.arguments.map((e) => eval(e, enviroment)).toList();
      final argExceptions = args.whereType<MetaException>();
      if (argExceptions.isNotEmpty) {
        return argExceptions.first;
      }
      final calee = eval(exp.calee, enviroment);
      if (calee is MetaException) {
        return calee;
      }
      return calee.call(args);
    }
    if (exp is Access) {
      final target = eval(exp.target, enviroment);
      if (target is MetaException) {
        return target;
      }
      return target.access(exp.accessed.contents);
    }
    if (exp is Literal) {
      switch (exp.token.kind) {
        case TokenKind.StringLiteral:
          return MetaString(exp.token.content);
        case TokenKind.DoubleLiteral:
          return MetaDouble(double.parse(exp.token.content));
        case TokenKind.IntLiteral:
          return MetaInt(int.parse(exp.token.content));
        default:
          throw StateError('');
      }
    }
    if (exp is Type) {
      return MetaType(exp);
    }
    throw TypeError();
  }
}

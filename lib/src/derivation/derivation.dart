import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart';
import 'package:code_builder/code_builder.dart' as b;
import 'derivers.dart';
import 'hive.dart';
import '../compilation.dart';
import '../object.dart';
import '../syntax.dart';

import 'signature.dart';
import 'built.dart';
part 'constructor.dart';
part 'other.dart';
part 'utils.dart';
part 'visit.dart';

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

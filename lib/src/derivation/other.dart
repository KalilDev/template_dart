part of 'derivation.dart';

void finalDataClassDeriver(
  DataClass klass,
  DartClassBuilder bdr,
  ProgramContext ctx,
) {
  bdr.builder.fields
      .map((f) => f.rebuild((f) => f.modifier = FieldModifier.final$));
}

void debugPrintDataDeriver(
  DataDeclaration klass,
  Set<DartClassBuilder> bdr,
  ProgramContext ctx,
  List<dynamic> args,
) {
  print('\nDEBUG:');
  print(
      'ArgTypes     : ${args.map((e) => e.type).map((e) => printer(e as Type)).join(', ')}');
  print('Args         : ${args.join(', ')}');
  print('ArgDartValues: ${args.map((e) => e.dartValue).join(', ')}');
}

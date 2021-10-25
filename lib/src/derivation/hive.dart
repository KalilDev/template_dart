import 'dart:core' hide Type;
import 'package:code_builder/code_builder.dart' as b;
import 'derivation.dart';
import '../compilation.dart';
import '../ast.dart';
import '../object.dart';

class HiveDeriver extends SimpleDeriver<void> {
  final DeriverSignature<void> signature = NoArgumentsDeriverSignature();

  HiveDeriver() : super('Hive');

  @override
  void deriveDataClass(DataClass klass, DartClassBuilder bdr,
      ProgramContext context, void args) {
    super.deriveDataClass(klass, bdr, context, args);
    if (klass.isUnionSupertype) {
      return;
    }
    final typeId = klass.metadatas
        ?.map((e) => context.interpreter.eval(e.expression, {}))
        .maybeSingleOfType<MetaInt>()
        ?.dartValue;
    if (typeId == null) {
      return;
    }
    bdr.builder.annotations
        .add(b.refer('HiveType').call([], {'typeId': b.literal(typeId)}));
    final fieldNameIdMap = <String, int>{};
    for (final ref in bdr.klass.body?.refs ?? <DataReference>[]) {
      final fieldId = ref.metadata
          ?.map((e) => context.interpreter.eval(e.expression, {}))
          .maybeSingleOfType<MetaInt>()
          ?.dartValue;
      if (fieldId == null) {
        continue;
      }
      fieldNameIdMap[ref.name.contents] = fieldId;
    }
    bdr.builder.fields.map((field) => fieldNameIdMap.containsKey(field.name)
        ? field.rebuild(
            (bdr) => bdr.annotations.add(
              b.refer('HiveField').call(
                [b.literal(fieldNameIdMap[field.name])],
              ),
            ),
          )
        : field);
    bdr.builder.methods.map((getter) => fieldNameIdMap.containsKey(getter.name)
        ? getter.rebuild(
            (bdr) => bdr.annotations.add(
              b.refer('HiveField').call(
                [b.literal(fieldNameIdMap[getter.name])],
              ),
            ),
          )
        : getter);
  }
}

extension _<T> on Iterable<T> {
  T? get maybeSingle => length == 1 ? single : null;
  T? get maybeFirst => isEmpty ? null : first;
  E? maybeSingleOfType<E>() => whereType<E>().maybeSingle;
}

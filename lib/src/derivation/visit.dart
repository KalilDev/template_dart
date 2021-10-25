part of 'derivation.dart';

void _visitSignatureFor(DataDeclaration decl, MethodBuilder bdr, bool isCata) {
  final body = decl.body as DataUnionBody;
  for (final member in body.constructors) {
    final String args;
    if (isCata) {
      args = (member.body?.refs ?? [])
          .map((e) => '${dartPrinter(e.type)} ${e.name.contents}')
          .join(',');
    } else {
      args = member.name.contents;
    }
    final param = Parameter((b) => b
      ..required = true
      ..named = true
      ..name = toLowerCamelCase(member.name.contents)
      ..type = refer('R Function($args)'));
    bdr.optionalParameters.add(param);
  }
  bdr
    ..types.add(refer('R'))
    ..returns = refer('R');
}

class VisitDeclaration {
  final String name;
  final bool isCata;

  VisitDeclaration(this.name, this.isCata);
}

class VisitConfiguration {
  final List<VisitDeclaration> declarations;

  VisitConfiguration(this.declarations);
}

class _Cata extends MetaMarkerOrGroupMarker<_Cata> {
  const _Cata(List<MetaObject>? args) : super(args);
  static const instance = _Cata(null);

  @override
  _Cata withArgs(List<MetaObject> args) => _Cata(args);
}

class _Visit extends MetaMarkerOrGroupMarker<_Visit> {
  const _Visit(List<MetaObject>? args) : super(args);
  static const instance = _Visit(null);

  @override
  _Visit withArgs(List<MetaObject> args) => _Visit(args);
}

class VisitDeriverSignature
    extends UnorderedArgumentsSignature<VisitConfiguration> {
  @override
  final Set<Type> argumentTypes = {
    _Visit.instance.type,
    _Cata.instance.type,
  };

  @override
  VisitConfiguration instantiateConfiguration(List<MetaObject> arguments) {
    if (arguments.isEmpty) {
      return VisitConfiguration([VisitDeclaration('visit', false)]);
    }
    return VisitConfiguration(arguments.map((e) {
      final args = (e as MetaMarkerOrGroupMarker).args;
      final name = args?.isEmpty ?? true
          ? 'visit'
          : args!.whereType<MetaString>().single.dartValue;
      return VisitDeclaration(name, e is _Cata);
    }).toList());
  }
}

class VisitDeriver extends SimpleDeriver<VisitConfiguration> {
  VisitDeriver() : super('Visit');

  @override
  late final Map<String, MetaObject> additionalEnviroment = {
    ...super.additionalEnviroment,
    'Cata': _Cata.instance,
    'Visit': _Visit.instance,
  };

  @override
  void deriveDataClass(DataClass klass, DartClassBuilder bdr,
      ProgramContext context, VisitConfiguration args) {
    if (!klass.isUnion) {
      throw DerivationException(Exception('Visit is only valid for unions'));
    }
    super.deriveDataClass(klass, bdr, context, args);
    for (final decl in args.declarations) {
      final visitMethod = Method((bdr) {
        _visitSignatureFor(
          klass.parentDeclaration,
          bdr,
          decl.isCata,
        );
        bdr.name = decl.name;
        if (klass.isSupertype) {
          return;
        }
        final b.Code body;
        if (decl.isCata) {
          final members =
              (klass.body?.refs ?? []).map((e) => e.name.contents).join(',');
          body = b.Code(toLowerCamelCase(klass.name) + '($members)');
        } else {
          body = b.Code(toLowerCamelCase(klass.name) + '(this)');
        }
        bdr
          ..lambda = true
          ..annotations.add(refer('override'))
          ..body = body;
      });
      bdr.builder.methods.add(visitMethod);
    }
  }

  @override
  final DeriverSignature<VisitConfiguration> signature =
      VisitDeriverSignature();
}

import '../grammar.dart';

import 'ast.dart';
import 'visitor.dart';

final _prettyPrinter = PrettyPrintVisitor();
final _dartPrinter = DartLikePrettyPrintVisitor();
String dartPrinter(ASTNode node) => _dartPrinter.visitNode(node).toString();
String printer(ASTNode node) => _prettyPrinter.visitNode(node).toString();
String printTokens(TokenList list) {
  final buff = StringBuffer();
  PrettyPrintVisitor.writeTokenList(list, buff);
  return buff.toString();
}

class DartLikePrettyPrintVisitor extends PrettyPrintVisitor {
  @override
  StringBuffer visitDataClassBody(DataClassBody node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitDataConstructor(DataConstructor node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitDataDeclaration(DataDeclaration node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitDataRecord(DataRecord node, [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitDataReference(DataReference node, [StringBuffer? context]) {
    context ??= StringBuffer();

    _visitDocumented(node, context);
    _visitAnnotated(node, context);

    visitType(node.type, context);
    context.write(' ');
    return visitIdentifier(node.name, context);
  }

  @override
  StringBuffer visitDataUnionBody(DataUnionBody node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitDeriveClause(DeriveClause node, [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitFactoryMember(FactoryOrConstructorMember node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitImplementMember(TypeModifierMember node,
          [StringBuffer? context]) =>
      throw UnimplementedError();
  @override
  StringBuffer visitMetaProgram(MetaProgram node, [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitOnDeclaration(OnDeclaration node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitTypeParameter(TypeParameter node, [StringBuffer? context]) {
    context ??= StringBuffer();
    visitIdentifier(node.name, context);
    if (node.constraint == null) {
      return context;
    }
    context.write(' extends ');
    visitType(node.constraint!, context);
    return context;
  }

  @override
  StringBuffer visitIdentifier(Identifier node, [StringBuffer? context]) {
    context ??= StringBuffer();
    return context..write(node.contents);
  }

  @override
  StringBuffer visitLiteral(Literal node, [StringBuffer? context]) {
    context ??= StringBuffer();
    return context..write(node.value);
  }

  @override
  StringBuffer visitFunctionDefinition(FunctionDefinition node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.isStatic) {
      context.write('static ');
    }
    if (node.isGet) {
      context.write('get ');
    }
    if (node.isSet) {
      context.write('set ');
    }
    if (node.returnType != null) {
      visitType(node.returnType!, context);
      context.write(' ');
    }
    visitIdentifier(node.name, context);
    visitFunctionParameters(node.parameters, context);
    return context;
  }

  @override
  StringBuffer visitRedirectMember(RedirectMember node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitTopLevelDerive(TopLevelDerive node,
          [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitMetadata(Metadata node, [StringBuffer? context]) =>
      throw UnimplementedError();

  @override
  StringBuffer visitFunctionType(FunctionType node, [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.returnType != null) {
      visitType(node.returnType!, context);
      context.write(' ');
    }
    visitIdentifier(node.function, context);
    if (node.parameters != null) {
      visitFunctionParameters(node.parameters!, context);
    }
    if (node.isNullable) {
      context.write('?');
    }
    return context;
  }
}

class PrettyPrintVisitor extends ASTVisitor<StringBuffer> {
  @override
  StringBuffer visitDataClassBody(DataClassBody node, [StringBuffer? context]) {
    context ??= StringBuffer();
    return visitDataRecord(node.body, context);
  }

  @override
  StringBuffer visitDataConstructor(DataConstructor node,
      [StringBuffer? context]) {
    context ??= StringBuffer();

    _visitDocumented(node, context);
    _visitAnnotated(node, context);
    _visitMetadated(node, context);

    visitIdentifier(node.name, context);
    if (node.body != null) {
      visitDataRecord(node.body!, context);
    }
    return context;
  }

  @override
  StringBuffer visitDataDeclaration(DataDeclaration node,
      [StringBuffer? context]) {
    context ??= StringBuffer();

    _visitDocumented(node, context);
    _visitAnnotated(node, context);
    _visitMetadated(node, context);

    context.write('data ');
    visitDataTypeDeclaration(node.typeDeclaration, context);
    visitDataBody(node.body, context);
    if (node.deriveClause != null) {
      context.write(' ');
      visitDeriveClause(node.deriveClause!, context);
    }
    return context..write(';');
  }

  @override
  StringBuffer visitDataRecord(DataRecord node, [StringBuffer? context]) {
    context ??= StringBuffer();

    return _writeWrappedNodeList(
      node.refs,
      visitDataReference,
      context,
      WrapAndSeparator.dataRecord,
    );
  }

  @override
  StringBuffer visitDataReference(DataReference node, [StringBuffer? context]) {
    context ??= StringBuffer();

    _visitDocumented(node, context);
    _visitAnnotated(node, context);

    visitIdentifier(node.name, context);
    context.write(' :: ');
    return visitType(node.type, context);
  }

  @override
  StringBuffer visitDataTypeDeclaration(DataTypeDeclaration node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    visitParameterizedType(node.type, context);
    context.write(' ');
    if (node.extended != null) {
      context.write('extends ');
      visitType(node.extended!, context);
      context.write(' ');
    }
    if (node.implemented != null) {
      context.write('implements ');
      _writeWrappedNodeList(
        node.implemented!,
        visitType,
        context,
        WrapAndSeparator.comma,
      );
      context.write(' ');
    }
    if (node.mixed != null) {
      context.write('with ');
      _writeWrappedNodeList(
        node.mixed!,
        visitType,
        context,
        WrapAndSeparator.comma,
      );
      context.write(' ');
    }
    return context;
  }

  @override
  StringBuffer visitDataUnionBody(DataUnionBody node, [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write('= ');
    return _writeWrappedNodeList(
      node.constructors,
      visitDataConstructor,
      context,
      WrapAndSeparator.dataUnionBody,
    );
  }

  @override
  StringBuffer visitDeriveClause(DeriveClause node, [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write('derive');
    _writeWrappedNodeList(
      node.derivations,
      visitExpression,
      context,
      WrapAndSeparator.argumentList,
    );
    return context;
  }

  @override
  StringBuffer visitFactoryMember(FactoryOrConstructorMember node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write(node.isFactory ? 'factory' : 'constructor');
    if (node.name != null) {
      context.write('(');
      visitIdentifier(node.name!, context);
      context.write(')');
    }
    context.write(' ');
    context.write(WrapAndSeparator.block.begin);
    visitDartBody(node.body, context);
    context.write(WrapAndSeparator.block.end);
    return context;
  }

  @override
  StringBuffer visitImplementMember(TypeModifierMember node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write(node.isImplement ? 'implement ' : 'mix ');
    return _writeWrappedNodeList(
      node.types,
      visitType,
      context,
      WrapAndSeparator.commaSeparatedBlock,
    );
  }

  @override
  StringBuffer visitFunctionMember(FunctionMember node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    visitFunctionDefinition(node.definition, context);
    context.write(' ');
    visitFunctionBody(node.body, context);
    return context;
  }

  @override
  StringBuffer visitInstantiatedType(InstantiatedType node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    visitIdentifier(node.name, context);
    _writeWrappedNodeList(
      node.typeParameters,
      visitType,
      context,
      WrapAndSeparator.typeArgumentList,
      ignoreEmpty: true,
    );
    if (node.isNullable) {
      context.write('?');
    }
    return context;
  }

  @override
  StringBuffer visitMetaProgram(MetaProgram node, [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.derive != null) {
      visitTopLevelDerive(node.derive!, context);
    }
    return _writeWrappedNodeList(
      node.declarations,
      visitDeclaration,
      context,
      WrapAndSeparator.statements,
    );
  }

  static StringBuffer writeTokenList(TokenList list, StringBuffer buff) {
    list.fold<SourceLocation>(SourceLocation(0, 0), (lastLoc, token) {
      if (token.kind == TokenKind.EOF) {
        return lastLoc;
      }
      final start = token.range.start;
      final startNewLines = start.row - lastLoc.row;
      final startSpaces =
          startNewLines > 0 ? start.col : start.col - lastLoc.col;
      for (var i = 0; i < startNewLines; i++) {
        buff.writeln();
      }
      for (var i = 0; i < startSpaces; i++) {
        buff.write(' ');
      }
      buff.write(token.content);
      return token.range.end;
    });
    return buff;
  }

  @override
  StringBuffer visitOnDeclaration(OnDeclaration node, [StringBuffer? context]) {
    context ??= StringBuffer();
    _visitDocumented(node, context);

    context.write('on ');
    visitIdentifier(node.typeName, context);
    return _writeWrappedNodeList(
      node.members,
      visitOnMember,
      context,
      WrapAndSeparator.block,
    );
  }

  StringBuffer _writeWrappedNodeList<T extends ASTNode>(
    Iterable<T> values,
    StringBuffer Function(T, [StringBuffer?]) visitor,
    StringBuffer buff,
    WrapAndSeparator wrapAndSeparator, {
    bool ignoreEmpty = false,
  }) {
    if (values.isEmpty) {
      if (ignoreEmpty) {
        return buff;
      }
      buff
        ..write(wrapAndSeparator.begin)
        ..write(wrapAndSeparator.end);
      return buff;
    }
    buff.write(wrapAndSeparator.begin);
    var first = true;
    for (final v in values) {
      if (!first) {
        buff.write(wrapAndSeparator.separator);
      }
      first = false;
      visitor(v, buff);
    }
    buff.write(wrapAndSeparator.end);
    return buff;
  }

  StringBuffer _writeWrappedList(
    Iterable<Object> values,
    StringBuffer buff,
    WrapAndSeparator wrapAndSeparator, {
    bool ignoreEmpty = false,
  }) {
    if (values.isEmpty) {
      if (ignoreEmpty) {
        return buff;
      }
      buff
        ..write(wrapAndSeparator.begin)
        ..write(wrapAndSeparator.end);
      return buff;
    }
    buff.write(wrapAndSeparator.begin);
    var first = true;
    for (final v in values) {
      if (!first) {
        buff.write(wrapAndSeparator.separator);
      }
      first = false;
      buff.write(v);
    }
    buff.write(wrapAndSeparator.end);
    return buff;
  }

  @override
  StringBuffer visitParameterizedType(ParameterizedType node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    visitIdentifier(node.name, context);
    return _writeWrappedNodeList(
      node.typeParameters,
      visitTypeParameter,
      context,
      WrapAndSeparator.typeArgumentList,
      ignoreEmpty: true,
    );
  }

  @override
  StringBuffer visitTypeParameter(TypeParameter node, [StringBuffer? context]) {
    context ??= StringBuffer();
    visitIdentifier(node.name, context);
    if (node.constraint == null) {
      return context;
    }
    context.write(': ');
    visitType(node.constraint!, context);
    return context;
  }

  @override
  StringBuffer visitCall(Call node, [StringBuffer? context]) {
    context ??= StringBuffer();
    visitExpression(node.calee, context);
    return _writeWrappedNodeList(node.arguments, visitExpression, context,
        WrapAndSeparator.argumentList);
  }

  @override
  StringBuffer visitIdentifier(Identifier node, [StringBuffer? context]) {
    context ??= StringBuffer();
    return context..write(node.contents);
  }

  @override
  StringBuffer visitLiteral(Literal node, [StringBuffer? context]) {
    context ??= StringBuffer();
    return context..write(node.value);
  }

  @override
  StringBuffer visitDartBody(DartBody node, [StringBuffer? context]) {
    context ??= StringBuffer();
    final sep = node.isExpression
        ? WrapAndSeparator.arrowBody
        : WrapAndSeparator.jointBlock;
    context.write(sep.begin);
    writeTokenList(node.body, context);
    context.write(sep.end);
    return context;
  }

  @override
  StringBuffer visitFunctionParameters(FunctionParameters node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.typeParameters.isNotEmpty) {
      _writeWrappedNodeList(node.typeParameters, visitTypeParameter, context,
          WrapAndSeparator.typeArgumentList);
    }
    final regular =
        node.positioned.where((e) => !e.item2).map((e) => e.item1).toList();
    final optional =
        node.positioned.where((e) => e.item2).map((e) => e.item1).toList();
    final named = node.named.values.toList();

    context.write('(');
    if (regular.isNotEmpty) {
      _writeWrappedNodeList(
        regular,
        visitDataReference,
        context,
        WrapAndSeparator.comma,
      );
      context.write(',');
    }
    if (optional.isNotEmpty) {
      _writeWrappedNodeList(
        optional,
        visitDataReference,
        context,
        WrapAndSeparator.optionalParameters,
      );
      context.write(',');
    }
    if (named.isNotEmpty) {
      _writeWrappedNodeList(
        named,
        visitDataReference,
        context,
        WrapAndSeparator.commaSeparatedBlock,
      );
      context.write(',');
    }
    context.write(')');
    return context;
  }

  @override
  StringBuffer visitAccess(Access node, [StringBuffer? context]) {
    context ??= StringBuffer();
    visitExpression(node.target, context);
    context.write('.');
    visitExpression(node.accessed, context);
    return context;
  }

  @override
  StringBuffer visitFunctionDefinition(FunctionDefinition node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.isStatic) {
      context.write('static ');
    }
    if (node.isGet) {
      context.write('get ');
    }
    if (node.isSet) {
      context.write('set ');
    }
    visitIdentifier(node.name, context);
    visitFunctionParameters(node.parameters, context);
    if (node.returnType != null) {
      context.write(' -> ');
      visitType(node.returnType!, context);
    }
    return context;
  }

  @override
  StringBuffer visitRedirectMember(RedirectMember node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write('redirect ');
    visitFunctionDefinition(node.definition, context);
    context.write(' to ');
    visitExpression(node.target, context);
    return context;
  }

  StringBuffer _visitMetadated(MetadatedNode node, StringBuffer context) {
    if (node.metadata == null) {
      return context;
    }
    return _writeWrappedNodeList(
      node.metadata!,
      visitMetadata,
      context,
      WrapAndSeparator.statements,
    );
  }

  StringBuffer _visitAnnotated(AnnotatedNode node, StringBuffer context) {
    if (node.annotations == null) {
      return context;
    }
    return _writeWrappedNodeList(
      node.annotations!,
      visitAnnotation,
      context,
      WrapAndSeparator.statements,
    );
  }

  StringBuffer _visitDocumented(DocumentedNode node, StringBuffer context) {
    if (node.comments == null) {
      return context;
    }
    return visitDocumentation(node.comments!, context);
  }

  @override
  StringBuffer visitFunctionBody(FunctionBody node, [StringBuffer? context]) {
    context ??= StringBuffer();
    if (node.isAbstract) {
      context.write(';');
      return context;
    }
    if (node.qualifier != null) {
      context.write(node.qualifier);
    }
    visitDartBody(node.body!, context);
    return context;
  }

  @override
  StringBuffer visitAnnotation(Annotation node, [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write('@');
    visitExpression(node.expression, context);
    context.write(' ');
    return context;
  }

  @override
  StringBuffer visitDocumentation(Documentation node, [StringBuffer? context]) {
    context ??= StringBuffer();
    writeTokenList(node.comments, context);
    context.writeln();
    return context;
  }

  @override
  StringBuffer visitTopLevelDerive(TopLevelDerive node,
      [StringBuffer? context]) {
    context ??= StringBuffer();
    _visitDocumented(node, context);
    context.write('derive ');
    _writeWrappedNodeList(
        node.expressions, visitExpression, context, WrapAndSeparator.comma);
    context.write(';');
    return context;
  }

  @override
  StringBuffer visitMetadata(Metadata node, [StringBuffer? context]) {
    context ??= StringBuffer();
    context.write('#');
    return visitExpression(node.expression, context);
  }

  @override
  StringBuffer visitFunctionType(FunctionType node, [StringBuffer? context]) {
    context ??= StringBuffer();
    visitIdentifier(node.function, context);
    if (node.isNullable) {
      context.write('?');
    }
    if (node.parameters != null) {
      visitFunctionParameters(node.parameters!, context);
    }
    if (node.returnType != null) {
      context.write(' -> ');
      visitType(node.returnType!, context);
    }
    return context;
  }
}

class WrapAndSeparator {
  final String begin;
  final String separator;
  final String end;

  const WrapAndSeparator(this.begin, this.separator, this.end);
  static const typeArgumentList = WrapAndSeparator('<', ',', '>');
  static const block = WrapAndSeparator('{\n', ',', '\n}');
  static const jointBlock = WrapAndSeparator('{\n', '', '\n}');
  static const commaSeparatedBlock = WrapAndSeparator('{', ',', '}');
  static const optionalParameters = WrapAndSeparator('[', ',', ']');
  static const dataRecord = WrapAndSeparator('{', ',\n', '}');
  static const statements = WrapAndSeparator('', '\n', '');
  static const dataUnionBody = WrapAndSeparator('', '\n| ', '');
  static const argumentList = WrapAndSeparator('(', ', ', ')');
  static const comma = WrapAndSeparator('', ',', '');
  static const arrowBody = WrapAndSeparator('=> ', '', ';');
}

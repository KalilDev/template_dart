import 'ast.dart';
import 'dart:core' hide Type;

abstract class ASTVisitor<T> {
  T visitNode(ASTNode node, [T? context]) {
    if (node is MetaProgram) {
      return visitMetaProgram(node, context);
    }
    if (node is InstantiatedType) {
      return visitInstantiatedType(node, context);
    }
    if (node is DataDeclaration) {
      return visitDataDeclaration(node, context);
    }
    if (node is DataTypeDeclaration) {
      return visitDataTypeDeclaration(node, context);
    }
    if (node is DeriveClause) {
      return visitDeriveClause(node, context);
    }
    if (node is DataClassBody) {
      return visitDataClassBody(node, context);
    }
    if (node is DataRecord) {
      return visitDataRecord(node, context);
    }
    if (node is DataReference) {
      return visitDataReference(node, context);
    }
    if (node is DataUnionBody) {
      return visitDataUnionBody(node, context);
    }
    if (node is DataConstructor) {
      return visitDataConstructor(node, context);
    }
    if (node is OnDeclaration) {
      return visitOnDeclaration(node, context);
    }
    if (node is TypeModifierMember) {
      return visitImplementMember(node, context);
    }
    if (node is FactoryOrConstructorMember) {
      return visitFactoryMember(node, context);
    }
    if (node is FunctionMember) {
      return visitFunctionMember(node, context);
    }
    if (node is DartBody) {
      return visitDartBody(node, context);
    }
    if (node is FunctionParameters) {
      return visitFunctionParameters(node, context);
    }
    if (node is ParameterizedType) {
      return visitParameterizedType(node, context);
    }
    if (node is TypeParameter) {
      return visitTypeParameter(node, context);
    }
    if (node is RedirectMember) {
      return visitRedirectMember(node, context);
    }
    if (node is FunctionDefinition) {
      return visitFunctionDefinition(node, context);
    }
    if (node is FunctionBody) {
      return visitFunctionBody(node, context);
    }
    if (node is Annotation) {
      return visitAnnotation(node, context);
    }
    if (node is Documentation) {
      return visitDocumentation(node, context);
    }
    if (node is Literal) {
      return visitLiteral(node, context);
    }
    if (node is Call) {
      return visitCall(node, context);
    }
    if (node is Identifier) {
      return visitIdentifier(node, context);
    }
    if (node is Access) {
      return visitAccess(node, context);
    }
    if (node is TopLevelDerive) {
      return visitTopLevelDerive(node, context);
    }
    if (node is Metadata) {
      return visitMetadata(node, context);
    }
    if (node is FunctionType) {
      return visitFunctionType(node, context);
    }
    throw TypeError();
  }

  T visitExpression(Expression node, [T? context]) {
    if (node is Type) {
      return visitType(node, context);
    }
    if (node is Literal) {
      return visitLiteral(node, context);
    }
    if (node is Call) {
      return visitCall(node, context);
    }
    if (node is Identifier) {
      return visitIdentifier(node, context);
    }
    if (node is Access) {
      return visitAccess(node, context);
    }
    throw TypeError();
  }

  T visitType(Type node, [T? context]) {
    if (node is InstantiatedType) {
      return visitInstantiatedType(node, context);
    }
    if (node is FunctionType) {
      return visitFunctionType(node, context);
    }
    throw TypeError();
  }

  T visitDeclaration(Declaration node, [T? context]) {
    if (node is DataDeclaration) {
      return visitDataDeclaration(node, context);
    }
    if (node is OnDeclaration) {
      return visitOnDeclaration(node, context);
    }
    throw TypeError();
  }

  T visitDataBody(DataBody node, [T? context]) {
    if (node is DataClassBody) {
      return visitDataClassBody(node, context);
    }
    if (node is DataUnionBody) {
      return visitDataUnionBody(node, context);
    }
    throw TypeError();
  }

  T visitOnMember(OnMember node, [T? context]) {
    if (node is TypeModifierMember) {
      return visitImplementMember(node, context);
    }
    if (node is FactoryOrConstructorMember) {
      return visitFactoryMember(node, context);
    }
    if (node is FunctionMember) {
      return visitFunctionMember(node, context);
    }
    if (node is RedirectMember) {
      return visitRedirectMember(node, context);
    }
    throw TypeError();
  }

  T visitMetaProgram(MetaProgram node, [T? context]);
  T visitLiteral(Literal node, [T? context]);
  T visitIdentifier(Identifier node, [T? context]);
  T visitCall(Call node, [T? context]);
  T visitAccess(Access node, [T? context]);
  T visitInstantiatedType(InstantiatedType node, [T? context]);
  T visitFunctionType(FunctionType node, [T? context]);
  T visitDataDeclaration(DataDeclaration node, [T? context]);
  T visitDataTypeDeclaration(DataTypeDeclaration node, [T? context]);
  T visitDeriveClause(DeriveClause node, [T? context]);
  T visitDataClassBody(DataClassBody node, [T? context]);
  T visitDataRecord(DataRecord node, [T? context]);
  T visitDataReference(DataReference node, [T? context]);
  T visitDataUnionBody(DataUnionBody node, [T? context]);
  T visitDataConstructor(DataConstructor node, [T? context]);
  T visitOnDeclaration(OnDeclaration node, [T? context]);
  T visitTopLevelDerive(TopLevelDerive node, [T? context]);

  T visitFunctionMember(FunctionMember node, [T? context]);
  T visitRedirectMember(RedirectMember node, [T? context]);
  T visitImplementMember(TypeModifierMember node, [T? context]);
  T visitFunctionDefinition(FunctionDefinition node, [T? context]);
  T visitFunctionBody(FunctionBody node, [T? context]);
  T visitDartBody(DartBody node, [T? context]);
  T visitFactoryMember(FactoryOrConstructorMember node, [T? context]);
  T visitFunctionParameters(FunctionParameters node, [T? context]);
  T visitParameterizedType(ParameterizedType node, [T? context]);
  T visitTypeParameter(TypeParameter node, [T? context]);

  T visitAnnotation(Annotation node, [T? context]);
  T visitMetadata(Metadata node, [T? context]);
  T visitDocumentation(Documentation node, [T? context]);
}

mixin ThrowingASTVisitorMixin<T> on ASTVisitor<T> {
  @override
  T visitDataClassBody(DataClassBody node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitDataConstructor(DataConstructor node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitDataDeclaration(DataDeclaration node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitDataRecord(DataRecord node, [T? context]) =>
      throw UnimplementedError();
  @override
  T visitDataReference(DataReference node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitDataTypeDeclaration(DataTypeDeclaration node, [T? context]) =>
      throw UnimplementedError();
  @override
  T visitDataUnionBody(DataUnionBody node, [T? context]) =>
      throw UnimplementedError();
  @override
  T visitDeriveClause(DeriveClause node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitFactoryMember(FactoryOrConstructorMember node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitImplementMember(TypeModifierMember node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitInstantiatedType(InstantiatedType node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitMetaProgram(MetaProgram node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitOnDeclaration(OnDeclaration node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitParameterizedType(ParameterizedType node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitTypeParameter(TypeParameter node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitCall(Call node, [T? context]) => throw UnimplementedError();

  @override
  T visitIdentifier(Identifier node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitLiteral(Literal node, [T? context]) => throw UnimplementedError();

  @override
  T visitDartBody(DartBody node, [T? context]) => throw UnimplementedError();

  @override
  T visitFunctionMember(FunctionMember node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitFunctionParameters(FunctionParameters node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitAccess(Access node, [T? context]) => throw UnimplementedError();
  @override
  T visitFunctionBody(FunctionBody node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitFunctionDefinition(FunctionDefinition node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitRedirectMember(RedirectMember node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitAnnotation(Annotation node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitDocumentation(Documentation node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitTopLevelDerive(TopLevelDerive node, [T? context]) =>
      throw UnimplementedError();

  @override
  T visitMetadata(Metadata node, [T? context]) => throw UnimplementedError();

  @override
  T visitFunctionType(FunctionType node, [T? context]) =>
      throw UnimplementedError();
}

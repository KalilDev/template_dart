import 'package:tuple/tuple.dart';

import '../grammar/token.dart';
import 'dart:core' as dc;
import 'dart:core' hide Type;

abstract class ASTNode {}

/// [MetaProgram] ::= [TopLevelDerive]? [Declaration]*
class MetaProgram extends ASTNode {
  final TopLevelDerive? derive;
  final List<Declaration> declarations;

  MetaProgram(this.derive, this.declarations);
}

/// [TopLevelDerive] ::= `derive` expressions `;`
/// expressions ::= [Expression] (`,` [Expression])*
class TopLevelDerive extends ASTNode with DocumentedNode {
  final List<Expression> expressions;

  TopLevelDerive(this.expressions);
}

/// [Expression] ::= [Identifier]
///                | [Type]
///                | [Literal]
///                | [Call]
///                | [Access]
abstract class Expression extends ASTNode {}

/// [Annotation] ::= `#` [Expression]
class Metadata extends ASTNode {
  final Expression expression;

  Metadata(this.expression);
}

/// [Annotation] ::= `@` [Expression]
class Annotation extends ASTNode {
  final Expression expression;

  Annotation(this.expression);
}

/// [Documentation] ::= [Token]*
class Documentation extends ASTNode {
  final TokenList comments;

  Documentation(this.comments);
}

mixin AnnotatedNode on ASTNode {
  List<Annotation>? annotations;
}

mixin MetadatedNode on ASTNode {
  List<Metadata>? metadata;
}

mixin DocumentedNode on ASTNode {
  Documentation? comments;
}

/// [Identifier] ::= \c+
class Identifier extends Expression {
  final String contents;

  Identifier(this.contents);
}

/// [Literal] ::= [Token]
class Literal extends Expression {
  final Token token;

  Literal(this.token);

  dynamic get value {
    switch (token.kind) {
      case TokenKind.StringLiteral:
        return token.content;
      case TokenKind.DoubleLiteral:
        return double.parse(token.content);
      case TokenKind.IntLiteral:
        return int.parse(token.content);
      default:
        throw StateError('');
    }
  }
}

/// [Call] ::= [Expression] `(` arguments `)`
/// arguments ::= [Expression]? (`,` [Expression])*
class Call extends Expression {
  final Expression calee;
  final List<Expression> arguments;

  Call(this.calee, this.arguments);
}

/// [Access] ::= [Expression] `.` [Expression]
class Access extends Expression {
  final Expression target;
  final Identifier accessed;

  Access(this.target, this.accessed);
}

/// [Type] ::= [InstantiatedType]
///          | [FunctionType]
abstract class Type extends Expression {
  bool get isNullable;
  Type withNullability(bool nullability);
}

/// [FunctionType] ::= `Function` nullabilitySuffix? [FunctionParameters]?  returnType?
/// nullabilitySuffix ::= `?`
/// returnType ::= `->` [Type]
class FunctionType extends Type {
  final Identifier function;
  final FunctionParameters? parameters;
  @override
  final bool isNullable;
  final Type? returnType;

  FunctionType(
      this.function, this.parameters, this.isNullable, this.returnType);

  @override
  Type withNullability(dc.bool nullability) =>
      FunctionType(function, parameters, nullability, returnType);
}

/// [InstantiatedType] ::= [Identifier] typeParameters? nullabilitySuffix?
/// typeParameters ::= `<` [Type] (`,` [Type])* `>`
/// nullabilitySuffix ::= `?`
class InstantiatedType extends Type {
  final Identifier name;
  final List<Type> typeParameters;
  @override
  final bool isNullable;

  InstantiatedType(this.name, this.typeParameters, this.isNullable);
  @override
  InstantiatedType withNullability(bool nullability) =>
      InstantiatedType(name, typeParameters, nullability);
}

/// [Declaration] ::= [DataDeclaration]
///                 | [OnDeclaration]
abstract class Declaration extends ASTNode with DocumentedNode {}

/// [DataDeclaration] ::= `data` [DataTypeDeclaration] [DataBody] [DeriveClause]? `;`
class DataDeclaration extends Declaration with AnnotatedNode, MetadatedNode {
  final DataTypeDeclaration typeDeclaration;
  final DataBody body;
  final DeriveClause? deriveClause;

  DataDeclaration(this.typeDeclaration, this.body, this.deriveClause);
  bool get isUnion => body is DataUnionBody;
}

/// [DataTypeDeclaration] ::= [ParameterizedType] extends? with? implements?
/// extends ::= `extends` [Type]
/// with ::= `with` [Type] (`,` [Type])*
/// implements ::= `implements` [Type] (`,` [Type])*
class DataTypeDeclaration extends Declaration {
  final ParameterizedType type;
  final Type? extended;
  final List<Type>? mixed;
  final List<Type>? implemented;

  DataTypeDeclaration(this.type, this.extended, this.mixed, this.implemented);
}

/// [DeriveClause] ::= `derive` `(` derivations `)`
/// derivations ::= [Expression]? (`,` [Expression])*
class DeriveClause extends ASTNode {
  final List<Expression> derivations;

  DeriveClause(this.derivations);
}

/// [DataBody] ::= [DataClassBody]
///              | [DataUnionBody]
abstract class DataBody extends ASTNode {}

/// [DataClassBody] ::= [DataRecord]
class DataClassBody extends DataBody {
  final DataRecord body;

  DataClassBody(this.body);
}

/// [DataRecord] ::= `{` references `}`
/// references ::= [DataReference]? (`,` [DataReference])*
class DataRecord extends ASTNode {
  final List<DataReference> refs;

  DataRecord(this.refs);
}

/// [DataReference] ::= [Identifier] `::` [Type]
class DataReference extends ASTNode
    with AnnotatedNode, DocumentedNode, MetadatedNode {
  final Identifier name;
  final Type type;

  DataReference(this.name, this.type);
}

/// [DataUnionBody] ::= `=` [DataConstructor] (`|` [DataConstructor])*
class DataUnionBody extends DataBody {
  final List<DataConstructor> constructors;

  DataUnionBody(this.constructors);
}

/// [DataConstructor] ::= [Identifier] [DataRecord]?
class DataConstructor extends ASTNode
    with AnnotatedNode, DocumentedNode, MetadatedNode {
  final Identifier name;
  final DataRecord? body;

  DataConstructor(this.name, this.body);
}

/// [OnDeclaration] ::= `on` [Identifier] `{` [OnMember]* `}`
class OnDeclaration extends Declaration {
  final Identifier typeName;
  final List<OnMember> members;

  OnDeclaration(this.typeName, this.members);
}

/// [OnMember] ::= [TypeModifierMember]
///              | [FactoryOrConstructorMember]
///              | [InjectMember]
abstract class OnMember extends ASTNode {}

/// [TypeModifierMember] ::= keyword `{` [Type]* `}`
/// keyword ::= `implement`
///           | `mix`
class TypeModifierMember extends OnMember {
  final List<Type> types;
  final bool isImplement;

  TypeModifierMember(this.types, this.isImplement);
}

/// [FactoryOrConstructorMember] ::= keyword name? [DartBody]
/// keyword ::= `factory`
///           | `constructor`
/// name ::= `(`[Identifier]`)`
class FactoryOrConstructorMember extends OnMember {
  final Identifier? name;
  final DartBody body;
  final bool isFactory;

  FactoryOrConstructorMember(this.name, this.body, this.isFactory);
}

/// [FunctionParameters] ::= typeParameters? `(` positioned? optional? named? `)`
/// typeParameters ::= `<` [TypeParameter] (`,` [TypeParameter])* `>`
/// positioned ::= [DataReference]? (`,` [DataReference])*
/// optional ::= `[` [DataReference]? (`,` [DataReference])* `]`
/// named ::= `{` [DataReference]? (`,` [DataReference])* `}`
class FunctionParameters extends ASTNode {
  final List<TypeParameter> typeParameters;
  final List<Tuple2<DataReference, bool>> positioned;
  final Map<Identifier, DataReference> named;

  FunctionParameters(this.positioned, this.named, this.typeParameters);
}

/// [FunctionMember] ::= [FunctionDefinition] [FunctionBody]
class FunctionMember extends OnMember {
  final FunctionDefinition definition;
  final FunctionBody body;

  FunctionMember(this.definition, this.body);
}

/// [RedirectMember] ::= `redirect` [FunctionDefinition] `to` [Expression]
class RedirectMember extends OnMember {
  final FunctionDefinition definition;
  final Expression target;

  RedirectMember(this.definition, this.target);
}

/// [FunctionBody] ::= `;`
///                  | qualifier? [DartBody]
/// qualifier ::= `sync*`
///             | `async`
///             | `async*`
class FunctionBody extends ASTNode {
  final String? qualifier;
  final DartBody? body;

  FunctionBody(this.qualifier, this.body);
  bool get isAbstract => body == null;
}

/// [FunctionDefinition] ::= `static`? `get`? `set`? [Identifier] [FunctionParameters] returnType?
/// returnType ::= `->` [Type]
class FunctionDefinition extends ASTNode {
  final bool isStatic;
  final bool isGet;
  final bool isSet;
  final Identifier name;
  final FunctionParameters parameters;
  final Type? returnType;

  FunctionDefinition(this.isStatic, this.isGet, this.isSet, this.name,
      this.parameters, this.returnType);
}

/// [DartBody] ::= `{` [Token]* `}`
///                | `=>` [Token]*;
class DartBody extends ASTNode {
  final TokenList body;
  final bool isExpression;

  DartBody(this.body, this.isExpression);
}

/// [ParameterizedType] ::= [Identifier] typeParameters?
/// typeParameters ::= `<` [TypeParameter] (`,` [TypeParameter])* `>`
class ParameterizedType extends ASTNode {
  final Identifier name;
  final List<TypeParameter> typeParameters;

  ParameterizedType(this.name, this.typeParameters);
  InstantiatedType instantiation([
    bool nullable = false,
    Map<String, Type> replacements = const {},
  ]) =>
      InstantiatedType(
        name,
        typeParameters
            .map<Type>((e) =>
                replacements[e.name] ?? InstantiatedType(e.name, [], false))
            .toList(),
        nullable,
      );
}

/// [TypeParameter] ::= [Identifier] nullabilitySuffix? constraint?
/// nullabilitySuffix ::= `?`
/// constraint ::= `:` [Type]
class TypeParameter extends ASTNode {
  final Identifier name;
  final Type? constraint;

  TypeParameter(this.name, this.constraint);
}

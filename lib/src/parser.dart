import 'ast.dart';
import 'package:tuple/tuple.dart';
import 'dart:core' hide Type;
import 'token.dart';

abstract class SyntaxException implements Exception {
  final Token atToken;

  SyntaxException(this.atToken);
}

class _UnexpectedTokenException<T extends ASTNode> extends SyntaxException {
  final TokenKind? expectedKind;
  final Set<TokenKind>? expectedKinds;
  final Set<String>? expectedValues;

  _UnexpectedTokenException(
    Token token, {
    this.expectedKind,
    this.expectedKinds,
    this.expectedValues,
  }) : super(token);

  String get expected {
    if (expectedKind != null) {
      return 'An $expectedKind was expected!';
    }
    if (expectedKinds != null) {
      return 'One of {${expectedKinds!.join(', ')}} was expected!';
    }
    if (expectedValues != null) {
      return 'One of {${expectedValues!.join(', ')}} was expected!';
    }
    throw StateError('');
  }

  @override
  String toString() => 'Unexpected token $atToken while trying to parse an $T; '
      '$expected';
}

class _UnexpectedIdentifierException<T extends ASTNode>
    extends SyntaxException {
  final Set<String> expected;

  _UnexpectedIdentifierException(Token token, this.expected) : super(token);

  @override
  String toString() => 'Unexpected token $atToken while trying to parse an $T; '
      'An Identifier with one of {${expected.join(', ')}} contents was expected!';
}

class Parser {
  static bool isTokenAllowed(Token token) {
    switch (token.kind) {
      case TokenKind.GreaterEqualsEquals:
      case TokenKind.SmallerDollarGreater:
        return false;
      default:
        return true;
    }
  }

  final TokenList tokens;

  Parser(this.tokens);

  final List<Object> errors = [];

  Identifier parseIdentifier(TokenIterator cursor) {
    final name = _expectKind<Identifier>(cursor, TokenKind.Identifier);
    return Identifier(name.content);
  }

  Token _expectKind<T extends ASTNode>(TokenIterator cursor, TokenKind kind) =>
      _expectKinds<T>(cursor, {kind});

  Token _expectKinds<T extends ASTNode>(
      TokenIterator cursor, Set<TokenKind> kinds) {
    final peeked = _expectPeekKinds<T>(cursor, kinds);
    cursor.consume();
    return peeked;
  }

  Token _expectPeekKinds<T extends ASTNode>(
      TokenIterator cursor, Set<TokenKind> kinds) {
    final token = cursor.peek;
    if (!kinds.contains(token?.kind)) {
      throw _UnexpectedTokenException<T>(
        cursor.peek!,
        expectedKinds: kinds.length == 1 ? null : kinds,
        expectedKind: kinds.length == 1 ? kinds.single : null,
      );
    }
    return token!;
  }

  String _expectPeekIdentifiers<T extends ASTNode>(
      TokenIterator cursor, Set<String> identifiers) {
    final peek = cursor.peek;
    if (!identifiers.contains(peek?.content)) {
      throw _UnexpectedTokenException<T>(peek!, expectedValues: identifiers);
    }
    return peek!.content;
  }

  String _expectIdentifiers<T extends ASTNode>(
      TokenIterator cursor, Set<String> identifiers) {
    final id = _expectPeekIdentifiers<T>(cursor, identifiers);
    cursor.consume();
    return id;
  }

  String _expectIdentifier<T extends ASTNode>(
          TokenIterator cursor, String identifier) =>
      _expectIdentifiers<T>(cursor, {identifier});

  String? _maybeParseOneIdentifierOf<T extends ASTNode>(
      TokenIterator cursor, Set<String> identifiers) {
    if (cursor.peek?.kind == TokenKind.Identifier) {
      if (!identifiers.contains(cursor.peek!.content)) {
        throw _UnexpectedIdentifierException<T>(cursor.peek!, identifiers);
      }
      return cursor.consume()!.content;
    }
    return null;
  }

  String _parseOneIdentifierOf<T extends ASTNode>(
      TokenIterator cursor, Set<String> identifiers) {
    if (cursor.peek?.kind == TokenKind.Identifier) {
      if (!identifiers.contains(cursor.peek!.content)) {
        throw _UnexpectedIdentifierException<T>(cursor.peek!, identifiers);
      }
      return cursor.consume()!.content;
    }
    throw _UnexpectedTokenException<T>(cursor.peek!,
        expectedKind: TokenKind.Identifier);
  }

  bool _parseNullabilitySuffix(TokenIterator cursor) {
    if (cursor.peek?.kind == TokenKind.Interrogation) {
      cursor.consume();
      return true;
    }
    return false;
  }

  InstantiatedType parseInstantiatedType(TokenIterator cursor,
      [Identifier? name]) {
    name ??= parseIdentifier(cursor);
    if (name.contents == 'Function') {
      throw _UnexpectedIdentifierException(cursor.current, {});
    }
    if (cursor.peek?.kind != TokenKind.Smaller) {
      return InstantiatedType(name, [], _parseNullabilitySuffix(cursor));
    }
    final typeArguments = _parseWrappedSeparatedListOf(
      parseType,
      cursor,
      TokenKind.Smaller,
      TokenKind.Greater,
      TokenKind.Comma,
    );
    return InstantiatedType(
      name,
      typeArguments,
      _parseNullabilitySuffix(cursor),
    );
  }

  FunctionType parseFunctionType(TokenIterator cursor, [Identifier? name]) {
    name ??= parseIdentifier(cursor);
    if (name.contents != 'Function') {
      throw _UnexpectedIdentifierException(cursor.current, {'Function'});
    }
    final nullable = _parseNullabilitySuffix(cursor);
    FunctionParameters? parameters;
    if (cursor.peek?.kind == TokenKind.Smaller ||
        cursor.peek?.kind == TokenKind.OpenParens) {
      parameters = parseFunctionParameters(cursor);
    }
    Type? returnType;
    if (cursor.peek?.kind == TokenKind.MinusGreater) {
      cursor.consume();
      returnType = parseType(cursor);
    }
    return FunctionType(name, parameters, nullable, returnType);
  }

  Type parseType(TokenIterator cursor) {
    final name = parseIdentifier(cursor);
    if (name.contents == 'Function') {
      return parseFunctionType(cursor, name);
    }
    return parseInstantiatedType(cursor, name);
  }

  R _maybeParseWrapped<R>(
    R Function(TokenIterator) parse,
    R Function() orElse,
    TokenIterator cursor,
    TokenKind start,
    TokenKind end,
  ) {
    if (cursor.peek!.kind != start) {
      return orElse();
    }
    cursor.consume()!;
    var level = 0;
    final inner = cursor.consumeUntil((t) {
      final isStart = t.kind == start;
      final isEnd = t.kind == end;
      if (isEnd) {
        level--;
      }
      if (isStart) {
        level++;
      }

      return level < 0;
    });
    if (inner == null) {
      return orElse();
    }
    return parse(inner.iterator..moveNext());
  }

  R _parseWrapped<R>(
    R Function(TokenIterator) parse,
    TokenIterator cursor,
    TokenKind start,
    TokenKind end,
  ) =>
      _maybeParseWrapped(
          parse, () => throw StateError('Fail'), cursor, start, end);

  List<T> _parseSeparatedListOf<T>(
    T Function(TokenIterator) parse,
    TokenIterator cursor,
    TokenKind separator,
  ) {
    final values = <T>[];
    var isFirst = true;
    while (cursor.peek!.kind != TokenKind.EOF) {
      if (!isFirst) {
        if (cursor.peek!.kind != separator) {
          break;
        }
        // TODO: T
        _expectKind(cursor, separator);
      }
      values.add(parse(cursor));
      isFirst = false;
    }
    return values;
  }

  List<T> _maybeParseWrappedSeparatedListOf<T>(
    T Function(TokenIterator) parse,
    TokenIterator cursor,
    TokenKind start,
    TokenKind end,
    TokenKind separator,
    List<T> Function() orElse,
  ) =>
      _maybeParseWrapped<List<T>>(
          (cursor) => cursor.peek?.kind == end
              ? []
              : _parseSeparatedListOf(
                  parse,
                  cursor,
                  separator,
                ),
          orElse,
          cursor,
          start,
          end);

  List<T> _parseWrappedSeparatedListOf<T>(
    T Function(TokenIterator) parse,
    TokenIterator cursor,
    TokenKind start,
    TokenKind end,
    TokenKind separator,
  ) =>
      _maybeParseWrappedSeparatedListOf(
        parse,
        cursor,
        start,
        end,
        separator,
        () => throw StateError('Invalid start token'),
      );

  TypeModifierMember parseTypeModifierMember(TokenIterator cursor) {
    final isImplement =
        _parseOneIdentifierOf(cursor, {'mix', 'implement'}) == 'implement';
    final types = _parseWrappedSeparatedListOf(
      parseType,
      cursor,
      TokenKind.OpenBracket,
      TokenKind.CloseBracket,
      TokenKind.Comma,
    );
    return TypeModifierMember(types, isImplement);
  }

  DartBody parseDartBody(TokenIterator cursor) {
    final start = cursor.peek;
    TokenList body;
    var isExpression = false;
    if (start?.kind == TokenKind.OpenBracket) {
      body = _parseWrapped(
        (it) => TokenList.fromIterator(it),
        cursor,
        TokenKind.OpenBracket,
        TokenKind.CloseBracket,
      );
    } else if (start?.kind == TokenKind.EqualsGreater) {
      isExpression = true;
      // TODO this is not correct, an lambda would break the logic.
      body = _parseWrapped((it) => TokenList.fromIterator(it), cursor,
          TokenKind.EqualsGreater, TokenKind.Semicolon);
    } else {
      throw _UnexpectedTokenException<DartBody>(start!, expectedKinds: {
        TokenKind.OpenBracket,
        TokenKind.EqualsGreater,
      });
    }
    return DartBody(body, isExpression);
  }

  FactoryOrConstructorMember parseFactoryOrConstructorMember(
      TokenIterator cursor) {
    final isFactory =
        _parseOneIdentifierOf(cursor, {'factory', 'constructor'}) == 'factory';
    final name = _maybeParseWrapped(
      parseIdentifier,
      () => null,
      cursor,
      TokenKind.OpenParens,
      TokenKind.CloseParens,
    );
    final body = parseDartBody(cursor);
    return FactoryOrConstructorMember(name, body, isFactory);
  }

  FunctionBody parseFunctionBody(TokenIterator cursor) {
    String? parseQualifier() {
      final maybeKeyword = cursor.peek!;
      if (maybeKeyword.kind != TokenKind.Identifier) {
        return null;
      }
      final qualifier = maybeKeyword.content;
      if (qualifier != 'sync' || qualifier != 'async') {
        return null;
      }
      cursor.consume();
      final maybeStar = cursor.peek!;
      if (maybeStar.kind != TokenKind.Star) {
        return qualifier;
      }
      cursor.consume();
      return qualifier + '*';
    }

    DartBody? parseBody() {
      final maybeSemicolon = cursor.peek!;
      if (maybeSemicolon.kind == TokenKind.Semicolon) {
        cursor.consume();
        return null;
      }
      return parseDartBody(cursor);
    }

    final qualifier = parseQualifier();
    final body = parseBody();
    return FunctionBody(qualifier, body);
  }

  FunctionDefinition parseFunctionDefinition(TokenIterator cursor) {
    bool parseMaybeKeyword(String keyword) {
      var maybeKeyword = cursor.peek!;
      if (maybeKeyword.content == keyword) {
        cursor.consume();
        return true;
      }
      return false;
    }

    Type? parseReturnType() {
      final maybeArrow = cursor.peek!;
      if (maybeArrow.kind != TokenKind.MinusGreater) {
        return null;
      }
      cursor.consume();
      return parseType(cursor);
    }

    final isStatic = parseMaybeKeyword('static');
    final isGet = parseMaybeKeyword('get');
    final isSet = parseMaybeKeyword('set');

    final name = parseIdentifier(cursor);
    final parameters = parseFunctionParameters(cursor);
    final returnType = parseReturnType();
    return FunctionDefinition(
      isStatic,
      isGet,
      isSet,
      name,
      parameters,
      returnType,
    );
  }

  FunctionParameters parseFunctionParameters(TokenIterator cursor) {
    final typeParameters = _parseTypeParameterList(cursor);
    return _parseWrapped(
      (cursor) {
        List<DataReference> required = [];
        List<DataReference>? optional;
        List<DataReference>? named;
        var token = cursor.peek;
        while (token != null && token.kind != TokenKind.CloseParens) {
          if (token.kind == TokenKind.Comma) {
            cursor.consume();
            token = cursor.peek;
            continue;
          }
          if (token.kind == TokenKind.OpenSquareBracket) {
            optional = _parseWrappedSeparatedListOf(
              parseDataReference,
              cursor,
              TokenKind.OpenSquareBracket,
              TokenKind.CloseSquareBracket,
              TokenKind.Comma,
            );
            token = cursor.peek;
            continue;
          }
          if (token.kind == TokenKind.OpenBracket) {
            named = _parseWrappedSeparatedListOf(
              parseDataReference,
              cursor,
              TokenKind.OpenBracket,
              TokenKind.CloseBracket,
              TokenKind.Comma,
            );
            token = cursor.peek;
            continue;
          }
          required.add(parseDataReference(cursor));
          token = cursor.peek;
        }
        return FunctionParameters(
            required
                .map((e) => Tuple2(e, false))
                .followedBy((optional ?? []).map((e) => Tuple2(e, true)))
                .toList(),
            Map.fromEntries((named ?? []).map((e) => MapEntry(e.name, e))),
            typeParameters);
      },
      cursor,
      TokenKind.OpenParens,
      TokenKind.CloseParens,
    );
  }

  RedirectMember parseRedirectMember(TokenIterator cursor) {
    _expectIdentifier<RedirectMember>(cursor, 'redirect');

    final definition = parseFunctionDefinition(cursor);

    _expectIdentifier<RedirectMember>(cursor, 'to');
    final target = parseExpression(cursor);
    return RedirectMember(
      definition,
      target,
    );
  }

  FunctionMember parseFunctionMember(TokenIterator cursor) {
    final definition = parseFunctionDefinition(cursor);
    final body = parseFunctionBody(cursor);
    return FunctionMember(
      definition,
      body,
    );
  }

  OnMember parseOnMember(TokenIterator cursor) {
    final identifier = cursor.peek!.content;
    switch (identifier) {
      case 'mix':
      case 'implement':
        return parseTypeModifierMember(cursor);
      case 'constructor':
      case 'factory':
        return parseFactoryOrConstructorMember(cursor);
      case 'redirect':
        return parseRedirectMember(cursor);
      default:
        return parseFunctionMember(cursor);
    }
  }

  OnDeclaration parseOnDeclaration(TokenIterator cursor) =>
      _parseDocumented(cursor, (cursor) {
        _expectIdentifier<OnDeclaration>(cursor, 'on');
        final typeName = parseIdentifier(cursor);
        _expectKind<OnDeclaration>(cursor, TokenKind.OpenBracket);
        final members = <OnMember>[];
        while (cursor.peek!.kind != TokenKind.CloseBracket &&
            cursor.peek!.kind != TokenKind.EOF) {
          members.add(parseOnMember(cursor));
        }
        _expectKind<OnDeclaration>(cursor, TokenKind.CloseBracket);
        return OnDeclaration(typeName, members);
      });

  List<TypeParameter> _parseTypeParameterList(TokenIterator cursor) =>
      _maybeParseWrappedSeparatedListOf(
          parseTypeParameter,
          cursor,
          TokenKind.Smaller,
          TokenKind.Greater,
          TokenKind.Comma,
          () => <TypeParameter>[]);

  ParameterizedType parseParameterizedType(TokenIterator cursor) {
    final name = parseIdentifier(cursor);
    final parameters = _parseTypeParameterList(cursor);
    return ParameterizedType(name, parameters);
  }

  TypeParameter parseTypeParameter(TokenIterator cursor) {
    final name = parseIdentifier(cursor);
    if (cursor.peek?.kind != TokenKind.Colon) {
      return TypeParameter(name, null);
    }
    cursor.consume()!;
    final constraint = parseType(cursor);
    return TypeParameter(name, constraint);
  }

  DataTypeDeclaration parseDataTypeDeclaration(TokenIterator cursor) {
    final type = parseParameterizedType(cursor);
    Type? extended;
    List<Type>? mixed;
    List<Type>? implemented;
    void parseExtends() {
      extended = parseType(cursor);
    }

    void parseTypelist(void Function(List<Type>) setter) {
      final types = _parseSeparatedListOf(parseType, cursor, TokenKind.Comma);
      setter(types);
    }

    void parseModifier(String target) {
      final next = cursor.peek!;
      if (next.content != target) {
        return;
      }
      cursor.consume();
      switch (target) {
        case 'with':
          parseTypelist((els) => mixed = els);
          break;
        case 'extends':
          parseExtends();
          break;
        case 'implements':
          parseTypelist((els) => implemented = els);
          break;
      }
    }

    parseModifier('extends');
    parseModifier('implements');
    parseModifier('with');
    return DataTypeDeclaration(type, extended, mixed, implemented);
  }

  DataReference parseDataReference(TokenIterator cursor) => _parseDocumented(
        cursor,
        (cursor) => _parseAnnotated(
          cursor,
          (cursor) => _parseMetadated(cursor, (cursor) {
            final name = parseIdentifier(cursor);
            _expectKind<DataReference>(cursor, TokenKind.ColonColon);
            final type = parseType(cursor);
            return DataReference(name, type);
          }),
        ),
      );

  DataRecord parseDataRecord(TokenIterator cursor) =>
      DataRecord(_parseWrappedSeparatedListOf(
        parseDataReference,
        cursor,
        TokenKind.OpenBracket,
        TokenKind.CloseBracket,
        TokenKind.Comma,
      ));
  DataConstructor parseDataConstructor(TokenIterator cursor) =>
      _parseDocumented(
        cursor,
        (cursor) => _parseAnnotated(
          cursor,
          (cursor) => _parseMetadated(cursor, (cursor) {
            final name = parseIdentifier(cursor);
            if (cursor.peek?.kind != TokenKind.OpenBracket) {
              return DataConstructor(name, null);
            }
            final record = parseDataRecord(cursor);
            return DataConstructor(name, record);
          }),
        ),
      );

  DataUnionBody parseDataUnionBody(TokenIterator cursor) {
    _expectKind<DataUnionBody>(cursor, TokenKind.Equals);
    final constructors =
        _parseSeparatedListOf(parseDataConstructor, cursor, TokenKind.Or);
    return DataUnionBody(constructors);
  }

  Literal parseLiteral(TokenIterator cursor) {
    return Literal(
      _expectKinds<Literal>(cursor, {
        TokenKind.StringLiteral,
        TokenKind.DoubleLiteral,
        TokenKind.IntLiteral
      }),
    );
  }

  Call parseCall(TokenIterator cursor, Expression callee) {
    final args = _parseWrappedSeparatedListOf(parseExpression, cursor,
        TokenKind.OpenParens, TokenKind.CloseParens, TokenKind.Comma);

    return Call(callee, args);
  }

  Access parseAccess(TokenIterator cursor, Expression target) {
    _expectKind<Access>(cursor, TokenKind.Dot);
    return Access(target, parseIdentifier(cursor));
  }

  Expression _parseIdentifierTypeOrCall(TokenIterator cursor) {
    final token = _expectKind<Expression>(cursor, TokenKind.Identifier);
    final id = Identifier(token.content);
    final nextToken = cursor.peek;
    if (nextToken?.kind == TokenKind.OpenParens) {
      return parseCall(cursor, id);
    }
    if (nextToken?.kind == TokenKind.Smaller) {
      return parseInstantiatedType(cursor, id);
    }
    // Ambiguity between 0-ary instantiated types and identifiers!!!
    return id;
  }

  Expression parseExpression(TokenIterator cursor) {
    final token = _expectPeekKinds<Expression>(cursor, {
      TokenKind.StringLiteral,
      TokenKind.DoubleLiteral,
      TokenKind.IntLiteral,
      TokenKind.Identifier,
    });
    Expression result;
    switch (token.kind) {
      case TokenKind.StringLiteral:
      case TokenKind.DoubleLiteral:
      case TokenKind.IntLiteral:
        result = parseLiteral(cursor);
        break;
      case TokenKind.Identifier:
        result = _parseIdentifierTypeOrCall(cursor);
        break;
      default:
        throw StateError('Unreachable');
    }
    while (cursor.peek?.kind == TokenKind.Dot) {
      result = parseAccess(cursor, result);
    }
    return result;
  }

  DataClassBody parseDataClassBody(TokenIterator cursor) =>
      DataClassBody(parseDataRecord(cursor));

  DataBody parseDataBody(TokenIterator cursor) =>
      cursor.peek?.kind == TokenKind.Equals
          ? parseDataUnionBody(cursor)
          : parseDataClassBody(cursor);

  DeriveClause parseDeriveClause(TokenIterator cursor) {
    _expectIdentifier<DeriveClause>(cursor, 'derive');
    final derivations = _parseWrappedSeparatedListOf(
      parseExpression,
      cursor,
      TokenKind.OpenParens,
      TokenKind.CloseParens,
      TokenKind.Comma,
    );
    return DeriveClause(derivations);
  }

  DataDeclaration parseDataDeclaration(TokenIterator cursor) =>
      _parseDocumented(
        cursor,
        (cursor) => _parseAnnotated(
          cursor,
          (cursor) => _parseMetadated(
            cursor,
            (cursor) {
              _expectIdentifier<DataDeclaration>(cursor, 'data');
              final dataType = parseDataTypeDeclaration(cursor);
              final body = parseDataBody(cursor);
              if (cursor.peek!.kind == TokenKind.Semicolon) {
                cursor.consume();
                return DataDeclaration(dataType, body, null);
              }
              final derive = parseDeriveClause(cursor);
              _expectKind<DataDeclaration>(cursor, TokenKind.Semicolon);
              return DataDeclaration(dataType, body, derive);
            },
          ),
        ),
      );

  T _parseDocumented<T extends DocumentedNode>(
    TokenIterator cursor,
    T Function(TokenIterator) parse,
  ) {
    switch (cursor.peek?.kind) {
      case TokenKind.LineComment:
      case TokenKind.BlockComment:
        final doc = parseDocumentation(cursor);
        return parse(cursor)..comments = doc;
      default:
        return parse(cursor);
    }
  }

  Metadata parseMetadata(TokenIterator cursor) {
    _expectKind<Metadata>(cursor, TokenKind.Hashtag);

    return Metadata(parseExpression(cursor));
  }

  T _parseMetadated<T extends MetadatedNode>(
    TokenIterator cursor,
    T Function(TokenIterator) parse,
  ) {
    if (cursor.peek?.kind != TokenKind.Hashtag) {
      return parse(cursor);
    }
    final metas = <Metadata>[];
    while (cursor.peek?.kind == TokenKind.Hashtag) {
      metas.add(parseMetadata(cursor));
    }
    return parse(cursor)..metadata = metas;
  }

  T _parseAnnotated<T extends AnnotatedNode>(
    TokenIterator cursor,
    T Function(TokenIterator) parse,
  ) {
    if (cursor.peek?.kind != TokenKind.At) {
      return parse(cursor);
    }
    final anns = <Annotation>[];
    while (cursor.peek?.kind == TokenKind.At) {
      anns.add(parseAnnotation(cursor));
    }
    return parse(cursor)..annotations = anns;
  }

  Documentation parseDocumentation(TokenIterator cursor) {
    final docKinds = {TokenKind.LineComment, TokenKind.BlockComment};
    _expectKinds<Documentation>(cursor, docKinds);
    final comments =
        cursor.consumeWhile((token) => docKinds.contains(token.kind))!;

    return Documentation(comments);
  }

  Annotation parseAnnotation(TokenIterator cursor) {
    _expectKind<Annotation>(cursor, TokenKind.At);

    return Annotation(parseExpression(cursor));
  }

  void _consumeMetadatas(TokenIterator cursor) {
    while (cursor.peek?.kind == TokenKind.Hashtag &&
        cursor.peek?.kind != TokenKind.EOF) {
      parseMetadata(cursor);
    }
  }

  void _consumeDocumentation(TokenIterator cursor) {
    while ({TokenKind.LineComment, TokenKind.BlockComment}
            .contains(cursor.peek?.kind) &&
        cursor.peek?.kind != TokenKind.EOF) {
      cursor.consume();
    }
  }

  void _consumeAnnotations(TokenIterator cursor) {
    while (cursor.peek?.kind == TokenKind.At &&
        cursor.peek?.kind != TokenKind.EOF) {
      parseAnnotation(cursor);
    }
  }

  void _consumeMetadataAndAnnotations(TokenIterator cursor) {
    _consumeMetadatas(cursor);
    _consumeAnnotations(cursor);
  }

  void _consumeOptionalData(TokenIterator cursor) {
    _consumeDocumentation(cursor);
    _consumeMetadataAndAnnotations(cursor);
  }

  TokenIterator _cursorAfterDocumentation(TokenIterator cursor) {
    final clone = cursor.clone();
    _consumeDocumentation(clone);
    return clone;
  }

  TokenIterator _cursorAfterMetas(TokenIterator cursor) {
    final clone = cursor.clone();
    _consumeMetadataAndAnnotations(clone);
    return clone;
  }

  TokenIterator _cursorAfterOptionalData(TokenIterator cursor) {
    final clone = cursor.clone();
    _consumeOptionalData(clone);
    return clone;
  }

  Declaration parseDeclaration(TokenIterator initialCursor) {
    final cursor = _cursorAfterOptionalData(initialCursor);
    final kind = _expectPeekIdentifiers<Declaration>(cursor, {'on', 'data'});
    switch (kind) {
      case 'on':
        return parseOnDeclaration(initialCursor);
      case 'data':
        return parseDataDeclaration(initialCursor);
      default:
        throw StateError('unreachable');
    }
  }

  TopLevelDerive parseTopLevelDerive(TokenIterator cursor) =>
      _parseDocumented(cursor, (cursor) {
        _expectIdentifier<TopLevelDerive>(cursor, 'derive');
        final derives =
            _parseSeparatedListOf(parseExpression, cursor, TokenKind.Comma);
        _expectKind<TopLevelDerive>(cursor, TokenKind.Semicolon);
        return TopLevelDerive(derives);
      });

  MetaProgram parseProgram(TokenIterator cursor) {
    final declarations = <Declaration>[];
    TopLevelDerive? topLevelDerive;

    final topLevelDerivePeekCursor = _cursorAfterOptionalData(cursor);
    if (topLevelDerivePeekCursor.peek?.content == 'derive') {
      topLevelDerive = parseTopLevelDerive(cursor);
    }
    while (!cursor.isAtEOF) {
      declarations.add(parseDeclaration(cursor));
    }
    return MetaProgram(topLevelDerive, declarations);
  }

  MetaProgram parse() {
    final it = tokens.iterator;
    if (!it.moveNext()) {
      // there is always an EOF token
      throw StateError('unreachable');
    }
    return parseProgram(it);
  }
}

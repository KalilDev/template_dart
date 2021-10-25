import 'token.dart';
import 'dart:core' hide Type;

class Scanner {
  Scanner(this.input);
  final String input;
  late final List<SourceLocation> _locations = _computeLocations();

  SourceLocation _locationAt(int offset) => offset >= _locations.length
      ? SourceLocation(
          _locations.last.row,
          _locations.last.col + _locations.length - offset,
        )
      : _locations[offset];
  List<SourceLocation> _computeLocations() {
    final result = List<SourceLocation?>.filled(input.length, null);
    var row = 0, col = 0;
    for (var i = 0; i < input.length; i++) {
      result[i] = SourceLocation(row, col);
      if (input[i] == '\n') {
        row++;
        col = 0;
      } else {
        col++;
      }
    }
    return result.cast();
  }

  static const _special = {
    '>==': TokenKind.GreaterEqualsEquals,
    '<\$>': TokenKind.SmallerDollarGreater,
    '->': TokenKind.MinusGreater,
    '>=': TokenKind.GreaterEquals,
    '>>': TokenKind.GreaterGreater,
    '<<': TokenKind.SmallerSmalller,
    '::': TokenKind.ColonColon,
    '=>': TokenKind.EqualsGreater,
    '>': TokenKind.Greater,
    '<': TokenKind.Smaller,
    '-': TokenKind.Minus,
    '+': TokenKind.Plus,
    '(': TokenKind.OpenParens,
    ')': TokenKind.CloseParens,
    '{': TokenKind.OpenBracket,
    '}': TokenKind.CloseBracket,
    '[': TokenKind.OpenSquareBracket,
    ']': TokenKind.CloseSquareBracket,
    ';': TokenKind.Semicolon,
    '|': TokenKind.Or,
    ',': TokenKind.Comma,
    '.': TokenKind.Dot,
    '=': TokenKind.Equals,
    ':': TokenKind.Colon,
    '?': TokenKind.Interrogation,
    '*': TokenKind.Star,
    '@': TokenKind.At,
    '#': TokenKind.Hashtag,
  };
  static const _intRegex = r"0x[0-9|A-F]+|0b[01]+|(?:-|)[0-9]+";
  static const _doubleRegex = r"[-+]?(?:\d*\.?\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?";
  static const _singleQuoteMultilineStringLiteral = r"'''(?:.|\n)*?'''";
  static const _singleQuoteStringLiteral = r"'.*?'";
  static const _doubleQuoteMultilineStringLiteral = r'"""(?:.|\n)*?""';
  static const _doubleQuoteStringLiteral = r'".*?"';
  static const _lineComment = r'.*\/\/.*';
  static const _blockComment = r'\/\*(?:.|\n)*?\*\/';
  static final _backslashCode = '\\'.codeUnits.single;
  static final _charsThatNeedToBeEscaped = r'|.(){}+$[]?*'.codeUnits.toSet();
  static bool _needsToBeEscaped(int charCode) =>
      _charsThatNeedToBeEscaped.contains(charCode);
  static String _escaped(String str) => str.codeUnits
      .map((e) => _needsToBeEscaped(e)
          ? String.fromCharCodes([_backslashCode, e])
          : String.fromCharCode(e))
      .join();
  static final _regexStr = [
    _group('int', _intRegex),
    _group('double', _doubleRegex),
    _group('lineComment', _lineComment),
    _group('blockComment', _blockComment),
  ].followedBy(_special.keys.map(_escaped)).followedBy([
    _group(
        'string',
        '$_singleQuoteMultilineStringLiteral'
            '|$_singleQuoteStringLiteral'
            '|$_doubleQuoteMultilineStringLiteral'
            '|$_doubleQuoteStringLiteral'),
    _group('whitespace', r'\s+'),
  ]).join('|');
  static const _otherKinds = {
    'int': TokenKind.IntLiteral,
    'double': TokenKind.DoubleLiteral,
    'string': TokenKind.StringLiteral,
    'lineComment': TokenKind.LineComment,
    'blockComment': TokenKind.BlockComment,
  };
  static final _regex = RegExp(_regexStr, unicode: true);

  static String _group(String groupName, String regex) =>
      '(?<$groupName>$regex)';

  TokenKind _kindFor(RegExpMatch match, String content) {
    final special = _special[content];
    if (special != null) {
      return special;
    }
    final otherKind = _otherKinds.entries
        .map((e) => match.namedGroup(e.key) == null ? null : e.value)
        .whereType<TokenKind>();
    if (otherKind.isNotEmpty) {
      return otherKind.single;
    }
    return TokenKind.Identifier;
  }

  Token? _onNonMatch(int index, String content) {
    return Token(
        content,
        SourceRange(_locationAt(index), _locationAt(index + content.length)),
        TokenKind.Identifier);
  }

  Token? _onMatch(Match rawMatch) {
    final match = rawMatch as RegExpMatch;
    if (rawMatch.namedGroup('whitespace') != null) {
      return null;
    }
    final content = match.group(0)!;
    final range = SourceRange(_locationAt(match.start), _locationAt(match.end));
    final kind = _kindFor(match, content);
    return Token(content, range, kind);
  }

  TokenList parse() {
    final list = input
        .splitMap<Token>(_regex, onMatch: _onMatch, onNonMatch: _onNonMatch)
        .where((token) => token.content.isNotEmpty) // ????
        .fold<TokenList>(TokenList(), (list, token) => list..add(token));
    list.add(Token('', SourceRange.synthetic, TokenKind.EOF));
    return list;
  }
}

extension StringE on String {
  Iterable<T> _splitMapEmptyString<T>(T? Function(Match match) onMatch,
      T? Function(int start, String nonMatch) onNonMatch) sync* {
    // Pattern is the empty string.
    int length = this.length;
    int i = 0;
    final r0 = onNonMatch(0, "");
    if (r0 != null) {
      yield r0;
    }
    while (i < length) {
      final r1 = onMatch(_StringMatch(i, this, ""));
      if (r1 != null) {
        yield r1;
      }
      // Special case to avoid splitting a surrogate pair.
      int code = codeUnitAt(i);
      if ((code & ~0x3FF) == 0xD800 && length > i + 1) {
        // Leading surrogate;
        code = codeUnitAt(i + 1);
        if ((code & ~0x3FF) == 0xDC00) {
          // Matching trailing surrogate.
          final r2 = onNonMatch(i, substring(i, i + 2));
          if (r2 != null) {
            yield r2;
          }
          i += 2;
          continue;
        }
      }

      final r3 = onNonMatch(i, this[i]);
      if (r3 != null) {
        yield r3;
      }
      i++;
    }
    final r4 = onMatch(_StringMatch(i, this, ""));
    if (r4 != null) {
      yield r4;
    }
    final r5 = onNonMatch(length, "");
    if (r5 != null) {
      yield r5;
    }
  }

  // ignore: prefer_void_to_null
  static Null _returnNull([Object? _, Object? __]) => null;

  Iterable<T> splitMap<T>(Pattern pattern,
      {T? Function(Match match)? onMatch,
      T? Function(int start, String nonMatch)? onNonMatch}) {
    onMatch ??= _returnNull;
    onNonMatch ??= _returnNull;
    if (pattern is String) {
      String stringPattern = pattern;
      if (stringPattern.isEmpty) {
        return _splitMapEmptyString(onMatch!, onNonMatch!);
      }
    }
    return () sync* {
      onMatch!;
      onNonMatch!;
      int startIndex = 0;
      for (Match match in pattern.allMatches(this)) {
        final nm = onNonMatch(startIndex, substring(startIndex, match.start));
        if (nm != null) {
          yield nm;
        }
        final m = onMatch(match);
        if (m != null) {
          yield m;
        }
        startIndex = match.end;
      }
      final r = onNonMatch(startIndex, substring(startIndex));
      if (r != null) {
        yield r;
      }
    }();
  }
}

class _StringMatch implements Match {
  const _StringMatch(this.start, this.input, this.pattern);

  @override
  int get end => start + pattern.length;
  @override
  String operator [](int g) => group(g);
  @override
  int get groupCount => 0;

  @override
  String group(int group) {
    if (group != 0) {
      throw RangeError.value(group);
    }
    return pattern;
  }

  @override
  List<String> groups(List<int> groups) {
    List<String> result = <String>[];
    for (int g in groups) {
      result.add(group(g));
    }
    return result;
  }

  @override
  final int start;
  @override
  final String input;
  @override
  final String pattern;
}

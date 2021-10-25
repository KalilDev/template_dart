// ignore_for_file: constant_identifier_names

import 'dart:collection';
import 'dart:core' hide Type;

enum TokenKind {
  StringLiteral,
  DoubleLiteral,
  IntLiteral,
  GreaterEqualsEquals,
  SmallerDollarGreater,
  MinusGreater,
  GreaterEquals,
  GreaterGreater,
  SmallerSmalller,
  ColonColon,
  EqualsGreater,
  Greater,
  Smaller,
  Minus,
  Plus,
  OpenParens,
  CloseParens,
  OpenBracket,
  CloseBracket,
  Hashtag,
  OpenSquareBracket,
  CloseSquareBracket,
  Semicolon,
  Or,
  Comma,
  Dot,
  Equals,
  Colon,
  Star,
  At,
  LineComment,
  BlockComment,
  Identifier,
  Interrogation,
  EOF,
}

class SourceLocation {
  const SourceLocation(this.row, this.col);

  final int row;
  final int col;

  @override
  String toString() => '$row:$col';
  static const synthetic = SourceLocation(-1, -1);
}

class SourceRange {
  const SourceRange(this.start, this.end);

  static const synthetic = SourceRange(
    SourceLocation.synthetic,
    SourceLocation.synthetic,
  );

  final SourceLocation start;
  final SourceLocation end;

  @override
  String toString() => '{$start to $end}';
}

class TokenList extends Iterable<Token> {
  TokenList();
  TokenList.sublist(Token tail, Token head)
      : _head = head,
        _tail = tail;
  factory TokenList.fromIterator(TokenIterator it) {
    final tail = it.current;
    while (it.moveNext()) {}
    final head = it.current;
    return TokenList.sublist(tail, head);
  }
  Token? _head;
  Token? _tail;

  void add(Token next) {
    if (_head == null) {
      _head = next;
      _tail = next;
      return;
    }
    _head!.append(next);
    _head = next;
  }

  @override
  TokenIterator get iterator => TokenIterator(this);

  SourceRange get location => _head == null
      ? SourceRange.synthetic
      : SourceRange(_tail!.range.start, _head!.range.end);
}

class TokenIterator extends BidirectionalIterator<Token> {
  final TokenList self;
  late _IntrusiveDoubleLinkedQueueIterator<Token> it =
      _IntrusiveDoubleLinkedQueueIterator<Token>(self._tail);

  TokenIterator(this.self);

  @override
  Token get current => it.current;

  TokenIterator clone() => TokenIterator(self)
    ..it = (_IntrusiveDoubleLinkedQueueIterator(it._cursor)
      ..cursorOffset = it.cursorOffset);

  Token? get peek => current;
  Token? get peekAfterComments {
    final it = clone();
    it.consumeWhile((token) {
      switch (token.kind) {
        case TokenKind.LineComment:
        case TokenKind.BlockComment:
          return true;
        default:
          return false;
      }
    });
    return it.peek;
  }

  TokenList? peekMany(int count) {
    final tail = peek;
    if (tail == null) {
      return null;
    }
    Token? head = tail;
    for (var i = 1;
        i < count && head != null;
        head = self._head == head ? null : head.next, i++) {}
    if (head == null) {
      return null;
    }
    return TokenList.sublist(tail, head);
  }

  TokenList? peekWhile(bool Function(Token) condition) {
    final tail = peek;
    if (tail == null) {
      return null;
    }
    var head = tail;
    while (condition(head) && self._head != head) {
      final next = head.next;
      if (next == null) {
        break;
      }
      head = next;
    }
    return TokenList.sublist(tail, head);
  }

  TokenList? peekUntil(bool Function(Token) condition) {
    final whileList = peekWhile((t) => !condition(t));
    if (whileList == null) {
      return null;
    }
    return whileList.._head = whileList._head!.next;
  }

  Token? consume() {
    if (!moveNext()) {
      return null;
    }
    return current;
  }

  TokenList? consumeWhile(bool Function(Token) condition) {
    final peeked = peekWhile(condition);
    if (peeked == null) {
      return null;
    }
    for (var i = 0; i < peeked.length; i++) {
      consume()!;
    }
    return peeked;
  }

  TokenList? consumeUntil(bool Function(Token) condition) {
    final peeked = peekUntil(condition);
    if (peeked == null) {
      return null;
    }
    for (var i = 0; i < peeked.length; i++) {
      consume()!;
    }
    return peeked;
  }

  TokenList? consumeMany(int count) {
    final tail = peek;
    if (tail == null) {
      return null;
    }
    Token? head = tail;
    for (var i = 1;
        i < count && head != null;
        head = self._head == head ? null : head.next, i++) {}
    if (head == null) {
      return null;
    }
    while (current != head) {
      assert(moveNext());
    }
    return TokenList.sublist(tail, head);
  }

  bool get isAtEOF =>
      it._cursor?.kind == TokenKind.EOF ||
      it._cursor?.next?.kind == TokenKind.EOF;

  @override
  bool moveNext() {
    final didMove = it.moveNext();
    if (didMove && current == self._head) {
      it.movePrevious();
      return false;
    }
    return didMove;
  }

  @override
  bool movePrevious() {
    if (current == self._tail) {
      return false;
    }
    return it.movePrevious();
  }
}

class _IntrusiveDoubleLink<Link extends _IntrusiveDoubleLink<Link>> {
  Link? _previousLink;
  Link? _nextLink;

  void _link(Link? previous, Link? next) {
    _nextLink = next;
    _previousLink = previous;
    if (previous != null) previous._nextLink = this as Link;
    if (next != null) next._previousLink = this as Link;
  }

  void _unlink() {
    if (_previousLink != null) _previousLink!._nextLink = _nextLink;
    if (_nextLink != null) _nextLink!._previousLink = _previousLink;
    _nextLink = null;
    _previousLink = null;
  }

  bool get _isLinked => _previousLink != null || _nextLink != null;
}

/// An entry in a doubly linked list. It contains a pointer to the next
/// entry, the previous entry, and the boxed element.
abstract class IntrusiveDoubleLinkedQueueEntry<
        E extends IntrusiveDoubleLinkedQueueEntry<E>>
    extends _IntrusiveDoubleLink<IntrusiveDoubleLinkedQueueEntry<E>>
    implements DoubleLinkedQueueEntry<E> {
  /// Appends the given [e] as entry just after this entry.
  @override
  void append(E e) {
    if (e._isLinked) {
      throw StateError('Cannot append an already linked [$E]');
    }
    e._link(this, _nextLink);
  }

  /// Prepends the given [e] as entry just before this entry.
  @override
  void prepend(E e) {
    if (e._isLinked) {
      throw StateError('Cannot append an already linked [$E]');
    }
    e._link(_previousLink, this);
  }

  @override
  E remove() {
    _unlink();
    return this as E;
  }

  /// Returns the previous entry or `null` if there is none.
  E? get previous => _previousLink as E?;

  /// Returns the next entry or `null` if there is none.
  E? get next => _nextLink as E?;

  @override
  E get element => this as E;

  @override
  set element(E element) => throw StateError('Invalid operation!');

  @override
  DoubleLinkedQueueEntry<E>? nextEntry() => _nextLink;

  @override
  DoubleLinkedQueueEntry<E>? previousEntry() => _previousLink;
}

class _IntrusiveDoubleLinkedQueueIterator<
        Entry extends IntrusiveDoubleLinkedQueueEntry<Entry>>
    implements BidirectionalIterator<Entry> {
  _IntrusiveDoubleLinkedQueueIterator(this._cursor);

  Entry? _cursor;
  int cursorOffset = -1;

  Entry? get cursor => cursorOffset == 0 ? _cursor : null;

  @override
  Entry get current => cursor!;

  @override
  bool moveNext() {
    if (_cursor == null) {
      return false;
    }
    if (cursorOffset != 0) {
      cursorOffset++;
      return cursorOffset == 0;
    }
    final next = cursor!.next;
    if (next == null) {
      cursorOffset++;
      return false;
    }
    _cursor = next;
    return true;
  }

  @override
  bool movePrevious() {
    if (_cursor == null) {
      return false;
    }
    if (cursorOffset != 0) {
      cursorOffset--;
      return cursorOffset == 0;
    }
    final prev = cursor!.previous;
    if (prev == null) {
      cursorOffset--;
      return false;
    }
    _cursor = prev;
    return true;
  }
}

class Token extends IntrusiveDoubleLinkedQueueEntry<Token> {
  Token(this.content, this.range, this.kind);
  Token.synthetic(this.content, this.kind) : range = SourceRange.synthetic;
  Token? get prev => previous;

  final String content;
  final SourceRange range;
  final TokenKind kind;

  @override
  String toString() => 'T{ `$content` at $range}';
}

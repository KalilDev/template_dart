# Template dart

An metaprogramming language, with easy syntax, created to build complex
class-structures for dart programs without boilerplate in an customizable,
extensible and simple way.

## Features

- Out of the box Union support
- Out of the box built_value Derivers
- Simple Object Model and easy interop
- Robust compiler
- Allows injecting verbatin dart code
- Allows injecting annotations and documentation on the dart code
- Allows injecting metadata to be read by the Derivers
- Allows running code for an library, the classes with the derivation clause
  (In case of unions, every member and the super class, and in case of an
  single class, the class itself), and for each data declaration.
- Allows generic types


## Examples

### Maybe monad
The template code down below:
```
data Maybe<T : Object> implements Monad<T> = Just { _value :: T } | None
    derive(Visit(Cata), Final, Constructor);

on Maybe {
    map<R>(fn :: Function(T :: value) -> R) -> Maybe<R> {
        return visit(just: (v) => Just(fn(v)), none: () => None());
    }
    bind<R>(fn :: Function(T :: value) -> Maybe<R>) -> Maybe<R> {
        return visit(just: (v) => fn(v), none: () => None());
    }
}
```

Generates the dart code below:
```dart
abstract class Maybe<T extends Object> implements Monad<T> {
  const Maybe._();

  R visit<R>({required R Function(T _value) just, required R Function() none});
  Maybe<R> map<R extends Object>(
      R Function(
    T v,
  )
          fn) {
    return visit(just: (v) => Just(fn(v)), none: () => None());
  }

  Maybe<R> bind<R extends Object>(
      Maybe<R> Function(
    T v,
  )
          fn) {
    return visit(just: (v) => fn(v), none: () => None());
  }
}

class Just<T extends Object> extends Maybe<T> {
  const Just(T value)
      : _value = value,
        super._();

  final T _value;

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      just(_value);
}

class None<T extends Object> extends Maybe<T> {
  const None() : super._();

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      none();
}
```

### Maybe built serializable
The template code down below:
```
//
data Maybe<T : Object> implements Monad<T> with MaybeMixin<T> = Just { _value :: T } | None
    derive(Visit(Cata), Built(Serializable(WithoutWireTypeInfo, PreserveGenerics)));
```

Generates the dart code below:
```dart
abstract class Maybe<T extends Object> with MaybeMixin<T> implements Monad<T> {
  Maybe._();

  R visit<R>(
      {required R Function(T _value) just, required R Function() none});
  Map<String, dynamic> toJson();
}

class Just<T extends Object>
    with MaybeMixin<T>
    implements Maybe<T>, Built<Just<T>, JustBuilder<T>> {
  Just._();

  static final Serializer<Object> serializer = _$justSerializer;

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      just(_value);
  T get _value;
  Map<String, dynamic> toJson() =>
      serializers.serialize(this, specifiedType: FullType(Maybe, [FullType(T)]))
          as Map<String, dynamic>;
  static Just<T> fromJson<T>(Map<String, dynamic> json) =>
      serializers.deserialize(json,
          specifiedType: FullType(Maybe, [FullType(T)])) as Just<T>;
}

class None<T extends Object>
    with MaybeMixin<T>
    implements Maybe<T>, Built<None<T>, NoneBuilder<T>> {
  None._();

  static final Serializer<Object> serializer = _$noneSerializer;

  @override
  R visit<R>(
          {required R Function(T _value) just, required R Function() none}) =>
      none();
  Map<String, dynamic> toJson() =>
      serializers.serialize(this, specifiedType: FullType(Maybe, [FullType(T)]))
          as Map<String, dynamic>;
  static None<T> fromJson<T>(Map<String, dynamic> json) =>
      serializers.deserialize(json,
          specifiedType: FullType(Maybe, [FullType(T)])) as None<T>;
}
```

### Hive type adapter generation
```
#1
data Foo {#0 field :: Type}
        derive(Hive);
```

```dart
@HiveType(typeId: 1)
class Foo {
    @HiveField(0)
    Type field;
}
```

## Usage

To generate code you can use the Scanner, Parser and Compiler classes directly,
or use the `compileMetaprogram` Function.

```dart
const program = '''
data Foo {};
''';
try {
    final compiled = compileMetaprogram(program);
    print(compiled);
} on MetaprogramCompileException catch (e) {
    print('Oops!');
    print(e);
}
```
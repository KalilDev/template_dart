part of 'derivation.dart';

bool hasUnderline(String s) => s.startsWith('_');
// innefficient af
String withoutUnderlines(String s) =>
    hasUnderline(s) ? withoutUnderlines(s.substring(1)) : s;

String toLowerCamelCase(String s) => s[0].toLowerCase() + s.substring(1);

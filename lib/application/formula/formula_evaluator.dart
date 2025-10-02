import 'dart:math' as math;

typedef FormulaLookup = double? Function(String reference);

class FormulaEvaluator {
  FormulaEvaluator._();

  static final RegExp _formulaPattern = RegExp(r'^\s*=\s*(.*)$');

  static String? evaluate(
    String input, {
    FormulaLookup? lookup,
  }) {
    final match = _formulaPattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    final expression = match.group(1)?.trim();
    if (expression == null || expression.isEmpty) {
      return null;
    }
    final tokens = _tokenize(expression);
    if (tokens.isEmpty) {
      return null;
    }
    final rpn = _toRpn(tokens);
    if (rpn == null) {
      return null;
    }
    final result = _evaluateRpn(rpn, lookup);
    if (result == null || result.isNaN || result.isInfinite) {
      return null;
    }
    if ((result % 1).abs() < 1e-10) {
      return result.toInt().toString();
    }
    final rounded = double.parse(result.toStringAsFixed(12));
    return _trimTrailingZeros(rounded.toString());
  }

  static List<String> _tokenize(String expression) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    String? previous;
    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == ' ' || char == '\t') {
        continue;
      }
      if (_isOperator(char) || char == '(' || char == ')') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        if (char == '-' && (previous == null || _isOperator(previous) || previous == '(')) {
          buffer.write(char);
        } else {
          tokens.add(char);
          previous = char;
        }
        continue;
      }
      if (_isIdentifierStart(char) ||
          (buffer.isNotEmpty && _isIdentifierCandidate(buffer.toString()) && _isIdentifierPart(char))) {
        buffer.write(char);
        previous = buffer.toString();
        continue;
      }
      if (_isNumericChar(char) || char == '.') {
        buffer.write(char);
        previous = buffer.toString();
        continue;
      }
      return <String>[];
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }

  static List<String>? _toRpn(List<String> tokens) {
    final output = <String>[];
    final operators = <String>[];
    for (final token in tokens) {
      if (_isNumber(token) || _isIdentifier(token)) {
        output.add(token);
        continue;
      }
      if (_isOperator(token)) {
        while (operators.isNotEmpty &&
            _isOperator(operators.last) &&
            _precedence(operators.last) >= _precedence(token)) {
          output.add(operators.removeLast());
        }
        operators.add(token);
        continue;
      }
      if (token == '(') {
        operators.add(token);
        continue;
      }
      if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isEmpty || operators.removeLast() != '(') {
          return null;
        }
        continue;
      }
      return null;
    }
    while (operators.isNotEmpty) {
      final op = operators.removeLast();
      if (op == '(' || op == ')') {
        return null;
      }
      output.add(op);
    }
    return output;
  }

  static double? _evaluateRpn(List<String> rpn, FormulaLookup? lookup) {
    final stack = <double>[];
    for (final token in rpn) {
      if (_isNumber(token)) {
        final value = double.tryParse(token);
        if (value == null) {
          return null;
        }
        stack.add(value);
        continue;
      }
      if (_isIdentifier(token)) {
        if (lookup == null) {
          return null;
        }
        final isNegative = token.startsWith('-');
        final reference = isNegative ? token.substring(1) : token;
        if (reference.isEmpty) {
          return null;
        }
        final resolved = lookup(reference);
        if (resolved == null) {
          return null;
        }
        stack.add(isNegative ? -resolved : resolved);
        continue;
      }
      if (!_isOperator(token) || stack.length < 2) {
        return null;
      }
      final b = stack.removeLast();
      final a = stack.removeLast();
      switch (token) {
        case '+':
          stack.add(a + b);
          break;
        case '-':
          stack.add(a - b);
          break;
        case '*':
          stack.add(a * b);
          break;
        case '/':
          if (b == 0) {
            return null;
          }
          stack.add(a / b);
          break;
        case '^':
          stack.add(math.pow(a, b).toDouble());
          break;
        default:
          return null;
      }
    }
    if (stack.length != 1) {
      return null;
    }
    return stack.single;
  }

  static bool _isOperator(String token) =>
      token == '+' || token == '-' || token == '*' || token == '/' || token == '^';

  static bool _isNumericChar(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isNumber(String token) => double.tryParse(token) != null;

  static bool _isIdentifierStart(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '_' ||
        char == '\$';
  }

  static bool _isIdentifierPart(String char) => _isIdentifierStart(char) || _isNumericChar(char);

  static bool _isIdentifierCandidate(String buffer) {
    if (buffer.isEmpty) {
      return false;
    }
    var index = 0;
    if (buffer[index] == '-') {
      index++;
      if (index >= buffer.length) {
        return true;
      }
    }
    if (!_isIdentifierStart(buffer[index])) {
      return false;
    }
    for (var i = index + 1; i < buffer.length; i++) {
      if (!_isIdentifierPart(buffer[i])) {
        return false;
      }
    }
    return true;
  }

  static bool _isIdentifier(String token) {
    if (token.isEmpty) {
      return false;
    }
    var index = 0;
    if (token.startsWith('-')) {
      index = 1;
      if (index >= token.length) {
        return false;
      }
    }
    if (!_isIdentifierStart(token[index])) {
      return false;
    }
    for (var i = index + 1; i < token.length; i++) {
      if (!_isIdentifierPart(token[i])) {
        return false;
      }
    }
    return true;
  }

  static int _precedence(String operatorToken) {
    switch (operatorToken) {
      case '^':
        return 3;
      case '*':
      case '/':
        return 2;
      case '+':
      case '-':
        return 1;
      default:
        return 0;
    }
  }

  static String _trimTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value;
    }
    var trimmed = value;
    while (trimmed.contains('.') && trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

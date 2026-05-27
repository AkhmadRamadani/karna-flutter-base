/// Convert snake_case to PascalCase.
/// Example: order_history → OrderHistory
String toPascalCase(String input) {
  return input.split('_').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1);
  }).join();
}

/// Convert snake_case to camelCase.
/// Example: order_history → orderHistory
String toCamelCase(String input) {
  final pascal = toPascalCase(input);
  if (pascal.isEmpty) return '';
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// Validate a snake_case name.
bool isValidSnakeCase(String input) {
  return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(input);
}

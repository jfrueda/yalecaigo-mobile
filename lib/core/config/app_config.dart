class AppConfig {
  /// URL base de la API. Se puede reemplazar al ejecutar o compilar con:
  /// --dart-define=API_BASE_URL=http://10.0.2.2:8088/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8088/api',
  );

  /// Activa registros mínimos de red sin imprimir tokens ni contraseñas.
  static const bool enableNetworkLogs = bool.fromEnvironment(
    'API_LOGS',
    defaultValue: false,
  );

  static String get normalizedBaseUrl {
    final value = baseUrl.trim();
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

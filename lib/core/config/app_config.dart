/// Configuracao injetada em tempo de build:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000
///
/// Padrao 10.0.2.2 = o "localhost do Windows" visto de dentro do emulador
/// Android. Em celular fisico use o IP da maquina na rede local e libere a
/// porta 3000 no Firewall do Windows.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Prefixo das rotas de negocio. /health fica fora dele.
  static const String apiUrl = '$apiBaseUrl/api/v1';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

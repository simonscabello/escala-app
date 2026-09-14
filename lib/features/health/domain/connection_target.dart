/// Como o servidor aparece na tela de diagnóstico.
///
/// **O endereço de produção não é mostrado.** A tela é aberta por qualquer
/// pessoa, inclusive sem login, e o nome do serviço na nuvem não ajuda ninguém
/// da equipe a resolver um problema de conexão — só expõe onde a API mora. Em
/// servidor local (emulador, rede de casa) o endereço continua visível: aí
/// quem abre a tela é quem desenvolve, e o `10.0.2.2:3000` é justamente a
/// informação de que precisa.
class ServerTarget {
  const ServerTarget({
    required this.label,
    required this.isLocal,
    required this.isSecure,
    this.detail,
  });

  /// "Servidor da Pauta" ou "Servidor local".
  final String label;

  /// "Conexão segura" em produção; `host:porta` no servidor local.
  final String? detail;
  final bool isLocal;
  final bool isSecure;
}

bool _isLocalHost(String host) {
  if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
    return true;
  }
  // Faixas de rede privada: o celular físico falando com a máquina de casa.
  return host.startsWith('192.168.') ||
      host.startsWith('10.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
}

ServerTarget describeServer(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty) {
    return const ServerTarget(
      label: 'Servidor não configurado',
      isLocal: false,
      isSecure: false,
    );
  }

  final secure = uri.scheme == 'https';
  if (_isLocalHost(uri.host)) {
    return ServerTarget(
      label: 'Servidor local',
      detail: uri.hasPort ? '${uri.host}:${uri.port}' : uri.host,
      isLocal: true,
      isSecure: secure,
    );
  }

  return ServerTarget(
    label: 'Servidor da Pauta',
    detail: secure ? 'Conexão segura' : 'Conexão sem criptografia',
    isLocal: false,
    isSecure: secure,
  );
}

/// Tira o endereço do servidor de produção de um texto antes de exibi-lo.
///
/// Mensagens de erro de rede às vezes carregam a URL inteira; na tela, ela
/// vira "servidor da Pauta". No servidor local nada é trocado.
String redactServerAddress(String text, String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty || _isLocalHost(uri.host)) return text;
  return text
      .replaceAll(baseUrl, 'servidor da Pauta')
      .replaceAll(uri.host, 'servidor da Pauta');
}

/// "Produção", "Desenvolvimento", "Teste" — o `NODE_ENV` dito em português.
String environmentLabel(String environment) => switch (environment) {
      'production' => 'Produção',
      'development' => 'Desenvolvimento',
      'test' => 'Teste',
      _ => environment,
    };

/// "Rápida (120 ms)", "Normal (800 ms)", "Lenta (2,4 s)".
String responseTimeLabel(Duration duration) {
  final ms = duration.inMilliseconds;
  final valor = ms < 1000
      ? '$ms ms'
      : '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';
  final ritmo = ms < 400
      ? 'Rápida'
      : ms < 1500
          ? 'Normal'
          : 'Lenta';
  return '$ritmo ($valor)';
}

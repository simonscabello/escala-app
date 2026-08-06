/// Funcionalidades prontas, porém desligadas na interface.
///
/// O código (tela, diálogo e endpoint) continua no lugar: esconder por flag
/// evita remover e reescrever depois, e deixa explícito que a ausência é uma
/// decisão, não um esquecimento.
class FeatureFlags {
  const FeatureFlags._();

  /// Duplicar uma escala para outra data. Backend e diálogo funcionam; a
  /// entrada some do menu enquanto o fluxo não for revisto.
  static const bool duplicateSchedule = false;
}

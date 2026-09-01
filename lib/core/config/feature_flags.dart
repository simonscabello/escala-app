/// Chaves de liberação gradual de funcionalidades.
class FeatureFlags {
  const FeatureFlags._();

  /// Duplicar uma escala para outra data.
  ///
  /// Liberada depois da revisão do fluxo e da verificação de que cultos,
  /// escalação, ministrante, recados e repertório continuam nos horários
  /// correspondentes da cópia.
  static const bool duplicateSchedule = true;
}

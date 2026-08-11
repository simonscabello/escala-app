import 'package:flutter/material.dart';

/// Tempos e curvas do movimento.
///
/// A regra do app é que **animação serve para explicar, não para enfeitar**:
/// ela mostra de onde uma coisa veio ou que algo mudou de estado. Onde não há
/// nada a explicar, não há animação.
///
/// Três tempos bastam, e ter só três é o ponto: valores escolhidos a olho por
/// tela (180 aqui, 250 ali) produzem um app que parece ter sido montado por
/// pessoas diferentes, sem que ninguém consiga apontar o motivo.
class AppMotion {
  const AppMotion._();

  /// Resposta ao toque: cor de um chip, aparecer de um selo. Rápido o bastante
  /// para parecer instantâneo, lento o bastante para não piscar.
  static const Duration fast = Duration(milliseconds: 120);

  /// O padrão: trocar o conteúdo de uma lista, abrir e fechar um bloco.
  static const Duration normal = Duration(milliseconds: 200);

  /// Movimento que percorre a tela. Acima disto o usuário espera pela interface.
  static const Duration slow = Duration(milliseconds: 320);

  /// Sai rápido, chega devagar — o mesmo perfil do Material, que é o que o
  /// Android inteiro faz. Ir contra isso faz o app parecer estranho antes de
  /// parecer diferente.
  static const Curve standard = Curves.easeOutCubic;

  /// Para o que entra na tela vindo do nada.
  static const Curve enter = Curves.easeOut;
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../features/team/domain/position_visuals.dart';

/// Icone da funcao (violao, bateria, mesa de som).
///
/// Usa [FaIcon] e nao [Icon]: os glifos do Font Awesome nao sao quadrados, e o
/// [Icon] os encaixa a forca numa caixa `size x size` -- "sliders", que e bem
/// mais largo que alto, sai deformado.
class PositionIcon extends StatelessWidget {
  const PositionIcon(
    this.name, {
    super.key,
    this.category,
    this.size = 18,
    this.color,
  });

  final String name;

  /// `VOCAL`, `INSTRUMENT` ou `TECH`. Ausente no detalhe da escala, onde o
  /// backend so devolve o nome da funcao.
  final String? category;

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FaIcon(
      PositionVisuals.icon(name, category: category),
      size: size,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

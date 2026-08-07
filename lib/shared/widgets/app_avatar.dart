import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;

  /// Caminho devolvido pela API ("/uploads/avatars/x.jpg"). Absoluto tambem
  /// funciona. Nulo, vazio ou com falha de carregamento cai na inicial: a
  /// lista de integrantes não pode ficar com buracos quando a rede oscila.
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  String? get _absoluteUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${AppConfig.apiBaseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = _absoluteUrl;

    final initial = Text(
      _initial,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: foregroundColor ?? scheme.onPrimaryContainer,
          ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? scheme.primaryContainer,
      foregroundColor: foregroundColor ?? scheme.onPrimaryContainer,
      child: url == null
          ? initial
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // A inicial fica visivel enquanto a foto carrega, em vez de um
                // circulo vazio piscando na lista.
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : initial,
                errorBuilder: (_, __, ___) => initial,
              ),
            ),
    );
  }
}

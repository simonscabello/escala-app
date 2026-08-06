import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? scheme.primaryContainer,
      foregroundColor: foregroundColor ?? scheme.onPrimaryContainer,
      child: Text(
        _initial,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: foregroundColor ?? scheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

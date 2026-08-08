import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Os horários da escala em linhas alinhadas: rótulo à esquerda, hora à direita.
///
/// Antes eram etiquetas coloridas num `Wrap`, e duas coisas não funcionavam.
/// O ensaio em outro dia carregava a data por extenso e estourava a etiqueta
/// ("Ensaio Segunda-feira, 10 de agosto 00:30"); e o fundo colorido dava a três
/// linhas de informação corriqueira o peso visual de um alerta — a mesma cor
/// que a faixa de "alguém avisou que não pode" usa logo abaixo.
///
/// Em coluna, as horas caem todas na mesma vertical e ficam comparáveis de
/// relance ("08:30 / 19:00"), que é a pergunta real de quem abre a escala. O
/// rótulo longo corta com "…" em vez de quebrar o cartão. A cor sobrou só no
/// ícone do culto, que é o que se procura primeiro.
class EventTimesList extends StatelessWidget {
  const EventTimesList({
    super.key,
    required this.event,
    required this.timezone,
  });

  final Event event;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final cultos = event.displayServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cultos.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _TimeRow(
            icon: Icons.church_rounded,
            label: cultos[i].label,
            value: formatEventTime(cultos[i].startsAt, timezone),
            emphasized: true,
          ),
        ],
        const SizedBox(height: 6),
        if (event.rehearsalAt != null)
          _TimeRow(
            icon: Icons.music_note_rounded,
            label: 'Ensaio',
            value: formatRehearsalTime(
              event.rehearsalAt!,
              event.startsAt,
              timezone,
            ),
          )
        else
          // Ausência de ensaio é informação, não vazio: quem recebe a escala
          // precisa saber que não há, e não deduzir da linha que falta.
          const _TimeRow(icon: Icons.music_off_rounded, label: 'Sem ensaio'),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;

  /// Nulo quando não há hora a mostrar ("Sem ensaio").
  final String? value;

  /// O horário do culto é a informação que se procura primeiro.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasized ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            value!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasized ? scheme.onSurface : scheme.onSurfaceVariant,
              // Tabular: com "08:30" e "19:00" um sob o outro, largura de dígito
              // variável desalinharia os dois-pontos.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Os horários da escala, **escritos como se alguém estivesse contando**.
///
/// "Cultos: Manhã às 08:30 e Noite às 19:00. Ensaio no sábado às 19:00."
///
/// Já foram duas outras coisas. Primeiro `[ícone] Rótulo ....... 09:00`, com a
/// hora encostada na margem direita — a resposta à única pergunta que importa
/// ("que horas eu preciso estar lá?") ficava no fim da leitura. Depois uma
/// coluna de horas alinhadas, que respondia a pergunta certa mas lia como
/// tabela: informação correta, exposta como planilha no meio de uma tela que
/// não tem nenhuma outra.
///
/// Em frase, três coisas melhoram de uma vez: some a aparência de dado solto, o
/// ensaio ganha o dia por extenso em vez de uma abreviação ("no sábado", não
/// "sáb"), e o texto vira o que a pessoa repetiria para alguém no telefone.
///
/// **A hora continua sendo a âncora** — não pela posição, agora, mas pelo peso:
/// os horários saem em 700 na cor cheia do texto, e tudo em volta em regular no
/// cinza de apoio. Numa frase inteira em cinza, só os números pulam. Continuam
/// tabulares, para que "08:30" e "19:00" tenham a mesma largura quando caem um
/// embaixo do outro na quebra de linha.
///
/// A forma corrida da lista da agenda ("Manhã 08:30 · Noite 19:00") não muda:
/// ali a pergunta é "qual escala é esta?", e uma frase por item gastaria três
/// linhas em cada.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final base = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.55,
    );
    final hour = base.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: AppTypography.tabular,
    );

    return Text.rich(
      TextSpan(
        children: [
          ..._services(hour),
          const TextSpan(text: '\n'),
          ..._rehearsal(hour),
        ],
      ),
      style: base,
    );
  }

  /// "Culto às 09:00." com um; "Cultos: A às 08:30 e B às 19:00." com vários.
  ///
  /// O prefixo "Cultos:" só entra quando há mais de um. Com um só, ele
  /// produziria "Cultos: Culto às 09:00" — que é o rótulo mais comum da grade.
  List<InlineSpan> _services(TextStyle hour) {
    final services = event.displayServices;
    if (services.isEmpty) return const [];

    InlineSpan time(String value) => TextSpan(text: value, style: hour);

    if (services.length == 1) {
      return [
        TextSpan(text: '${services.first.label} às '),
        time(formatEventTime(services.first.startsAt, timezone)),
        const TextSpan(text: '.'),
      ];
    }

    final spans = <InlineSpan>[const TextSpan(text: 'Cultos: ')];
    for (var i = 0; i < services.length; i++) {
      if (i > 0) {
        // Vírgula entre os do meio, "e" antes do último: é assim que se lê uma
        // enumeração, e com dois cultos (o caso comum) só existe o "e".
        spans.add(TextSpan(text: i == services.length - 1 ? ' e ' : ', '));
      }
      spans
        ..add(TextSpan(text: '${services[i].label} às '))
        ..add(time(formatEventTime(services[i].startsAt, timezone)));
    }
    return spans..add(const TextSpan(text: '.'));
  }

  List<InlineSpan> _rehearsal(TextStyle hour) {
    final rehearsalAt = event.rehearsalAt;
    if (rehearsalAt == null) {
      // Ausência de ensaio é informação, não vazio: quem recebe a escala
      // precisa saber que não há, e não deduzir da linha que falta.
      return const [TextSpan(text: 'Sem ensaio.')];
    }

    final day = formatRehearsalDayPhrase(rehearsalAt, event.startsAt, timezone);

    return [
      TextSpan(text: day.isEmpty ? 'Ensaio às ' : 'Ensaio $day às '),
      TextSpan(
        text: formatEventTime(rehearsalAt, timezone),
        style: hour,
      ),
      const TextSpan(text: '.'),
    ];
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/date/civil_date.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../domain/event_datetime.dart';

/// Calendário de consulta, independente dos modelos de escala e de Riverpod.
/// Segue a semana e as cores do seletor de indisponibilidade; aqui o passado
/// também é selecionável.
///
/// **O dia com compromisso é um dia pintado, não um dia com um ponto.** O ponto
/// de 5px embaixo do número era o desenho anterior, e ele pedia atenção para
/// ser notado: quem abre a agenda de relance — que é como ela é usada — via
/// trinta números iguais. Agora o dia marcado ganha o fundo de
/// `primaryContainer`, o número em negrito e um traço embaixo; o mês inteiro se
/// lê sem procurar. O traço fica porque cor sozinha não é sinal para quem não
/// distingue as duas, e porque é ele que conta **quantos** compromissos o dia
/// tem (um por compromisso, até três).
///
/// **Quatro estados, quatro desenhos diferentes**, e é isso que a tela precisa
/// garantir: dia comum (sem fundo), hoje (moldura), dia com compromisso (fundo
/// claro + traço) e dia selecionado (fundo cheio, da cor da marca). Selecionado
/// **com** compromisso é o fundo cheio com o traço por cima, em `onPrimary` —
/// selecionar um dia não pode apagar a informação que trouxe o dedo até ele.
///
/// **O que o traço significa é de quem chama** ([legend]): a agenda inteira
/// pinta os dias com algo marcado -- escala ou evento --, e o recorte pessoal
/// pinta os dias que são seus.
/// É o mesmo desenho dizendo duas coisas, e o rótulo embaixo é o que separa as
/// duas — inclusive para quem ouve a tela.
class AgendaCalendar extends StatelessWidget {
  const AgendaCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.markedDays,
    required this.onSelected,
    required this.onMonthChanged,
    required this.onToday,
    this.legend = 'Com compromisso',
  });

  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;

  /// Dia (`AAAA-MM-DD`) -> quantos compromissos ele tem.
  ///
  /// É um mapa e não um conjunto porque o número aparece: o traço embaixo do
  /// dia se repete uma vez por compromisso, e a leitura de tela diz "2
  /// compromissos" em vez de só "com compromisso".
  final Map<String, int> markedDays;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onToday;

  /// O que um dia marcado quer dizer. Vai na legenda e na leitura de tela.
  final String legend;

  /// Quantos traços cabem embaixo do número sem virar tracejado.
  ///
  /// Acima disto a contagem some do desenho e fica só na leitura de tela e na
  /// lista do dia: três domingos de vigília não precisam de sete riscos de
  /// 4px para dizer "tem bastante coisa aqui".
  static const int maxMarks = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leading = DateTime(month.year, month.month).weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((leading + count) / 7).ceil();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthYearLabel(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Em celulares muito estreitos, conserva o alvo de toque sem
              // diminuir a fonte escolhida pelo usuário.
              final width = math.max(constraints.maxWidth, 7 * 44.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Table(
                    children: [
                      TableRow(
                        children: [
                          for (final label in [
                            'D',
                            'S',
                            'T',
                            'Q',
                            'Q',
                            'S',
                            'S',
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: ExcludeSemantics(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (var row = 0; row < rows; row++)
                        TableRow(
                          children: [
                            for (var col = 0; col < 7; col++)
                              if (row * 7 + col < leading ||
                                  row * 7 + col >= leading + count)
                                const SizedBox.shrink()
                              else
                                _day(
                                  context,
                                  DateTime(
                                    month.year,
                                    month.month,
                                    row * 7 + col - leading + 1,
                                  ),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                // A legenda mostra o **mesmo** desenho do dia marcado, em
                // miniatura: um ponto solto ao lado de "Com compromisso"
                // mandava procurar no mês uma coisa que não está lá.
                _LegendChip(
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    legend,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: onToday, child: const Text('Hoje')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = dateKey(day) == dateKey(selectedDay);
    final isToday = dateKey(day) == dateKey(today);
    final count = markedDays[dateKey(day)] ?? 0;
    final marked = count > 0;

    // Fundo cheio para o selecionado, fundo claro para o dia que tem algo,
    // nada para o resto. São três superfícies distintas, e é delas que vem a
    // leitura de relance -- o traço embaixo confirma e conta.
    final background = selected
        ? scheme.primary
        : marked
            ? scheme.primaryContainer
            : Colors.transparent;
    final foreground = selected
        ? scheme.onPrimary
        : marked
            ? scheme.onPrimaryContainer
            : scheme.onSurface;

    return Semantics(
      key: ValueKey('agenda-day-${dateKey(day)}'),
      button: true,
      selected: selected,
      label:
          '${capitalizeWeekday(DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(day))}'
          '${isToday ? ', hoje' : ''}'
          '${marked ? ', ${_countLabel(count)}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            // Hoje é uma **moldura**, e continua sendo nos quatro estados: é o
            // único sinal que não disputa com o fundo, e sem ele o dia de hoje
            // desapareceria dentro de um mês cheio de dias pintados.
            side: isToday
                ? BorderSide(
                    color: selected ? scheme.onPrimary : scheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelected(day),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected || isToday || marked
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // O espaço é reservado mesmo vazio: sem isto a grade
                    // sacode meio pixel entre um mês com compromissos e outro
                    // sem.
                    SizedBox(
                      height: 4,
                      child: marked
                          ? _DayMarks(count: count, color: foreground)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _countLabel(int count) => count == 1
      ? '1 compromisso'
      : '$count compromissos';
}

/// Os traços embaixo do número: um por compromisso, até [AgendaCalendar.maxMarks].
///
/// Traço e não ponto porque ele é mais largo que alto, e é essa proporção que
/// o faz aparecer num quadrado de 44px sem virar uma bolinha disputando espaço
/// com o número.
class _DayMarks extends StatelessWidget {
  const _DayMarks({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final marks = count.clamp(1, AgendaCalendar.maxMarks);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < marks; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 6,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

/// O dia marcado em miniatura, para a legenda.
class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      alignment: Alignment.center,
      child: _DayMarks(count: 1, color: foreground),
    );
  }
}

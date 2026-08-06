import 'package:flutter/material.dart';

/// Uma linha da grade de cultos da igreja: "Domingo, 08:30, Manhã".
///
/// Serve para montar a escala escolhendo uma data em vez de digitar rótulo e
/// horário toda semana -- que era o caminho para ter "Manhã", "manha" e
/// "Manhã " em domingos diferentes.
class ServiceTemplate {
  const ServiceTemplate({
    required this.id,
    required this.label,
    required this.weekday,
    required this.startMinutes,
    this.isActive = true,
  });

  factory ServiceTemplate.fromJson(Map<String, dynamic> json) {
    return ServiceTemplate(
      id: json['id'] as String,
      label: json['label'] as String,
      weekday: json['weekday'] as int,
      startMinutes: json['startMinutes'] as int,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String label;

  /// 0 = domingo ... 6 = sábado, igual ao `Date.getDay()` do JavaScript.
  ///
  /// **Não** é o `DateTime.weekday` do Dart, que vai de 1 (segunda) a 7
  /// (domingo). A conversão fica em [matchesDate] para não vazar daqui.
  final int weekday;

  /// Minutos desde a meia-noite: 08:30 = 510.
  final int startMinutes;

  final bool isActive;

  int get hour => startMinutes ~/ 60;
  int get minute => startMinutes % 60;

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Esta linha da grade vale para esta data?
  bool matchesDate(DateTime date) => weekday == jsWeekday(date);

  /// Converte o `DateTime.weekday` do Dart (1 = segunda ... 7 = domingo) para a
  /// convenção do backend (0 = domingo ... 6 = sábado).
  static int jsWeekday(DateTime date) => date.weekday % 7;
}

/// Escala futura que seria afetada por uma mudança na grade.
class AffectedEvent {
  const AffectedEvent({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.label,
  });

  factory AffectedEvent.fromJson(Map<String, dynamic> json) {
    return AffectedEvent(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
      label: json['label'] as String,
    );
  }

  final String eventId;
  final String title;

  /// Horário do **culto**, não da escala: é ele que mudaria.
  final DateTime startsAt;
  final String label;
}

const weekdayNames = [
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

String weekdayName(int jsWeekday) => weekdayNames[jsWeekday];

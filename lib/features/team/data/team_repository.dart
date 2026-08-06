import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/service_template.dart';
import '../domain/team_models.dart';

class TeamRepository {
  const TeamRepository(this._dio);

  final Dio _dio;

  Future<Team> create({required String name}) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams',
        data: {'name': name},
      );
      return Team.fromJson(response.data!);
    });
  }

  Future<Team> find(String teamId) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/teams/$teamId');
      return Team.fromJson(response.data!);
    });
  }

  Future<List<Member>> members(
    String teamId, {
    bool includeGuests = false,
  }) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/members',
        queryParameters: includeGuests ? {'includeGuests': true} : null,
      );
      return response.data!
          .map((e) => Member.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<Position>> positions(String teamId) async {
    return _guard(() async {
      final response =
          await _dio.get<List<dynamic>>('/teams/$teamId/positions');
      return response.data!
          .map((e) => Position.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  // --- Grade de cultos da igreja ---

  Future<List<ServiceTemplate>> serviceTemplates(String teamId) async {
    return _guard(() async {
      final response =
          await _dio.get<List<dynamic>>('/teams/$teamId/service-templates');
      return response.data!
          .map((e) => ServiceTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<ServiceTemplate> addServiceTemplate(
    String teamId, {
    required String label,
    required int weekday,
    required int startMinutes,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/service-templates',
        data: {
          'label': label,
          'weekday': weekday,
          'startMinutes': startMinutes,
        },
      );
      return ServiceTemplate.fromJson(response.data!);
    });
  }

  /// Escalas futuras que usam esta linha da grade.
  ///
  /// Consultado **antes** de salvar, para o app perguntar se a mudança também
  /// vale para elas em vez de decidir sozinho.
  Future<List<AffectedEvent>> serviceTemplateFutureEvents(
    String teamId,
    String templateId,
  ) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/service-templates/$templateId/future-events',
      );
      return response.data!
          .map((e) => AffectedEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<ServiceTemplate> updateServiceTemplate(
    String teamId,
    String templateId, {
    String? label,
    int? weekday,
    int? startMinutes,
    bool applyToFutureEvents = false,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/teams/$teamId/service-templates/$templateId',
        data: {
          if (label != null) 'label': label,
          if (weekday != null) 'weekday': weekday,
          if (startMinutes != null) 'startMinutes': startMinutes,
          if (applyToFutureEvents) 'applyToFutureEvents': true,
        },
      );
      return ServiceTemplate.fromJson(response.data!);
    });
  }

  Future<void> removeServiceTemplate(String teamId, String templateId) async {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/service-templates/$templateId');
    });
  }

  Future<Member> addMember(
    String teamId, {
    required String displayName,
    String? phone,
    List<String> positionIds = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/members',
        data: {
          'displayName': displayName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (positionIds.isNotEmpty) 'positionIds': positionIds,
        },
      );
      return Member.fromJson(response.data!);
    });
  }

  /// Convidado: entra na escala e no texto compartilhado, mas não vira
  /// integrante nem recebe convite.
  Future<Member> addGuest(String teamId, String displayName) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/members',
        data: {'displayName': displayName, 'isGuest': true},
      );
      return Member.fromJson(response.data!);
    });
  }

  Future<Member> updateMember(
    String teamId,
    String membershipId, {
    String? displayName,
    String? phone,
    List<String>? positionIds,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/teams/$teamId/members/$membershipId',
        data: {
          if (displayName != null) 'displayName': displayName,
          if (phone != null) 'phone': phone,
          if (positionIds != null) 'positionIds': positionIds,
        },
      );
      return Member.fromJson(response.data!);
    });
  }

  Future<void> removeMember(String teamId, String membershipId) async {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/members/$membershipId');
    });
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(dioProvider));
});

/// Equipe ativa: no MVP e a primeira (e normalmente unica) do usuario.
final activeTeamIdProvider = Provider<String?>((ref) {
  final teams = ref.watch(authControllerProvider).teams;
  return teams.isEmpty ? null : teams.first.teamId;
});

final membersProvider =
    FutureProvider.autoDispose.family<List<Member>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).members(teamId);
});

/// Quem pode ser escalado: integrantes + convidados. Separado do
/// [membersProvider] porque convidado não é integrante e não deve aparecer na
/// tela de equipe.
final schedulableMembersProvider =
    FutureProvider.autoDispose.family<List<Member>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).members(teamId, includeGuests: true);
});

/// Cadastra um músico de fora e devolve o registro criado.
final addGuestProvider = Provider<
    Future<Member> Function(String teamId, String displayName)>((ref) {
  return (teamId, displayName) =>
      ref.read(teamRepositoryProvider).addGuest(teamId, displayName);
});

final positionsProvider =
    FutureProvider.autoDispose.family<List<Position>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).positions(teamId);
});

/// A grade de cultos da igreja. Leitura liberada a qualquer integrante: a tela
/// de nova escala depende dela.
final serviceTemplatesProvider = FutureProvider.autoDispose
    .family<List<ServiceTemplate>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).serviceTemplates(teamId);
});

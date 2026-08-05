import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/invite_models.dart';

class InviteRepository {
  const InviteRepository(this._dio);

  final Dio _dio;

  Future<List<Invite>> list(String teamId) {
    return _guard(() async {
      final response =
          await _dio.get<List<dynamic>>('/teams/$teamId/invites');
      return response.data!
          .map((e) => Invite.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Invite> create(String teamId, {String? membershipId}) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/invites',
        data: {if (membershipId != null) 'membershipId': membershipId},
      );
      return Invite.fromJson(response.data!);
    });
  }

  Future<void> revoke(String teamId, String inviteId) {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/invites/$inviteId');
    });
  }

  Future<InvitePreview> preview(String code) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/invites/$code');
      return InvitePreview.fromJson(response.data!);
    });
  }

  Future<AcceptedInvite> accept(String code) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/invites/accept',
        data: {'code': code},
      );
      return AcceptedInvite.fromJson(response.data!);
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

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(dioProvider));
});

final invitesProvider =
    FutureProvider.autoDispose.family<List<Invite>, String>((ref, teamId) {
  return ref.watch(inviteRepositoryProvider).list(teamId);
});

import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/invites/domain/invite_models.dart';

Map<String, dynamic> inviteJson({
  String? forMembershipId,
  String? url,
  int? maxUses,
}) {
  return {
    'id': 'i1',
    'code': '50MEXB2VQTGVBP2XPANM',
    'formattedCode': '50MEX-B2VQT-GVBP2-XPANM',
    'url': url,
    'forMembershipId': forMembershipId,
    'forName': forMembershipId == null ? null : 'Joao',
    'expiresAt': '2026-08-12T20:25:15.016Z',
    'maxUses': maxUses,
    'uses': 0,
  };
}

void main() {
  group('Invite', () {
    test('distingue convite geral de individual', () {
      expect(Invite.fromJson(inviteJson()).isIndividual, isFalse);
      expect(
        Invite.fromJson(inviteJson(forMembershipId: 'm1')).isIndividual,
        isTrue,
      );
    });

    test('convite individual carrega o nome de quem vai assumir', () {
      final invite = Invite.fromJson(inviteJson(forMembershipId: 'm1'));
      expect(invite.forName, 'Joao');
    });

    test('url nula quando não ha pagina publica configurada', () {
      expect(Invite.fromJson(inviteJson()).url, isNull);
      expect(
        Invite.fromJson(inviteJson(url: 'https://x.com/convite/ABC')).url,
        'https://x.com/convite/ABC',
      );
    });

    test('código formatado em grupos de cinco', () {
      final invite = Invite.fromJson(inviteJson());
      expect(invite.formattedCode.split('-').every((g) => g.length == 5), isTrue);
      expect(invite.formattedCode.replaceAll('-', ''), invite.code);
    });
  });

  group('AcceptedInvite', () {
    test('joined falso quando a pessoa ja era da equipe', () {
      final result = AcceptedInvite.fromJson({
        'teamName': 'Louvor',
        'displayName': 'Joao',
        'joined': false,
      });
      expect(result.joined, isFalse);
    });

    test('joined assume verdadeiro quando ausente', () {
      final result = AcceptedInvite.fromJson({
        'teamName': 'Louvor',
        'displayName': 'Joao',
      });
      expect(result.joined, isTrue);
    });
  });

  group('InvitePreview', () {
    test('convite geral não traz nome de destinatario', () {
      final preview = InvitePreview.fromJson({
        'teamName': 'Ministerio de Louvor',
        'invitedBy': 'Samuel',
        'invitedName': null,
      });
      expect(preview.teamName, 'Ministerio de Louvor');
      expect(preview.invitedBy, 'Samuel');
      expect(preview.invitedName, isNull);
    });
  });
}

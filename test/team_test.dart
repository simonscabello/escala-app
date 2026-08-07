import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/team/domain/team_models.dart';

Map<String, dynamic> memberJson({
  String role = 'MEMBER',
  bool hasAccount = true,
  List<Map<String, dynamic>> positions = const [],
}) {
  return {
    'id': 'm1',
    'displayName': 'Joao',
    'role': role,
    'hasAccount': hasAccount,
    'phone': null,
    'email': hasAccount ? 'joao@teste.com' : null,
    'positions': positions,
  };
}

void main() {
  group('Member', () {
    test('placeholder sem conta e identificado', () {
      final member = Member.fromJson(memberJson(hasAccount: false));
      expect(member.hasAccount, isFalse);
      expect(member.email, isNull);
    });

    test('OWNER e LEADER gerenciam; MEMBER nao', () {
      expect(Member.fromJson(memberJson(role: 'OWNER')).canManage, isTrue);
      expect(Member.fromJson(memberJson(role: 'LEADER')).canManage, isTrue);
      expect(Member.fromJson(memberJson(role: 'MEMBER')).canManage, isFalse);
    });

    test('somente o OWNER e sinalizado como dono', () {
      expect(Member.fromJson(memberJson(role: 'OWNER')).isOwner, isTrue);
      expect(Member.fromJson(memberJson(role: 'LEADER')).isOwner, isFalse);
    });

    test('rotulos de papel em portugues', () {
      expect(Member.fromJson(memberJson(role: 'OWNER')).roleLabel, 'Dono');
      expect(Member.fromJson(memberJson(role: 'LEADER')).roleLabel, 'Líder');
      expect(Member.fromJson(memberJson(role: 'MEMBER')).roleLabel, 'Membro');
    });

    test('foto so existe para quem tem conta', () {
      final semConta = Member.fromJson(memberJson(hasAccount: false));
      expect(semConta.avatarUrl, isNull);

      final comFoto = Member.fromJson({
        ...memberJson(),
        'avatarUrl': '/uploads/avatars/abc.jpg',
      });
      expect(comFoto.avatarUrl, '/uploads/avatars/abc.jpg');
    });

    test('um membro pode acumular funções', () {
      final member = Member.fromJson(
        memberJson(
          positions: [
            {'id': 'p1', 'name': 'Vocalista', 'category': 'VOCAL'},
            {'id': 'p2', 'name': 'Violao', 'category': 'INSTRUMENT'},
          ],
        ),
      );

      expect(member.positions.map((p) => p.name), ['Vocalista', 'Violao']);
      expect(member.positions.first.isVocal, isTrue);
      expect(member.positions.last.isVocal, isFalse);
    });
  });

  group('Team', () {
    test('assume o fuso da igreja quando ausente', () {
      final team = Team.fromJson({'id': 't1', 'name': 'Louvor'});
      expect(team.timezone, 'America/Sao_Paulo');
      expect(team.memberCount, 0);
    });
  });
}

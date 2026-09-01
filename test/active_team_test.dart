import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/team/data/team_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restaura a equipe ativa quando ela continua disponível', () async {
    SharedPreferences.setMockInitialValues({'active_team_id': 't2'});
    final prefs = await SharedPreferences.getInstance();
    final controller = ActiveTeamController(prefs, ['t1', 't2']);

    expect(controller.state, 't2');
  });

  test('cai para a primeira equipe quando a escolha antiga não existe',
      () async {
    SharedPreferences.setMockInitialValues({'active_team_id': 'removida'});
    final prefs = await SharedPreferences.getInstance();
    final controller = ActiveTeamController(prefs, ['t1', 't2']);

    expect(controller.state, 't1');
  });

  test('persiste uma nova escolha válida', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ActiveTeamController(prefs, ['t1', 't2']);

    await controller.select('t2');

    expect(controller.state, 't2');
    expect(prefs.getString('active_team_id'), 't2');
  });
}

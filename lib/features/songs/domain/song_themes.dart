import '../../../core/text/text_search.dart';

/// Os temas com que a igreja escolhe o repertório do culto.
///
/// **Espelho do enum `SongTheme` do servidor**, na mesma ordem alfabética que o
/// índice temático impresso usa. A chave é o valor que viaja no JSON; o valor é
/// o rótulo que aparece na tela — mesma divisão de trabalho que `kindLabel` e
/// `paceLabel` já faziam para tipo e andamento.
///
/// Ficam aqui, e não numa chamada à API, porque são vocabulário fechado: não há
/// tela que crie tema, a lista é a mesma para toda equipe, e buscá-la pela rede
/// atrasaria a abertura do filtro para entregar um texto que não muda. O preço
/// é lembrar de acrescentar dos dois lados quando um tema novo entrar — e
/// [songThemeLabel] cobre o intervalo entre um release e outro.
const Map<String, String> songThemes = {
  'ACOES_DE_GRACAS': 'Ações de Graças',
  'ADOCAO': 'Adoção',
  'ADORACAO': 'Adoração',
  'ALEGRIA': 'Alegria',
  'AMOR_E_MISERICORDIA_DE_DEUS': 'Amor e Misericórdia de Deus',
  'ARREPENDIMENTO': 'Arrependimento',
  'ATRIBUTOS_DE_DEUS': 'Atributos de Deus',
  'BONDADE_DE_DEUS': 'Bondade de Deus',
  'CEIA': 'Ceia',
  'COMPROMISSO': 'Compromisso',
  'COMUNHAO': 'Comunhão',
  'CONFIANCA': 'Confiança',
  'CREDO': 'Credo',
  'CRIACAO': 'Criação',
  'CRIADOR': 'Criador',
  'CRUCIFICACAO': 'Crucificação',
  'CRUZ': 'Cruz',
  'DECLARACAO': 'Declaração',
  'DEPENDENCIA_DE_DEUS': 'Dependência de Deus',
  'DEUS': 'Deus',
  'ELEICAO': 'Eleição',
  'ENCARNACAO': 'Encarnação',
  'ENTREGA': 'Entrega',
  'ESPERANCA': 'Esperança',
  'ESPIRITO_SANTO': 'Espírito Santo',
  'ETERNIDADE': 'Eternidade',
  'ETERNO': 'Eterno',
  'EVANGELHO': 'Evangelho',
  'EVANGELISMO': 'Evangelismo',
  'EVANGELISMO_E_MISSOES': 'Evangelismo e Missões',
  'EXALTACAO': 'Exaltação',
  'EXPIACAO': 'Expiação',
  'FE': 'Fé',
  'FIDELIDADE': 'Fidelidade',
  'FIDELIDADE_DE_DEUS': 'Fidelidade de Deus',
  'GLORIA': 'Glória',
  'GRACA': 'Graça',
  'GRATIDAO': 'Gratidão',
  'HUMILDADE': 'Humildade',
  'IGREJA': 'Igreja',
  'INIMIGO': 'Inimigo',
  'JESUS_CRISTO': 'Jesus Cristo',
  'JUSTICA': 'Justiça',
  'JUSTIFICACAO_E_PERDAO': 'Justificação e Perdão',
  'LEI_DE_DEUS': 'Lei de Deus',
  'MAJESTADE': 'Majestade',
  'NATAL': 'Natal',
  'ONIPRESENCA': 'Onipresença',
  'ONISCIENCIA': 'Onisciência',
  'ORACAO': 'Oração',
  'PALAVRA_DE_DEUS': 'Palavra de Deus',
  'PASCOA': 'Páscoa',
  'PECADO': 'Pecado',
  'PERSEVERANCA': 'Perseverança',
  'PODER_DE_DEUS': 'Poder de Deus',
  'PRESENCA_DE_DEUS': 'Presença de Deus',
  'PROCLAMACAO': 'Proclamação',
  'PROMESSA': 'Promessa',
  'PROTECAO': 'Proteção',
  'REDENCAO': 'Redenção',
  'REFORMA': 'Reforma',
  'REGENERACAO': 'Regeneração',
  'REINO': 'Reino',
  'RESSURREICAO': 'Ressurreição',
  'SABEDORIA': 'Sabedoria',
  'SALMOS': 'Salmos',
  'SALVACAO': 'Salvação',
  'SALVADOR': 'Salvador',
  'SANGUE_DE_CRISTO': 'Sangue de Cristo',
  'SANTIDADE': 'Santidade',
  'SANTIFICACAO': 'Santificação',
  'SEGUNDA_VINDA': 'Segunda Vinda',
  'SEGURANCA': 'Segurança',
  'SOBERANIA': 'Soberania',
  'SOFRIMENTO': 'Sofrimento',
  'SUFICIENCIA': 'Suficiência',
  'TRANSCENDENCIA': 'Transcendência',
  'TRINDADE': 'Trindade',
  'UNIAO_COM_CRISTO': 'União com Cristo',
  'UNIDADE': 'Unidade',
  'VIDA_CRISTA': 'Vida Cristã',
  'VIDA_ETERNA': 'Vida Eterna',
};

/// A ordem em que os temas aparecem: alfabética, como no índice do hinário.
///
/// Uma ordem por frequência de uso pareceria mais esperta e seria pior — a
/// lista mudaria de forma com o tempo, e quem já sabe onde "Natal" fica
/// perderia o lugar a cada mês.
List<String> get songThemeValues => songThemes.keys.toList();

/// O rótulo de um tema, ou uma leitura aceitável dele.
///
/// O `??` não é zelo vazio: o servidor pode conhecer um tema que este app ainda
/// não conhece (migration aplicada, APK antigo no celular do músico). Nesse dia
/// a etiqueta vira "Vida Eterna" a partir de "VIDA_ETERNA" — sem acento, mas
/// legível — em vez de sumir da tela e fazer a música parecer não classificada.
String songThemeLabel(String value) => songThemes[value] ?? _readable(value);

String _readable(String value) => value
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0] + word.substring(1).toLowerCase())
    .join(' ');

/// Os temas que casam com o que se digitou no campo de busca do seletor.
///
/// Compara **sem acento e por trecho**: "gracas" acha "Ações de Graças" e
/// "deus" acha os sete temas que falam dele. Sem busca, devolve a lista
/// inteira — 82 temas rolam bem, e esconder tudo atrás de um campo vazio
/// obrigaria a adivinhar o vocabulário antes de vê-lo.
List<String> searchSongThemes(String query) {
  final term = normalizeForSearch(query);
  if (term.isEmpty) return songThemeValues;

  return [
    for (final entry in songThemes.entries)
      if (normalizeForSearch(entry.value).contains(term)) entry.key,
  ];
}

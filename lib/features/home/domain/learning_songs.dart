/// A legenda do atalho "Músicas novas" da Home.
///
/// **Um número, e não uma lista.** A Home já teve um cartão com as músicas em
/// aprendizado e ele saiu, a pedido: a Home não lista nada. O atalho diz
/// quanto há para estudar, e a lista mora na aba "Novas" do repertório.
///
/// Nulo é "ainda não sei" (carregando, ou a contagem falhou): a legenda fica
/// genérica em vez de afirmar um zero que ninguém contou.
String learningShortcutSubtitle(int? count) => switch (count) {
      null => 'Para estudar',
      0 => 'Nada novo agora',
      1 => '1 para estudar',
      _ => '$count para estudar',
    };

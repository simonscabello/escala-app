import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_status_colors.dart';
import 'app_feedback.dart';

/// Falar com um integrante — WhatsApp e ligação.
///
/// O telefone era **coletado e não usado**: o cadastro pedia, a API devolvia e
/// nenhuma tela fazia nada com ele. Quem precisava avisar alguém copiava o
/// número na mão e trocava de app. Isto fecha essa ponta.
///
/// `wa.me` em vez de `whatsapp://`: o esquema próprio não abre no navegador e
/// falha calado quando o WhatsApp não está instalado. O `https` cai no
/// WhatsApp Web ou na loja, que é o que a pessoa espera nos dois casos.
Future<void> openWhatsApp(
  BuildContext context,
  String phoneDigits, {
  String? message,
}) async {
  final query = message == null || message.isEmpty
      ? ''
      : '?text=${Uri.encodeComponent(message)}';
  await _open(
    context,
    'https://wa.me/$phoneDigits$query',
    'Não foi possível abrir o WhatsApp.',
  );
}

Future<void> callPhone(BuildContext context, String phoneDigits) async {
  await _open(
    context,
    'tel:$phoneDigits',
    'Este aparelho não faz ligações.',
  );
}

Future<void> _open(BuildContext context, String url, String erro) async {
  bool ok;
  try {
    ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // No navegador, um `tel:` sem aplicativo associado lança em vez de
    // devolver false. Cai na mesma mensagem.
    ok = false;
  }

  if (!ok && context.mounted) {
    showAppSnackBar(context, erro, tone: AppTone.danger);
  }
}

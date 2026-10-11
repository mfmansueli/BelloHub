// Transactional email texts: booking facts and a link, never anything clinical (docs/06 section 8, D31).
// Written natively for each language (D41: no reviewer yet, so every text is `needs_review` in spirit). `es-419` reads
// as `es-MX` and `en-GB` as `en`, the same derivation the app's string catalog uses.
//
// Placeholders: {code} {professional} {service} {when} {link}. `{when}` is a date and time already formatted for the
// reader in the professional's time zone.

import type { LocaleId } from '../contracts/common.js';

export type EmailTemplateId =
  | 'verificationCode'
  | 'bookingConfirmed'
  | 'bookingPending'
  | 'bookingApproved'
  | 'bookingDeclined'
  | 'bookingCancelled'
  | 'bookingMoved';

export const EMAIL_TEMPLATE_IDS: readonly EmailTemplateId[] = [
  'verificationCode',
  'bookingConfirmed',
  'bookingPending',
  'bookingApproved',
  'bookingDeclined',
  'bookingCancelled',
  'bookingMoved'
];

export interface EmailText {
  subject: string;
  body: string;
}

export type EmailTexts = Record<EmailTemplateId, EmailText>;

/** The twelve languages written by hand; the other two localizations read from these. */
export type WrittenLocale = Exclude<LocaleId, 'es-419' | 'en-GB'>;

export const EMAIL_LOCALE_FALLBACK: Record<'es-419' | 'en-GB', WrittenLocale> = { 'es-419': 'es-MX', 'en-GB': 'en' };

export const EMAIL_TEXTS: Record<WrittenLocale, EmailTexts> = {
  'pt-BR': {
    verificationCode: {
      subject: '{code} é o seu código de verificação',
      body: 'Seu código de verificação é {code}. Ele vale por 30 minutos. Se você não pediu esse código, ignore esta mensagem.'
    },
    bookingConfirmed: {
      subject: 'Seu horário com {professional} está confirmado',
      body: '{service} com {professional}: {when}.\n\nPara remarcar ou cancelar, use seu link pessoal:\n{link}\n\nGuarde esta mensagem: o link é a sua entrada.'
    },
    bookingPending: {
      subject: 'Recebemos o seu pedido para {professional}',
      body: '{professional} vai confirmar o seu pedido de {service} para {when}. Nada está marcado até a confirmação.\n\nSeu link pessoal:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} confirmou o seu horário',
      body: '{service} com {professional}: {when}.\n\nPara remarcar ou cancelar, use seu link pessoal.'
    },
    bookingDeclined: {
      subject: '{professional} não pôde confirmar o seu pedido',
      body: '{professional} não conseguiu confirmar o seu pedido de {service} para {when}. Você pode escolher outro horário aqui:\n{link}'
    },
    bookingCancelled: {
      subject: 'Seu horário com {professional} foi cancelado',
      body: '{professional} cancelou o seu horário de {service} em {when}. Você pode escolher outro horário aqui:\n{link}'
    },
    bookingMoved: {
      subject: 'Seu horário com {professional} mudou',
      body: '{professional} mudou o seu horário de {service} para {when}.\n\nSe esse horário não funcionar, use seu link pessoal para remarcar ou cancelar.'
    }
  },
  'pt-PT': {
    verificationCode: {
      subject: '{code} é o seu código de verificação',
      body: 'O seu código de verificação é {code}. É válido durante 30 minutos. Se não pediu este código, ignore esta mensagem.'
    },
    bookingConfirmed: {
      subject: 'A sua marcação com {professional} está confirmada',
      body: '{service} com {professional}: {when}.\n\nPara alterar ou desmarcar, use o seu link pessoal:\n{link}\n\nGuarde esta mensagem: o link é a sua entrada.'
    },
    bookingPending: {
      subject: 'Recebemos o seu pedido para {professional}',
      body: '{professional} vai confirmar o seu pedido de {service} para {when}. Nada fica marcado até à confirmação.\n\nO seu link pessoal:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} confirmou a sua marcação',
      body: '{service} com {professional}: {when}.\n\nPara alterar ou desmarcar, use o seu link pessoal.'
    },
    bookingDeclined: {
      subject: '{professional} não pôde confirmar o seu pedido',
      body: '{professional} não conseguiu confirmar o seu pedido de {service} para {when}. Pode escolher outra hora aqui:\n{link}'
    },
    bookingCancelled: {
      subject: 'A sua marcação com {professional} foi cancelada',
      body: '{professional} cancelou a sua marcação de {service} em {when}. Pode escolher outra hora aqui:\n{link}'
    },
    bookingMoved: {
      subject: 'A sua marcação com {professional} mudou',
      body: '{professional} alterou a sua marcação de {service} para {when}.\n\nSe esta hora não lhe servir, use o seu link pessoal para alterar ou desmarcar.'
    }
  },
  'es-MX': {
    verificationCode: {
      subject: '{code} es tu código de verificación',
      body: 'Tu código de verificación es {code}. Vale por 30 minutos. Si no lo pediste, ignora este mensaje.'
    },
    bookingConfirmed: {
      subject: 'Tu cita con {professional} está confirmada',
      body: '{service} con {professional}: {when}.\n\nPara cambiarla o cancelarla, usa tu enlace personal:\n{link}\n\nGuarda este mensaje: el enlace es tu entrada.'
    },
    bookingPending: {
      subject: 'Recibimos tu solicitud para {professional}',
      body: '{professional} confirmará tu solicitud de {service} para {when}. No hay nada agendado hasta que confirme.\n\nTu enlace personal:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} confirmó tu cita',
      body: '{service} con {professional}: {when}.\n\nPara cambiarla o cancelarla, usa tu enlace personal.'
    },
    bookingDeclined: {
      subject: '{professional} no pudo confirmar tu solicitud',
      body: '{professional} no pudo confirmar tu solicitud de {service} para {when}. Puedes elegir otro horario aquí:\n{link}'
    },
    bookingCancelled: {
      subject: 'Tu cita con {professional} fue cancelada',
      body: '{professional} canceló tu cita de {service} programada para {when}. Puedes elegir otro horario aquí:\n{link}'
    },
    bookingMoved: {
      subject: 'Tu cita con {professional} cambió',
      body: '{professional} cambió tu cita de {service} a {when}.\n\nSi ese horario no te funciona, usa tu enlace personal para cambiarla o cancelarla.'
    }
  },
  es: {
    verificationCode: {
      subject: '{code} es tu código de verificación',
      body: 'Tu código de verificación es {code}. Caduca en 30 minutos. Si no lo has pedido, ignora este mensaje.'
    },
    bookingConfirmed: {
      subject: 'Tu cita con {professional} está confirmada',
      body: '{service} con {professional}: {when}.\n\nPara cambiarla o cancelarla, usa tu enlace personal:\n{link}\n\nGuarda este mensaje: el enlace es tu entrada.'
    },
    bookingPending: {
      subject: 'Hemos recibido tu solicitud para {professional}',
      body: '{professional} confirmará tu solicitud de {service} para {when}. No queda reservada ninguna cita hasta que confirme.\n\nTu enlace personal:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} ha confirmado tu cita',
      body: '{service} con {professional}: {when}.\n\nPara cambiarla o cancelarla, usa tu enlace personal.'
    },
    bookingDeclined: {
      subject: '{professional} no ha podido confirmar tu solicitud',
      body: '{professional} no ha podido confirmar tu solicitud de {service} para {when}. Puedes elegir otra hora aquí:\n{link}'
    },
    bookingCancelled: {
      subject: 'Tu cita con {professional} se ha cancelado',
      body: '{professional} ha cancelado tu cita de {service} prevista para {when}. Puedes elegir otra hora aquí:\n{link}'
    },
    bookingMoved: {
      subject: 'Tu cita con {professional} ha cambiado',
      body: '{professional} ha cambiado tu cita de {service} a {when}.\n\nSi esa hora no te va bien, usa tu enlace personal para cambiarla o cancelarla.'
    }
  },
  en: {
    verificationCode: {
      subject: '{code} is your verification code',
      body: 'Your verification code is {code}. It is valid for 30 minutes. If you did not ask for it, ignore this message.'
    },
    bookingConfirmed: {
      subject: 'Your appointment with {professional} is confirmed',
      body: '{service} with {professional}: {when}.\n\nTo change or cancel, use your personal link:\n{link}\n\nKeep this message: the link is your way back in.'
    },
    bookingPending: {
      subject: 'We received your request for {professional}',
      body: '{professional} will confirm your request for {service} on {when}. Nothing is booked until they confirm.\n\nYour personal link:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} confirmed your appointment',
      body: '{service} with {professional}: {when}.\n\nTo change or cancel, use your personal link.'
    },
    bookingDeclined: {
      subject: '{professional} could not confirm your request',
      body: '{professional} could not confirm your request for {service} on {when}. You can choose another time here:\n{link}'
    },
    bookingCancelled: {
      subject: 'Your appointment with {professional} was cancelled',
      body: '{professional} cancelled your {service} appointment on {when}. You can choose another time here:\n{link}'
    },
    bookingMoved: {
      subject: 'Your appointment with {professional} was moved',
      body: '{professional} moved your {service} appointment to {when}.\n\nIf that time does not work, use your personal link to change or cancel.'
    }
  },
  it: {
    verificationCode: {
      subject: '{code} è il tuo codice di verifica',
      body: "Il tuo codice di verifica è {code}. Vale 30 minuti. Se non l'hai richiesto, ignora questo messaggio."
    },
    bookingConfirmed: {
      subject: 'Il tuo appuntamento con {professional} è confermato',
      body: "{service} con {professional}: {when}.\n\nPer modificarlo o annullarlo usa il tuo link personale:\n{link}\n\nConserva questo messaggio: il link è la tua porta d'ingresso."
    },
    bookingPending: {
      subject: 'Abbiamo ricevuto la tua richiesta per {professional}',
      body: '{professional} confermerà la tua richiesta di {service} per {when}. Non è prenotato nulla finché non conferma.\n\nIl tuo link personale:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} ha confermato il tuo appuntamento',
      body: '{service} con {professional}: {when}.\n\nPer modificarlo o annullarlo usa il tuo link personale.'
    },
    bookingDeclined: {
      subject: '{professional} non ha potuto confermare la tua richiesta',
      body: '{professional} non ha potuto confermare la tua richiesta di {service} per {when}. Puoi scegliere un altro orario qui:\n{link}'
    },
    bookingCancelled: {
      subject: 'Il tuo appuntamento con {professional} è stato annullato',
      body: '{professional} ha annullato il tuo appuntamento di {service} previsto per {when}. Puoi scegliere un altro orario qui:\n{link}'
    },
    bookingMoved: {
      subject: 'Il tuo appuntamento con {professional} è stato spostato',
      body: "{professional} ha spostato il tuo appuntamento di {service} a {when}.\n\nSe quell'orario non va bene, usa il tuo link personale per modificarlo o annullarlo."
    }
  },
  fr: {
    verificationCode: {
      subject: '{code} est votre code de vérification',
      body: "Votre code de vérification est {code}. Il est valable 30 minutes. Si vous ne l'avez pas demandé, ignorez ce message."
    },
    bookingConfirmed: {
      subject: 'Votre rendez-vous avec {professional} est confirmé',
      body: "{service} avec {professional} : {when}.\n\nPour le modifier ou l'annuler, utilisez votre lien personnel :\n{link}\n\nConservez ce message : le lien est votre porte d'entrée."
    },
    bookingPending: {
      subject: 'Nous avons reçu votre demande pour {professional}',
      body: "{professional} va confirmer votre demande de {service} pour {when}. Rien n'est réservé tant que la confirmation n'est pas arrivée.\n\nVotre lien personnel :\n{link}"
    },
    bookingApproved: {
      subject: '{professional} a confirmé votre rendez-vous',
      body: "{service} avec {professional} : {when}.\n\nPour le modifier ou l'annuler, utilisez votre lien personnel."
    },
    bookingDeclined: {
      subject: "{professional} n'a pas pu confirmer votre demande",
      body: "{professional} n'a pas pu confirmer votre demande de {service} pour {when}. Vous pouvez choisir un autre horaire ici :\n{link}"
    },
    bookingCancelled: {
      subject: 'Votre rendez-vous avec {professional} a été annulé',
      body: '{professional} a annulé votre rendez-vous de {service} prévu pour {when}. Vous pouvez choisir un autre horaire ici :\n{link}'
    },
    bookingMoved: {
      subject: 'Votre rendez-vous avec {professional} a été déplacé',
      body: "{professional} a déplacé votre rendez-vous de {service} à {when}.\n\nSi cet horaire ne vous convient pas, utilisez votre lien personnel pour le modifier ou l'annuler."
    }
  },
  de: {
    verificationCode: {
      subject: '{code} ist Ihr Bestätigungscode',
      body: 'Ihr Bestätigungscode lautet {code}. Er ist 30 Minuten gültig. Wenn Sie ihn nicht angefordert haben, ignorieren Sie diese Nachricht.'
    },
    bookingConfirmed: {
      subject: 'Ihr Termin bei {professional} ist bestätigt',
      body: '{service} bei {professional}: {when}.\n\nZum Ändern oder Absagen nutzen Sie Ihren persönlichen Link:\n{link}\n\nBewahren Sie diese Nachricht auf: Der Link ist Ihr Zugang.'
    },
    bookingPending: {
      subject: 'Wir haben Ihre Anfrage für {professional} erhalten',
      body: '{professional} bestätigt Ihre Anfrage für {service} am {when}. Bis zur Bestätigung ist nichts gebucht.\n\nIhr persönlicher Link:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} hat Ihren Termin bestätigt',
      body: '{service} bei {professional}: {when}.\n\nZum Ändern oder Absagen nutzen Sie Ihren persönlichen Link.'
    },
    bookingDeclined: {
      subject: '{professional} konnte Ihre Anfrage nicht bestätigen',
      body: '{professional} konnte Ihre Anfrage für {service} am {when} nicht bestätigen. Hier können Sie eine andere Zeit wählen:\n{link}'
    },
    bookingCancelled: {
      subject: 'Ihr Termin bei {professional} wurde abgesagt',
      body: '{professional} hat Ihren Termin für {service} am {when} abgesagt. Hier können Sie eine andere Zeit wählen:\n{link}'
    },
    bookingMoved: {
      subject: 'Ihr Termin bei {professional} wurde verschoben',
      body: '{professional} hat Ihren Termin für {service} auf {when} verschoben.\n\nWenn diese Zeit nicht passt, ändern oder sagen Sie den Termin über Ihren persönlichen Link ab.'
    }
  },
  tr: {
    verificationCode: {
      subject: '{code} doğrulama kodunuzdur',
      body: 'Doğrulama kodunuz: {code}. 30 dakika geçerlidir. Siz istemediyseniz bu mesajı yok sayın.'
    },
    bookingConfirmed: {
      subject: '{professional} ile randevunuz onaylandı',
      body: '{service}, {professional}: {when}.\n\nDeğiştirmek veya iptal etmek için kişisel bağlantınızı kullanın:\n{link}\n\nBu mesajı saklayın: bağlantı sizin girişinizdir.'
    },
    bookingPending: {
      subject: '{professional} için talebinizi aldık',
      body: '{professional}, {when} için {service} talebinizi onaylayacak. Onaylanana kadar hiçbir şey ayrılmış değildir.\n\nKişisel bağlantınız:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} randevunuzu onayladı',
      body: '{service}, {professional}: {when}.\n\nDeğiştirmek veya iptal etmek için kişisel bağlantınızı kullanın.'
    },
    bookingDeclined: {
      subject: '{professional} talebinizi onaylayamadı',
      body: '{professional}, {when} için {service} talebinizi onaylayamadı. Başka bir zamanı buradan seçebilirsiniz:\n{link}'
    },
    bookingCancelled: {
      subject: '{professional} ile randevunuz iptal edildi',
      body: '{professional}, {when} tarihli {service} randevunuzu iptal etti. Başka bir zamanı buradan seçebilirsiniz:\n{link}'
    },
    bookingMoved: {
      subject: '{professional} ile randevunuz değişti',
      body: '{professional}, {service} randevunuzu {when} olarak değiştirdi.\n\nBu zaman uygun değilse kişisel bağlantınızla değiştirebilir veya iptal edebilirsiniz.'
    }
  },
  id: {
    verificationCode: {
      subject: '{code} adalah kode verifikasi Anda',
      body: 'Kode verifikasi Anda adalah {code}. Berlaku selama 30 menit. Jika Anda tidak memintanya, abaikan pesan ini.'
    },
    bookingConfirmed: {
      subject: 'Janji temu Anda dengan {professional} sudah dikonfirmasi',
      body: '{service} dengan {professional}: {when}.\n\nUntuk mengubah atau membatalkan, gunakan tautan pribadi Anda:\n{link}\n\nSimpan pesan ini: tautan ini adalah jalan masuk Anda.'
    },
    bookingPending: {
      subject: 'Permintaan Anda untuk {professional} sudah kami terima',
      body: '{professional} akan mengonfirmasi permintaan {service} Anda untuk {when}. Belum ada yang terjadwal sampai dikonfirmasi.\n\nTautan pribadi Anda:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} mengonfirmasi janji temu Anda',
      body: '{service} dengan {professional}: {when}.\n\nUntuk mengubah atau membatalkan, gunakan tautan pribadi Anda.'
    },
    bookingDeclined: {
      subject: '{professional} belum bisa mengonfirmasi permintaan Anda',
      body: '{professional} belum bisa mengonfirmasi permintaan {service} Anda untuk {when}. Anda dapat memilih waktu lain di sini:\n{link}'
    },
    bookingCancelled: {
      subject: 'Janji temu Anda dengan {professional} dibatalkan',
      body: '{professional} membatalkan janji temu {service} Anda pada {when}. Anda dapat memilih waktu lain di sini:\n{link}'
    },
    bookingMoved: {
      subject: 'Janji temu Anda dengan {professional} diubah',
      body: '{professional} memindahkan janji temu {service} Anda ke {when}.\n\nJika waktu itu tidak cocok, gunakan tautan pribadi Anda untuk mengubah atau membatalkan.'
    }
  },
  hi: {
    verificationCode: {
      subject: '{code} आपका सत्यापन कोड है',
      body: 'आपका सत्यापन कोड {code} है। यह 30 मिनट तक मान्य है। अगर आपने इसे नहीं माँगा है, तो इस संदेश को अनदेखा करें।'
    },
    bookingConfirmed: {
      subject: '{professional} के साथ आपकी अपॉइंटमेंट पक्की हो गई है',
      body: '{service}, {professional} के साथ: {when}।\n\nबदलने या रद्द करने के लिए अपना निजी लिंक इस्तेमाल करें:\n{link}\n\nयह संदेश सँभालकर रखें: यह लिंक ही आपका रास्ता है।'
    },
    bookingPending: {
      subject: '{professional} के लिए आपका अनुरोध मिल गया',
      body: '{professional}, {when} के लिए आपके {service} अनुरोध की पुष्टि करेंगे। पुष्टि होने तक कुछ भी बुक नहीं है।\n\nआपका निजी लिंक:\n{link}'
    },
    bookingApproved: {
      subject: '{professional} ने आपकी अपॉइंटमेंट की पुष्टि की',
      body: '{service}, {professional} के साथ: {when}।\n\nबदलने या रद्द करने के लिए अपना निजी लिंक इस्तेमाल करें।'
    },
    bookingDeclined: {
      subject: '{professional} आपके अनुरोध की पुष्टि नहीं कर सके',
      body: '{professional}, {when} के लिए आपके {service} अनुरोध की पुष्टि नहीं कर सके। आप यहाँ दूसरा समय चुन सकते हैं:\n{link}'
    },
    bookingCancelled: {
      subject: '{professional} के साथ आपकी अपॉइंटमेंट रद्द हो गई',
      body: '{professional} ने {when} की आपकी {service} अपॉइंटमेंट रद्द कर दी है। आप यहाँ दूसरा समय चुन सकते हैं:\n{link}'
    },
    bookingMoved: {
      subject: '{professional} के साथ आपकी अपॉइंटमेंट बदल गई',
      body: '{professional} ने आपकी {service} अपॉइंटमेंट {when} पर कर दी है।\n\nअगर यह समय ठीक न हो, तो अपने निजी लिंक से इसे बदलें या रद्द करें।'
    }
  },
  ar: {
    verificationCode: {
      subject: '{code} هو رمز التحقق الخاص بك',
      body: 'رمز التحقق الخاص بك هو {code}. صالح لمدة 30 دقيقة. إذا لم تطلبه، تجاهل هذه الرسالة.'
    },
    bookingConfirmed: {
      subject: 'تم تأكيد موعدك مع {professional}',
      body: '{service} مع {professional}: {when}.\n\nلتغيير الموعد أو إلغائه، استخدم رابطك الشخصي:\n{link}\n\nاحتفظ بهذه الرسالة: الرابط هو مدخلك.'
    },
    bookingPending: {
      subject: 'استلمنا طلبك لدى {professional}',
      body: 'سيؤكد {professional} طلب {service} الخاص بك في {when}. لا يوجد حجز قبل التأكيد.\n\nرابطك الشخصي:\n{link}'
    },
    bookingApproved: {
      subject: 'أكّد {professional} موعدك',
      body: '{service} مع {professional}: {when}.\n\nلتغيير الموعد أو إلغائه، استخدم رابطك الشخصي.'
    },
    bookingDeclined: {
      subject: 'تعذّر على {professional} تأكيد طلبك',
      body: 'تعذّر على {professional} تأكيد طلب {service} الخاص بك في {when}. يمكنك اختيار وقت آخر هنا:\n{link}'
    },
    bookingCancelled: {
      subject: 'تم إلغاء موعدك مع {professional}',
      body: 'ألغى {professional} موعد {service} الخاص بك في {when}. يمكنك اختيار وقت آخر هنا:\n{link}'
    },
    bookingMoved: {
      subject: 'تم تغيير موعدك مع {professional}',
      body: 'نقل {professional} موعد {service} الخاص بك إلى {when}.\n\nإذا لم يناسبك هذا الوقت، استخدم رابطك الشخصي لتغييره أو إلغائه.'
    }
  }
};

export function emailTextsFor(locale: LocaleId): EmailTexts {
  const written: WrittenLocale = locale === 'es-419' || locale === 'en-GB' ? EMAIL_LOCALE_FALLBACK[locale] : locale;
  return EMAIL_TEXTS[written];
}

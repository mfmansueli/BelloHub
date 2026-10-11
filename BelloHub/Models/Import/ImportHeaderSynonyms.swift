//
//  ImportHeaderSynonyms.swift
//  BelloHub
//

import Foundation

/// The words a column title uses for each part of a client, in the languages of the product and in the English
/// headers most address-book exports (Google Contacts, Outlook) write. Matching folds case and accents and ignores
/// punctuation, so "Teléfono", "TELEFONO" and "telefono:" are one word, and a title that merely *contains* a
/// phrase ("Phone 1 - Value") still matches it.
enum ImportHeaderSynonyms {
    static func phrases(for role: ImportColumnRole) -> [String] {
        switch role {
        case .email: email
        case .phone: phone
        case .lastName: lastName
        case .name: name
        }
    }

    /// A column that says what *kind* of value another column holds ("Phone 1 - Label", "Tipo de teléfono") is
    /// never the value column.
    static let kindWords: Set<String> = [
        "label", "type", "tipo", "typ", "etiqueta", "etichetta", "libelle", "jenis", "tur"
    ]

    private static let email = [
        "email", "e mail", "mail", "correo", "correo electronico", "email address", "e mail address", "courriel",
        "adresse e mail", "adresse email", "posta", "e posta", "eposta", "surel", "alamat email", "e mail adresse",
        "indirizzo email", "endereco de email", "endereco de e mail", "ईमेल", "ई मेल", "البريد", "البريد الالكتروني",
        "بريد الكتروني", "ايميل", "الايميل"
    ]

    private static let phone = [
        "phone", "phone number", "telephone", "tel", "telefone", "telefono", "celular", "cell", "cellphone",
        "cell phone", "mobile", "mobile phone", "mobile number", "movil", "whatsapp", "wpp", "zap", "numero",
        "number", "telemovel", "handy", "handynummer", "mobilnummer", "telefonnummer", "rufnummer", "portable",
        "telephone portable", "numero de telephone", "numero de portable", "cep", "cep telefonu", "telefon",
        "telefon numarasi", "telepon", "nomor telepon", "nomor hp", "no hp", "hp", "nomor", "cellulare",
        "numero di telefono", "numero de telefono", "numero de celular", "फ़ोन", "फोन", "मोबाइल", "मोबाइल नंबर",
        "फ़ोन नंबर", "फोन नंबर", "नंबर", "الهاتف", "هاتف", "رقم الهاتف", "الجوال", "جوال", "رقم الجوال", "موبايل",
        "واتساب", "رقم"
    ]

    private static let lastName = [
        "last name", "lastname", "surname", "family name", "sobrenome", "apellido", "apellidos", "cognome",
        "nom de famille", "nachname", "familienname", "soyad", "soyadi", "nama belakang", "उपनाम", "अंतिम नाम",
        "اسم العائلة", "الكنية", "اللقب"
    ]

    private static let name = [
        "name", "full name", "fullname", "display name", "client", "customer", "contact name", "client name",
        "customer name", "first name", "firstname", "given name", "nome", "nome completo", "nome do cliente",
        "nome da cliente", "cliente", "nombre", "nombre completo", "nombre del cliente", "nom", "nom complet",
        "prenom", "vorname", "name des kunden", "kunde", "kundin", "kundenname", "ad", "adi", "ad soyad", "isim",
        "musteri", "musteri adi", "nama", "nama lengkap", "nama klien", "klien", "pelanggan", "nominativo",
        "nome e cognome", "पहला नाम", "नाम", "पूरा नाम", "ग्राहक", "क्लाइंट", "الاسم", "اسم", "الاسم الكامل",
        "الاسم الاول", "العميل", "اسم العميل"
    ]
}

# HANDOFF · comportamento de cada tela (97)

Prosa em português (idioma da dona do produto); **os textos entre aspas são a copy exata em inglês do protótipo** (a fonte para todos os idiomas, `docs/07-LOCALIZATION.md`). Em conflito, valem `docs/02-DECISIONS.md` e os documentos de `docs/`; depois este arquivo; depois o HTML do protótipo.

## Como ler

- **Imagem**: captura da tela (390×844 @2x) em `design/screenshots/`. As fontes do protótipo (Fraunces e DM Sans) não estavam disponíveis na renderização: as capturas usam fontes de reserva parecidas. Use `docs/08-DESIGN-SYSTEM.md` para as fontes reais.
- **Dados**: onde a informação vive (`docs/05-DATA-MODEL.md`). "Aparelho + iCloud" = cofre da profissional (nunca vai ao servidor). "Servidor" = só o necessário para a cliente agendar.
- **Chega de / Vai para**: navegação extraída dos links do protótipo.
- **Estados**: variáveis de estado que a tela do protótipo muda. Servem para escrever o `ViewModel`. Estados que atravessam telas (`hubState`, por exemplo `CancelPolicy`, `LanguageRegion`) viram valores de domínio de um repositório ou serviço, não globais.
- **Textos**: copy exata. Textos que dependem de dados (`{{…}}`) não aparecem.
- Layout: **somente iPhone** (D1). O protótipo é o layout final de iPhone; modo escuro vem dos tokens (`docs/08`).

## Ajustes em relação ao protótipo (valem para o código)

1. **Somente iPhone** (D1): sem layouts de iPad.
2. **Barra de abas e folhas**: use os componentes nativos do iOS 26 (`docs/04` §5, `docs/08` §5), não a barra flutuante desenhada.
3. **Moeda e idioma** por negócio (D7, D24, D25): o protótipo mostra R$ e inglês como exemplo.
4. **Fontes** Fraunces + DM Sans embarcadas, escala única (`docs/08` §3).
5. **ExportAll** sem "link por e-mail" (D18). **AISettings**: ajuda na nuvem desativada, revisão travada ligada (D23). **Confirmação e lembretes** conforme o canal (D31). Registrar em "Design additions".
6. **Team** continua "later" (D5).
7. **Movimento** conforme `docs/09-MOTION.md` (as classes `m-*` do protótipo são o resumo do que ele descreve).
8. **Telas com ficha de saúde da cliente** só enviam envelopes selados (D21). Nenhum dado clínico em texto aberto fora do cofre.


---

## 01 · Entrada e configuração inicial

### 1.1 · Onb-1-Welcome: 01 Welcome
- **Imagem**: `design/screenshots/01-01_Onb-1-Welcome.png`
- **Propósito**: Boas-vindas. "Get started" abre o onboarding; "Sign in" leva ao login de quem já tem conta.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `Onb-2-Profession`, `SignIn`
- **Vai para**: `Onb-2-Profession`, `SignIn`
- **Textos**: "Today" · "JM" · "Julia Mendes" · "Deep Cleansing" · "CR" · "Camila Rocha" · "Glow Facial" · "AC" · "Ana Costa" · "Last visit Aug 30 · Glow Facial" · "Important" · "Sensitive skin · fragrance-free products" · "Remembered, so you don't have to" · "bello" · "hub" · "Agenda. Clientes. Gestão." · "Everything you need to manage your beauty business and remember every client." · "Get started" · "Already have an account?" · "Sign in"

### 1.2 · SignIn: Sign in
- **Imagem**: `design/screenshots/01-02_SignIn.png`
- **Propósito**: Login por telefone com código (SMS ou WhatsApp). Seletor de código do país. Etapas: telefone, código, Face ID opcional.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Account`, `More`, `Onb-1-Welcome`
- **Vai para**: `Home`, `Onb-1-Welcome`
- **Estados**: `cd`, `em`, `ph`, `resent`, `step`
- **Textos**: "bello" · "hub" · "Welcome back." · "Sign in to see your day and your clients." · "We will text you a 6-digit code. Standard rates may apply." · "Send code" · "New to Bello Hub?" · "Create your workspace" · "Check your phone." · "Sign in" · "Use a different number"

### 1.3 · Onb-2-Profession: 02 Profession
- **Imagem**: `design/screenshots/01-03_Onb-2-Profession.png`
- **Propósito**: Escolha da(s) profissão(ões): pode marcar mais de uma. A escolha adapta nomes, serviços sugeridos e campos da ficha.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Account`, `Onb-1-Welcome`, `Onb-3-Services`
- **Vai para**: `Onb-1-Welcome`, `Onb-3-Services`
- **Estados**: `sel`
- **Textos**: "What do you do?" · "Choose everything that applies. Bello Hub adapts to how you work." · "Continue"

### 1.4 · Onb-3-Services: 03 Services
- **Imagem**: `design/screenshots/01-04_Onb-3-Services.png`
- **Propósito**: Seleção dos serviços sugeridos para a profissão, com duração. Preço opcional, mostrado só se a profissional quiser.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Onb-2-Profession`, `Onb-4-CustomService`, `Onb-5-Terminology`
- **Vai para**: `Onb-2-Profession`, `Onb-4-CustomService`, `Onb-5-Terminology`
- **Estados**: `sel`
- **Textos**: "What do you offer?" · "Suggested for estheticians. Prices and durations are easy to change later." · "Brazilian Glow" · "Your service · R$120 · 90 min" · "+ Add custom service" · "Continue"

### 1.5 · Onb-4-CustomService: 04 Custom service
- **Imagem**: `design/screenshots/01-05_Onb-4-CustomService.png`
- **Propósito**: Cria um serviço próprio (nome, duração, preço opcional).
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Onb-3-Services`
- **Vai para**: `Onb-3-Services`
- **Estados**: `key`, `wk`
- **Textos**: "Cancel" · "New service" · "Name" · "Category" · "Price" · "Duration" · "Recommended follow-up" · "Clients become due for a follow-up this long after the service." · "Before and after photos" · "Remind me to take them" · "Aftercare" · "Share a template with the client" · "Add service"

### 1.6 · Onb-5-Terminology: 05 Your terminology
- **Imagem**: `design/screenshots/01-06_Onb-5-Terminology.png`
- **Propósito**: Como a profissional chama quem atende: cliente, paciente, aluna. O app usa esse termo em todas as telas.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Onb-3-Services`, `Onb-6-Tags`
- **Vai para**: `Onb-3-Services`, `Onb-6-Tags`
- **Textos**: "Use the language you already use." · "Name your services and protocols the way you say them. They show up exactly like this everywhere." · "Glow Facial" · "Service" · "Brazilian Glow" · "Protocol 360" · "Protocol" · "Bello Hub learns the names you use for your services and protocols, so voice notes and records sound like you." · "Continue"

### 1.7 · Onb-6-Tags: 06 Tags
- **Imagem**: `design/screenshots/01-07_Onb-6-Tags.png`
- **Propósito**: Tags iniciais para classificar clientes (VIP, pele sensível, noiva...). "+ New tag" leva ao gerenciador de tags.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Onb-5-Terminology`, `Onb-6b-Record`
- **Vai para**: `Onb-5-Terminology`, `Onb-6b-Record`, `Tags`
- **Estados**: `sel`
- **Textos**: "Tag the way you think." · "Tags make clients easy to find and remind you what matters. Pick a few, add your own anytime." · "+ New tag" · "Tags are private. Your clients never see them." · "Continue"

### 1.8 · Onb-6b-Record: 07 Your client record
- **Imagem**: `design/screenshots/01-08_Onb-6b-Record.png`
- **Propósito**: Escolha dos campos que a profissional quer lembrar de cada cliente (a ficha adaptativa). Vem pré-preenchida pela profissão.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Onb-6-Tags`
- **Vai para**: `Onb-6-Tags`, `Permissions`
- **Estados**: `off`, `prof`
- **Textos**: "What do you want to remember about each client?" · "Your client record is built around your craft. Switch on only what you use." · "Treatment record" · "You only see these fields when you register a treatment. Voice notes fill them for you." · "Before the first visit" · "Continue"

### 1.9 · Permissions: Permissions
- **Imagem**: `design/screenshots/01-09_Permissions.png`
- **Propósito**: Pedido guiado das permissões do iOS (notificações, câmera, microfone, contatos), uma explicação antes de cada diálogo do sistema.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `Onb-6b-Record`
- **Vai para**: `Onb-7-Ready`
- **Estados**: `i`, `sys`
- **Textos**: "Not now" · "All set." · "You can change any of this later in Privacy and security." · "Continue" · "Don't allow" · "OK"

### 1.10 · Onb-7-Ready: 08 Workspace ready
- **Imagem**: `design/screenshots/01-10_Onb-7-Ready.png`
- **Propósito**: Fim do onboarding: link de agendamento pronto com botão de copiar, atalho para importar clientes.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Permissions`
- **Vai para**: `Home`, `ImportClients`
- **Estados**: `copied`
- **Textos**: "Your Bello Hub is ready." · "Maria, your workspace is set up for estheticians. It will fill up as clients book." · "Appointments today" · "Clients" · "Follow-ups" · "Your booking link" · "bellohub.app/maria" · "Import your clients" · "From your phone or a spreadsheet" · "Go to Home"

### 1.11 · Locked: Locked
- **Imagem**: `design/screenshots/01-11_Locked.png`
- **Propósito**: Tela de bloqueio do app (Face ID ou código) ao voltar do segundo plano.
- **Dados**: Só no aparelho
- **Chega de**: (ponto de entrada)
- **Vai para**: `Home`
- **Estados**: `mode`, `pin`
- **Textos**: "Bello Hub is locked." · "Client information is protected." · "Unlock with Face ID" · "Use passcode" · "Open Bello Hub" · "Use Face ID"


---

## 02 · Abas da profissional

### 2.1 · Home: Home
- **Imagem**: `design/screenshots/02-01_Home.png`
- **Propósito**: Dia de hoje: próximo atendimento (com "Running late? Tell ..."), resto do dia, atalhos, follow-ups e ações rápidas. Variante `fresh` mostra o estado vazio.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BeforeYouStart`, `Cl-3-Rebook`, `FollowUps`, `Locked`, `Onb-7-Ready`, `RunningLate`, `SignIn`, `Tx-1-Register`, `Tx-5-Saved`, `Tx-7-NextSession`, `WeekGlance`, `WinBack`
- **Vai para**: `Appointment`, `BeforeYouStart`, `Calendar`, `Camera`, `FollowUps`, `More`, `NewAppointment`, `NewClient`, `RunningLate`, `ShareLink`, `Tx-1-Register`, `Waitlist`, `WeekGlance`, `WinBack`
- **Estados**: `callOpen`, `calling`
- **Variantes**: `fresh`
- **Textos**: "Good morning, Maria" · "Wednesday, September 30" · "MB" · "Next up · in 1 h 20 min" · "CR" · "Camila Rocha" · "Glow Facial · 60 min" · "Confirmed" · "Bridal" · "Before you start" · "Open" · "Running late? Tell Camila" · "The rest of today" · "2 left" · "JM" · "Julia Mendes" · "Deep Cleansing" · "Completed" · "AC" · "Ana Costa" · "Brazilian Glow" · "open slots this week" · "on the waitlist" · "haven't returned" · "Follow-ups" · "3 clients are ready to hear from you" · "BL" · "Beatriz" · "· Glow Facial" · "28 days ago" · "MA" · "Marina" · "· Deep Cleansing" · "35 days ago" · "PN" · "Paula" · "42 days ago" · "View follow-ups" · "Your day is clear." · "New bookings appear here as soon as someone books with your link." · "Share your link" · "Quick actions" · "New appointment" · "New client" · "Register treatment"

### 2.2 · Clients: Clients
- **Imagem**: `design/screenshots/02-02_Clients.png`
- **Propósito**: Lista de clientes com busca e filtros (todas, para voltar, cancela com frequência, novas, tags). Faixa de "quem não voltou". Estado vazio com convite a compartilhar o link e importar.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientEdit`, `ClientProfile`, `ImportClients`, `NewClient`, `Notifications`
- **Vai para**: `ClientProfile`, `ImportClients`, `NewClient`, `ShareLink`, `WinBack`
- **Estados**: `flt`, `q`
- **Variantes**: `fresh`
- **Textos**: "Clients" · "3 clients" · "have not been back in 2+ months" · "No clients yet" · "Clients appear when someone books with you. You can also add or import them yourself." · "Share your link" · "Import"

### 2.3 · Calendar: Calendar
- **Imagem**: `design/screenshots/02-03_Calendar.png`
- **Propósito**: Agenda por dia e por semana. Horário livre aparece como espaço tracejado que leva à lista de espera.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Appointment`, `BlockTime`, `BookingRequest`, `CancelAppointment`, `Home`, `NewAppointment`, `NoShowMark`, `Notifications`, `Reschedule`, `RescheduleRequest`, `RunningLate`, `Waitlist`, `WeekGlance`
- **Vai para**: `Appointment`, `NewAppointment`, `Waitlist`, `WeekGlance`
- **Estados**: `sel`, `view`
- **Textos**: "Calendar" · "Day" · "Week" · "Lunch · 12:30 to 13:30" · "New booking from your link" · "Thu 15:00 is open." · "3 people are waiting."

### 2.4 · Notifications: Alerts
- **Imagem**: `design/screenshots/02-04_Notifications.png`
- **Propósito**: Central de alertas: pedido de reserva e de remarcação, cliente atrasada, cancelamento, check-in, formulário recebido, aniversários, follow-ups, quem não voltou; **mais a seção "Reminders ready"** (D31, `docs/10` §9, adição de design).
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BookingRequest`, `Incident`, `RescheduleRequest`, `Waitlist`
- **Vai para**: `Appointment`, `BeforeYouStart`, `BookingRequest`, `Calendar`, `ClientHealth`, `Clients`, `FollowUps`, `Incident`, `NotificationSettings`, `RescheduleRequest`, `Waitlist`, `WinBack`
- **Textos**: "Alerts" · "Booking activity, replies and follow-ups" · "Today" · "Camila is running late" · "just now" · "Camila Rocha will arrive about 15 minutes after her 11:30 Glow Facial. She told you from her booking page." · "Reply" · "Booking request" · "4 min" · "Ana Costa asks for Brazilian Glow on Thursday, Oct 15 at 10:00. You chose to confirm her bookings." · "Review request" · "Reschedule request" · "12 min" · "Camila Rocha asks to move Friday, Oct 2 at 10:00 to Saturday, Oct 3 at 11:00. It is inside your free-change period." · "Helena cancelled" · "2 min" · "Thursday, Oct 1 at 15:00 is free again. 3 people are on the waitlist." · "Offer the time" · "Renata answered her check-in" · "1 h" · ""A bit irritated, cheeks red since morning." after Glow Facial on Sep 29." · "Log a reaction" · "New booking" · "9 min" · "Helena Duarte booked Brazilian Glow for Thursday, Oct 1 at 15:00." · "New client" · "Helena was added to your clients automatically from your booking link." · "Health form completed" · "8 min" · "Helena answered the health form and signed the consent." · "Birthdays this week" · "Julia Mendes today and Larissa Souza on Friday, Oct 2." · "Send your wishes" · "Follow-ups due" · "3 clients are ready for a follow-up." · "View follow-ups" · "Haven't returned" · "3 clients have not visited in more than 2 months." · "Send a message" · "Upcoming appointment" · "Ana Costa at 15:00. Review what matters before you start." · "Earlier" · "Cancellation" · "Tue" · "Larissa Souza cancelled Friday at 10:00. The slot is open again."

### 2.5 · More: More
- **Imagem**: `design/screenshots/02-05_More.png`
- **Propósito**: Menu: negócio, clientes, mensagens, preferências e conta.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `AISettings`, `Account`, `Availability`, `BookingSettings`, `Credentials`, `Help`, `Home`, `Integrations`, `NotificationSettings`, `Plan`, `Privacy`, `Products`, `QuickReplies`, `RecordTemplate`, `Services`, `States`, `Tags`, `Team`
- **Vai para**: `AISettings`, `Account`, `Availability`, `BookingSettings`, `Credentials`, `FormTemplates`, `Help`, `ImportClients`, `Integrations`, `NotificationSettings`, `Plan`, `Privacy`, `Products`, `QuickReplies`, `RecordTemplate`, `Services`, `ShareLink`, `SignIn`, `States`, `Tags`, `Team`
- **Textos**: "More" · "MB" · "Maria Beauty" · "Esthetician · São Paulo" · "Business" · "Services" · "4 services" · "Products" · "3 products" · "Booking page" · "Live" · "Availability" · "Tue to Sat" · "Training and credentials" · "3 credentials" · "Team" · "Just you" · "Clients" · "Record fields" · "What you remember about clients" · "Client forms" · "Health form and consent" · "Client tags" · "4 tags" · "Import clients" · "Phone or spreadsheet" · "Messages" · "Quick replies" · "6 messages" · "Share link and QR" · "bellohub.app/maria" · "Preferences" · "Notifications" · "Privacy and security" · "Face ID on" · "AI assistant" · "Review before saving" · "Integrations" · "Google Calendar" · "Account" · "Your plan" · "Free trial · 12 days left" · "Help and support" · "System states" · "Reference for developers"

### 2.6 · WeekGlance: Week at a glance
- **Imagem**: `design/screenshots/02-06_WeekGlance.png`
- **Propósito**: Resumo da semana com sugestões (horários vazios, clientes para chamar).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Calendar`, `Home`
- **Vai para**: `Calendar`, `Home`, `Waitlist`, `WinBack`
- **Textos**: "Home" · "This week" · "Sep 29 to Oct 3 · Tuesday to Saturday" · "left today" · "open slots" · "on the waitlist" · "haven't returned" · "Bookings by day" · "Open slots" · "Open slots follow your availability and the 15-minute buffer between clients."

### 2.7 · FollowUps: Follow-ups due
- **Imagem**: `design/screenshots/02-07_FollowUps.png`
- **Propósito**: Clientes cujo retorno chegou (mensagem pronta e atalho para agendar) e aniversariantes da semana com mensagem de parabéns que abre no WhatsApp.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Home`, `Notifications`
- **Vai para**: `Cl-1-Reminder`, `Home`, `NewAppointment`, `WinBack`
- **Estados**: `bopen`, `bsent`, `open`, `sent`
- **Textos**: "Home" · "Follow-ups" · "Clients whose recommended return date has arrived." · "Book" · "Birthdays this week" · "3 clients" · "have not been back in 2+ months" · "Sent from your number on WhatsApp." · "Choose a time" · "bellohub.app/maria" · "Send reminder" · "Cancel" · "Reminder sent" · "See what your client receives" · "Done" · "Opens WhatsApp with this message ready. You press send." · "Wishing you a lovely day. Whenever you want a little care for your skin, I am here." · "Open WhatsApp"

### 2.8 · WinBack: Win back clients
- **Imagem**: `design/screenshots/02-08_WinBack.png`
- **Propósito**: Quem não volta há 60+ dias, com mensagem pronta para reconquistar.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Clients`, `FollowUps`, `Home`, `Notifications`, `WeekGlance`
- **Vai para**: `Home`, `QuickReplies`
- **Estados**: `open`, `sent`
- **Textos**: "Home" · "Haven't returned" · "People whose last visit was more than 2 months ago." · "clients to reconnect" · "with this month" · "Sent" · "Message" · "A short, friendly message often brings people back. Nothing is sent until you tap Send." · "Preview on WhatsApp" · "Edit this message" · "Send on WhatsApp" · "Not now"

### 2.9 · Waitlist: Waitlist
- **Imagem**: `design/screenshots/02-09_Waitlist.png`
- **Propósito**: Lista de espera: quando um horário abre, a profissional oferece a quem está na fila.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BlockTime`, `Calendar`, `CancelAppointment`, `Home`, `Notifications`, `WeekGlance`
- **Vai para**: `Calendar`, `Notifications`
- **Estados**: `off`
- **Textos**: "Alerts" · "Waitlist" · "A time opened up. Offer it to people who asked." · "Freed by Helena Duarte" · "Thursday, Oct 1 · Brazilian Glow" · "90 min · until 16:30" · "Waiting for this day" · "Cancels often" · "Offered" · "Offer" · "Back to calendar"

### 2.10 · BookingRequest: Booking request
- **Imagem**: `design/screenshots/02-10_BookingRequest.png`
- **Propósito**: Pedido de reserva que espera aprovação (cliente nova, se "confirmar novas clientes" estiver ligado, ou cliente que atingiu o limite de faltas). Aceitar, recusar ou sugerir outro horário.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Notifications`
- **Vai para**: `Calendar`, `MessageClient`, `NoShowHistory`, `Notifications`
- **Estados**: `dec`, `zero`
- **Textos**: "Alerts" · "Booking request" · "Ana asked for this time. Nothing is booked until you say yes." · "AC" · "Ana Costa" · "Brazilian Glow · 90 min" · "Thursday, Oct 15 · 10:00 to 11:30" · "Her note" · "Hi Maria! I can make it this time. I set two reminders." · "You asked to confirm Ana's bookings." · "She has 3 no-shows in the last 12 months. See her history." · "Start her count from zero" · "Online booking opens again for her." · "Decline" · "Approve" · "Suggest another time" · "Open calendar" · "Back to alerts"

### 2.11 · RescheduleRequest: Reschedule request
- **Imagem**: `design/screenshots/02-11_RescheduleRequest.png`
- **Propósito**: Pedido de remarcação da cliente dentro do período de troca restrito. O horário atual continua reservado até a profissional aceitar. Aceitar, recusar ou sugerir outro horário.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Notifications`
- **Vai para**: `Calendar`, `MessageClient`, `Notifications`
- **Estados**: `dec`
- **Textos**: "Alerts" · "Reschedule request" · "Camila asked to move a visit. Her current time stays booked until you say yes." · "CR" · "Camila Rocha" · "Glow Facial · 60 min" · "Now" · "Friday, Oct 2 · 10:00 to 11:00" · "Asks for" · "Saturday, Oct 3 · 11:00 to 12:00" · "Her note" · "Hi Maria, something came up at work. Could we do Saturday instead? Sorry for the short notice!" · "Inside your free-change period" · "Your calendar is free on Saturday at 11:00." · "Decline" · "Move to Saturday" · "Suggest another time" · "Open calendar" · "Back to alerts"

### 2.12 · RunningLate: Running late
- **Imagem**: `design/screenshots/02-12_RunningLate.png`
- **Propósito**: A profissional avisa que vai atrasar: 10 a 45 min, escolhe quem avisar e abre o WhatsApp com a mensagem pronta (o app nunca envia sozinho). O calendário não muda.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Appointment`, `Home`
- **Vai para**: `Calendar`, `Home`
- **Estados**: `delay`, `on`, `sent`
- **Textos**: "Today" · "Running late" · "Tell the next clients before they arrive. Your calendar stays as it is." · "How late?" · "Who to tell" · "What they get" · "WhatsApp opens with the message ready. You press send." · "That is a long wait. Offer to reschedule if someone cannot stay." · "Done" · "Open calendar"


---

## 03 · Agendamentos

### 3.1 · NewAppointment: New appointment
- **Imagem**: `design/screenshots/03-01_NewAppointment.png`
- **Propósito**: Cria agendamento: cliente, tipo de visita (tratamento novo, retoque, verificação após reação), serviço, adicionais, convidadas e horário. Avisa de sobreposição, almoço, pausa, fim do expediente, intervalo menor que o configurado, falta de teste de alergia, contraindicação do serviço e cliente que falta com frequência. "Agendar mesmo assim" libera o conflito; "Bloquear horário" abre `BlockTime`.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Calendar`, `ClientProfile`, `FollowUps`, `Home`, `Incident`, `NewClient`, `Tx-7-NextSession`
- **Vai para**: `BlockTime`, `Calendar`, `ClientHealth`, `ClientProfile`, `MessageClient`, `NewClient`
- **Estados**: `ao`, `client`, `force`, `gs`, `q`, `service`, `time`, `vt`
- **Textos**: "Cancel" · "New appointment" · "Client" · "New client" · "Beatriz missed 2 appointments without a message." · "One more and your no-show rule applies. Send a reminder the day before." · "Visit type" · "Service" · "Duration" · "Price shown to client" · "No patch test on record for Camila." · "Brazilian Glow asks for one at least 48 hours before. Message her to arrange it." · "Beatriz reported isotretinoin in the last 6 months." · "Deep Cleansing is marked not suitable for that. Review her health form first." · "Add-ons" · "Guests" · "Each guest is booked back to back, with the same service." · "Date and time" · "Date" · "Today · Wed, Sep 30" · "Block time instead" · "Confirm appointment" · "Choose another time"

### 3.2 · Appointment: Appointment detail
- **Imagem**: `design/screenshots/03-02_Appointment.png`
- **Propósito**: Folha do agendamento: status, alergia em destaque, preparo (ficha de saúde, teste de alergia, lembrete sem resposta com "Remind again"), Before you start, concluir, mensagem, "Running late", remarcar, no-show e cancelar.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Calendar`, `CancelAppointment`, `Home`, `NoShowMark`, `Notifications`, `Reschedule`
- **Vai para**: `BeforeYouStart`, `Calendar`, `CancelAppointment`, `ClientProfile`, `MessageClient`, `NoShowMark`, `Reschedule`, `RunningLate`, `Tx-1-Register`
- **Textos**: "Calendar" · "AC" · "Ana Costa" · "Brazilian Glow · 90 min" · "Confirmed" · "Today · 15:00 to 16:30" · "Fragrance allergy." · "Skin barrier plan, session 3 of 6." · "Health form signed · patch test not needed" · "Reminder sent yesterday. No reply yet." · "Remind again" · "Before you start" · "Mark completed" · "Message" · "Running late" · "Reschedule" · "No-show" · "Cancel appointment"

### 3.3 · BeforeYouStart: Before you start
- **Imagem**: `design/screenshots/03-03_BeforeYouStart.png`
- **Propósito**: Resumo antes de atender: alergias, plano de sessões, último resultado, checagem de contraindicações do serviço, consentimento, fotos recentes.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Appointment`, `Home`, `Notifications`
- **Vai para**: `ClientHealth`, `ClientProfile`, `Home`, `RecordHistory`, `SessionPlan`, `Tx-1-Register`, `Tx-6-Photos`
- **Textos**: "Today" · "Confirmed" · "Ana Costa" · "Brazilian Glow · Today · 15:00 to 16:30" · "Important" · "Sensitive skin" · "Allergy: fragrance" · "Prefers fragrance-free products" · "Client knowledge · noted by you" · "Skin barrier repair" · "Session 3 of 6 · every 4 weeks" · "Last visit" · "Glow Facial" · "Aug 30" · "Previous result" · "Good response" · "No reaction" · "Checked against Brazilian Glow: no contraindications in her health form." · "Consent signed Sep 12" · "Patch test Jul 20 · no reaction" · "Recent photos" · "4 photos" · "See full record" · "Open client" · "Mark completed"

### 3.4 · Reschedule: Reschedule
- **Imagem**: `design/screenshots/03-04_Reschedule.png`
- **Propósito**: Remarcar: escolhe novo horário e avisa a cliente.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Appointment`
- **Vai para**: `Appointment`, `Calendar`
- **Estados**: `day`, `done`, `nt`, `tm`
- **Textos**: "Close" · "Reschedule" · "AC" · "Ana Costa" · "Brazilian Glow · 90 min" · "Now: Wed 15:00" · "New day" · "New time" · "Message Ana on WhatsApp" · "Tell her about the new time" · "Confirm new time" · "Moved." · "Back to calendar" · "Open appointment"

### 3.5 · CancelAppointment: Cancel appointment
- **Imagem**: `design/screenshots/03-05_CancelAppointment.png`
- **Propósito**: A profissional cancela: motivo, aviso (cancelamento feito por ela não conta contra a cliente), mensagem à cliente e oferta à lista de espera.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Appointment`
- **Vai para**: `Appointment`, `Calendar`, `Waitlist`
- **Estados**: `done`, `n1`, `n2`, `r`
- **Textos**: "Close" · "Cancel appointment" · "AC" · "Ana Costa" · "Brazilian Glow · Wed, Sep 30 · 15:00" · "Reason" · "Cancelled by you, so it does not count against Ana. Offer her a new time in your message." · "Message Ana" · "Let her know and offer new times" · "Offer the time to the waitlist" · "3 people are waiting" · "Keep appointment" · "Appointment cancelled." · "Open waitlist" · "Back to calendar"

### 3.6 · MessageClient: Message a client
- **Imagem**: `design/screenshots/03-06_MessageClient.png`
- **Propósito**: Mensagem pronta para a cliente (WhatsApp, SMS), com respostas rápidas.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `Appointment`, `BookingRequest`, `ClientProfile`, `NewAppointment`, `NoShowMark`, `RescheduleRequest`
- **Vai para**: `ClientProfile`, `QuickReplies`
- **Estados**: `copied`, `opened`, `sel`
- **Textos**: "Ana" · "Message Ana" · "Pick a message, check it, then open WhatsApp." · "AC" · "Ana Costa" · "+55 11 98123-4410 · WhatsApp" · "Message" · "Edit templates" · "Open WhatsApp"

### 6.6 · BlockTime: Block time
- **Imagem**: `design/screenshots/06-06_BlockTime.png`
- **Propósito**: Bloquear dias ou horas em que não pode trabalhar, com motivo privado. Lista as clientes já marcadas e deixa escolher entre cancelar e convidar a remarcar ou manter por enquanto. Cancelamento feito pela profissional nunca conta como falta. Mensagem pronta por cliente abre no WhatsApp. O horário some da página pública na hora.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Availability`, `NewAppointment`
- **Vai para**: `Availability`, `Calendar`, `Waitlist`
- **Estados**: `days`, `done`, `from`, `handle`, `reason`, `scope`, `sent`, `to`
- **Textos**: "Availability" · "Block time" · "Close your calendar when you cannot work. Your booking page stops offering these times right away." · "Which days" · "How long" · "Whole day" · "Some hours" · "From" · "Until" · "Reason" · "Only you see this." · "Cancel" · "Time blocked." · "What each client gets" · "WhatsApp opens with the message ready. You press send." · "Offer the free times to the waitlist" · "3 people are waiting" · "Back to availability" · "Open calendar"

### 3.7 · NoShowMark: Mark a no-show
- **Imagem**: `design/screenshots/03-07_NoShowMark.png`
- **Propósito**: A profissional marca "não compareceu" depois do horário. Pode avisar a cliente. Mostra quantas faltas a cliente soma e se isso atinge o limite.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Appointment`
- **Vai para**: `Appointment`, `Calendar`, `MessageClient`, `NoShowHistory`, `NoShowPolicy`
- **Estados**: `done`, `kind`, `note`
- **Textos**: "Close" · "Didn't show up" · "AC" · "Ana Costa" · "Brazilian Glow · Today · 15:00 to 16:30" · "Did Ana miss this one?" · "She did not come and did not tell you." · "Ana's count" · "Change my rule" · "Send a friendly note" · "In your WhatsApp, after you save." · "Hi Ana, we missed you today. If you can't make it, a quick message helps me offer your time to someone else. See you soon!" · "Not now" · "Send the friendly note" · "Ready in WhatsApp. You read it first." · "Open Ana's history" · "Back to calendar"


---

## 04 · Ficha da cliente

### 4.1 · ClientProfile: Client profile
- **Imagem**: `design/screenshots/04-01_ClientProfile.png`
- **Propósito**: Ficha da cliente com foto, contato rápido, etiquetas (inclui "Online booking stopped"), visão geral, histórico, fotos e produtos.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Appointment`, `BeforeYouStart`, `ClientEdit`, `ClientHealth`, `ClientKnowledge`, `Clients`, `ExportRecord`, `Incident`, `MessageClient`, `NewAppointment`, `NoShowHistory`, `RecordHistory`, `SessionPlan`
- **Vai para**: `Camera`, `ClientEdit`, `ClientHealth`, `ClientKnowledge`, `Clients`, `ExportRecord`, `Incident`, `MessageClient`, `NewAppointment`, `NoShowHistory`, `RecordHistory`, `SessionPlan`, `Tx-1-Register`, `Tx-6-Photos`
- **Estados**: `callOpen`, `calling`, `tab`
- **Textos**: "Edit" · "Ana Costa" · "Sensitive skin" · "Regular" · "2 no-shows" · "Online booking stopped" · "Call" · "Message" · "Book" · "Important to know" · "Allergic to fragrance" · "Sensitive skin · prefers fragrance-free products" · "Skin barrier repair" · "Session 3 of 6 · every 4 weeks" · "Last visit" · "Glow Facial" · "Aug 30" · "Good response" · "Next" · "Brazilian Glow" · "Today · 15:00" · "Confirmed" · "Client knowledge" · "Sensitivities" · "Cheeks" · "Preferences" · "Fragrance-free" · "Recurring requests" · "Gentle pressure" · "Health and consent" · "Signed Sep 12" · "Habits" · "Only you" · "Visits" · "Cancelled" · "No-shows" · "Late cancellations" · "1 · Jun 3" · "Comes back" · "Every ~6 weeks" · "Usually books" · "Afternoons" · "Most booked" · "Found you via" · "Booking link"

### 4.2 · NewClient: New client
- **Imagem**: `design/screenshots/04-02_NewClient.png`
- **Propósito**: Cadastro de cliente, com foto, tags e campos da ficha da profissão.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Clients`, `Home`, `NewAppointment`
- **Vai para**: `Clients`, `ImportClients`, `NewAppointment`, `Tags`
- **Estados**: `link`, `photo`, `sel`
- **Textos**: "Cancel" · "New client" · "Import many at once" · "From phone contacts or a spreadsheet" · "Name" · "WhatsApp" · "Email" · "Tags" · "+ New tag" · "Important to know" · "Stays private. It appears at the top of Before you start." · "Send my booking link" · "So she can book herself next time." · "Clients who book through your link are added automatically. Use this for people you already know." · "Save client" · "Save and book appointment"

### 4.3 · ClientEdit: Edit client
- **Imagem**: `design/screenshots/04-03_ClientEdit.png`
- **Propósito**: Edita a cliente (nome, WhatsApp, e-mail, aniversário, tags), pode parar a reserva online dela com motivo (privado), desligar lembretes e follow-ups, arquivar, mesclar duplicata.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientProfile`
- **Vai para**: `ClientProfile`, `Clients`, `Privacy`
- **Estados**: `archOpen`, `blocked`, `du`, `k`, `mergeOpen`, `rem`, `tg`, `why`
- **Textos**: "Cancel" · "Edit client" · "Save" · "AC" · "Change photo" · "Name" · "WhatsApp" · "Email" · "Birthday" · "Tags" · "Online booking" · "Stop online booking for Ana" · "She cannot book on her own. You can still book her." · "Reason (only you see it)" · "On your booking page she reads: Please message Maria to book. Her existing appointments are not touched." · "Reminders and follow-ups" · "Off if she asked not to be messaged." · "Archive client" · "Hide from lists, keep the record" · "Merge with a duplicate" · "Combine two profiles into one" · "Delete client data" · "Open privacy tools" · "Archive Ana?" · "She disappears from your client list and booking suggestions. Her record is kept and you can restore her any time." · "Choose the profile to combine into Ana Costa. Records, photos and notes move to Ana." · "Merge profiles"

### 4.4 · ClientKnowledge: Edit client knowledge
- **Imagem**: `design/screenshots/04-04_ClientKnowledge.png`
- **Propósito**: Edita o que a profissional lembra da cliente (sensibilidades, preferências, pedidos recorrentes).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientProfile`
- **Vai para**: `ClientProfile`
- **Estados**: `drafts`, `lists`
- **Textos**: "Client knowledge" · "Done" · "What you want to remember about Ana, in your own words. Only you see this." · "Add" · "Shown to you before every appointment. Never shared with Ana."

### 4.5 · ClientHealth: Health and consent
- **Imagem**: `design/screenshots/04-05_ClientHealth.png`
- **Propósito**: Saúde e consentimento: respostas da ficha, assinatura, data.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `BeforeYouStart`, `ClientProfile`, `NewAppointment`, `Notifications`, `Tx-6-Photos`
- **Vai para**: `Cl-4-Intake`, `ClientProfile`
- **Estados**: `added`
- **Textos**: "Ana" · "Health and consent" · "Private. Only you can see this." · "Health history" · "Allergies" · "Fragrance" · "Medication" · "None" · "Pregnant or breastfeeding" · "No" · "Skin conditions" · "Sensitive skin" · "Reported by Ana · Sep 12" · "Review every 12 months" · "Consent" · "Facial treatments" · "Signed by Ana Costa · Sep 12" · "Patch test log" · "Record patch test" · "Send form again" · "Ana gets a link on WhatsApp and fills it in on her phone. No app needed."

### 4.6 · ImportClients: Import clients
- **Imagem**: `design/screenshots/04-06_ImportClients.png`
- **Propósito**: Importa clientes dos contatos do celular ou de planilha.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Clients`, `Integrations`, `More`, `NewClient`, `Onb-7-Ready`
- **Vai para**: `Clients`
- **Estados**: `sel`, `send`, `step`
- **Textos**: "Cancel" · "Back" · "Import clients" · "Bring your clients with you." · "Start with names and phone numbers. Their history grows from the next visit on." · "Phone contacts" · "Choose who to bring over" · "Spreadsheet" · "Excel or CSV with name and phone" · "Other booking apps" · "Coming soon" · "Choose clients" · "They are in your Clients list. Add tags and notes whenever you like." · "Send my booking link" · "Invite them on WhatsApp so they can book on their own." · "View clients"

### 4.7 · RecordHistory: Record history
- **Imagem**: `design/screenshots/04-07_RecordHistory.png`
- **Propósito**: Histórico completo do prontuário, com trilha de edição e correções (registro trava em 24 h).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `BeforeYouStart`, `ClientProfile`, `Tx-5-Saved`
- **Vai para**: `ClientProfile`
- **Estados**: `addOpen`, `added`, `cf`
- **Textos**: "Ana" · "Record history" · "Glow Facial · Aug 30" · "Locked." · "Original entries can't be edited. Changes are added below as corrections and logged with date and time." · "Add correction" · "It will be saved as a new entry. The original stays unchanged." · "What should be corrected?" · "Save correction" · "Cancel"

### 4.8 · SessionPlan: Session plan
- **Imagem**: `design/screenshots/04-08_SessionPlan.png`
- **Propósito**: Plano de sessões (ex.: 6 sessões a cada 4 semanas), sessão atual e próximas.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `BeforeYouStart`, `ClientProfile`
- **Vai para**: `ClientProfile`
- **Estados**: `gap`, `n`, `pn`, `rem`
- **Textos**: "Ana" · "Treatment plan" · "A series of sessions toward one goal. No prices, just the rhythm." · "Plan name" · "Sessions" · "Number of sessions" · "Time between sessions" · "Timeline" · "Remind me to rebook" · "After each session, suggest the next date" · "Save plan"

### 4.9 · Incident: Report a reaction
- **Imagem**: `design/screenshots/04-09_Incident.png`
- **Propósito**: Registra reação (o que aconteceu, gravidade, área, o que foi feito, retorno). Depois de salvar, "Book a check visit" abre `NewAppointment` como verificação após reação, ligada à visita.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientProfile`, `Notifications`
- **Vai para**: `ClientProfile`, `NewAppointment`, `Notifications`
- **Estados**: `fu`, `key`, `nt`, `saved`
- **Textos**: "Close" · "Log a reaction" · "Keep a clear, neutral note of what the client reported or you saw." · "Client" · "What happened" · "Severity" · "Area" · "What you did" · "Notes" · "Follow up with the client" · "Reminds you to check in tomorrow" · "Save to record" · "Logged to the record." · "Book a check visit" · "Back to alerts" · "Open Ana's profile"

### 4.10 · ExportRecord: Export record
- **Imagem**: `design/screenshots/04-10_ExportRecord.png`
- **Propósito**: Exporta a ficha em PDF para a cliente ou para um médico.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientProfile`, `Privacy`
- **Vai para**: `ClientProfile`
- **Estados**: `done`, `on`, `per`, `shared`
- **Textos**: "Ana" · "Export record" · "A PDF of the client record to keep or share." · "AC" · "Ana Costa" · "2 treatments · consent signed Sep 12" · "Include" · "Period" · "Ana Costa · Client record" · "Maria Beauty · exported Sep 30, 2026" · "Share only with the client or a health professional she authorises." · "Export PDF" · "Your PDF is ready." · "The record was exported with the items you chose. Photos and internal notes stay private unless you included them." · "Ana-Costa-record.pdf" · "Share" · "Back to profile"

### 4.11 · NoShowHistory: No-show history
- **Imagem**: `design/screenshots/04-11_NoShowHistory.png`
- **Propósito**: Histórico de faltas e cancelamentos tardios de uma cliente, com opção de perdoar uma falta.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `BookingRequest`, `ClientProfile`, `NoShowMark`
- **Vai para**: `ClientProfile`, `NoShowPolicy`
- **Estados**: `ex`, `reset`
- **Textos**: "Ana Costa" · "No-shows" · "Ana Costa · counted over the last 12 months" · "Change my rule" · "History" · "Allow online booking again" · "Her count starts from zero. The history stays here." · "Online booking is open again. Count: 0." · "Only you see this. Ana is told about your rule on your booking page, and she can ask you to review it."


---

## 05 · Registro de atendimento

### 5.1 · Tx-1-Register: 01 Register treatment
- **Imagem**: `design/screenshots/05-01_Tx-1-Register.png`
- **Propósito**: Início do registro de atendimento: gravar por voz ou escrever manualmente.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Appointment`, `BeforeYouStart`, `ClientProfile`, `Home`, `Tx-2-Listening`, `Tx-Form`
- **Vai para**: `Home`, `Tx-2-Listening`, `Tx-Form`
- **Textos**: "Cancel" · "Register treatment" · "AC" · "Ana Costa" · "Brazilian Glow · Sep 30, 15:00" · "Completed" · "Record treatment" · "Just say what you did. Bello AI organizes it into a clean record for you to review." · "You might say" · "“Her skin was a little sensitive around the cheeks, so I reduced the intensity there. She should come back in about four weeks.”" · "Write it myself instead"

### 5.2 · Tx-2-Listening: 02 Listening
- **Imagem**: `design/screenshots/05-02_Tx-2-Listening.png`
- **Propósito**: Gravando e transcrevendo a voz.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Tx-1-Register`, `Tx-Form`
- **Vai para**: `Tx-1-Register`, `Tx-3-Organizing`
- **Textos**: "Cancel" · "Ana Costa · Brazilian Glow" · "Listening…" · "What bello ai hears" · "“Today I did the Brazilian Glow. Her skin was a little sensitive around the cheeks, so I reduced the intensity there." · "I used the calming serum and she responded really…" · "Tap to finish"

### 5.3 · Tx-3-Organizing: 03 AI organizing
- **Imagem**: `design/screenshots/05-03_Tx-3-Organizing.png`
- **Propósito**: IA organiza o texto nos campos do prontuário.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Tx-2-Listening`, `Tx-4-Review`
- **Vai para**: `Tx-4-Review`
- **Textos**: "Bello AI is organizing your treatment" · "Turning your voice note into a clear record. Nothing is saved until you review it." · "Voice note transcribed" · "Products and technique found" · "Structuring your record" · "Bello AI only organizes what you said. It never diagnoses or adds products." · "Review draft"

### 5.4 · Tx-4-Review: 04 Review and save
- **Imagem**: `design/screenshots/05-04_Tx-4-Review.png`
- **Propósito**: Revisão do que a IA entendeu. A profissional corrige e só então salva.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Tx-3-Organizing`
- **Vai para**: `Tx-3-Organizing`, `Tx-5-Saved`
- **Estados**: `resolved`
- **Textos**: "Back" · "AI draft" · "Review and save" · "Ana Costa · Brazilian Glow · Sep 30. Tap any field to edit." · "Observations" · "Skin a little sensitive around the cheeks." · "Technique" · "Reduced intensity on the cheeks." · "Products" · "Calming serum" · "Please review" · "Product name unclear. You mentioned a second product but Bello AI could not catch its name." · "Mark as reviewed" · "Reviewed by you" · "Result" · "Responded well." · "Recommendation" · "Return in about 4 weeks." · "Every field comes from your voice note. Reaction and aftercare were not mentioned, so they stay empty instead of guessed." · "Save to Ana's history"

### 5.5 · Tx-Form: Manual treatment record
- **Imagem**: `design/screenshots/05-05_Tx-Form.png`
- **Propósito**: Registro manual por formulário adaptado à profissão.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Tx-1-Register`
- **Vai para**: `Tx-1-Register`, `Tx-2-Listening`, `Tx-5-Saved`
- **Estados**: `prof`, `sel`
- **Textos**: "Cancel" · "Treatment record" · "AC" · "Ana Costa" · "Brazilian Glow · Sep 30" · "Fields for your craft" · "Anything you leave empty stays empty. Nothing is guessed or filled in for you." · "Save to Ana's history"

### 5.6 · Tx-5-Saved: 05 Saved treatment
- **Imagem**: `design/screenshots/05-06_Tx-5-Saved.png`
- **Propósito**: Atendimento salvo: resumo, próxima sugestão, check-in e cuidados pós-atendimento (envio opcional à cliente).
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Tx-4-Review`, `Tx-6-Photos`, `Tx-7-NextSession`, `Tx-Form`
- **Vai para**: `Home`, `RecordHistory`, `Tx-6-Photos`, `Tx-7-NextSession`
- **Estados**: `added`, `more`
- **Textos**: "Done" · "Saved to Ana's history" · "Brazilian Glow" · "September 30, 2026 · Ana Costa" · "This session" · "Observations" · "Skin a little sensitive around the cheeks." · "Technique" · "Reduced intensity on the cheeks." · "Products" · "Calming serum" · "Result" · "Responded well." · "Reaction" · "Not recorded" · "Aftercare" · "Photos" · "None yet" · "See the full record" · "Edit trail and corrections" · "Suggested for ana's profile" · "Add “Cheeks” to Ana's sensitivities so you see it before every visit?" · "Not now" · "Set next session" · "Add before and after"

### 5.7 · Tx-6-Photos: 06 Before and after
- **Imagem**: `design/screenshots/05-07_Tx-6-Photos.png`
- **Propósito**: Antes e depois: lado a lado, controle deslizante e linha do tempo. Foto de câmera ou da galeria.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `BeforeYouStart`, `Camera`, `ClientProfile`, `Tx-5-Saved`
- **Vai para**: `Camera`, `ClientHealth`, `Tx-5-Saved`, `Tx-7-NextSession`
- **Estados**: `lib`, `pos`, `tab`
- **Textos**: "Back" · "Before and after" · "Ana Costa · Brazilian Glow · Sep 30" · "Photo consent signed Sep 12" · "Photos stay private to you unless Ana agrees" · "Before" · "After" · "Sep 30 · Brazilian Glow" · "Today" · "Aug 30 · Glow Facial" · "Jul 20 · Deep Cleansing" · "Take photo" · "Private by default. Photos stay linked to Ana, the date and this session, and never become marketing content unless you choose." · "Continue"

### 5.8 · Camera: Camera
- **Imagem**: `design/screenshots/05-08_Camera.png`
- **Propósito**: Câmera própria com guia de enquadramento para fotos comparáveis.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `ClientProfile`, `Home`, `Tx-6-Photos`
- **Vai para**: `Tx-6-Photos`
- **Estados**: `back`, `cons`, `flash`, `ghost`, `shot`, `side`
- **Textos**: "Saved only in Bello, not in your camera roll" · "Ghost" · "Review photo" · "Who can see this photo?" · "Portfolio use needs the client's OK. Ana's consent from Sep 12 covers private records only." · "Retake" · "Save photo"

### 5.9 · Tx-7-NextSession: 07 Next session
- **Imagem**: `design/screenshots/05-09_Tx-7-NextSession.png`
- **Propósito**: Define a próxima sessão e o retorno recomendado.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Cl-1-Reminder`, `Tx-5-Saved`, `Tx-6-Photos`
- **Vai para**: `Cl-1-Reminder`, `Home`, `NewAppointment`, `Tx-5-Saved`
- **Estados**: `auto`, `wk`
- **Textos**: "Back" · "Skip" · "Next session" · "When should Ana come back for Brazilian Glow?" · "Recommended" · "Your default for Brazilian Glow is 4 weeks." · "Remind Ana automatically" · "A week before. She gets a link to book, no app needed." · "Book now" · "Remind client"


---

## 06 · Configuração do negócio

### 6.1 · Services: Services
- **Imagem**: `design/screenshots/06-01_Services.png`
- **Propósito**: Lista de serviços, "Add a service", Adicionais e Produtos.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `AddOns`, `More`, `ServiceEdit`
- **Vai para**: `AddOns`, `More`, `Products`, `ServiceEdit`
- **Textos**: "More" · "Services" · "Named your way. Each one carries its own follow-up rhythm." · "Photos" · "Aftercare" · "Add a service" · "Add-ons" · "Extras clients can add to a visit" · "Products" · "What you use and recommend"

### 6.2 · ServiceEdit: New service
- **Imagem**: `design/screenshots/06-02_ServiceEdit.png`
- **Propósito**: Cria ou edita serviço: nome, preço, categoria, duração, visibilidade de preço, follow-up, "Não indicado se a cliente tem..." (gravidez, isotretinoína nos últimos 6 meses, infecção ativa, queimadura solar, anticoagulantes), fotos, perguntas, cuidados e teste de alergia antes da primeira visita.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Services`
- **Vai para**: `Services`
- **Estados**: `cat`, `ci`, `cx`, `dur`, `key`, `vis`, `wk`
- **Textos**: "Cancel" · "New service" · "Name" · "Price" · "Bello Hub learns the names you use and keeps them everywhere, including voice notes." · "Category" · "+ New" · "Duration" · "Price on your booking page" · "Recommended follow-up" · "Not suitable if the client has" · "You see a warning when a client's health form matches." · "Before and after photos" · "Remind me to take them" · "Pre-appointment questions" · "Ask first-time clients when they book" · "Aftercare" · "Share a template after the visit" · "Patch test before the first visit" · "Ask new clients for a patch test at least 48 hours ahead" · "Aftercare template" · "Save service"

### 6.4 · Products: Products
- **Imagem**: `design/screenshots/06-04_Products.png`
- **Propósito**: Produtos que a profissional usa e indica (sem estoque financeiro).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `More`, `Services`
- **Vai para**: `More`
- **Estados**: `cat`, `flips`, `name`, `share`, `sheet`
- **Textos**: "More" · "Products" · "What you use and recommend. Pick them in treatment records, and choose what clients see." · "Shared products appear in the client's own view. Private ones only appear in your records." · "New product" · "Name" · "Brand" · "Share with clients" · "Shows in their journey after a visit" · "Add product"

### 6.5 · Availability: Availability
- **Imagem**: `design/screenshots/06-05_Availability.png`
- **Propósito**: Horário de trabalho por dia, pausas, intervalo entre clientes e bloqueios. "Block days" abre `BlockTime`; bloqueios salvos aparecem na lista.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BlockTime`, `More`
- **Vai para**: `BlockTime`, `More`
- **Estados**: `blk`, `brk`, `buf`, `on`
- **Textos**: "More" · "Availability" · "When clients can book you. Changes apply to your booking page right away." · "Working hours" · "Breaks" · "Lunch" · "12:30 to 13:30 · every day" · "Coffee break" · "16:30 to 16:45 · every day" · "Add a break" · "Time between clients" · "Time to reset the room and write your notes before the next person." · "Days off and vacation" · "Day off" · "Monday, October 12" · "Blocked" · "Vacation" · "Dec 22 to Jan 5" · "Block days"

### 6.7 · BookingSettings: Booking page settings
- **Imagem**: `design/screenshots/06-07_BookingSettings.png`
- **Propósito**: Link e página de reserva: aceitar reservas (pausa com data de volta), confirmar novas clientes primeiro, convidadas por reserva (0 a 2), visibilidade de preço, regras e acesso a Cancelamentos e No-show.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `CancelPolicy`, `More`, `NoShowPolicy`, `ShareLink`
- **Vai para**: `Bk-1-Page`, `CancelPolicy`, `More`, `NoShowPolicy`, `ShareLink`
- **Estados**: `acc`, `back`, `cn`, `copied`, `guests`, `modes`
- **Textos**: "More" · "Preview" · "Booking page" · "Your booking link" · "bellohub.app/maria" · "Clients book in their browser. No app, no password." · "Share" · "Whatsapp message" · "Hi Ana!" · "You can book your next appointment directly here:" · "Book with Maria" · "Maria Beauty · Esthetician" · "The link opens a clean booking page. Nothing to download." · "Taking bookings" · "Accepting bookings" · "Back on" · "Clients see this on your page and can message you. Their booked visits are not touched." · "Confirm new clients first" · "You approve each first booking. Returning clients book freely." · "Guests per booking" · "A client can bring a friend or a relative. Visits are back to back and the time adds up." · "Price visibility" · "Booking rules" · "Availability" · "Tue to Sat · 09:00 to 19:00" · "Buffer between clients" · "15 min" · "Minimum notice" · "2 hours" · "Booking window" · "60 days ahead" · "Cancellations and changes" · "No-show protection" · "Profile" · "Business name" · "Maria Beauty" · "Specialties" · "Facials, skin care"

### 6.8 · ShareLink: Share link and QR
- **Imagem**: `design/screenshots/06-08_ShareLink.png`
- **Propósito**: Link e QR code para compartilhar (folha de compartilhar do iOS).
- **Dados**: Servidor (Firebase)
- **Chega de**: `BookingSettings`, `Clients`, `Home`, `Integrations`, `More`
- **Vai para**: `BookingSettings`
- **Estados**: `ar`, `bio`, `copied`, `printed`
- **Textos**: "Booking page" · "Share your link" · "One link for Instagram, WhatsApp and your table." · "bellohub.app/maria" · "Scan to book with Maria" · "Where to put it" · "Instagram bio" · "Book with me: bellohub.app/maria" · "WhatsApp auto-reply" · "Answers new chats with your link" · "Hi! Thanks for your message. You can book with Maria here: bellohub.app/maria"

### 6.9 · QuickReplies: Quick replies
- **Imagem**: `design/screenshots/06-09_QuickReplies.png`
- **Propósito**: Mensagens prontas.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `MessageClient`, `More`, `NoShowPolicy`, `WinBack`
- **Vai para**: `More`
- **Estados**: `saved`, `sel`, `texts`
- **Textos**: "More" · "Quick replies" · "Ready-made messages for WhatsApp. You always review before sending." · "Words in curly braces, like {name}, are filled in for each client." · "Message" · "Preview" · "Close"

### 6.10 · Credentials: Training and credentials
- **Imagem**: `design/screenshots/06-10_Credentials.png`
- **Propósito**: Formação e certificados exibidos na página pública.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Bk-1-Page`, `More`
- **Vai para**: `Bk-1-Page`, `More`
- **Estados**: `addOpen`, `extra`, `f1`, `f2`, `show`
- **Textos**: "More" · "Training and credentials" · "Build trust before a client books. Shown on your booking page if you choose." · "Show on my booking page" · "Your credentials" · "Add credential" · "Registration" · "Professional registration" · "Optional. Council or city registration number." · "See how it looks to clients" · "Name" · "Institution and year" · "Add certificate photo" · "Save credential" · "Cancel"

### 6.11 · Team: Team
- **Imagem**: `design/screenshots/06-11_Team.png`
- **Propósito**: Equipe com várias profissionais. FORA da primeira versão (marcar como "mais tarde").
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `More`
- **Vai para**: `More`
- **Estados**: `added`, `invOpen`, `iv`, `k`, `role`
- **Textos**: "More" · "Team" · "Add professionals and decide what they can see." · "Clients choose who to book" · "Adds a step to your booking page" · "People" · "Invited" · "Invite a professional" · "What professionals can do" · "See client history" · "Records, notes and consent" · "See client photos" · "Private photos" · "Edit services and prices" · "Services and availability" · "You are the owner and always see everything. Each professional has their own calendar and booking times." · "Name" · "Role" · "Send invite on WhatsApp" · "Cancel"

### 6.12 · Tags: Client tags
- **Imagem**: `design/screenshots/06-12_Tags.png`
- **Propósito**: Gerencia tags de clientes.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `More`, `NewClient`, `Onb-6-Tags`
- **Vai para**: `More`
- **Estados**: `addOpen`, `added`, `col`, `edit`, `gone`, `tn`
- **Textos**: "More" · "Client tags" · "Quick labels that help you remember who is who." · "Your tags" · "New tag" · "Name" · "Color" · "Add tag" · "Cancel"

### 6.13 · RecordTemplate: Record fields
- **Imagem**: `design/screenshots/06-13_RecordTemplate.png`
- **Propósito**: Campos da ficha por profissão (editor de modelo).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `AISettings`, `FormTemplates`, `More`
- **Vai para**: `FormTemplates`, `More`
- **Estados**: `addOpen`, `custom`, `kind`, `nf`, `off`, `prof`, `saved`
- **Textos**: "More" · "Record fields" · "What you want to remember about each client. The voice assistant fills these in." · "Treatment record" · "Yours" · "Add your own field" · "Before the first visit" · "Edit client forms" · "Questions and consent text" · "Field name" · "How do you fill it?" · "Add field" · "Cancel"

### 6.14 · FormTemplates: Client forms
- **Imagem**: `design/screenshots/06-14_FormTemplates.png`
- **Propósito**: Modelos de ficha de saúde e consentimento.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `More`, `RecordTemplate`
- **Vai para**: `Cl-4-Intake`, `RecordTemplate`
- **Estados**: `ag`, `ct`, `on`, `saved`
- **Textos**: "Record fields" · "Client forms" · "What clients fill in on their phone before a first visit." · "Health form questions" · "Consent" · "Consent text" · "Clients agree and sign by typing their name." · "Ask again every" · "Preview as client"

### 6.3 · AddOns: Add-ons
- **Imagem**: `design/screenshots/06-03_AddOns.png`
- **Propósito**: Adicionais que a cliente pode marcar ao reservar (nome, minutos extras, preço opcional). Cada um soma tempo ao atendimento. Interruptor por adicional e criação de novos.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Services`
- **Vai para**: `Services`
- **Estados**: `extra`, `mn`, `newOpen`, `nm`, `on`
- **Textos**: "Services" · "Add-ons" · "Extras clients can add when they book. Each one adds time to the visit." · "New add-on" · "Prices follow your price visibility settings. Nothing is charged in the app." · "What clients see" · "On the service step they tick the extras they want. The booking page adds the time and shows the new total before they pick a day." · "Name it your way. It appears for every service." · "Name" · "Extra time" · "Add add-on" · "Cancel"

### 6.16 · CancelPolicy: Cancellations and changes
- **Imagem**: `design/screenshots/06-16_CancelPolicy.png`
- **Propósito**: Regras de cancelamento e troca definidas pela profissional: prazo grátis (2/12/24/48/72 h), cliente remarca sozinha ou não, quantas vezes, o que fazer depois do prazo (cancelar com aviso ou pedir mensagem; pedido de remarcação ou mensagem), lembrete pedindo confirmação, tolerância de atraso (5 a 20 min). Mostra "O que a cliente lê". Alterações valem para reservas novas e existentes.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BookingSettings`, `Cl-8-Reminder`, `NoShowPolicy`
- **Vai para**: `Bk-1-Page`, `BookingSettings`, `Cl-8-Reminder`, `NoShowPolicy`
- **Estados**: `grace`, `key`, `remind`, `resMax`, `selfRes`, `win`
- **Textos**: "Booking page" · "Cancellations and changes" · "Set the rules once. Clients read them before they book." · "Free changes" · "Clients cancel or reschedule on their own up to this long before the visit." · "Rescheduling" · "Clients reschedule themselves" · "Off: they message you to move a visit." · "How many times per visit" · "After the free period" · "The last hours are the hard ones. Choose what clients can do on their own." · "Cancelling" · "No-show protection" · "Moving the visit" · "Reminder" · "Ask clients to confirm" · "See the message" · "What the client receives" · "Late arrivals" · "How long you hold the time when a client is late. They can tell you from their page." · "What clients read" · "See it as a client" · "Also shown before they confirm a booking, and on their personal page." · "Related" · "Changes save automatically and apply to new and existing bookings. A client who books for tomorrow morning is already inside the free per..."

### 6.15 · NoShowPolicy: No-show protection
- **Imagem**: `design/screenshots/06-15_NoShowPolicy.png`
- **Propósito**: Proteção contra falta sem aviso: liga/desliga, limite de faltas (1 a 5), o que acontece ao atingir (só avisar, aprovar novas reservas, pausar reserva online) e se cancelamento tardio conta como falta. Mostra o texto que a cliente lê.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `BookingSettings`, `CancelPolicy`, `NoShowHistory`, `NoShowMark`
- **Vai para**: `BookingSettings`, `CancelPolicy`, `QuickReplies`
- **Estados**: `act`, `late`, `lim`, `on`, `per`, `warn`
- **Textos**: "Booking page" · "No-show protection" · "Teach clients to show up, or to tell you in time." · "Protect my calendar" · "Count missed appointments and act when a client reaches your limit." · "Allowed no-shows" · "Limit" · "Clients reach it after this many." · "What counts" · "Didn't show up" · "No message, no notice." · "Always counts" · "Also counts toward the limit. Your free period is set in" · "Cancellations and changes" · "Counting period" · "Older no-shows stop counting by themselves, so one bad day never follows a client forever." · "When a client reaches the limit" · "Before the limit" · "Friendly note after the 2nd one" · "Opens in your WhatsApp. You read it before sending." · "Edit the note" · "Ready-made messages" · "What clients read" · "Shown on your booking page under the cancellation policy." · "Protection is off. Everyone can book online. Missed appointments are still written on each client's profile, so you can turn this on late..." · "Changes save automatically. Counts stay on your iPhone and in your iCloud. Only your own clients are counted: nothing is shared with othe..."


---

## 07 · Conta e ajustes

### 7.1 · Account: Account
- **Imagem**: `design/screenshots/07-01_Account.png`
- **Propósito**: Perfil da profissional (nome, negócio, link, WhatsApp, e-mail, cidade, profissão), Idioma e região, trocar foto, sair e excluir a conta (com exportação antes).
- **Dados**: Servidor (Firebase)
- **Chega de**: `ExportAll`, `LanguageRegion`, `More`, `RecoveryKey`
- **Vai para**: `LanguageRegion`, `More`, `Onb-2-Profession`, `Privacy`, `SignIn`
- **Estados**: `delOpen`, `k`, `outOpen`, `photoOpen`, `saved`
- **Textos**: "More" · "Account" · "MB" · "Change photo" · "Your name" · "Business name" · "Booking link" · "WhatsApp number" · "Email" · "City" · "Profession" · "Esthetician" · "Language and region" · "Sign out" · "You can sign back in with your phone" · "Delete account" · "Removes your workspace and all client data" · "Take photo" · "Choose from library" · "Remove photo" · "Cancel" · "Sign out of Bello Hub?" · "Your data stays safe. Sign back in with your phone number." · "Delete your account?" · "This permanently removes your workspace, clients, records and photos. Export them first if you need a copy." · "Export my data first" · "Keep my account"

### 7.2 · LanguageRegion: Language and region
- **Imagem**: `design/screenshots/07-02_LanguageRegion.png`
- **Propósito**: Idioma e região do negócio: escolhe a região do negócio entre os presets de `docs/16-MARKETS.md` (o protótipo desenha cinco: pt-BR, pt-PT, es-MX, es-ES, en-US; o app tem 14 localizações, veja `docs/07-LOCALIZATION.md`), mostra o que isso define (moeda, data, hora, início da semana, telefone, canal de mensagens, lei de privacidade), moeda dos preços, prévia das mensagens (confirmação, lembrete, atraso, aniversário) e os idiomas da página de reserva.
- **Dados**: Aparelho + iCloud, com cópia mínima no servidor para o agendamento
- **Chega de**: `Account`
- **Vai para**: `Account`
- **Estados**: `cur`, `kind`, `loc`, `pages`, `saved`
- **Textos**: "Account" · "Language and region" · "How the app, your booking page and your messages to clients read." · "App language and region" · "What this sets" · "Currency for your prices" · "Prices are only shown. Nothing is charged in the app. Clients see your currency written the way their own language writes numbers." · "Messages to your clients" · "Words the app uses" · "Booking page languages"

### 7.3 · Plan: Your plan
- **Imagem**: `design/screenshots/07-03_Plan.png`
- **Propósito**: Assinatura do Bello Hub (StoreKit): teste grátis, o que está incluso, gerenciar e restaurar compras. Separada de qualquer cobrança da profissional às clientes, que o app não faz.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `More`
- **Vai para**: `More`
- **Estados**: `mgr`, `rst`
- **Textos**: "More" · "Your plan" · "This is your Bello Hub subscription. It is separate from anything you charge your clients." · "Bello Hub Pro" · "12 days left" · "Free trial · ends Oct 12" · "What is included" · "Unlimited clients and appointments" · "Voice-AI treatment records" · "Online booking page and QR" · "Follow-ups, waitlist and check-ins" · "Private photos and consent forms" · "Manage subscription" · "Restore purchases"

### 7.4 · NotificationSettings: Notification settings
- **Imagem**: `design/screenshots/07-04_NotificationSettings.png`
- **Propósito**: Alertas para a profissional (reservas, cancelamentos, check-ins, follow-ups, aniversários), horário de silêncio (alertas urgentes passam: atraso de cliente e cancelamento no mesmo dia), resumo diário e lembretes às clientes.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `More`, `Notifications`
- **Vai para**: `More`, `Privacy`
- **Estados**: `k`, `qf`, `qu`, `rm`, `tm`
- **Textos**: "More" · "Notifications" · "Choose what reaches you, and what reaches your clients." · "For you" · "New bookings" · "When someone books with you" · "Cancellations" · "And a freed time for the waitlist" · "Client check-ins" · "When a client answers how they feel" · "Follow-ups due" · "Clients ready to hear from you" · "Client birthdays" · "A nudge the day before, to send your wishes" · "Quiet hours" · "Silence alerts at night and on days off" · "From" · "Until" · "Urgent alerts still come through: a client running late and same-day cancellations. Everything else waits until the morning." · "Daily summary" · "Your day at a glance" · "For your clients" · "Reminders sent to clients" · "By WhatsApp, before each appointment" · "Names can be hidden on the lock screen in Privacy and security." · "Open Privacy and security"

### 7.5 · AISettings: AI assistant
- **Imagem**: `design/screenshots/07-05_AISettings.png`
- **Propósito**: IA no aparelho (D23): onde roda (sempre neste iPhone), estado (pronta, indisponível, idioma não suportado), ajuda na nuvem (desativada: "Not available yet"), revisão sempre obrigatória (ligada e travada), apagar gravações, idioma da voz, campos da ficha.
- **Dados**: Só no aparelho
- **Chega de**: `More`
- **Vai para**: `More`, `RecordTemplate`
- **Estados**: `k`, `lg`
- **Textos**: "More" · "AI assistant" · "It turns your voice into an organized record. You stay in charge." · "Where it runs" · "On this iPhone" · "Your voice and notes are organized on the device. Nothing is sent to a server." · "Ready" · "Cloud help for older iPhones" · "Only if this iPhone cannot do it itself. Asks the client first and keeps nothing." · "How it works" · "What it does" · "Organizes what you said into your record fields" · "Suggests the products and steps you mentioned" · "Drafts a follow-up when you ask" · "What it never does" · "Invent reactions, products or results" · "Save anything before you review it" · "Share a record with anyone" · "Settings" · "Review before saving" · "Always check the draft first" · "Delete recordings after organizing" · "Audio is removed once the text is ready" · "Voice language" · "Record fields" · "Choose what the assistant fills in"

### 7.6 · Integrations: Integrations
- **Imagem**: `design/screenshots/07-06_Integrations.png`
- **Propósito**: Google Calendar, Apple Calendar (sincronização nos dois sentidos), WhatsApp (envio pelo número dela), link na bio do Instagram e importação de contatos.
- **Dados**: Só no aparelho
- **Chega de**: `More`
- **Vai para**: `ImportClients`, `More`, `ShareLink`
- **Estados**: `c`
- **Textos**: "More" · "Integrations" · "Connect the tools you already use." · "Connected apps" · "Google Calendar" · "Show appointments in your calendar" · "Apple Calendar" · "Two-way sync with iCloud" · "WhatsApp" · "Send messages from your number" · "Instagram bio link" · "Add your booking link" · "Import contacts" · "From your phone or a spreadsheet"

### 7.7 · Privacy: Privacy and security
- **Imagem**: `design/screenshots/07-07_Privacy.png`
- **Propósito**: Privacidade e segurança: onde os dados vivem (neste iPhone, no iCloud, nos servidores), chave de recuperação, Face ID e prazo de bloqueio, fotos só dentro do app, notificações sem nome, exportar tudo, exportar e excluir os dados de uma cliente, retenção.
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Account`, `ClientEdit`, `ExportAll`, `More`, `NotificationSettings`, `RecoveryKey`
- **Vai para**: `ExportAll`, `ExportRecord`, `More`, `RecoveryKey`
- **Estados**: `delOpen`, `dl`, `fid`, `hid`, `lk`, `pho`, `vs`
- **Textos**: "More" · "Privacy and security" · "Client data is sensitive. These settings keep it yours." · "Where your data lives" · "On this iPhone" · "Records, notes, photos and recordings, locked with Face ID" · "In your iCloud" · "A private copy, sealed so only you can read it" · "On Bello Hub servers" · "Only bookings: name, phone, day and time. Health answers arrive sealed and are deleted once your iPhone has them" · "Recovery key" · "Lock" · "Face ID lock" · "Ask for Face ID when you open the app" · "Lock after" · "Photos" · "Keep photos only in Bello" · "Never saved to your camera roll" · "New photos are" · "Notifications" · "Hide names on the lock screen" · "Notifications say "A client" instead of a name" · "Client data" · "Export all my data" · "Export a client's data" · "Delete a client's data" · "How long records are kept" · "Until you or the client asks to delete" · "Clients can ask for a copy or deletion of their data at any time. You decide who is on their record." · "This removes their record, photos and notes. It can't be undone. Export first if you need a copy." · "Cancel"

### 7.10 · Help: Help and support
- **Imagem**: `design/screenshots/07-10_Help.png`
- **Propósito**: Ajuda e contato com o suporte.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `More`
- **Vai para**: `More`
- **Estados**: `chat`, `fb`, `fbOpen`, `open`, `sent`
- **Textos**: "More" · "Help and support" · "Quick answers, or talk to a person." · "Common questions" · "Need a person?" · "Chat with support" · "Send feedback" · "Tell us what would help" · "What would help?" · "Close"

### 7.11 · States: System states
- **Imagem**: `design/screenshots/07-11_States.png`
- **Propósito**: Estados do sistema: sem rede, erro, carregando, sem microfone, conflito de horário, vazio, sessão expirada, teste encerrado, confirmar exclusão.
- **Dados**: Sem dados próprios (interface do sistema ou de navegação)
- **Chega de**: `More`
- **Vai para**: `More`
- **Textos**: "More" · "System states" · "How the app behaves when something is missing, slow or wrong. Reference for building." · "Offline" · "You are offline" · "Changes are saved on this phone and will sync when you are back online." · "Syncing and synced" · "All changes saved" · "Last synced just now." · "Error toast" · "Could not save" · "Check your connection and try again." · "Retry" · "Loading" · "Microphone is off" · "Microphone access is off" · "Turn it on in Settings to record by voice, or write the record yourself." · "Settings" · "Voice not understood" · "We could not hear that" · "Try again closer to the microphone, or write it yourself." · "Time conflict" · "This time overlaps" · "Camila Rocha is booked at 11:30. Pick another time or keep both." · "Empty calendar day" · "Nothing booked today" · "Share your link, or add an appointment yourself." · "No photos yet" · "No photos for this client" · "Take the first before photo during the next treatment." · "Plan ended" · "Your trial has ended" · "Your clients and records are safe. Online booking is paused until you choose a plan. Your clients see: Maria is not taking bookings right..." · "Plans" · "Session expired" · "Please sign in again" · "For your security, the session ended." · "Sign in" · "Confirm before deleting" · "Delete this photo?" · "It will be removed from Ana's record. This can't be undone." · "Cancel" · "Delete"

### 7.8 · ExportAll: Export all my data
- **Imagem**: `design/screenshots/07-08_ExportAll.png`
- **Propósito**: Exportar todos os dados: gerado no iPhone (D18), CSV e PDFs num ZIP, fotos opcionais, entregue pela folha de compartilhar ou Arquivos. A entrega "link por e-mail, 7 dias" do protótipo NÃO é construída (copiar ajustado em `PROGRESS.md`).
- **Dados**: Aparelho + iCloud da profissional
- **Chega de**: `Privacy`
- **Vai para**: `Account`, `Privacy`
- **Estados**: `done`, `fm`, `on`
- **Textos**: "Privacy and security" · "Export all my data" · "Everything in your Bello Hub account, to keep or move elsewhere." · "Include" · "Format" · "Delivery" · "Download link by email" · "maria@example.com" · "The link opens only after you sign in and stops working after 7 days. Your clients' data stays private to you." · "Prepare my export" · "We are preparing it." · "Back to privacy" · "Open Account"

### 7.9 · RecoveryKey: Recovery key
- **Imagem**: `design/screenshots/07-09_RecoveryKey.png`
- **Propósito**: Chave de recuperação de 12 palavras: mostrada só depois do Face ID, salvar em Arquivos ou imprimir, confirmar que guardou. O Bello Hub nunca vê essa chave. As palavras na tela do protótipo são de exemplo. Ver `docs/06-PRIVACY-SECURITY.md` §4.
- **Dados**: Só no aparelho
- **Chega de**: `Privacy`
- **Vai para**: `Account`, `Privacy`
- **Estados**: `done`, `ok`, `show`
- **Textos**: "Privacy and security" · "Recovery key" · "Your clients' records are sealed so only you can read them. This key is the way back in if you lose your iPhone and your iCloud Keychain." · "Your 12 words" · "The words shown here are an example for the prototype. Your real key is shown after Face ID." · "Save to Files" · "A text file only you can open" · "Print it" · "Keep the paper somewhere safe" · "I saved it somewhere safe" · "Not in a screenshot or a message" · "Why it matters" · "Bello Hub never sees this key and cannot recover it for you. Without it, records sealed for you stay sealed. Keep it away from your iPhone." · "I saved my key" · "Your key is saved." · "If you ever open Bello Hub on a new iPhone and iCloud cannot restore your records, enter these 12 words. You can see them again in Privac..." · "Back to privacy" · "Open Account"


---

## 08 · Página de agendamento da cliente (web)

### 8.1 · Bk-1-Page: 01 Public booking page
- **Imagem**: `design/screenshots/08-01_Bk-1-Page.png`
- **Propósito**: Página pública: perfil, serviços, regras de cancelamento (lidas da profissional), "Já reservei? Encontre meu agendamento". Quando a reserva está pausada mostra aviso e troca o botão por mensagem à profissional.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-10-Review`, `Bk-11-Find`, `Bk-2-Service`, `BookingSettings`, `CancelPolicy`, `Credentials`
- **Vai para**: `Bk-11-Find`, `Bk-2-Service`, `Credentials`
- **Estados**: `lang`, `langOpen`, `wa`
- **Textos**: "MB" · "Maria Beauty" · "Glow Facial" · "60 min" · "Brazilian Glow" · "90 min" · "Deep Cleansing" · "75 min" · "Protocol 360" · "120 min"

### 8.2 · Bk-2-Service: 02 Select service
- **Imagem**: `design/screenshots/08-02_Bk-2-Service.png`
- **Propósito**: Escolha do serviço e dos adicionais. A barra inferior mostra o nome, o tempo total e o preço somado.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-1-Page`, `Bk-3-Professional`, `Bk-4-DateTime`
- **Vai para**: `Bk-1-Page`
- **Estados**: `ao`, `sel`
- **Variantes**: `multiPro`
- **Textos**: "Choose a service" · "with Maria Beauty" · "Add to your visit" · "Optional extras. They add time." · "Continue"

### 8.3 · Bk-3-Professional: 03 Choose professional (teams only)
- **Imagem**: `design/screenshots/08-03_Bk-3-Professional.png`
- **Propósito**: Escolha da profissional (só quando há equipe).
- **Dados**: Servidor (Firebase)
- **Chega de**: (ponto de entrada)
- **Vai para**: `Bk-2-Service`, `Bk-4-DateTime`
- **Estados**: `sel`
- **Textos**: "Who would you like to see?" · "Brazilian Glow · 90 min" · "Continue"

### 8.4 · Bk-4-DateTime: 04 Date and time
- **Imagem**: `design/screenshots/08-04_Bk-4-DateTime.png`
- **Propósito**: Calendário e horários livres; entrar na lista de espera quando não há horário.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-3-Professional`, `Bk-5-Info`
- **Vai para**: `Bk-2-Service`, `Bk-5-Info`
- **Estados**: `day`, `m`, `time`, `wait`
- **Textos**: "Pick a day and time" · "Brazilian Glow · 90 min · Maria Beauty" · "S" · "M" · "T" · "W" · "F" · "Times shown in São Paulo time." · "Continue"

### 8.5 · Bk-5-Info: 05 Your details
- **Imagem**: `design/screenshots/08-05_Bk-5-Info.png`
- **Propósito**: Nome, WhatsApp, e-mail. "Vem com alguém?" (se a profissional permitir) soma o tempo de convidadas, e "Good to know" mostra as regras.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-4-DateTime`, `Bk-6-Verify`
- **Vai para**: `Bk-4-DateTime`, `Bk-6-Verify`
- **Estados**: `gname`, `guests`
- **Textos**: "Almost there." · "Thursday, Oct 1 at 15:00. Tell Maria who is coming." · "Name" · "WhatsApp" · "Email" · "· optional" · "No password and no account. We send a quick code to confirm it's you." · "Coming with someone?" · "Maria can see you both back to back." · "Guest name" · "Good to know" · "Your personal link." · "We send it to your WhatsApp right after you book. Use it any time to cancel or reschedule. No app or password." · "Please tell Maria if you cannot come." · "Send verification code"

### 8.6 · Bk-6-Verify: 06 Verification
- **Imagem**: `design/screenshots/08-06_Bk-6-Verify.png`
- **Propósito**: Verificação do telefone por código de 6 dígitos: SMS (padrão no v1) ou e-mail; WhatsApp só quando `whatsAppAutomation` estiver ligado (D31).
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-10-Review`, `Bk-5-Info`, `Bk-7-Questions`
- **Vai para**: `Bk-5-Info`
- **Estados**: `via`
- **Textos**: "Enter your code" · "Verification code" · "Resend in 0:24" · "Use SMS" · "Use email" · "Verify"

### 8.7 · Bk-7-Questions: 07 First-time questions
- **Imagem**: `design/screenshots/08-07_Bk-7-Questions.png`
- **Propósito**: Perguntas da primeira visita (ficha rápida).
- **Dados**: Servidor (Firebase)
- **Chega de**: (ponto de entrada)
- **Vai para**: `Bk-6-Verify`, `Bk-8-Confirmed`
- **Estados**: `seen`, `sel`
- **Textos**: "Tell Maria a little about you." · "Optional. It helps your first Brazilian Glow feel made for you." · "What would you like to achieve?" · "Have you had this treatment before?" · "Any preferences your professional should know?" · "Confirm appointment" · "Skip for now"

### 8.8 · Bk-8-Confirmed: 08 Booking confirmed
- **Imagem**: `design/screenshots/08-08_Bk-8-Confirmed.png`
- **Propósito**: Confirmação com serviço, adicionais, convidadas, horário final, link pessoal (copiar), adicionar ao calendário, ficha de saúde. O texto do canal depende de D31: sem WhatsApp automático diz "Save your link", com ele diz "A confirmation is on its way to your WhatsApp".
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-7-Questions`, `Bk-9-Appointment`
- **Vai para**: `Bk-9-Appointment`, `Cl-4-Intake`
- **Estados**: `cal`
- **Textos**: "You're booked." · "A confirmation is on its way to your WhatsApp." · "Thursday · October 1" · "MB" · "Maria Beauty" · "São Paulo" · "View appointment" · "Complete your health form" · "One minute, before your first visit. Only Maria sees it." · "Need to change plans? Use your link." · "Your Brazilian Glow with Maria is confirmed for Thursday, Oct 1 at 15:00." · "Change or cancel: bellohub.app/m/7Hq2xk" · "Optional. A faster experience next time." · "Get Bello Hub"

### 8.9 · Bk-9-Appointment: 09 View appointment
- **Imagem**: `design/screenshots/08-09_Bk-9-Appointment.png`
- **Propósito**: Página de gestão do agendamento (link pessoal): confirmar presença, avisar atraso, remarcar e cancelar conforme as regras, ver as regras da profissional, mensagem no WhatsApp.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-11-Find`, `Bk-8-Confirmed`, `Cl-6-Cancel`, `Cl-8-Reminder`, `Cl-9-Reschedule`
- **Vai para**: `Bk-8-Confirmed`, `Cl-3-Rebook`, `Cl-6-Cancel`, `Cl-9-Reschedule`
- **Estados**: `attend`, `cal`, `late`, `wa`
- **Textos**: "Back" · "Your appointment" · "Moved from Thursday · October 1 at 15:00" · "Yes, I will be there" · "I cannot make it" · "Reschedule" · "Cancel appointment" · "This appointment was cancelled." · "Maria has been told. You can book another time whenever you like." · "Book another time" · "Maria's rules" · "MB" · "Questions for Maria?" · "Booking by Bello Hub"

### 8.10 · Bk-10-Review: 10 Booking needs Maria
- **Imagem**: `design/screenshots/08-10_Bk-10-Review.png`
- **Propósito**: Página da cliente quando a reserva precisa da aprovação da profissional ("Maria will confirm this one") ou quando a reserva online está pausada para ela. Texto muda conforme o motivo.
- **Dados**: Servidor (Firebase)
- **Chega de**: (ponto de entrada)
- **Vai para**: `Bk-1-Page`, `Bk-6-Verify`
- **Estados**: `sent`, `wa`, `why`
- **Textos**: "Back" · "MB" · "Maria Beauty" · "Maria will confirm this one." · "Your request" · "Brazilian Glow · 90 min" · "Thursday, Oct 15 · 10:00 to 11:30" · "Add a note for Maria (optional)" · "Send request" · "Request sent." · "Maria will answer on WhatsApp, usually within a few hours. Nothing is booked until she confirms. When she does, your personal link arrive..." · "Back to Maria's page" · "Online booking is paused for now." · "Maria likes to talk before your next visit. Send her a message and you will be back on her calendar quickly." · "Why am I seeing this?" · "This only applies to Maria. It does not follow you to other professionals. If you think it is a mistake, tell her and she can open online..."

### 8.11 · Bk-11-Find: 11 Find your appointment
- **Imagem**: `design/screenshots/08-11_Bk-11-Find.png`
- **Propósito**: "Já reservei": a cliente informa o telefone, recebe um código e vê seus agendamentos para abrir o link de gestão. Alternativa para quem perdeu a mensagem.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-1-Page`
- **Vai para**: `Bk-1-Page`, `Bk-9-Appointment`
- **Estados**: `again`, `step`
- **Textos**: "Maria's page" · "Find your appointment" · "Enter the WhatsApp number you booked with. We send a code, so only you can open it." · "WhatsApp" · "No account and no password. Your link is also in the WhatsApp message from your booking." · "Send code" · "Enter your code" · "We sent a 6-digit code to +55 11 98765 4321." · "Code" · "Find my appointment" · "Here it is." · "1 upcoming appointment with Maria." · "Brazilian Glow" · "with Maria Beauty · 90 min" · "Confirm, reschedule or cancel" · "We also sent your link to WhatsApp again. Keep that message: it is your door back in." · "Not the appointment you expected? Check you used the same number as when you booked, or message Maria." · "Back to Maria's page"


---

## 09 · Portal da cliente (web)

### 9.1 · Cl-1-Reminder: 01 Reminder on WhatsApp
- **Imagem**: `design/screenshots/09-01_Cl-1-Reminder.png`
- **Propósito**: Como a cliente vê o lembrete de retorno no WhatsApp.
- **Dados**: Servidor (Firebase)
- **Chega de**: `FollowUps`, `Tx-7-NextSession`
- **Vai para**: `Cl-3-Rebook`, `Tx-7-NextSession`
- **Textos**: "MB" · "Maria Beauty" · "Business" · "Wednesday, October 21" · "Hi Ana!" · "It's time for your next Brazilian Glow." · "bellohub.app/maria" · "Book with Maria" · "Choose a time for your next Brazilian Glow. No app or password needed." · "Choose a time" · "Message"

### 9.2 · Cl-2-Portal: 02 Client portal
- **Imagem**: `design/screenshots/09-02_Cl-2-Portal.png`
- **Propósito**: Portal da cliente: próximos agendamentos e cuidados pós-atendimento.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Cl-3-Rebook`, `Cl-4-Intake`, `Cl-5-CheckIn`, `Cl-7-MyData`
- **Vai para**: `Cl-3-Rebook`
- **Estados**: `tab`
- **Textos**: "MB" · "Maria Beauty" · "AC" · "Hi Ana." · "Everything about your visits with Maria, in one place." · "Next session" · "Brazilian Glow" · "Recommended around Wednesday, October 28" · "Book again" · "Past appointments" · "September 30" · "Completed" · "Glow Facial" · "August 30" · "Shared by maria" · "Your skin responded well. Keep products gentle and fragrance-free." · "Good response. Next visit recommended in about 4 weeks." · "You only see what Maria chooses to share with you." · "After your Brazilian Glow · Sep 30" · "Use only a gentle, fragrance-free cleanser tonight." · "Wear sunscreen in the morning." · "Message Maria if anything feels uncomfortable." · "Products maria shared" · "Calming serum" · "Used in your treatment"

### 9.3 · Cl-3-Rebook: 03 Book again
- **Imagem**: `design/screenshots/09-03_Cl-3-Rebook.png`
- **Propósito**: Reagendar o mesmo serviço.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-9-Appointment`, `Cl-1-Reminder`, `Cl-2-Portal`, `Cl-6-Cancel`
- **Vai para**: `Cl-2-Portal`, `Home`
- **Estados**: `day`, `done`, `time`, `wa`
- **Textos**: "My journey" · "Welcome back, Ana." · "Your details are saved. Just choose a time." · "MB" · "Brazilian Glow" · "with Maria Beauty · 90 min · R$120" · "Choose a day" · "Best" · "BEST is Maria's recommended return date." · "Choose a time" · "with Maria Beauty · 90 min" · "View my journey" · "See it on Maria's side"

### 9.4 · Cl-4-Intake: 04 Health form
- **Imagem**: `design/screenshots/09-04_Cl-4-Intake.png`
- **Propósito**: Ficha de saúde da cliente (menor de 18 inclusive) com consentimento: preenchida no navegador e **selada** com a chave pública da profissional antes de sair (D21). Texto de sucesso exato em `docs/06` §3.5.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-8-Confirmed`, `ClientHealth`, `FormTemplates`
- **Vai para**: `Cl-2-Portal`
- **Estados**: `al`, `consent`, `done`, `kid`, `minor`, `name`, `yn`
- **Textos**: "MB" · "Maria Beauty" · "A few questions before your visit." · "Takes about a minute. Your answers are sealed on your phone before they are sent, so only Maria can read them." · "Any allergies?" · "No" · "Yes" · "Anything else Maria should know?" · "Optional. Skin that reacts easily, products you avoid, a recent procedure." · "Is this visit for someone under 18?" · "A parent or guardian gives the consent below and comes to the visit." · "Consent" · "I agree" · "Submit to Maria" · "Thank you." · "Your answers were sealed and sent. Only Maria can read them, and your consent is saved with them. You will not be asked again for 12 months." · "Back to my appointment"

### 9.5 · Cl-5-CheckIn: 05 Skin check-in
- **Imagem**: `design/screenshots/09-05_Cl-5-CheckIn.png`
- **Propósito**: Check-in da pele depois do atendimento (um toque), nota e foto opcionais, **seladas** no navegador (D21).
- **Dados**: Servidor (Firebase)
- **Chega de**: (ponto de entrada)
- **Vai para**: `Cl-2-Portal`
- **Estados**: `done`, `nt`, `photo`, `sel`
- **Textos**: "MB" · "Maria Beauty" · "How is your skin today?" · "Hi Ana, a quick check-in after your Brazilian Glow. One tap is enough." · "Maria will get in touch with you today. If it feels severe or keeps getting worse, please contact a doctor." · "Anything to add?" · "Send to Maria" · "Thank you, Ana." · "Back to my appointments"

### 9.6 · Cl-6-Cancel: 06 Cancel or change
- **Imagem**: `design/screenshots/09-06_Cl-6-Cancel.png`
- **Propósito**: Cancelar ou trocar o horário, com política e motivo.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-9-Appointment`
- **Vai para**: `Bk-9-Appointment`, `Cl-3-Rebook`, `Cl-9-Reschedule`
- **Estados**: `done`, `r`, `wa`
- **Textos**: "MB" · "Maria Beauty" · "Brazilian Glow" · "90 min" · "Why are you cancelling?" · "Optional. It helps Maria offer you a better time." · "Message Maria to reschedule" · "Book another time"

### 9.7 · Cl-7-MyData: 07 Your information
- **Imagem**: `design/screenshots/09-07_Cl-7-MyData.png`
- **Propósito**: A cliente vê o que a profissional guarda e pede cópia ou exclusão. O pedido vai como envelope selado (`datarequest`, `docs/06` §3.4). A data "Signed …" vem do sinal operacional do servidor, sem conteúdo.
- **Dados**: Servidor (Firebase)
- **Chega de**: (ponto de entrada)
- **Vai para**: `Cl-2-Portal`
- **Estados**: `copied`, `delOpen`, `pf`
- **Textos**: "MB" · "Maria Beauty" · "Your information" · "This is what Maria keeps about you, and only she can see it." · "What Maria keeps" · "Contact details" · "Name, WhatsApp and email" · "Health form and consent" · "Signed Sep 12 · sealed, only Maria can open it" · "Treatment records" · "What Maria did and used" · "Photos" · "Private to Maria" · "Your choices" · "Photos in Maria's portfolio" · "Off. Maria asks you before using any photo." · "Ask Maria to delete your data?" · "Maria is notified and removes your records and photos. You will no longer be able to see your history." · "Send request" · "Cancel"

### 9.8 · Cl-8-Reminder: 8 Appointment reminder
- **Imagem**: `design/screenshots/09-08_Cl-8-Reminder.png`
- **Propósito**: Mensagem de lembrete que a cliente recebe no WhatsApp com o link pessoal. Mostra a data e o prazo grátis.
- **Dados**: Servidor (Firebase)
- **Chega de**: `CancelPolicy`
- **Vai para**: `Bk-9-Appointment`, `CancelPolicy`
- **Textos**: "MB" · "Maria Beauty" · "Business" · "Hi Helena!" · "A reminder of your Brazilian Glow with Maria: Thursday, Oct 1 at 15:00." · "bellohub.app/m/7Hq2xk" · "Your appointment" · "Confirm, reschedule or cancel. No app or password needed." · "Open my appointment" · "Same link as your confirmation. It works until the visit is over." · "Message"

### 9.9 · Cl-9-Reschedule: 9 Reschedule
- **Imagem**: `design/screenshots/09-09_Cl-9-Reschedule.png`
- **Propósito**: A cliente escolhe novo dia e horário. Modo conforme as regras: remarca sozinha, envia pedido ou fala por mensagem. Horários ocupados riscados.
- **Dados**: Servidor (Firebase)
- **Chega de**: `Bk-9-Appointment`, `Cl-6-Cancel`
- **Vai para**: `Bk-9-Appointment`
- **Estados**: `day`, `done`, `time`, `wa`
- **Textos**: "Your appointment" · "Your current time" · "Choose a day" · "Choose a time" · "Crossed-out times are taken." · "Add a note for Maria (optional)" · "Rescheduling goes through Maria." · "Back to my appointment"

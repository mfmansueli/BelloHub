# Task: simpler routine for the independent professional (12 improvements)

Queued by the owner on 2026-10-11, after v1 (`v1.0.0-rc2`, head `3a2a261`). Branch: `build/v1`. Goal: fewer initial
decisions, clearer actions, continuity between the steps of a visit. Keep every existing function and the approved
visual identity (graphite and orange palette of PR #1, the official icon). Descriptions in older docs may be out of date:
the code and the latest decisions (D40 to D58) win. This file is the owner's text, kept verbatim in Portuguese.

Split of work (two agents, disjoint areas; the coordinator merges):
- **Agent A (main checkout, `build/v1`):** items 1, 2, 3, 4, 5, 6, 7, 8, 12 (language and logo first, then onboarding and
  Home, then visit closing, follow-up queue, WhatsApp states, manual record and return suggestions).
- **Agent B (own worktree, branch `routine-b`):** items 9, 10, 11 and the marketing phrases.

## Texto do dono

Analise o estado atual do Bello Hub e implemente as melhorias abaixo, preservando as funções existentes e a identidade
visual aprovada.

Trabalhe na branch atual que contém o app completo. Consulte o código e as decisões mais recentes, pois algumas descrições
antigas podem estar desatualizadas.

O objetivo é tornar a rotina da profissional autônoma mais simples, com menos decisões iniciais, ações mais claras e
continuidade entre as etapas do atendimento.

### 1. Corrigir o idioma aplicado parcialmente

Ao selecionar português, várias partes do app continuam em inglês.

Audite telas, menus, alertas, modais, formulários, placeholders, mensagens de erro e textos gerados pelo app. Identifique a
causa: textos fixos, traduções ausentes, fallback incorreto, textos resolvidos antes da troca ou componentes que não
recebem o idioma escolhido.

Aplique o idioma consistentemente, incluindo telas já abertas, bloqueio/desbloqueio e reabertura do app. Diferencie
português do Brasil e de Portugal conforme as opções existentes.

Preserve nomes e conteúdos escritos pela profissional. Não confunda idioma da interface com país, fuso horário ou idioma
de voz. Corrija a causa estrutural para beneficiar os demais idiomas também.

### 2. Corrigir o logo da tela de segurança com Face ID

Na tela de bloqueio/desbloqueio do próprio app aparece uma marca diferente do logo oficial do Bello Hub.

Localize essa tela e reutilize o asset oficial ou a composição correta do ícone atual. Confira o código e os assets para
distinguir a versão oficial de marcas provisórias ou antigas.

Não redesenhe o logo. Se necessário, derive uma versão adequada para exibição dentro do app, preservando geometria, cores
e proporções. Ajuste tamanho e contraste nos modos claro e escuro.

Preserve o funcionamento da autenticação e do bloqueio. A alteração é na tela do app, não no diálogo de Face ID do sistema.

### 3. Onboarding mais curto

Concentre a configuração inicial em nome, profissão e primeiro serviço, aproveitando padrões úteis por profissão.

Adie tags, terminologia e personalização detalhada da ficha, mantendo essas opções facilmente acessíveis depois.

Solicite câmera, microfone e contatos no momento de usar a função correspondente. Peça notificações quando seu benefício
estiver claro. Preserve progresso e escolhas realizadas.

### 4. Home mais objetiva

Priorize próximo atendimento, pendências de hoje e agenda do dia.

Deixe "Novo agendamento" fácil de encontrar sem percorrer todos os cards. Resuma acompanhamentos, retornos e recuperação
de clientes em uma área secundária acionável.

Reduza indicadores e atalhos repetidos, preservando o acesso às funções. Adapte a hierarquia para dias vazios e cheios.

### 5. Fila de acompanhamento organizada

Unifique a apresentação de lembretes, acompanhamento pós-atendimento, retornos e clientes que não voltaram.

Mostre motivo, prazo e próxima ação. Quando a mesma cliente tiver várias pendências, agrupe-as sem perder informações.
Preserve filtros e permita adiar ou dispensar sugestões quando fizer sentido.

Mantenha solicitações de agendamento claramente identificadas, pois exigem decisões diferentes dos acompanhamentos.

### 6. Estados claros no WhatsApp

Diferencie "Pronto para enviar" e "Conversa aberta". Abrir o WhatsApp não comprova envio ou entrega.

Se houver confirmação manual de envio, deixe explícito que foi informada pela profissional. Preserve o envio manual
existente.

### 7. Fechamento rápido do atendimento

Conecte melhor as funções existentes em um caminho contínuo:

Registrar → adicionar fotos opcionais → preparar orientações → marcar retorno opcional.

Permita pular etapas opcionais e retomar depois, sem perder dados nem duplicar registros. Respeite o bloqueio do registro
e o histórico de correções.

### 8. Registro manual mais ágil e disponibilidade real de IA

A versão analisada usa UnavailableVoiceCapture e UnavailableRecordStructuring. Confira se isso continua atual.

Torne o formulário manual rápido, com padrões úteis e poucos campos indispensáveis. Ajuste a apresentação de voz e IA à
disponibilidade real.

Preserve os pontos de integração existentes; a implementação de uma nova infraestrutura de IA fica fora desta tarefa.

### 9. Importação e limite gratuito transparentes

Antes de confirmar uma importação, mostre quantas novas clientes serão cadastradas, quantas inscrições gratuitas restam e
se será necessária assinatura.

Permita selecionar um pequeno grupo para testar.

Preserve as dez inscrições gratuitas cumulativas, a deduplicação, os preços e o acesso aos dados existentes.

### 10. Configuração da agenda mais compreensível

Preserve a lógica atual de preparação, limpeza, tempo de processamento e redução de buracos.

Organize opções avançadas de forma progressiva, ofereça padrões por profissão e uma prévia visual dos horários que a
cliente verá.

Explique as configurações com exemplos da rotina profissional.

### 11. Referência de enquadramento para fotos

Avalie uma referência opcional baseada na foto anterior, com sobreposição ajustável e orientações simples de posição e
distância.

Preserve consentimentos, comparação antes/depois e armazenamento privado. Se exigir uma mudança grande na câmera,
documente como etapa posterior.

### 12. Sugestões de retorno com contexto

Explique por que cada sugestão aparece. Exemplo: "O intervalo habitual deste serviço passou e não há retorno marcado."

Use dados existentes e regras transparentes, sem inferência clínica ou promessa de resultado. A profissional decide se
deve entrar em contato.

### Frase aprovada para marketing futuro

"Você não está mais sozinha. Bello Hub, com você em cada etapa."

Variante contextual:
"Você não está mais sozinha. Bello Hub está com você em cada atendimento."

Registre essas frases na documentação de marketing. Use-as em contextos adequados, sem acrescentar uma etapa ao
onboarding ou prometer recursos indisponíveis.

### Execução e validação

Antes de editar, mapeie o que já existe e apresente brevemente a organização final proposta. Depois implemente por etapas:

1. Correções de idioma e logo.
2. Onboarding e Home.
3. Fechamento do atendimento e acompanhamentos.
4. Demais refinamentos.

Use os componentes, tokens e padrões existentes. Preserve privacidade, acessibilidade e traduções.

Verifique estados vazios, offline, erros, Dynamic Type, VoiceOver, modos claro/escuro e persistência do idioma escolhido.
Execute os testes relevantes para os fluxos alterados.

Informe o que depende de validação em iPhone real, especialmente Face ID, agendamento dentro do WhatsApp, sincronização,
recuperação e assinatura. Diferencie testes com mocks de integrações verificadas em produção.

Ao final, entregue um resumo das mudanças, verificações executadas e pendências reais.

## What each agent must hand back

1. A short map of what exists and the final organization proposed (`docs/agent-notes/routine-<a|b>.md`, section "Map and
   proposal", written and committed BEFORE the first code change).
2. Per stage: code, tests, strings in all 14 localizations (new batch files, S11 per-language style), `DESIGN.md`
   updates, commits pushed.
3. A final report: what changed, checks run, what needs a real iPhone (Face ID, scheduling inside WhatsApp, sync,
   recovery, subscription), and what was verified only with mocks versus in production.

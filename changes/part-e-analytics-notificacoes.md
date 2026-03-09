# PART E — Mudanças: Analytics e Notificações
**Status:** Feature nova — nada implementado além do `profiles.timezone`
**Referência:** `docs/overview.md` (Notifications: TBD) · `docs/chat.md` (push: open question) · `docs/journey.md` (reminder: future) · Auro Developer Handoff v1.0 Part E

> Analytics e notificações são **completamente ausentes** da arquitetura atual. Este documento especifica o sistema completo do zero: schema de suporte, mapa de eventos, copy exato de notificações e regras de frequência.

---

## Estado Atual vs Novo

| O que existia | O que entra na Part E |
|--------------|----------------------|
| `profiles.timezone` — campo IANA | Sistema completo de push notifications |
| Sem push token storage | Tabelas: `push_tokens`, `notification_preferences` |
| Sem provider de analytics | Provider definido: PostHog (ou Mixpanel) |
| Sem evento instrumentado | 40+ eventos mapeados com propriedades exatas |
| "Notifications: TBD" no overview | Copy exato de cada notificação + deep links |
| "Push notification strategy: open question" | Regras de frequência, horas silenciosas, opt-out granular |

---

## REGRA DE PRIVACIDADE — Não Negociável

> **Nunca registrar o CONTEÚDO do input do usuário em eventos de analytics.**

| ✅ Registrar | ❌ Nunca registrar |
|-------------|------------------|
| `word_count: 142` | Texto da entrada do diário |
| `checkin_type: "advanced"` | Respostas do check-in |
| `ritual_track: "emotional"` | Prática ou reflexão do ritual |
| `message_count: 7` | Conteúdo de mensagens de chat |
| `attachment_style_result: "secure"` | Respostas individuais do questionário |

---

## SEÇÃO 1 — Provider de Analytics

### Escolha do Provider

| Provider | Prós | Contras | Recomendação |
|----------|------|---------|-------------|
| **PostHog** | Open-source, auto-hostável, feature flags nativo, session recording, cohorts, barato | UI menos polida | ✅ Recomendado principal |
| **Mixpanel** | Mais maduro, funnels excelentes, melhor para mobile | Pricing agressivo em escala, fechado | ✅ Alternativa válida |

> Para um app de relacionamento que coleta dados sensíveis: **PostHog self-hosted** elimina envio de dados para terceiros. Considerar seriamente antes do lançamento nos EUA (CCPA).

### Integração no FlutterFlow

```dart
// Inicialização (main.dart ou equivalente)
// PostHog Flutter SDK: posthog_flutter

await Posthog().setup(
  'https://app.posthog.com',  // ou self-hosted URL
  PostHogConfig(
    apiKey: 'phc_...',        // token do cliente — seguro no app
    debug: kDebugMode,
    captureApplicationLifecycleEvents: true,
  ),
);
```

### Propriedades Globais (Super Properties)

Enviar automaticamente com **todos** os eventos via `identify` + super properties:

```dart
// Chamar após login e após qualquer mudança de subscription_tier
await Posthog().identify(
  userId: user.id,  // UUID interno — nunca email, nunca nome
  userProperties: {
    'subscription_tier': user.subscriptionTier,   // 'free' | 'premium'
    'active_mode': user.activeMode,               // 'dating' | 'couple'
    'has_active_couple': user.hasActiveCouple,    // bool
    'platform': Platform.isIOS ? 'ios' : 'android',
    'app_version': packageInfo.version,
    'days_since_signup': daysSince(user.createdAt),
    'couple_day_count': user.coupleDay ?? 0,
  },
);

// Super properties: anexadas a TODOS os eventos sem precisar passar manualmente
await Posthog().register({
  'subscription_tier': user.subscriptionTier,
  'active_mode': user.activeMode,
  'has_active_couple': user.hasActiveCouple,
  'platform': Platform.isIOS ? 'ios' : 'android',
  'app_version': packageInfo.version,
});
```

**Regra:** Atualizar `subscription_tier` imediatamente após mudança de plano. Nunca deixar desatualizado.

---

## SEÇÃO 2 — Schema de Suporte para Notificações

### 2.1 — Tabela `push_tokens`

Armazena os tokens de dispositivo para FCM (Android) e APNs (iOS):

```sql
CREATE TABLE push_tokens (
  token_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token       TEXT NOT NULL,
  platform    TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  device_id   TEXT,                    -- identificador do dispositivo
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMP DEFAULT NOW(),
  last_used_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_token UNIQUE (token)
);

-- RLS
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_push_tokens"
  ON push_tokens FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- INSERT/UPDATE/DELETE: apenas via Edge Function (service_role)

-- Índice
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id) WHERE is_active = true;
```

**Quando registrar/atualizar o token:**
- No login do usuário
- Quando o sistema operacional atualizar o token (APNs/FCM pode mudar)
- Ao abrir o app após longa inatividade

---

### 2.2 — Tabela `notification_preferences`

Opt-out granular por categoria. Usuário desativa categorias individualmente, nunca o sistema inteiro:

```sql
CREATE TABLE notification_preferences (
  pref_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Modo Namoro
  new_match           BOOLEAN DEFAULT true,
  new_message         BOOLEAN DEFAULT true,
  icebreaker_received BOOLEAN DEFAULT true,
  match_archived      BOOLEAN DEFAULT true,
  weekly_nudge        BOOLEAN DEFAULT true,

  -- Modo Casal — Rituais
  ritual_available    BOOLEAN DEFAULT true,
  partner_completed   BOOLEAN DEFAULT true,
  ritual_reminder     BOOLEAN DEFAULT true,   -- quinta-feira se não completou

  -- Modo Casal — Check-in
  checkin_available   BOOLEAN DEFAULT true,
  checkin_results     BOOLEAN DEFAULT true,

  -- Modo Casal — Desafio
  challenge_daily     BOOLEAN DEFAULT true,

  -- Modo Casal — Marcos
  streak_milestone    BOOLEAN DEFAULT true,
  badge_earned        BOOLEAN DEFAULT true,

  -- Sistema
  low_credits         BOOLEAN DEFAULT true,
  upgrade_prompts     BOOLEAN DEFAULT true,

  -- Horas silenciosas (por usuário)
  quiet_hours_enabled BOOLEAN DEFAULT true,
  quiet_start         TIME DEFAULT '22:00',
  quiet_end           TIME DEFAULT '08:00',

  updated_at          TIMESTAMP DEFAULT NOW()
);

-- RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_notification_prefs"
  ON notification_preferences FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

**Criar registro automaticamente no onboarding:**
```sql
-- Trigger: inserir preferências padrão ao criar perfil
CREATE OR REPLACE FUNCTION create_default_notification_prefs()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION create_default_notification_prefs();
```

---

### 2.3 — Tabela `notification_log`

Controla frequência e evita spam:

```sql
CREATE TABLE notification_log (
  log_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  sent_at           TIMESTAMP DEFAULT NOW(),
  deep_link         TEXT
);

-- Índice para consulta de frequência
CREATE INDEX idx_notif_log_user_type
  ON notification_log(user_id, notification_type, sent_at DESC);

-- RLS: apenas service_role escreve, usuário não vê
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
-- Sem SELECT policy para o cliente
```

**Uso na Edge Function de notificação:**
```typescript
// Antes de enviar qualquer notificação com limite de frequência:
async function canSendNotification(
  userId: string,
  type: string,
  cooldownDays: number
): Promise<boolean> {
  const { data } = await supabase
    .from('notification_log')
    .select('sent_at')
    .eq('user_id', userId)
    .eq('notification_type', type)
    .gte('sent_at', new Date(Date.now() - cooldownDays * 86400000).toISOString())
    .limit(1);

  return data?.length === 0; // true = pode enviar
}
```

---

## SEÇÃO 3 — Mapa Completo de Eventos

### Convenção de Nomenclatura

```
snake_case para todos os eventos e propriedades
Formato: [contexto]_[ação] ou [objeto]_[ação]
Exemplos: ritual_completed, journal_entry_created, subscription_started
```

---

### A — Eventos de Onboarding

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `app_opened` | Primeiro abrir após instalação | `source: 'organic'\|'paid'\|'referral'\|'unknown'` |
| `onboarding_started` | Toque em "Começar" | — |
| `onboarding_step_completed` | Usuário completa cada etapa | `step_name: string` (ver valores abaixo) |
| `onboarding_completed` | Chega ao app principal | `steps_completed: int` · `time_to_complete_seconds: int` |
| `onboarding_abandoned` | App fechado, não retomado em 24h | `last_step_completed: string` |
| `attachment_style_result` | Avaliação de apego completada | `result: 'secure'\|'anxious'\|'avoidant'\|'fearful_avoidant'` |
| `love_language_result` | Quiz completado | `primary: 'words'\|'acts'\|'gifts'\|'time'\|'touch'` |

**Valores válidos para `step_name`:**
```
account_created
photos_added
bio_written
basic_info_completed
astrology_added
relationship_prefs_completed
habits_completed
values_completed
love_language_completed
attachment_style_completed    ← novo (Part A — C1)
emotional_readiness_completed ← novo (Part A — C2)
communication_style_completed ← novo (Part A — C3)
mbti_completed
mode_selected
```

---

### B — Eventos do Modo Namoro

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `dating_mode_opened` | Entra no Modo Namoro | — |
| `profile_viewed` | Visualiza perfil completo de outro usuário | `compatibility_label: string` |
| `profile_swiped` | Faz swipe | `direction: 'like'\|'pass'` · `compatibility_label: string` |
| `match_created` | Like mútuo confirmado | `match_id: string (hash)` |
| `icebreaker_sent` | Envia icebreaker | `icebreaker_type: 'suggested'\|'custom'` · `is_first_message: bool` |
| `conversation_started` | Primeira mensagem num match | `hours_since_match: int` |
| `compatibility_deep_dive_viewed` | Abre relatório completo | `is_premium: bool` · `used_credits: bool` |
| `match_archived` | Match arquivado (30 dias inativo) | `days_inactive: int` |
| `match_reactivated` | Usuário reativa match arquivado | `days_since_archived: int` |
| `couple_mode_activated_from_dm` | Toca "Somos um casal" no perfil do match | — |

---

### C — Eventos de Ativação do Modo Casal

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `couple_mode_entry_viewed` | Vê tela de ativação | `entry_point: 'match_profile'\|'menu'\|'post_match_import'` |
| `couple_invite_sent` | Envia convite ao parceiro | `activation_source: 'auro_match'\|'imported'` |
| `couple_invite_accepted` | Parceiro aceita convite | `hours_to_accept: int` |
| `couple_invite_expired` | Convite expirou sem aceite | `hours_elapsed: int` |
| `couple_activated` | Ambos confirmados, casal criado | `activation_source: string` · `hours_from_invite: int` |
| `compatibility_offer_accepted` | Casal importado aceita avaliação de compatibilidade | — |

---

### D — Eventos de Engajamento do Modo Casal

#### D1 — Rituais

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `ritual_card_viewed` | Usuário abre o card de ritual da semana | `ritual_track: string` · `week_number: int` |
| `ritual_completed` | Usuário marca ritual como completo | `ritual_track: string` · `partner_also_completed: bool` · `days_after_generation: int` |
| `ritual_both_completed` | Ambos completaram o mesmo ritual | `hours_between_completions: int` |
| `ritual_reflection_written` | Usuário escreve reflexão pós-ritual | `word_count: int` ← NUNCA o conteúdo |
| `ritual_extra_requested` | Solicita ritual extra (créditos) | `credits_used: 3` · `balance_after: int` |
| `ritual_streak_updated` | Contagem de streak muda | `new_streak: int` · `previous_streak: int` |
| `ritual_from_library` | Ritual servido da biblioteca pré-escrita | `ritual_track: string` · `library_id: string (hash)` |

#### D2 — Diário

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `journal_entry_created` | Usuário cria nova entrada | `type: 'free_write'\|'ritual_reflection'\|'ai_prompted'\|'memory'` · `word_count: int` |
| `journal_entry_shared` | Usuário compartilha entrada com parceiro | — |
| `journal_entry_unshared` | Usuário reverte compartilhamento | — |
| `journal_prompt_used` | Usa prompt gerado por IA | `credits_used: 0\|1` |
| `journal_limit_reached` | Free atinge limite de 30 entradas | `current_count: 30` |

#### D3 — Check-In

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `checkin_started` | Usuário inicia check-in | `checkin_type: 'basic'\|'advanced'` |
| `checkin_completed` | Usuário envia respostas | `checkin_type: string` |
| `checkin_both_completed` | Ambos completaram | `hours_between: int` |
| `checkin_results_viewed` | Usuário vê resultados combinados | — |

#### D4 — Desafio

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `challenge_started` | Inicia desafio de 15 dias | `challenge_type: string` · `credits_used: 0\|5` |
| `challenge_day_completed` | Completa card diário | `day_number: int` · `challenge_type: string` |
| `challenge_completed` | 15 dias completos | `days_taken: int` |
| `challenge_paused` | Pausado por dias perdidos | `day_number: int` · `days_missed: int` |

#### D5 — Timeline

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `timeline_event_added` | Adiciona marco do relacionamento | `category: string` · `has_photo: bool` |
| `timeline_viewed` | Abre a timeline | `events_count: int` |
| `timeline_limit_reached` | Free atinge limite de 10 eventos | `current_count: 10` |

---

### E — Monetização

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `upgrade_prompt_shown` | Modal de upgrade exibido | `trigger: string` (ver valores abaixo) |
| `upgrade_prompt_dismissed` | Usuário dispensa modal | `trigger: string` |
| `upgrade_prompt_converted` | Usuário iniciou compra a partir do modal | `trigger: string` |
| `subscription_started` | Pagamento confirmado | `plan: string` (ver valores abaixo) |
| `subscription_cancelled` | Usuário cancela | `days_subscribed: int` · `plan: string` |
| `subscription_renewed` | Renovação automática confirmada | `plan: string` · `total_months: int` |
| `credits_purchased` | Compra de créditos confirmada | `pack_size: 20\|50\|100\|250` · `balance_after: int` |
| `credit_spent` | Usuário gasta créditos | `feature: string` · `credits_spent: int` · `balance_after: int` |
| `credit_balance_low` | Saldo chegou a 2 ou menos | `balance: int` |

**Valores válidos para `trigger` em upgrade prompts:**
```
journal_limit          → free tentou criar 31ª entrada
timeline_limit         → free tentou adicionar 11º evento
ritual_limit           → free tentou gerar ritual extra
credits_low            → saldo chegou a 2
streak_day_25          → 25 dias de streak (momento de engajamento)
level_5                → casal chegou ao nível 5
challenge_locked       → free tentou acessar desafio
advanced_checkin       → free tentou check-in avançado
deep_dive_locked       → free tentou ver relatório completo
```

**Valores válidos para `plan`:**
```
individual_monthly
individual_annual
couple_monthly
couple_annual
premium_plus_monthly
premium_plus_annual
```

---

### F — Funil de Compatibilidade (Dating Mode específico)

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `compatibility_score_calculated` | Score gerado para um novo par | `label: string` · `scoring_version: string` |
| `compatibility_explanation_viewed` | Usuário expande os 3 blocos narrativos | `label: string` · `blocks_expanded: int` |
| `compatibility_worth_exploring_tapped` | Usuário toca no bloco "Worth Exploring" | `label: string` |

---

### G — Retenção e Ciclo de Vida

| Evento | Quando dispara | Propriedades |
|--------|---------------|-------------|
| `app_session_started` | Usuário abre o app (não primeira vez) | `days_since_last_session: int` |
| `push_notification_tapped` | Usuário toca notificação | `notification_type: string` · `minutes_to_tap: int` |
| `push_notification_dismissed` | Usuário dispensa notificação | `notification_type: string` |
| `notification_pref_changed` | Usuário muda preferência de notificação | `category: string` · `enabled: bool` |
| `account_deletion_requested` | Inicia exclusão de conta | `days_since_signup: int` · `has_active_couple: bool` |
| `account_deletion_cancelled` | Cancela exclusão durante os 30 dias | `days_until_deletion: int` |
| `inactivity_warning_viewed` | Usuário vê aviso de inatividade | `months_inactive: int` |

---

## SEÇÃO 4 — Regras Globais de Notificação

### Limites de Frequência

| Contexto | Limite | Exceções |
|----------|--------|---------|
| Modo Casal — não-críticas | Máx 3/semana por usuário | Marcos e transacionais são isentos |
| Modo Namoro | Máx 7/semana por usuário | Novo match nunca é limitado |
| Saldo baixo de créditos | 1x a cada 7 dias | — |
| Nudge semanal de atividade | 1x/semana no máximo | — |
| Ritual disponível | 1x/semana (domingo) | — |
| Reminder de ritual não feito | 1x/semana (quinta-feira) | Só se não completou |

### Horas Silenciosas

```
Sem envio de notificações entre 22:00 e 08:00 no horário local do usuário
(usar profiles.timezone — campo IANA já existente no schema)

Se notificação seria enviada durante horas silenciosas:
  → Enfileirar para entrega às 08:01 local do usuário
  → Agrupar notificações enfileiradas (não disparar N notificações acumuladas)
  → Enviar apenas a mais recente ou um resumo
```

### Opt-Out Granular

```
Na tela de Configurações → Notificações:
  Cada categoria tem seu toggle independente
  NUNCA um "desativar tudo" que desliga o sistema inteiro
  Mínimo: deixar new_match e new_message sempre acessíveis

Se usuário desativa uma categoria:
  → UPDATE notification_preferences SET [categoria] = false
  → Imediato — próxima notificação dessa categoria já é bloqueada
```

### Lógica de Envio (Edge Function `send_notification`)

```typescript
async function sendNotification(params: {
  userId: string,
  type: string,
  title: string,
  body: string,
  deepLink: string,
  cooldownDays?: number,
}) {
  // 1. Verificar preferências do usuário
  const prefs = await getNotificationPrefs(params.userId);
  if (!prefs[params.type]) return; // categoria desativada pelo usuário

  // 2. Verificar horas silenciosas
  const userTimezone = await getUserTimezone(params.userId);
  if (isQuietHours(userTimezone, prefs.quiet_start, prefs.quiet_end)) {
    await enqueueForMorning(params); // enfileirar para 08:01 local
    return;
  }

  // 3. Verificar cooldown (se aplicável)
  if (params.cooldownDays) {
    const canSend = await canSendNotification(params.userId, params.type, params.cooldownDays);
    if (!canSend) return;
  }

  // 4. Buscar tokens ativos do usuário
  const tokens = await getActivePushTokens(params.userId);
  if (!tokens.length) return;

  // 5. Enviar via FCM/APNs
  for (const token of tokens) {
    await sendPush(token, params.title, params.body, params.deepLink);
  }

  // 6. Registrar no log
  await logNotification(params.userId, params.type, params.deepLink);

  // 7. Registrar evento de analytics
  await analytics.capture(params.userId, 'push_notification_sent', {
    notification_type: params.type,
  });
}
```

---

## SEÇÃO 5 — Copy Exato das Notificações

### A — Modo Namoro

| `notification_type` | Título | Corpo | Deep Link |
|--------------------|--------|-------|-----------|
| `new_match` | "New Match" | "You matched with [Nome] — see what you have in common" | `/dating/match/[match_id]` |
| `new_message` | "[Nome]" | "[Nome] sent you a message" | `/dating/chat/[match_id]` |
| `icebreaker_received` | "[Nome]" | "[Nome] broke the ice with a question for you 💬" | `/dating/chat/[match_id]` |
| `match_archived` | "Connection archived" | "Your connection with [Nome] was quietly archived. You can reactivate anytime." | `/dating/archived` |
| `weekly_nudge` | "New profiles for you" | "You have [X] new potential matches this week" | `/dating/discover` |

**Frequência:**
- `new_match` → imediata, sem limite de frequência
- `new_message` → imediata, máx 1 a cada 30 min por conversa (agrupar)
- `icebreaker_received` → imediata
- `match_archived` → 1x por match arquivado
- `weekly_nudge` → 1x/semana, máx

---

### B — Ativação do Modo Casal

| `notification_type` | Título | Corpo | Deep Link |
|--------------------|--------|-------|-----------|
| `couple_invite_sent` | "Invitation sent" | "You invited [Nome] to start your Couple Mode journey 💚" | `/couple/activation` |
| `couple_invite_received` | "[Nome] invited you" | "[Nome] wants to start the Couple Mode journey together 💚 Tap to accept." | `/couple/accept/[token]` |
| `couple_activated_sender` | "You're official 🎊" | "[Nome] accepted! Your journey starts today." | `/couple/dashboard` |
| `couple_activated_receiver` | "Your journey begins" | "Your journey with [Nome] starts now 🎊" | `/couple/dashboard` |
| `couple_invite_expiring` | "Invitation expiring soon" | "Your invitation to [Nome] expires in 24 hours." | `/couple/activation` |

---

### C — Engajamento do Modo Casal — Rituais

| `notification_type` | Título | Corpo | Deep Link | Quando enviar |
|--------------------|--------|-------|-----------|---------------|
| `ritual_available` | "Your ritual is ready ✨" | "This week's ritual for you and [Nome] is ready." | `/couple/ritual` | Domingo, após geração |
| `partner_completed_ritual` | "[Nome] completed it" | "[Nome] completed this week's ritual." | `/couple/ritual` | Quando parceiro marca completo |
| `ritual_reminder` | "This week's ritual" | "There's still time to complete this week's ritual with [Nome]." | `/couple/ritual` | Quinta-feira, se não completou |
| `ritual_streak_4` | "4-week streak 🔥" | "You and [Nome] have completed 4 rituals in a row!" | `/couple/dashboard` | Ao atingir streak 4 |
| `ritual_streak_12` | "3-month streak 🌟" | "12 weeks strong. You and [Nome] are building something real." | `/couple/dashboard` | Ao atingir streak 12 |
| `ritual_streak_52` | "One year of rituals 🏆" | "52 weeks together. That's remarkable." | `/couple/dashboard` | Ao atingir streak 52 |

**Regra:** Notificação de `ritual_reminder` (quinta-feira) **nunca** menciona "você não fez". Copy sempre positivo e voltado ao que é possível fazer, não ao que foi deixado de fazer.

---

### D — Engajamento do Modo Casal — Check-in

| `notification_type` | Título | Corpo | Deep Link | Quando enviar |
|--------------------|--------|-------|-----------|---------------|
| `checkin_available` | "Weekly check-in ready" | "Your weekly check-in with [Nome] is ready." | `/couple/checkin` | Segunda-feira |
| `checkin_results_ready` | "Results are in" | "You and [Nome] both completed the check-in. See your results." | `/couple/checkin/results` | Quando `both_completed = true` ou `visible_after` passou |
| `checkin_partner_completed` | "[Nome] checked in" | "[Nome] completed this week's check-in. Your turn." | `/couple/checkin` | Quando parceiro completa (se usuário ainda não fez) |

---

### E — Engajamento do Modo Casal — Desafio

| `notification_type` | Título | Corpo | Deep Link | Quando enviar |
|--------------------|--------|-------|-----------|---------------|
| `challenge_day` | "Day [X] of your challenge" | "Your card for today is waiting." | `/couple/challenge` | Diário, durante desafio ativo |
| `challenge_completed` | "Challenge complete 🏆" | "You and [Nome] finished the [X]-day challenge!" | `/couple/challenge/summary` | Ao completar |
| `challenge_paused` | "Life happened" | "Your challenge is paused — pick it back up when you're ready." | `/couple/challenge` | Após 2 dias perdidos |

---

### F — Sistema: Créditos e Upgrades

| `notification_type` | Título | Corpo | Deep Link | Frequência |
|--------------------|--------|-------|-----------|-----------|
| `low_credits` | "Credits running low" | "You have [X] credits left. Get more to keep going." | `/credits` | 1x/7 dias (saldo ≤ 2) |
| `credits_refreshed` | "Monthly credits added" | "Your [X] monthly credits have been added." | `/credits` | Dia 1 do mês |
| `upgrade_nudge_streak` | "Keep your streak going" | "You're on a [X]-week streak. Upgrade to protect it." | `/upgrade` | Dia 25 de streak |
| `upgrade_nudge_level` | "You've reached level 5" | "Unlock everything at level 5 with Premium." | `/upgrade` | Ao atingir level 5 |

---

### G — Sistema: Conta e Inatividade

| `notification_type` | Título | Corpo | Deep Link |
|--------------------|--------|-------|-----------|
| `inactivity_warning` | "We miss you" | "It's been a while. Your profile is still here when you're ready." | `/dating/discover` |
| `deletion_scheduled` | "Account deletion scheduled" | "Your account will be deleted in 30 days. Tap to cancel." | `/settings/account` |
| `couple_data_expiring` | "Your couple data" | "Your couple data will be deleted in 7 days. Export it before then." | `/couple/export` |

---

## SEÇÃO 6 — Funis Críticos para Monitorar

Estes funis devem ser configurados no PostHog/Mixpanel no dia do lançamento:

### Funil 1 — Onboarding Completion

```
app_opened
  → onboarding_started
  → onboarding_step_completed (account_created)
  → onboarding_step_completed (attachment_style_completed)
  → onboarding_completed

Métricas: taxa de conclusão por etapa, onde usuários abandonam
Alerta: se taxa de conclusão de attachment_style < 60% → revisar UX da etapa
```

### Funil 2 — Primeira Semana no Dating Mode

```
onboarding_completed
  → dating_mode_opened
  → profile_swiped (direction: like)
  → match_created
  → conversation_started

Métrica chave: % que cria um match na primeira semana
```

### Funil 3 — Ativação do Modo Casal

```
couple_mode_entry_viewed
  → couple_invite_sent
  → couple_invite_accepted
  → couple_activated

Segmentar por: activation_source (auro_match vs imported)
Métrica chave: taxa de conversão do convite (invite_sent → accepted)
Alerta: se invite_accepted < 50% → investigar UX do convite
```

### Funil 4 — Engajamento do Modo Casal (Semana 1→4)

```
couple_activated
  → ritual_card_viewed (week 1)
  → ritual_completed (week 1)
  → ritual_completed (week 2)
  → ritual_completed (week 4)

Métrica chave: retenção de rituais semana a semana
Alerta: queda de > 30% entre semana 1 e semana 2 → investigar
```

### Funil 5 — Conversão Free → Premium

```
upgrade_prompt_shown (trigger: qualquer)
  → upgrade_prompt_dismissed | upgrade_prompt_converted
  → subscription_started

Métricas por trigger: qual trigger converte mais
Segmentar por: active_mode, days_since_signup
```

---

## SEÇÃO 7 — Eventos de Cohort e Retenção

Configurar no provider de analytics como propriedades de cohort:

```
D1 retention  → app_session_started no dia 1 após onboarding_completed
D7 retention  → app_session_started nos dias 2–7
D30 retention → app_session_started nos dias 8–30
D90 retention → app_session_started nos dias 31–90

Couple retention:
  Week 1 ritual completion rate
  Week 4 ritual completion rate
  Week 8 ritual completion rate
```

---

## Checklist de Implementação (Part E)

### Schema

- [ ] Criar tabela `push_tokens` + RLS + índice
- [ ] Criar tabela `notification_preferences` + RLS
- [ ] Criar trigger de criação automática de `notification_preferences` no onboarding
- [ ] Criar tabela `notification_log` + índice
- [ ] Verificar que `profiles.timezone` existe e é preenchido no onboarding

### Analytics

- [ ] Escolher provider: PostHog self-hosted ou Mixpanel
- [ ] Integrar SDK no FlutterFlow
- [ ] Configurar `identify` + super properties na autenticação
- [ ] Implementar todos os eventos do Grupo A (Onboarding) — antes do lançamento
- [ ] Implementar todos os eventos do Grupo B (Dating Mode) — antes do lançamento
- [ ] Implementar todos os eventos do Grupo C (Couple Activation) — antes do Modo Casal
- [ ] Implementar todos os eventos do Grupo D (Couple Engagement) — antes do Modo Casal
- [ ] Implementar todos os eventos do Grupo E (Monetização) — antes do primeiro paywall
- [ ] Implementar todos os eventos do Grupo G (Retenção) — antes do lançamento
- [ ] Configurar os 5 funis críticos no provider

### Notificações

- [ ] Edge Function `send_notification` com toda a lógica (prefs + quiet hours + cooldown + log)
- [ ] Integrar FCM (Android) e APNs (iOS) — chaves nas variáveis de ambiente
- [ ] Fluxo de registro de push token no login / abertura do app
- [ ] Fluxo de revogação de token ao logout
- [ ] Tela de preferências de notificação no FlutterFlow (toggles por categoria)
- [ ] Lógica de horas silenciosas com `profiles.timezone`
- [ ] pg_cron: entregar notificações enfileiradas das horas silenciosas às 08:01 local
- [ ] Testar cada notificação com copy exato da Seção 5
- [ ] Confirmar deep links funcionando para cada tipo de notificação

---

## SQL Consolidado — Todas as Mudanças da Part E

```sql
-- ============================================================
-- PART E — Analytics e Notificações: Schema de Suporte
-- Versão: v1.0 | Março 2026
-- ============================================================

-- 1. PUSH TOKENS
CREATE TABLE push_tokens (
  token_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token        TEXT NOT NULL,
  platform     TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  device_id    TEXT,
  is_active    BOOLEAN DEFAULT true,
  created_at   TIMESTAMP DEFAULT NOW(),
  last_used_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT unique_token UNIQUE (token)
);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_push_tokens"
  ON push_tokens FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE INDEX idx_push_tokens_user
  ON push_tokens(user_id)
  WHERE is_active = true;

-- 2. NOTIFICATION PREFERENCES
CREATE TABLE notification_preferences (
  pref_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Dating Mode
  new_match           BOOLEAN DEFAULT true,
  new_message         BOOLEAN DEFAULT true,
  icebreaker_received BOOLEAN DEFAULT true,
  match_archived      BOOLEAN DEFAULT true,
  weekly_nudge        BOOLEAN DEFAULT true,

  -- Couple Mode — Rituais
  ritual_available    BOOLEAN DEFAULT true,
  partner_completed   BOOLEAN DEFAULT true,
  ritual_reminder     BOOLEAN DEFAULT true,

  -- Couple Mode — Check-in
  checkin_available   BOOLEAN DEFAULT true,
  checkin_results     BOOLEAN DEFAULT true,

  -- Couple Mode — Desafio
  challenge_daily     BOOLEAN DEFAULT true,

  -- Marcos
  streak_milestone    BOOLEAN DEFAULT true,
  badge_earned        BOOLEAN DEFAULT true,

  -- Sistema
  low_credits         BOOLEAN DEFAULT true,
  upgrade_prompts     BOOLEAN DEFAULT true,

  -- Horas silenciosas
  quiet_hours_enabled BOOLEAN DEFAULT true,
  quiet_start         TIME DEFAULT '22:00',
  quiet_end           TIME DEFAULT '08:00',

  updated_at          TIMESTAMP DEFAULT NOW()
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_notification_prefs"
  ON notification_preferences FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Trigger: criar preferências padrão ao criar perfil
CREATE OR REPLACE FUNCTION create_default_notification_prefs()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_notif_prefs
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION create_default_notification_prefs();

-- 3. NOTIFICATION LOG
CREATE TABLE notification_log (
  log_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  sent_at           TIMESTAMP DEFAULT NOW(),
  deep_link         TEXT
);

ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
-- Sem SELECT policy para o cliente — apenas service_role

CREATE INDEX idx_notif_log_user_type
  ON notification_log(user_id, notification_type, sent_at DESC);
```

---

*Documento de mudanças Part E — gerado em Março 2026*
*Referências: `docs/overview.md` · `docs/chat.md` · `docs/journey.md` · Auro Developer Handoff v1.0 Part E*

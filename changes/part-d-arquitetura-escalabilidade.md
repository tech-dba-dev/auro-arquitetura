# PART D — Mudanças: Arquitetura e Escalabilidade
**Status:** Stack base alinhada · Multi-modo ausente · Índices do Modo Casal faltando · IA sem estratégia de custo · TBDs resolvidos
**Referência:** `docs/overview.md` · `docs/schema.sql` (linhas 935–1003) · `docs/matching-engine.md` · Auro Developer Handoff v1.0 Part D

---

## Estado Atual vs Novo — Visão Geral

| Área | Estado Atual | Problema / O que muda | Prioridade |
|------|-------------|----------------------|-----------|
| Stack de 4 camadas | Implícito nos docs, não formalizado | Formalizar separação de responsabilidades por camada | 🟡 |
| Engine de astrologia | "Custom calculation service (TBD)" | Definido: biblioteca open-source dentro da Edge Function. Sem API externa. | 🔴 |
| AI Pipeline | "External LLM (TBD)" | Definido: Claude API (Anthropic) via Edge Functions. Cliente nunca chama diretamente. | 🔴 |
| Flags de multi-modo | Apenas `dating` e `couple` no enum `user_modes` | Adicionar 4 flags booleanas + `subscription_tier` em `profiles` | 🔴 |
| Namespaces de telas (FlutterFlow) | Não estruturado | Criar namespaces por modo + stubs ocultos para Wedding/Life | 🔴 |
| Índices — tabelas existentes | ✅ Maioria já criada no schema.sql | Alguns ajustes finos | ✅ Maioria OK |
| Índices — Modo Casal (10 tabelas) | ❌ Nenhum existe | Criar todos antes do lançamento do Modo Casal | 🔴 |
| Otimização de custo de IA | ❌ Sem estratégia documentada | 3 otimizações obrigatórias antes do primeiro cron | 🔴 |
| PgBouncer / connection pooling | Mencionado no matching-engine, não configurado | Ativar no Supabase Pro antes do lançamento | 🔴 |
| Regras de ouro para a equipe | ❌ Não documentadas | 12 regras formalizadas | 🟡 |

---

## SEÇÃO 1 — Stack de 4 Camadas (Formalização)

### Antes (`overview.md`)
Stack documentada como tabela simples de tecnologias, sem separação explícita de responsabilidades:
```
Backend / Database  → Supabase
Auth                → Supabase Auth
Geospatial          → PostGIS
Real-time Chat      → Supabase Realtime
Compatibility       → Edge Functions
AI Pipeline         → External LLM (TBD)  ← problema
Astrology Engine    → Custom service (TBD) ← problema
Media Storage       → Supabase Storage
```

Sem regras claras sobre o que pode rodar no cliente vs servidor.

### Depois

```
┌──────────────────────────────────────────────────────────────────┐
│ CAMADA 1: CLIENTE (FlutterFlow)                                  │
│                                                                  │
│  O que pode:                                                     │
│  • Renderizar UI e navegação                                     │
│  • Ler do Supabase via ANON key (RLS aplicado)                   │
│  • Chamar Edge Functions para lógica de negócio                  │
│  • Usar Supabase Realtime para chat                              │
│  • Enviar tokens de analytics (PostHog/Mixpanel)                 │
│                                                                  │
│  O que NUNCA pode:                                               │
│  • Ter chaves secretas (SERVICE_ROLE, Claude API, etc.)          │
│  • Chamar Claude API diretamente                                 │
│  • Modificar créditos, matches, scores diretamente              │
│  • Fazer upload de fotos sem passar pela Edge Function           │
└────────────────────┬─────────────────────────┬───────────────────┘
                     │ DB direto (Anon + RLS)   │ Edge Function calls
                     ↓                          ↓
┌────────────────────────────┐  ┌───────────────────────────────────┐
│ CAMADA 2: BANCO DE DADOS   │  │ CAMADA 3: EDGE FUNCTIONS          │
│ Supabase Postgres          │  │ Supabase (Deno / TypeScript)       │
│                            │  │                                   │
│ • Todas as tabelas         │  │ O que roda aqui:                  │
│ • RLS em cada tabela    ↔  │  │ • Geração de rituais de IA        │
│ • Supabase Storage         │  │ • Cálculo de score de compat.     │
│ • Supabase Auth            │  │ • Transações de créditos          │
│ • Supabase Realtime (chat) │  │ • CSAM detection + foto upload    │
│ • pg_cron (cron jobs)      │  │ • Geração de convites de casal    │
│                            │  │ • Exclusão de conta               │
└────────────────────────────┘  │ • Webhooks de pagamento IAP       │
                                └──────────────┬────────────────────┘
                                               │ Chamadas externas
                                               ↓
┌──────────────────────────────────────────────────────────────────┐
│ CAMADA 4: APIs EXTERNAS                                          │
│                                                                  │
│ Claude API (Anthropic)   → geração de rituais, explicações, IA  │
│ PhotoDNA / AWS Rekognition → CSAM detection                      │
│ FCM / APNs               → push notifications                   │
│ App Store / Play Store   → webhooks de IAP                       │
│ PostHog / Mixpanel       → analytics                             │
│                                                                  │
│ NÃO é API externa:                                               │
│ Astrologia → biblioteca open-source dentro da Edge Function      │
│ MBTI       → implementação interna no app                        │
└──────────────────────────────────────────────────────────────────┘
```

### Dois TBDs Resolvidos

#### Astrology Engine — Era TBD, agora definido

| Antes | Depois |
|-------|--------|
| "Custom calculation service (TBD)" | Biblioteca open-source de astrologia rodando dentro da Edge Function |
| Custo por chamada possível | Zero custo por cálculo |
| Dependência externa | Sem dependência externa, sem chave de API |

**Implementação:**
```typescript
// Edge Function: calculate_birth_chart
// Usar biblioteca open-source (ex: astronomia, ephemeris, ou similar)
// Calcular UMA VEZ no onboarding. Armazenar JSON em user_astrology.
// NUNCA recalcular para usuário existente (exceto re-edição de birth_time).

import { calculateNatalChart } from './lib/astrology'; // biblioteca local

const chart = calculateNatalChart({
  birthDate: '1995-08-15',
  birthTime: '14:30',
  birthLocation: { lat: -23.5505, lng: -46.6333 }
});

// Armazenar resultado completo:
// user_astrology.chart_json = { sun: 'leo', moon: 'taurus', rising: 'scorpio', ... }
```

#### AI Pipeline — Era "External LLM (TBD)", agora definido

| Antes | Depois |
|-------|--------|
| "External LLM" genérico | Claude API (Anthropic) especificamente |
| TBD para qual modelo | Modelo: `claude-sonnet-4-6` (balança custo e qualidade) |
| Sem regras de uso | Sempre via Edge Function, nunca do cliente |

**Atualização na tabela de stack do `overview.md`:**
```markdown
| AI Pipeline | Claude API (Anthropic) via Edge Functions — claude-sonnet-4-6 |
| Astrology Engine | Biblioteca open-source (Deno) dentro da Edge Function — sem API externa |
```

---

## SEÇÃO 2 — Multi-Modo: Flags e Namespaces

### D2.1 — Flags de Modo no `profiles`

**Estado atual:** O enum `app_mode` existe com `dating` e `couple`, mas as flags são controladas pela tabela `user_modes` (tabela separada). Não há `subscription_tier` em `profiles`. Sem flags para Wedding/Life.

**Por que mudar para colunas em `profiles`:**
- Consulta mais rápida (sem JOIN com `user_modes`)
- Flags de modos futuros adicionadas sem migração de tabela
- `subscription_tier` precisa estar em `profiles` para lógica de créditos e RLS

```sql
-- Adicionar à tabela profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS active_mode          TEXT DEFAULT 'dating'
    CHECK (active_mode IN ('dating', 'couple', 'wedding', 'life')),
  ADD COLUMN IF NOT EXISTS dating_mode_enabled  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS couple_mode_enabled  BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS wedding_mode_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS life_mode_enabled    BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS subscription_tier    TEXT DEFAULT 'free'
    CHECK (subscription_tier IN ('free', 'premium', 'premium_plus'));
```

> `wedding_mode_enabled` e `life_mode_enabled` são adicionados **agora**, mesmo que os modos não existam ainda. Custo zero. Não ter esses campos depois custa uma migração em produção com dados reais.

**Relação com `user_modes`:**
- Manter a tabela `user_modes` existente para compatibilidade com código já escrito
- Nas novas features, usar as colunas de `profiles` diretamente
- Eventualmente migrar e deprecar `user_modes` (não urgente)

---

### D2.2 — Namespaces de Telas no FlutterFlow

**Estado atual:** Modo Casal é TBD. Sem estrutura de telas definida. Risco de criar telas sem organização e dificultar adição de novos modos futuramente.

**Estrutura obrigatória de namespaces:**

```
FlutterFlow — Organização de Telas por Namespace:

NAMESPACE: SHARED (compartilhadas por todos os modos)
├── ProfileScreen
├── EditProfileScreen
├── SettingsScreen
├── CreditsScreen
├── NotificationsScreen
├── OnboardingFlow (steps 1–N)
└── AuthScreens (login, signup, forgot password)

NAMESPACE: DATING_MODE
├── DiscoverScreen       (swipe feed)
├── MatchProfileScreen   (perfil expandido + compatibilidade)
├── ChatListScreen       (lista de matches + conversas)
├── ChatScreen           (conversa individual)
└── CompatibilityScreen  (relatório completo de compatibilidade)

NAMESPACE: COUPLE_MODE
├── CoupleDashboardScreen   (hub central do casal)
├── RitualScreen            (ritual da semana)
├── JournalScreen           (diário + lista de entradas)
├── JournalEntryScreen      (criar/editar entrada)
├── TimelineScreen          (linha do tempo)
├── CheckInScreen           (check-in semanal)
├── ChallengeScreen         (desafio de 15 dias)
├── InsightsScreen          (insights premium)
├── BadgesScreen            (conquistas)
└── CoupleActivationScreen  (ativar modo casal — 2 opções)

NAMESPACE: WEDDING_MODE (stub — oculto, não navegável)
└── WeddingPlaceholderScreen  [hidden: true]

NAMESPACE: LIFE_MODE (stub — oculto, não navegável)
└── LifePlaceholderScreen     [hidden: true]
```

**Por que os stubs de Wedding e Life existem agora:**
- Quando o modo for lançado, a estrutura já existe — só habilitar e construir
- Evita reorganização traumática de um app grande em produção
- Custo de criar uma tela placeholder: ~10 minutos

---

## SEÇÃO 3 — Índices do Banco de Dados

### 3.1 — Índices Existentes (Tabelas Atuais)

Cruzamento entre o que o `schema.sql` já tem e o que o handoff especifica:

| Índice | Status no schema.sql | Observação |
|--------|---------------------|-----------|
| `idx_profiles_location` (GIST) | ✅ Existe (linha 965) | Correto |
| `idx_profiles_active` | ✅ Existe (linha 966) | Correto |
| `idx_compat_scores_user_a` | ✅ Existe (linha 969) | Correto |
| `idx_compat_scores_user_b` | ✅ Existe (linha 970) | Correto |
| `idx_compat_scores_total` (score DESC) | ✅ Existe (linha 972) | Correto |
| `idx_matches_user_a` (WHERE active) | ✅ Existe (linha 981) | Correto |
| `idx_matches_user_b` (WHERE active) | ✅ Existe (linha 982) | Correto |
| `idx_messages_match` (created_at DESC) | ✅ Existe (linha 986) | Correto |
| `idx_messages_unread` | ✅ Existe (linha 987) | Correto |
| `idx_user_personality_mbti` | ✅ Existe (linha 952) | OK — adicionar `attachment_style` |
| `idx_user_rel_prefs_dating_style` | ✅ Existe (linha 948) | Usado no Phase 1 filter |

**Índice faltando nas tabelas existentes:**

```sql
-- Attachment style: necessário para o novo filtro/scoring (Part A — B3)
CREATE INDEX idx_user_personality_attachment
  ON user_personality(attachment_style)
  WHERE attachment_style IS NOT NULL;

-- scoring_version: para auditar scores por versão do motor
CREATE INDEX idx_compat_scores_version
  ON compatibility_scores(scoring_version);

-- matches arquivados: para a tela "Archived Connections" (Part A — D1)
CREATE INDEX idx_matches_archived
  ON matches(user_a, archived_at DESC)
  WHERE status = 'archived';
CREATE INDEX idx_matches_archived_b
  ON matches(user_b, archived_at DESC)
  WHERE status = 'archived';
```

---

### 3.2 — Índices Faltando (Tabelas do Modo Casal — Part B)

**Nenhum existe ainda.** Criar todos antes do lançamento do Modo Casal:

```sql
-- ============================================================
-- ÍNDICES: MODO CASAL
-- Criar antes de qualquer usuário real usar o Modo Casal
-- ============================================================

-- couples: buscar casal ativo de um usuário (query mais frequente do Modo Casal)
CREATE INDEX idx_couples_user_a_active
  ON couples(user_a_id)
  WHERE status = 'active';

CREATE INDEX idx_couples_user_b_active
  ON couples(user_b_id)
  WHERE status = 'active';

-- couples: casais com exclusão agendada (cron de limpeza)
CREATE INDEX idx_couples_deletion_scheduled
  ON couples(deletion_scheduled_at)
  WHERE deletion_scheduled_at IS NOT NULL;

-- rituals: buscar ritual da semana atual de um casal
CREATE INDEX idx_rituals_couple_week
  ON rituals(couple_id, week_number DESC);

-- rituals: rituais pendentes de geração (cron de domingo)
CREATE INDEX idx_rituals_pending_generation
  ON rituals(generated_at)
  WHERE completed_a_at IS NULL AND completed_b_at IS NULL;

-- rituals: rituais por trilha (para evitar repetição na geração)
CREATE INDEX idx_rituals_couple_track
  ON rituals(couple_id, track, week_number DESC);

-- journal_entries: feed do diário (mais recentes primeiro)
CREATE INDEX idx_journal_couple_date
  ON journal_entries(couple_id, created_at DESC);

-- journal_entries: entradas do autor
CREATE INDEX idx_journal_author
  ON journal_entries(author_id, created_at DESC);

-- journal_entries: entradas compartilhadas com o parceiro
CREATE INDEX idx_journal_shared
  ON journal_entries(couple_id)
  WHERE shared_with_partner = true;

-- timeline_events: timeline ordenada por data do evento
CREATE INDEX idx_timeline_couple_date
  ON timeline_events(couple_id, event_date DESC);

-- timeline_events: por categoria (para filtrar por tipo)
CREATE INDEX idx_timeline_category
  ON timeline_events(couple_id, category);

-- check_ins: check-in da semana atual
CREATE INDEX idx_checkin_couple_week
  ON check_ins(couple_id, week_number DESC);

-- check_ins: check-ins com revelação pendente (para o cron de 48h se necessário)
CREATE INDEX idx_checkin_visible_after
  ON check_ins(visible_after)
  WHERE both_completed = false;

-- challenges: desafio ativo do casal
CREATE INDEX idx_challenges_couple_active
  ON challenges(couple_id)
  WHERE status = 'active';

-- challenges: para análise de conclusão (analytics)
CREATE INDEX idx_challenges_status
  ON challenges(couple_id, status, started_at DESC);

-- credits: busca rápida de saldo (operação mais frequente do sistema de créditos)
CREATE INDEX idx_credits_user
  ON credits(user_id);

-- credits: usuários com renovação pendente (cron mensal)
CREATE INDEX idx_credits_refresh_pending
  ON credits(last_refreshed_at)
  WHERE last_refreshed_at < DATE_TRUNC('month', CURRENT_DATE);

-- couple_insights: insight da semana atual
CREATE INDEX idx_insights_couple_week
  ON couple_insights(couple_id, week_number DESC);

-- couple_insights: retrospectivas mensais
CREATE INDEX idx_insights_retrospective
  ON couple_insights(couple_id, type)
  WHERE type = 'retrospective';

-- badges: conquistas do casal (ordenadas por data)
CREATE INDEX idx_badges_couple
  ON badges(couple_id, earned_at DESC);
```

---

## SEÇÃO 4 — Otimização de Custos de IA

### Contexto

**Estado atual:** Sem estratégia de custo documentada. Zero otimizações implementadas.

**Impacto sem otimização:**

| Escala | Custo semanal | Custo anual |
|--------|--------------|------------|
| 100K casais ativos, sem otimização | ~$3.200/semana | ~$166.000/ano |
| 100K casais ativos, totalmente otimizado | ~$35/semana | ~$1.820/ano |
| 1M casais ativos, sem otimização | ~$32.000/semana | ~$1.664.000/ano |
| 1M casais ativos, totalmente otimizado | ~$350/semana | ~$18.200/ano |

A diferença são **3 decisões de implementação**. Perder qualquer uma delas significa um problema de unit economics que se agrava com cada novo casal.

---

### Otimização 1 — Saída JSON Estruturada

**Impacto:** ~30% de redução de tokens. Zero ambiguidade de parsing. Implementação: 1 linha no system prompt.

**Antes (sem otimização):**
```
System prompt: "Generate a weekly ritual for this couple.
The ritual should have a title, an insight paragraph,
a practice description, and a reflection question."

Resposta típica da IA:
"Here's a ritual for your couple:

**Title:** The Unspoken Thank You

**Insight:** Gratitude is most powerful when it names something
specific. This week, you'll practice seeing each other in detail.

**Practice:** Set aside 15 minutes on any evening this week...

**Reflection question:** What's something your partner does that
you've never directly thanked them for?"

→ Tokens de saída: ~250
→ Parsing: regex/split frágil, quebra se a IA mudar o formato
```

**Depois (com otimização):**
```typescript
// System prompt obrigatório para TODA chamada de geração de ritual:
const SYSTEM_PROMPT = `Respond ONLY with a valid JSON object.
No preamble, no explanation, no markdown backticks, no commentary.
{ "track": "...", "title": "...", "insight": "...", "practice": "...", "reflection_question": "..." }`;

// Resposta da IA:
// {"track":"emotional","title":"The Unspoken Thank You","insight":"Gratitude is most powerful...","practice":"Set aside 15 minutes...","reflection_question":"What's something your partner..."}

// → Tokens de saída: ~150 (40% menos)
// → Parsing: JSON.parse() — nunca falha por mudança de formato
```

**Aplicar em todas as Edge Functions de IA:**
- `generate_weekly_rituals`
- `generate_ritual_on_demand`
- `generate_challenge_cards`
- `generate_weekly_insights`
- `generate_monthly_retrospective`

---

### Otimização 2 — Geração em Lote Mensal

**Impacto:** ~65% de redução de custo por casal. O contexto (system prompt + dados do casal) é pago uma vez, não quatro.

**Antes (geração semanal individual):**
```
Semana 1: [system prompt + dados do casal] + gerar 1 ritual → 1 chamada de API
Semana 2: [system prompt + dados do casal] + gerar 1 ritual → 1 chamada de API
Semana 3: [system prompt + dados do casal] + gerar 1 ritual → 1 chamada de API
Semana 4: [system prompt + dados do casal] + gerar 1 ritual → 1 chamada de API
Total: 4 chamadas × overhead de contexto
```

**Depois (geração mensal em lote):**
```typescript
// 1 chamada de API gera os 4 rituais do mês inteiro
const prompt = `Generate 4 weekly rituals for this couple for the next month.
Return a JSON array of exactly 4 ritual objects.
[
  { "week": 1, "track": "...", "title": "...", "insight": "...", "practice": "...", "reflection_question": "..." },
  { "week": 2, ... },
  { "week": 3, ... },
  { "week": 4, ... }
]`;

// Armazenar os 4 na tabela rituals com week_number correto
// Cron de domingo: verificar se ritual da semana já existe antes de gerar
```

**Quando usar geração semanal (exceção):**
- Casal completou um ritual e quer retroalimentar a geração da próxima semana com o contexto do ritual completado
- Casal mudou dados de perfil que afetam a geração (attachment_style, love_language)

---

### Otimização 3 — Biblioteca Pré-Escrita como Fallback (e Primeira Opção)

**Impacto:** ~50% dos casais atendidos com custo zero. IA usada apenas para casais ativamente engajados.

**Lógica de decisão:**
```typescript
async function generateWeeklyRitual(coupleId: string) {
  const engagementScore = await getCoupleEngagement(coupleId);
  // engagementScore = rituais completados nos últimos 30 dias

  if (engagementScore < 3) {
    // Casal pouco engajado → servir da biblioteca pré-escrita
    // Custo: $0.00
    return await getLibraryRitual(coupleId);
  } else {
    // Casal ativamente engajado → geração personalizada por IA
    // Custo: ~$0.003 por casal
    return await generateAIRitual(coupleId);
  }
}
```

**A biblioteca pré-escrita:**
- 200 rituais de alta qualidade, escritos manualmente
- Organizados por trilha (emotional, communication, intellectual, adventure, gratitude, playful)
- Sistema de rastreamento: nunca servir o mesmo ritual duas vezes para o mesmo casal
- Tabela no BD: `ritual_library` com campos `track`, `title`, `insight`, `practice`, `reflection_question`

```sql
-- Tabela da biblioteca pré-escrita
CREATE TABLE ritual_library (
  library_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track       TEXT NOT NULL CHECK (track IN ('emotional','communication','intellectual','adventure','gratitude','playful')),
  title       TEXT NOT NULL,
  insight     TEXT NOT NULL,
  practice    TEXT NOT NULL,
  reflection_question TEXT NOT NULL,
  difficulty  SMALLINT DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 3),
  created_at  TIMESTAMP DEFAULT NOW()
);

-- Rastrear quais rituais da biblioteca já foram usados por qual casal
CREATE TABLE ritual_library_used (
  couple_id   UUID REFERENCES couples(couple_id),
  library_id  UUID REFERENCES ritual_library(library_id),
  used_at     TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (couple_id, library_id)
);
```

---

### Tabela de Decisão: Quando Usar Cada Estratégia

| Casal | Situação | Estratégia | Custo |
|-------|---------|-----------|-------|
| Novo (semana 1–2) | Sem histórico suficiente para personalização | Biblioteca pré-escrita | $0 |
| Pouco engajado (< 3 rituais/30 dias) | Não vale personalização | Biblioteca pré-escrita | $0 |
| Ativamente engajado (≥ 3 rituais/30 dias) | Histórico suficiente | IA — lote mensal | ~$0.003 |
| Engajado + mudança de perfil | Dados novos disponíveis | IA — geração semanal | ~$0.003 |
| Premium com insights | Narrativa personalizada | IA — insight semanal | ~$0.005 |

---

### Onde Cada Otimização é Implementada

| Otimização | Onde implementar | Quando |
|-----------|-----------------|--------|
| JSON estruturado | System prompt de todas as Edge Functions de IA | Antes do primeiro cron de domingo |
| Geração em lote | Edge Function `generate_weekly_rituals` | Antes do primeiro cron de domingo |
| Biblioteca pré-escrita | Edge Function `generate_weekly_rituals` + tabela `ritual_library` | Antes do lançamento do Modo Casal |

---

## SEÇÃO 5 — Connection Pooling

### Estado Atual
PgBouncer mencionado no `matching-engine.md` como consideração de escala, mas sem configuração formal.

### O que fazer

```
Supabase Dashboard → Project Settings → Database → Connection Pooling:

1. Ativar PgBouncer: ON
2. Pool Mode: Transaction  (não Session — Edge Functions são stateless)
3. Pool Size: 15 (default para maioria dos planos)

4. Nas Edge Functions: usar a connection string POOLED, não a direta
   - Direct: postgres://postgres:[pass]@db.[ref].supabase.co:5432/postgres
   - Pooled: postgres://postgres:[pass]@db.[ref].supabase.co:6543/postgres  ← usar esta
```

**Por que Transaction mode:**
- Edge Functions são stateless — sem estado entre requisições
- Transaction mode: uma conexão do pool é alocada por transação, liberada imediatamente
- Session mode: uma conexão alocada por sessão inteira — inadequado para Edge Functions

**Impacto sem connection pooling:**
- Cada Edge Function abre uma nova conexão ao banco
- 1.000 requests simultâneos = 1.000 conexões abertas
- PostgreSQL tem limite de conexões (tipicamente 100 no Supabase Free, 200 no Pro)
- Resultado: conexões recusadas sob carga moderada

---

## SEÇÃO 6 — Fluxos de Requisição por Tipo (Referência)

Complementa o `overview.md`. Define qual camada executa cada tipo de operação:

| Tipo de Operação | Camada | Notas |
|-----------------|--------|-------|
| Enviar mensagem de chat | Cliente → DB direto | Supabase Realtime entrega. Sem Edge Function. |
| Ler feed de matches | Cliente → DB direto | RLS filtra. Query com índices geoespaciais. |
| Marcar ritual como completo | Cliente → DB direto | `UPDATE rituals SET completed_a_at = NOW()`. RLS valida pertencimento ao casal. |
| Gerar ritual (cron) | pg_cron → Edge Function → Claude API → DB | Lote. Service role. |
| Solicitar prompt de diário | Cliente → Edge Function → (créditos) → Claude API → DB | Sob demanda. |
| Fazer upload de foto | Cliente → Edge Function → CSAM → Storage → DB | NUNCA direto ao Storage. |
| Comprar créditos | App Store → webhook → Edge Function → DB | Idempotente. |
| Ver saldo de créditos | Cliente → DB direto | RLS: só vê o próprio. |
| Ativar Modo Casal | Cliente → Edge Function → DB | Gera token ou valida token. |
| Calcular score compat. | Edge Function → DB (write) | Na criação do match. Background. |
| Exportar dados do casal | Cliente → Edge Function → gera ZIP → Storage | Antes de deletar conta. |

---

## SEÇÃO 7 — Módulos Atualizados (`overview.md`)

**Antes:**
```
auro/
  |-- Mode: Couple  (relationship tools — TBD)
  |-- Notifications (push, in-app — TBD)
```

**Depois:**
```
auro/
  |-- Auth & Registration         (sign up, login, OAuth — Apple, Google)
  |-- Onboarding Flow             (multi-step: básico → astro → relacionamento
  |                                → hábitos → valores → personalidade →
  |                                → attachment style → prontidão emocional
  |                                → estilo de comunicação)
  |-- Profile Management          (view/edit — todos os campos do onboarding)
  |-- Astrology Engine            (biblioteca open-source local na Edge Function)
  |-- Compatibility Algorithm     (3 fases: filters → penalties → 4 blocks v2.0)
  |-- Matching Engine             (feed: slots, composite score, recycling)
  |-- Swipe System                (like, pass, super_like, undo, match creation)
  |-- Chat System                 (messages, ice-breakers, media, realtime)
  |-- Discovery Filters           (age, distance, compatibility, relationship type)
  |-- User Safety                 (block, report, moderation)
  |-- Journey Tab                 (mood tracker, daily rituals, zodiac predictions)
  |-- Mode: Dating                (swipe feed + chat + compatibility)
  |-- Mode: Couple                (rituais, diário, timeline, check-in, desafios,
  |                                insights premium, créditos, badges)
  |-- Mode: Wedding               (stub — oculto no MVP)
  |-- Mode: Life                  (stub — oculto no MVP)
  |-- Credits System              (saldo, compra, renovação mensal, webhooks IAP)
  |-- Notifications               (push via FCM/APNs + in-app — por categoria)
  |-- AI Pipeline                 (Claude API — rituais, explicações, prompts, insights)
  |-- Admin / Config              (weights, slots, feature_config, feature flags)
  |-- Analytics                   (PostHog/Mixpanel — eventos + propriedades globais)
```

---

## SEÇÃO 8 — 12 Regras de Ouro para a Equipe

Formalização das decisões que são fáceis de errar sob pressão de prazo.

| # | Regra | Por que importa |
|---|-------|----------------|
| 1 | **RLS em toda tabela** | Sem RLS, qualquer usuário autenticado lê dados de qualquer outro. Estado padrão do Supabase. |
| 2 | **SERVICE ROLE key = apenas Edge Functions** | Uma linha de cliente com essa chave ignora TODO o RLS. Incidente crítico imediato. |
| 3 | **Créditos = apenas Edge Function** | A tabela `credits` não tem policy de INSERT/UPDATE/DELETE para o cliente. Testar: UPDATE como cliente deve falhar. |
| 4 | **Cache de saída de IA** | Ritual gerado uma vez = cacheado na tabela `rituals`. Regenerar a cada carregamento de página = desastre de custo (~$0.003 por geração). |
| 5 | **Limites em `feature_config`, nunca no código** | "30 entradas de diário" hardcoded no app = novo deploy para mudar. Na tabela = alterar em 10 segundos sem deploy. |
| 6 | **Flags de modo em `profiles` adicionadas agora** | `wedding_mode_enabled` e `life_mode_enabled` custam zero. Não ter depois = migração em produção com dados reais. |
| 7 | **Stubs de telas em namespaces desde o dia 1** | WeddingPlaceholderScreen oculto existe no app. Quando o modo for lançado: habilitar e construir. Sem reorganização traumática. |
| 8 | **Todos os índices antes do primeiro usuário real** | Query de 2ms com 1K linhas = 8 segundos com 1M linhas. Índices depois = downtime para criar em tabela com dados. |
| 9 | **PgBouncer ativado em modo Transaction** | Sem pooling: 200 requests simultâneos = 200 conexões abertas = Postgres recusando conexões. |
| 10 | **CSAM antes de armazenar qualquer foto** | Obrigação legal. A Edge Function `upload_photo` executa CSAM antes de qualquer escrita no Storage. |
| 11 | **Astrologia = biblioteca local, sem API externa** | Custo zero por cálculo. Sem dependência. Calculado UMA VEZ no onboarding. Armazenado. Nunca recalcular. |
| 12 | **MBTI = implementação interna** | Sem licença, sem API, sem custo por uso. O questionário de 16 tipos é construído e pontuado pela equipe dentro do app. |

---

## Checklist de Implementação (Part D)

### 🔴 Crítico (antes do lançamento)

**TBDs resolvidos:**
- [ ] Definir e integrar biblioteca de astrologia open-source na Edge Function `calculate_birth_chart`
- [ ] Confirmar modelo Claude (`claude-sonnet-4-6`) nas Edge Functions de IA
- [ ] Atualizar `overview.md`: AI Pipeline e Astrology Engine com especificações finais

**Multi-modo:**
- [ ] `ALTER TABLE profiles` — adicionar 5 novas colunas (active_mode, 4 flags, subscription_tier)
- [ ] FlutterFlow — criar namespaces de telas por modo
- [ ] FlutterFlow — criar stubs ocultos para Wedding e Life mode

**Índices:**
- [ ] Criar `idx_user_personality_attachment` (attachment_style — Part A)
- [ ] Criar `idx_compat_scores_version` (scoring_version — Part A)
- [ ] Criar `idx_matches_archived` (matches arquivados — Part A)
- [ ] Criar todos os 18 índices do Modo Casal (Seção 3.2)

**Otimização de IA:**
- [ ] System prompt JSON estruturado em todas as Edge Functions de IA
- [ ] Geração em lote mensal na Edge Function `generate_weekly_rituals`
- [ ] Criar tabela `ritual_library` + seed com 200 rituais pré-escritos
- [ ] Criar tabela `ritual_library_used` (rastreamento de uso por casal)
- [ ] Implementar lógica de fallback na `generate_weekly_rituals`

**Connection pooling:**
- [ ] PgBouncer ativado no Supabase Pro (modo Transaction)
- [ ] Verificar que todas as Edge Functions usam string de conexão pooled (porta 6543)

### 🟡 Importante (1–2 semanas pós-lançamento)

- [ ] Atualizar `overview.md` com lista de módulos completa (Seção 7)
- [ ] Documentar fluxos de requisição por tipo (Seção 6) para a equipe
- [ ] Medir tokens/custo das primeiras semanas e ajustar thresholds de engajamento

---

## SQL Consolidado — Todas as Mudanças da Part D

```sql
-- ============================================================
-- PART D — Arquitetura e Escalabilidade
-- Versão: v1.0 | Março 2026
-- ============================================================

-- 1. FLAGS DE MULTI-MODO EM PROFILES
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS active_mode          TEXT DEFAULT 'dating'
    CHECK (active_mode IN ('dating', 'couple', 'wedding', 'life')),
  ADD COLUMN IF NOT EXISTS dating_mode_enabled  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS couple_mode_enabled  BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS wedding_mode_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS life_mode_enabled    BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS subscription_tier    TEXT DEFAULT 'free'
    CHECK (subscription_tier IN ('free', 'premium', 'premium_plus'));

-- 2. ÍNDICES FALTANDO — TABELAS EXISTENTES
CREATE INDEX IF NOT EXISTS idx_user_personality_attachment
  ON user_personality(attachment_style)
  WHERE attachment_style IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_compat_scores_version
  ON compatibility_scores(scoring_version);

CREATE INDEX IF NOT EXISTS idx_matches_archived_a
  ON matches(user_a, archived_at DESC)
  WHERE status = 'archived';

CREATE INDEX IF NOT EXISTS idx_matches_archived_b
  ON matches(user_b, archived_at DESC)
  WHERE status = 'archived';

-- 3. ÍNDICES — MODO CASAL (criar após Part B schema)
CREATE INDEX IF NOT EXISTS idx_couples_user_a_active
  ON couples(user_a_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_couples_user_b_active
  ON couples(user_b_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_couples_deletion_scheduled
  ON couples(deletion_scheduled_at) WHERE deletion_scheduled_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rituals_couple_week
  ON rituals(couple_id, week_number DESC);
CREATE INDEX IF NOT EXISTS idx_rituals_pending_generation
  ON rituals(generated_at)
  WHERE completed_a_at IS NULL AND completed_b_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_rituals_couple_track
  ON rituals(couple_id, track, week_number DESC);

CREATE INDEX IF NOT EXISTS idx_journal_couple_date
  ON journal_entries(couple_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_journal_author
  ON journal_entries(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_journal_shared
  ON journal_entries(couple_id) WHERE shared_with_partner = true;

CREATE INDEX IF NOT EXISTS idx_timeline_couple_date
  ON timeline_events(couple_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_timeline_category
  ON timeline_events(couple_id, category);

CREATE INDEX IF NOT EXISTS idx_checkin_couple_week
  ON check_ins(couple_id, week_number DESC);
CREATE INDEX IF NOT EXISTS idx_checkin_visible_after
  ON check_ins(visible_after) WHERE both_completed = false;

CREATE INDEX IF NOT EXISTS idx_challenges_couple_active
  ON challenges(couple_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_challenges_status
  ON challenges(couple_id, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_credits_user
  ON credits(user_id);
CREATE INDEX IF NOT EXISTS idx_credits_refresh_pending
  ON credits(last_refreshed_at)
  WHERE last_refreshed_at < DATE_TRUNC('month', CURRENT_DATE);

CREATE INDEX IF NOT EXISTS idx_insights_couple_week
  ON couple_insights(couple_id, week_number DESC);
CREATE INDEX IF NOT EXISTS idx_insights_retrospective
  ON couple_insights(couple_id, type) WHERE type = 'retrospective';

CREATE INDEX IF NOT EXISTS idx_badges_couple
  ON badges(couple_id, earned_at DESC);

-- 4. TABELA DA BIBLIOTECA DE RITUAIS PRÉ-ESCRITOS
CREATE TABLE IF NOT EXISTS ritual_library (
  library_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track               TEXT NOT NULL
    CHECK (track IN ('emotional','communication','intellectual','adventure','gratitude','playful')),
  title               TEXT NOT NULL,
  insight             TEXT NOT NULL,
  practice            TEXT NOT NULL,
  reflection_question TEXT NOT NULL,
  difficulty          SMALLINT DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 3),
  created_at          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ritual_library_used (
  couple_id  UUID REFERENCES couples(couple_id),
  library_id UUID REFERENCES ritual_library(library_id),
  used_at    TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (couple_id, library_id)
);

-- RLS
ALTER TABLE ritual_library ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ritual_library_readable" ON ritual_library
  FOR SELECT TO authenticated USING (true);

ALTER TABLE ritual_library_used ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ritual_library_used_own" ON ritual_library_used
  FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));
```

---

*Documento de mudanças Part D — gerado em Março 2026*
*Referências: `docs/overview.md` · `docs/schema.sql` linhas 935–1003 · `docs/matching-engine.md` · Auro Developer Handoff v1.0 Part D*

# PART F — Mudanças: Product Logic Addendum
**Status:** Atualização de lógica de produto — afeta Modo Casal, Journal, Streak, Milestones, Paywall
**Referência:** Product Logic Addendum (Alix Liasse, Março 2026) · Aprovado por CEO (Dércio da Barca)
**Afeta:** `docs/schema.sql` (v2.1) · `docs/couple-mode.md` · `changes/part-b-modo-casal.md`

> Este documento registra TODAS as mudanças derivadas do Product Logic Addendum. O addendum é a referência autoritativa para: ritual semanal, journal, milestones, streak, free vs premium, e paywall triggers.

---

## Estado Atual vs Novo

| O que existia (v2.0) | O que muda na Part F (v2.1) |
|----------------------|----------------------------|
| `couple_journal_entries` com `is_shared` e mood antigo (joyful, grateful, etc.) | Journal SEMPRE privado. `is_shared` removido. Mood novo: exhausted/tense/ok/good/great. `prompt_week` adicionado. |
| `couple_rituals` com `description`, `ritual_type` (daily/weekly/special), sem campos de insight/practice/reflection | Ritual SEMANAL apenas. Campos `insight`, `practice`, `reflection_question` adicionados. `description` mantido como fallback. `ritual_type` fixado em `weekly`. |
| `couples.current_level` — sistema de níveis 1-N | `current_level` REMOVIDO. Substituído por milestones (celebração, não rating). |
| Streak baseado em dias (7_day_streak, 30_day_streak) | Streak SEMANAL. Pausa em vez de resetar. Premium: proteção + recovery. |
| Sem tabela de milestones | Nova tabela `couple_milestones` — 4 semanas, 3 meses, 6 meses, 1 ano |
| Sem tabela de progressão | Nova tabela `couple_progression` — pontos semanais por ação |
| Sem tabela de paywall | Nova tabela `paywall_events` — 11 triggers definidos |
| Sem biblioteca de prompts do journal | Nova tabela `journal_prompts` — 12 prompts rotativos |
| `feature_config` sem entradas de addendum | Novas entradas: journal (30), timeline (10), streak protection, etc. |
| RLS do journal permitia leitura de `is_shared = true` | RLS simplificado: apenas autor lê. Parceiro NUNCA vê. |

---

## SEÇÃO 1 — Mudanças no Schema

### 1.1 — Novos ENUMs

```sql
-- Mood do journal — 5 estados, 1 toque
CREATE TYPE journal_mood_type AS ENUM (
  'exhausted',  -- 😴
  'tense',      -- 😤
  'ok',         -- 😐
  'good',       -- 🙂
  'great'       -- ✨
);

-- Tipos de milestone do casal
CREATE TYPE milestone_type AS ENUM (
  '4_weeks',
  '3_months',
  '6_months',
  '1_year'
);

-- Tipos de paywall trigger
CREATE TYPE paywall_trigger_type AS ENUM (
  'journal_limit',
  'timeline_limit',
  'extra_ritual',
  'credits_low',
  'streak_protection',
  'challenge_unlock',
  'ai_journal_prompt',
  'streak_week_25',
  'milestone_3_months',
  'milestone_challenge',
  'partner_premium'
);
```

---

### 1.2 — ALTER `couples` — Remover nível, ajustar streak

```sql
-- Remover sistema de níveis (substituído por milestones)
ALTER TABLE couples DROP COLUMN IF EXISTS current_level;

-- Adicionar campos de streak semanal com pausa
ALTER TABLE couples
  ADD COLUMN IF NOT EXISTS streak_paused_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS streak_protection_used TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS streak_recovered_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notification_day       SMALLINT DEFAULT 0
    CHECK (notification_day BETWEEN 0 AND 6);
    -- 0 = domingo, 1 = segunda... Casal define no onboarding.
```

**Mudança no `current_streak`:** O campo já existe. A semântica muda:
- **Antes:** contava dias consecutivos de ritual
- **Agora:** conta SEMANAS consecutivas com ritual completo por ambos

**Lógica de pausa (implementar na Edge Function):**
```
Se casal não completou ritual na semana:
  SE streak_protection disponível (premium, 1/mês):
    → usar proteção, streak NÃO quebra
    → streak_protection_used = NOW()
  SENÃO:
    → streak_paused_at = NOW()
    → current_streak NÃO reseta (diferente de antes)

Quando casal retorna e completa ritual:
  → streak_paused_at = NULL
  → current_streak += 1 (retoma de onde parou)

Streak Recovery (premium, 48h):
  SE streak quebrou há < 48h:
    → streak_recovered_at = NOW()
    → current_streak restaurado
```

---

### 1.3 — ALTER `couple_journal_entries` — Journal sempre privado

```sql
-- 1. Remover coluna de compartilhamento (journal é SEMPRE privado)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS is_shared;

-- 2. Remover coluna title (journal é mood + texto, não diário tradicional)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS title;

-- 3. Remover coluna tags (não usado no novo modelo)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS tags;

-- 4. Remover coluna updated_at (entradas não são editáveis)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS updated_at;

-- 5. Alterar mood para novo enum (obrigatório)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS mood;
ALTER TABLE couple_journal_entries
  ADD COLUMN mood journal_mood_type NOT NULL DEFAULT 'ok';

-- 6. Renomear content para free_text e tornar opcional
ALTER TABLE couple_journal_entries RENAME COLUMN content TO free_text;
ALTER TABLE couple_journal_entries ALTER COLUMN free_text DROP NOT NULL;

-- 7. Adicionar semana do prompt rotativo (1-12)
ALTER TABLE couple_journal_entries
  ADD COLUMN IF NOT EXISTS prompt_week SMALLINT CHECK (prompt_week BETWEEN 1 AND 12);

-- 8. Adicionar semana ISO para vincular ao ritual
ALTER TABLE couple_journal_entries
  ADD COLUMN IF NOT EXISTS week_number INT;
```

**Estrutura final de `couple_journal_entries`:**

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `id` | UUID PK | Sim | — |
| `couple_id` | UUID FK | Sim | Referência ao casal |
| `author_id` | UUID FK | Sim | Quem escreveu |
| `mood` | journal_mood_type | Sim | Seletor de 5 estados (1 toque) |
| `free_text` | TEXT | Não | Texto livre opcional |
| `prompt_week` | SMALLINT (1-12) | Não | Qual prompt rotativo foi exibido |
| `week_number` | INT | Não | Semana ISO — vincula ao ritual da semana |
| `created_at` | TIMESTAMPTZ | Sim | — |

---

### 1.4 — ALTER `couple_rituals` — Formato de 3 seções

```sql
-- Adicionar campos de 3 seções (Insight + Practice + Reflection Question)
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS insight             TEXT,
  ADD COLUMN IF NOT EXISTS practice            TEXT,
  ADD COLUMN IF NOT EXISTS reflection_question TEXT;

-- Adicionar week_number para vincular ao journal
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS week_number INT;

-- Adicionar campos de completude por parceiro (ambos devem completar)
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS completed_a_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_b_at TIMESTAMPTZ;

-- Adicionar mood dos parceiros no momento da geração (para auditoria)
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS journal_mood_a journal_mood_type,
  ADD COLUMN IF NOT EXISTS journal_mood_b journal_mood_type;

-- Adicionar versão do prompt/modelo de IA usado
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS ai_version TEXT;

-- Constraint: um ritual por casal por semana
ALTER TABLE couple_rituals
  ADD CONSTRAINT IF NOT EXISTS unique_couple_ritual_week UNIQUE (couple_id, week_number);

-- Atualizar ritual_type CHECK para remover 'daily' (rituais são semanais apenas)
-- Nota: em Postgres, alterar CHECK requer drop + add
ALTER TABLE couple_rituals DROP CONSTRAINT IF EXISTS couple_rituals_ritual_type_check;
ALTER TABLE couple_rituals
  ADD CONSTRAINT couple_rituals_ritual_type_check
  CHECK (ritual_type IN ('weekly', 'special'));
```

**Estrutura final de `couple_rituals` (campos relevantes):**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `title` | TEXT | Título do ritual (ex: "Arriving before speaking") |
| `insight` | TEXT | 2-3 frases de contexto emocional |
| `practice` | TEXT | Ação específica da semana (100-200 palavras) |
| `reflection_question` | TEXT | Pergunta para o casal (máx 25 palavras) |
| `week_number` | INT | Semana ISO |
| `completed_a_at` | TIMESTAMPTZ | Quando parceiro A completou |
| `completed_b_at` | TIMESTAMPTZ | Quando parceiro B completou |
| `journal_mood_a` | journal_mood_type | Mood do parceiro A na geração |
| `journal_mood_b` | journal_mood_type | Mood do parceiro B na geração |
| `ai_version` | TEXT | Versão do modelo/prompt |

---

### 1.5 — Nova tabela: `couple_milestones`

Milestones são celebrações, não ratings. Nunca bloqueiam acesso a features.

```sql
CREATE TABLE couple_milestones (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  milestone       milestone_type NOT NULL,
  weeks_required  SMALLINT NOT NULL,
  reached_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  celebrated_at   TIMESTAMPTZ,  -- quando o casal viu a celebração
  is_premium_only BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, milestone)
);
```

**Milestones definidos:**

| Milestone | Trigger | Semanas | Premium Only | Celebração |
|-----------|---------|---------|-------------|-----------|
| `4_weeks` | 4 semanas consecutivas, ritual completo por ambos | 4 | Não | Tela especial + badge. "One month of showing up." |
| `3_months` | 12 semanas consecutivas | 12 | Não | Ritual especial gerado por IA refletindo a jornada de 12 semanas |
| `6_months` | 26 semanas consecutivas | 26 | Sim | Retrospectiva mensal — padrões, rituais completados, momentos de crescimento |
| `1_year` | 52 semanas consecutivas | 52 | Sim | Ritual de aniversário personalizado com dados de 1 ano |

---

### 1.6 — Nova tabela: `couple_progression`

Sistema de pontos semanais. Pontos acumulam para milestones e engagement tracking.

```sql
CREATE TABLE couple_progression (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  week_number INT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN (
    'ritual_completed_both',    -- 50 pts (ambos completaram)
    'ritual_completed_one',     -- 25 pts (apenas um completou)
    'reflection_answered_both', -- 20 pts
    'journal_entry_a',          -- 20 pts
    'journal_entry_b',          -- 20 pts
    'challenge_completed'       -- 10 pts
  )),
  points      SMALLINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice para consulta semanal
CREATE INDEX idx_progression_couple_week ON couple_progression(couple_id, week_number);
```

**Regras de pontuação:**

| Ação | Pontos | Condição |
|------|--------|----------|
| Ritual completo — ambos parceiros | 50 | Ambos devem completar para pontuação total |
| Ritual completo — apenas um | 25 | Se apenas um parceiro completou |
| Reflection Question respondida — ambos | 20 | Ambos devem responder |
| Journal entry preenchido (por parceiro) | 20 | Por parceiro por semana. Máx 40 pts/semana de journal |
| Challenge completado | 10 | Bônus — não bloqueia progressão |

**Regra dos dois parceiros:** Milestones são do CASAL, não individuais. Ambos precisam participar para progressão completa.

---

### 1.7 — Nova tabela: `paywall_events`

Registra cada vez que um paywall trigger é exibido ao usuário. Para analytics e otimização de conversão.

```sql
CREATE TABLE paywall_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  couple_id    UUID REFERENCES couples(id) ON DELETE SET NULL,
  trigger_type paywall_trigger_type NOT NULL,
  context      JSONB,        -- dados contextuais (ex: streak_week, milestone_type)
  presented_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  converted_at TIMESTAMPTZ,  -- se o usuário converteu neste momento
  dismissed_at TIMESTAMPTZ   -- se o usuário dispensou
);

-- Índice para analytics
CREATE INDEX idx_paywall_user ON paywall_events(user_id, presented_at DESC);
CREATE INDEX idx_paywall_trigger ON paywall_events(trigger_type);
CREATE INDEX idx_paywall_conversion ON paywall_events(converted_at) WHERE converted_at IS NOT NULL;
```

**Os 11 triggers:**

| # | Trigger | Contexto | Tipo de UI | Princípio do Copy |
|---|---------|----------|-----------|-------------------|
| 1 | `journal_limit` | 30 entradas atingidas | Banner suave | "Unlock unlimited journaling." Nunca: 'limit reached.' |
| 2 | `timeline_limit` | 10 eventos atingidos | Banner suave | "Keep building your story together." |
| 3 | `extra_ritual` | Pedido de ritual extra na semana | Feature preview | "Want another ritual this week? Premium couples can." |
| 4 | `credits_low` | Saldo ≤ 2 créditos | Banner suave | "2 credits left. Upgrade for unlimited." |
| 5 | `streak_protection` | Tentou proteger streak | Modal | "Protect what you've built. One missed week won't break it on Premium." |
| 6 | `challenge_unlock` | Challenge premium bloqueado | Feature preview | Mostrar preview do challenge. "Unlock this with Premium." |
| 7 | `ai_journal_prompt` | Tocou em prompt IA personalizado | Banner suave | "This prompt was made for you. Premium gets AI prompts every week." |
| 8 | `streak_week_25` | Celebração de 25 semanas | Celebração → upsell | Celebrar primeiro. Depois: "25 weeks together. Protect every one of them." |
| 9 | `milestone_3_months` | Milestone de 3 meses atingido | Celebração → upsell | Celebrar. Mostrar o que o milestone de 6 meses desbloqueia no Premium. |
| 10 | `milestone_challenge` | Challenge de milestone completado | Celebração → soft upsell | Celebrar. "More milestone challenges unlock with Premium." |
| 11 | `partner_premium` | Parceiro já é premium | Nudge pessoal | "[Nome] upgraded. Join them on Premium — rituals are better together." |

**Princípio universal:** Mostrar valor, nunca culpa. 'Unlock unlimited writing' — nunca 'You've reached your limit.'

---

### 1.8 — Nova tabela: `journal_prompts`

Biblioteca de 12 prompts rotativos. Semanas 1-6 neutras, semanas 7/10/12 mais vulneráveis.

```sql
CREATE TABLE journal_prompts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_number  SMALLINT NOT NULL UNIQUE CHECK (week_number BETWEEN 1 AND 12),
  prompt_text  TEXT NOT NULL,
  is_vulnerable BOOLEAN NOT NULL DEFAULT false,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed: 12 prompts rotativos
INSERT INTO journal_prompts (week_number, prompt_text, is_vulnerable) VALUES
  (1,  'What has been taking up most of your headspace this week?', false),
  (2,  'How are you arriving to this ritual — present or distracted?', false),
  (3,  'Is there something you didn''t say but wanted to?', false),
  (4,  'What do you need most this week — space or closeness?', false),
  (5,  'How do you feel about the two of you right now?', false),
  (6,  'What gave you energy this week? What took it away?', false),
  (7,  'Is there something your partner doesn''t know you''re feeling?', true),
  (8,  'One word about your day?', false),
  (9,  'What do you want to bring to this ritual today?', false),
  (10, 'Is there anything you want AURO to know before we begin?', true),
  (11, 'How do you feel about the week ahead?', false),
  (12, 'Something small you''d like your partner to know?', true);
```

**Regra de sequência:**
- Semanas 1-6: prompts neutros. O usuário está construindo confiança com o produto.
- Semanas 7, 10, 12 (`is_vulnerable = true`): mais vulneráveis. Só aparecem após consistência.
- Após semana 12: ciclo repete. Biblioteca pode ser expandida no futuro.

---

### 1.9 — Atualizar `feature_config` seed data

```sql
-- Novas entradas para o Product Logic Addendum
INSERT INTO feature_config (feature_key, free_limit, premium_limit, unit, description) VALUES
  -- Journal
  ('couple_journal_entries',     30,    NULL, 'count',     'Max journal entries (free tier). Unlimited for premium.'),
  ('couple_journal_ai_prompts',  0,     NULL, 'per_week',  'AI-personalised journal prompts. Free = standard rotating only.'),
  ('couple_journal_history',     30,    NULL, 'count',     'Visible journal history. Free = last 30. Premium = full + patterns.'),
  -- Timeline
  ('couple_timeline_events',     10,    NULL, 'count',     'Max timeline events (free tier). Unlimited for premium.'),
  -- Streak
  ('couple_streak_protection',   0,       1, 'per_month', 'Grace weeks per month. Free = 0. Premium = 1.'),
  ('couple_streak_recovery',     0,       1, 'per_streak','Streak recovery within 48h. Free = no. Premium = yes.'),
  ('couple_streak_insights',     0,    NULL, 'boolean',   'Streak pattern insights. Premium only.'),
  -- Milestones
  ('couple_milestone_extended',  0,    NULL, 'boolean',   '6-month + 1-year milestones with AI retrospective. Premium only.'),
  -- Rituals
  ('couple_ritual_extra',        0,    NULL, 'per_week',  'Extra on-demand rituals beyond 1/week. Premium only.'),
  -- Insights
  ('couple_weekly_insight_full', 0,    NULL, 'boolean',   'Full weekly insight. Free = first sentence teaser only.')
ON CONFLICT (feature_key) DO NOTHING;

-- Atualizar entradas existentes que mudaram
UPDATE feature_config
SET free_limit = 30, unit = 'count', description = 'Max private journal entries (free tier) — was 5, now 30 per addendum'
WHERE feature_key = 'couple_journal_private';
```

---

### 1.10 — RLS: Journal SEMPRE privado

```sql
-- Remover política antiga que permitia leitura de is_shared = true
DROP POLICY IF EXISTS "journal_select" ON couple_journal_entries;

-- Nova política: APENAS o autor lê as próprias entradas
-- O parceiro NUNCA vê. A IA extrai temas — nunca texto literal.
CREATE POLICY "journal_select_author_only" ON couple_journal_entries
  FOR SELECT TO authenticated
  USING (author_id = auth.uid());

-- INSERT: apenas o próprio autor
DROP POLICY IF EXISTS "journal_insert" ON couple_journal_entries;
CREATE POLICY "journal_insert_own" ON couple_journal_entries
  FOR INSERT TO authenticated
  WITH CHECK (author_id = auth.uid());

-- UPDATE: bloqueado. Entradas de journal não são editáveis.
DROP POLICY IF EXISTS "journal_update" ON couple_journal_entries;
-- Sem política de UPDATE = bloqueado por RLS.

-- DELETE: bloqueado para o cliente. Apenas service_role (Edge Function) pode deletar.
-- Sem política de DELETE = bloqueado por RLS.
```

**Privacidade — o que cada ator vê:**

| Ator | O que vê |
|------|----------|
| O próprio usuário | Suas entradas de journal (histórico) |
| O parceiro | NADA. Nunca. Nem texto, nem mood, nem que a entrada existe. |
| A IA (Edge Function, service_role) | Texto + mood de ambos para gerar ritual. Extrai TEMAS, não texto literal. |
| Equipe AURO | Dados agregados e anonimizados. Nunca entradas individuais. |

---

### 1.11 — RLS para novas tabelas

```sql
-- couple_milestones
ALTER TABLE couple_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "milestones_select" ON couple_milestones FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_progression
ALTER TABLE couple_progression ENABLE ROW LEVEL SECURITY;
CREATE POLICY "progression_select" ON couple_progression FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
-- INSERT/UPDATE apenas por service_role (Edge Functions)

-- paywall_events
ALTER TABLE paywall_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paywall_select_own" ON paywall_events FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "paywall_insert_own" ON paywall_events FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- journal_prompts (leitura pública — conteúdo curado, sem dados de usuário)
ALTER TABLE journal_prompts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "journal_prompts_select" ON journal_prompts FOR SELECT TO authenticated
  USING (is_active = true);
```

---

### 1.12 — Novos índices

```sql
-- couple_milestones
CREATE INDEX idx_milestones_couple ON couple_milestones(couple_id);

-- couple_journal_entries — atualizar para novo modelo
DROP INDEX IF EXISTS idx_journal_shared;  -- não existe mais is_shared
CREATE INDEX idx_journal_couple_week ON couple_journal_entries(couple_id, week_number);

-- couple_rituals — por week_number
CREATE INDEX idx_rituals_couple_week_v2 ON couple_rituals(couple_id, week_number);

-- paywall_events — para analytics de conversão
CREATE INDEX idx_paywall_conversion_rate ON paywall_events(trigger_type, converted_at);
```

---

### 1.13 — Novos pg_cron jobs

```sql
-- Processar streak semanal (domingo 23:59 UTC)
-- Verifica se cada casal ativo completou ritual na semana
SELECT cron.schedule(
  'process-weekly-streak',
  '59 23 * * 0',
  $$
  -- Casais que completaram ritual esta semana: incrementar streak
  UPDATE couples SET
    current_streak = current_streak + 1,
    streak_paused_at = NULL
  WHERE status = 'active'
  AND id IN (
    SELECT couple_id FROM couple_rituals
    WHERE week_number = EXTRACT(ISOYEAR FROM now()) * 100 + EXTRACT(WEEK FROM now())
    AND completed_a_at IS NOT NULL
    AND completed_b_at IS NOT NULL
  );
  $$
);

-- Verificar milestones após atualização de streak (segunda 00:05 UTC)
SELECT cron.schedule(
  'check-milestones',
  '5 0 * * 1',
  $$
  -- 4 semanas
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '4_weeks', 4, false FROM couples
  WHERE status = 'active' AND current_streak >= 4
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '4_weeks')
  ON CONFLICT DO NOTHING;

  -- 3 meses (12 semanas)
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '3_months', 12, false FROM couples
  WHERE status = 'active' AND current_streak >= 12
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '3_months')
  ON CONFLICT DO NOTHING;

  -- 6 meses (26 semanas) — premium only
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '6_months', 26, true FROM couples
  WHERE status = 'active' AND current_streak >= 26
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '6_months')
  ON CONFLICT DO NOTHING;

  -- 1 ano (52 semanas) — premium only
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '1_year', 52, true FROM couples
  WHERE status = 'active' AND current_streak >= 52
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '1_year')
  ON CONFLICT DO NOTHING;
  $$
);
```

---

## SEÇÃO 2 — Mudanças na Geração de Rituais

### Antes vs Depois

| Aspecto | Antes (v2.0) | Depois (v2.1 — Addendum) |
|---------|-------------|-------------------------|
| Frequência | Diário + semanal | SEMANAL apenas |
| Seções | `title` + `description` | `title` + `insight` + `practice` + `reflection_question` |
| Input | Perfil base apenas | Perfil base + journal de AMBOS os parceiros |
| Adaptação | Estática | Dinâmica — ajusta ao estado emocional da semana |
| Geração em lote | 4 weekly + 30 daily/mês | 1 por semana, sob demanda |

### Prompt atualizado para IA

```
"Generate a weekly ritual for a couple with this profile:
Partner A — {attachment_style_a} attachment, love language: {love_language_a},
  communication: {communication_style_a}.
  Journal this week: mood = {mood_a}. Free text: {free_text_a_or_empty}.
Partner B — {attachment_style_b} attachment, love language: {love_language_b},
  communication: {communication_style_b}.
  Journal this week: mood = {mood_b}. Free text: {free_text_b_or_empty}.
Together {weeks_together} weeks. Last completed tracks: {last_4_tracks}.
Return JSON with: title, insight (2-3 sentences), practice (100-200 words),
  reflection_question (max 25 words).
{energy_calibration_instruction}"
```

**Instrução de calibração de energia (dinâmica):**

| Cenário | Instrução adicional |
|---------|---------------------|
| Parceiro A exausto, B ok | "Keep the ritual light given Partner A's energy. Practice should be something Partner B can initiate." |
| Ambos tensos | "Decompression ritual. Focus on gratitude and lightness. No deep exploration." |
| Ambos ótimos | "More challenging ritual. Use available energy for intellectual or adventure track." |
| Um ansioso, outro ok | "Include space for the calm partner to show support. Practice oriented toward emotional presence." |

### Privacidade na geração

A IA recebe o texto do journal via **Edge Function (service_role)**. O processo:

1. Edge Function lê journal entries de ambos parceiros (service_role ignora RLS)
2. IA recebe mood + texto livre (ou vazio) de cada parceiro
3. IA gera ritual com base nos temas — NÃO no texto literal
4. Ritual é armazenado em `couple_rituals`
5. Texto do journal NUNCA aparece no output do ritual
6. Raw journal NUNCA é acessível ao parceiro

---

## SEÇÃO 3 — Mudanças no Journal

### Novo fluxo UX (< 15 segundos)

```
1. Usuário abre AURO → tela de journal é o entry point para o ritual
2. Toca mood selector (obrigatório, 1 toque) → 2 segundos
3. Texto livre opcional com prompt rotativo → 0-30 segundos
4. Toca "Start ritual" → 1 segundo
5. Ritual apresentado (gerado com os inputs da semana)
```

### Disclaimers (3 locais)

| Local | Formato | Quando | Copy |
|-------|---------|--------|------|
| Onboarding | Card de texto completo | Uma vez | "Your journal is completely private. Your partner never sees what you write — ever. AURO uses what you share to understand how you're arriving to each week. Not to analyse you — to make that week's ritual more relevant for both of you." |
| Tela do journal | Texto cinza pequeno abaixo do campo | Sempre | "Only AURO reads this. Your responses are never shared with your partner — and they help make this week's ritual more relevant for both of you." |
| Primeira entrada | Tooltip, uma vez | Uma vez — desaparece | "What you share here helps AURO personalise your weekly ritual. Your partner never has access to these responses." |

### Edge states

| Cenário | Comportamento |
|---------|--------------|
| Parceiro A preencheu, B não | Ritual gerado com input de A + perfil base. B não é penalizado. |
| Nenhum preencheu | Ritual gerado do perfil base apenas. Comportamento padrão. |
| B preenche depois que ritual já foi gerado | Input não é retroativo. Entra no ciclo da próxima semana. |
| Input do journal conflita com perfil base | Journal tem precedência. É mais recente. Perfil é contexto — journal é estado atual. |

---

## SEÇÃO 4 — Mudanças no Streak

### Antes vs Depois

| Aspecto | Antes (v2.0) | Depois (v2.1 — Addendum) |
|---------|-------------|-------------------------|
| Unidade | Diário (7_day_streak, 30_day_streak) | SEMANAL (4_weeks, 12_weeks, 25_weeks...) |
| Quando quebra | Reset para zero | PAUSA — nunca reseta |
| Pressão | Implícita (contagem diária) | ZERO — sem culpa, sem owl chorando |
| Premium: proteção | Não | 1 semana de graça/mês |
| Premium: recovery | Não | Recuperar dentro de 48h |
| Premium: insights | Não | "You're most consistent on Sundays." Padrões ao longo do tempo. |

### Badges de streak atualizados

| Badge antigo | Badge novo | Trigger |
|-------------|-----------|---------|
| `7_day_streak` | `streak_4_weeks` | 4 semanas consecutivas |
| `30_day_streak` | `streak_12_weeks` | 12 semanas consecutivas |
| — | `streak_25_weeks` | 25 semanas (trigger de paywall) |
| — | `streak_52_weeks` | 52 semanas (1 ano) |

---

## SEÇÃO 5 — Free vs Premium — Lógica Completa

### Tabela consolidada

| Feature | Free | Premium |
|---------|------|---------|
| Ritual semanal | 1/semana — AI-generated | Ilimitado + extra on-demand |
| Journal entries | Até 30 total | Ilimitado |
| Journal mood selector | Incluído | Incluído |
| Journal texto livre | Incluído — alimenta IA | Incluído — alimenta IA |
| Journal prompts rotativos | Sim — biblioteca padrão | Sim + prompts IA personalizados por histórico |
| Journal histórico | Últimas 30 entradas | Histórico completo + padrões ao longo do tempo |
| Timeline events | Até 10 | Ilimitado |
| Streak tracking | Sim — contagem semanal | Sim — contagem semanal |
| Streak comportamento quando não usa | Streak pausa. Não reseta. | Igual |
| Milestone badges (4, 8, 12 semanas) | Sim — tela de celebração | Sim — tela de celebração |
| Streak Protection | Não | 1 semana de graça/mês |
| Streak Recovery | Não | Recuperar dentro de 48h |
| Streak Insights | Não | Padrões ao longo do tempo |
| Milestones estendidos (6 meses, 1 ano) | Não | Sim — IA retrospectiva |
| Weekly Insights tela | Primeira frase apenas — teaser | Insight semanal completo gerado por IA |
| Challenges | Básicos apenas | Todos incluindo milestone + exclusivos |
| Créditos | Limitados | Sem limites |

---

## SEÇÃO 6 — MVP vs Futuro

### O que construir AGORA (MVP)

| Feature | MVP |
|---------|-----|
| Journal mood | 5 estados, emoji selector, 1 toque |
| Journal texto | Prompts rotativos, texto opcional |
| Journal uso no ritual | Alimenta gerador de ritual semanal |
| Journal histórico | Inputs usados e descartados (sem histórico armazenado no MVP) |
| Compartilhamento | Nunca — privacidade total |
| Frequência | Semanal (antes do ritual) |

### O que construir DEPOIS (Visão Futura)

| Feature | Futuro |
|---------|--------|
| Journal mood | Slider contínuo + detecção de padrões |
| Journal texto | Input de voz — 30s falado, IA transcreve e extrai temas |
| Journal uso | Também alimenta insights semanais premium + retrospectiva mensal |
| Journal histórico | Love Map — padrões do journal ao longo do tempo, visível apenas para o usuário |
| Compartilhamento | Opcional: usuário pode escolher compartilhar uma entrada específica |
| Frequência | Diário opcional para premium — alimenta insights com maior granularidade |

### A razão para não construir tudo agora

> O MVP precisa provar UMA coisa: que inputs do journal fazem o ritual significativamente mais relevante — o suficiente para os casais notarem e valorizarem a diferença.
>
> Se essa prova existir nos dados do beta — retenção na semana 4, feedback qualitativo — então a visão futura tem uma base real. Se não, melhor saber antes de construir a versão completa.

---

## SEÇÃO 7 — Notificações do Journal

### Variantes de notificação semanal

Enviada no início da semana. Domingo à noite ou segunda de manhã — casal define preferência no onboarding (campo `couples.notification_day`).

| Variante | Copy |
|----------|------|
| Default | "Your ritual for this week is ready. How are you arriving?" |
| Light | "New week, new ritual. Two seconds before we begin?" |
| Com contexto | "AURO has something prepared for the two of you. Tell us how you're doing first." |
| Minimalista | "This week's ritual ↗" |

---

## Checklist de Implementação (Part F)

### Schema (prioridade máxima)
- [ ] Criar ENUMs: `journal_mood_type`, `milestone_type`, `paywall_trigger_type`
- [ ] ALTER `couples`: remover `current_level`, adicionar streak pause/protection fields
- [ ] ALTER `couple_journal_entries`: remover `is_shared`/`title`/`tags`/`updated_at`, adicionar `mood`/`prompt_week`/`week_number`
- [ ] ALTER `couple_rituals`: adicionar `insight`/`practice`/`reflection_question`/`week_number`/`completed_a_at`/`completed_b_at`/`journal_mood_a`/`journal_mood_b`/`ai_version`, remover `daily` de ritual_type
- [ ] Criar tabela `couple_milestones` + RLS
- [ ] Criar tabela `couple_progression` + RLS
- [ ] Criar tabela `paywall_events` + RLS
- [ ] Criar tabela `journal_prompts` + seed 12 prompts
- [ ] Atualizar `feature_config` seed data
- [ ] Atualizar RLS do journal (autor-only, sem shared)
- [ ] Criar novos índices
- [ ] Criar novos pg_cron jobs (streak, milestones)

### Edge Functions (atualizar)
- [ ] `generate_weekly_ritual` — novo prompt com 3 seções + journal input
- [ ] `process_weekly_streak` — lógica de pausa, proteção, recovery
- [ ] `check_milestones` — verificar e registrar milestones
- [ ] `track_paywall_event` — registrar os 11 triggers
- [ ] `get_journal_prompt` — retornar prompt rotativo da semana

### Analytics (novos eventos)
- [ ] `journal_mood_submitted` — mood selecionado
- [ ] `journal_text_submitted` — texto livre preenchido (flag, não conteúdo)
- [ ] `ritual_insight_viewed` — insight do ritual visualizado
- [ ] `ritual_practice_completed` — prática completada
- [ ] `ritual_reflection_answered` — reflection question respondida
- [ ] `milestone_reached` — milestone atingido
- [ ] `milestone_celebrated` — celebração visualizada
- [ ] `paywall_presented` — paywall exibido (com trigger_type)
- [ ] `paywall_converted` — usuário converteu
- [ ] `paywall_dismissed` — usuário dispensou
- [ ] `streak_paused` — streak pausado
- [ ] `streak_resumed` — streak retomado
- [ ] `streak_protected` — proteção de streak usada
- [ ] `streak_recovered` — streak recuperado

---

*Documento de mudanças Part F — gerado em Março 2026*
*Referências: Product Logic Addendum (Alix Liasse) · `docs/schema.sql` v2.1 · `docs/couple-mode.md`*

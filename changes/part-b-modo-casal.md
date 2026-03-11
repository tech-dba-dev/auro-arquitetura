# PART B — Mudanças: Modo Casal
**Status:** Feature nova — não existe na arquitetura atual
**Referência:** `docs/overview.md` (menção TBD) · Auro Developer Handoff v1.0 Part B

> ⚠️ **ATENÇÃO — PARTE PARCIALMENTE SUPERSEDED PELA PART F**
> A Part F (Product Logic Addendum, Março 2026) atualiza as seguintes áreas desta Part B:
> - **Journal**: agora é SEMPRE privado (sem `shared_with_partner`). Mood mudou para 5 estados (exhausted/tense/ok/good/great). Ver Part F §1.3.
> - **Rituais**: agora SEMANAL apenas (sem diário). Formato de 3 seções (insight + practice + reflection_question). Ver Part F §1.4.
> - **Streak**: agora SEMANAL, pausa em vez de resetar. Ver Part F §4.
> - **Milestones**: `current_level` removido. Substituído por milestone celebrations. Ver Part F §1.5.
> - **Paywall**: 11 triggers definidos. Ver Part F §1.7.
> Para a versão mais recente, sempre consultar `changes/part-f-product-logic-addendum.md` e `docs/schema.sql` (seção v2.1).

> O Modo Casal era marcado como **TBD** em toda a documentação existente. Este documento especifica a arquitetura completa do zero: schema, IA, créditos, ativação e segurança psicológica.

---

## Estado Atual vs Novo

| O que existia | O que entra na Part B |
|--------------|----------------------|
| `overview.md`: "Mode: Couple — relationship tools — TBD" | 10 novas tabelas completas |
| `user_modes` com enum `couple` como opção | Lógica completa de ativação de casal |
| Nenhuma tabela de casal, ritual, diário, crédito | Sistema de IA, créditos, desafios, timeline |
| Nenhuma Edge Function de Modo Casal | 5 novas Edge Functions específicas |

---

## SEÇÃO 1 — Banco de Dados: 10 Novas Tabelas

> **Regra obrigatória:** Toda tabela criada abaixo deve ter RLS ativado imediatamente. Não criar nenhuma tabela sem configurar a política de RLS no mesmo momento. Ver Part C para as políticas por tabela.

---

### Tabela 1 — `couples`

Registro central do casal. Cada par de usuários tem no máximo um registro ativo.

```sql
CREATE TABLE couples (
  couple_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id             UUID NOT NULL REFERENCES profiles(id),
  user_b_id             UUID NOT NULL REFERENCES profiles(id),
  status                TEXT NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active', 'archived', 'ended')),
  created_at            TIMESTAMP DEFAULT NOW(),
  activation_source     TEXT NOT NULL
                          CHECK (activation_source IN ('auro_match', 'imported')),
  day_count             INT DEFAULT 1,
  current_level         SMALLINT DEFAULT 1,
  current_streak        SMALLINT DEFAULT 0,
  last_ritual_week      INT,
  deletion_scheduled_at TIMESTAMP  -- preenchido quando status = 'ended'
);

-- Garantir que um par de usuários não tem dois registros ativos
CREATE UNIQUE INDEX idx_couples_active_pair
  ON couples(LEAST(user_a_id, user_b_id), GREATEST(user_a_id, user_b_id))
  WHERE status = 'active';
```

**Campos-chave:**

| Campo | Descrição |
|-------|-----------|
| `activation_source` | `auro_match` = vieram do Dating Mode · `imported` = "We met elsewhere" |
| `day_count` | Contador de dias juntos no Auro. Incrementado diariamente por cron. |
| `current_level` | Nível do casal (1–N). Sobe ao completar marcos. |
| `current_streak` | Semanas consecutivas com ritual completo. |
| `last_ritual_week` | Semana ISO do último ritual gerado. Evita geração duplicada. |
| `deletion_scheduled_at` | Preenchido ao encerrar: `NOW() + 30 dias`. Dados não deletados imediatamente. |

---

### Tabela 2 — `rituals`

Rituais semanais gerados por IA para cada casal.

```sql
CREATE TABLE rituals (
  ritual_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id           UUID NOT NULL REFERENCES couples(couple_id),
  week_number         INT NOT NULL,           -- semana ISO (ex: 202412)
  track               TEXT NOT NULL
                        CHECK (track IN (
                          'emotional', 'communication', 'intellectual',
                          'adventure', 'gratitude', 'playful'
                        )),
  title               TEXT NOT NULL,
  insight             TEXT,                   -- 2–3 frases geradas por IA
  practice            TEXT,                   -- 100–200 palavras geradas por IA
  reflection_question TEXT,
  completed_a_at      TIMESTAMP,              -- quando user_a marcou como completo
  completed_b_at      TIMESTAMP,              -- quando user_b marcou como completo
  generated_at        TIMESTAMP DEFAULT NOW(),
  ai_version          VARCHAR(10),            -- versão do modelo/prompt usado
  source              TEXT DEFAULT 'ai'
                        CHECK (source IN ('ai', 'library')), -- ai ou fallback pré-escrito

  CONSTRAINT unique_couple_week UNIQUE (couple_id, week_number)
);
```

**Trilhas disponíveis e quando usar cada uma:**

| Trilha | Foco |
|--------|------|
| `emotional` | Vulnerabilidade, conexão emocional |
| `communication` | Escuta, expressão, resolução de conflito |
| `intellectual` | Curiosidade compartilhada, debates, aprendizado |
| `adventure` | Novidade, desafios, sair da rotina |
| `gratitude` | Apreciação, reconhecimento, afeto |
| `playful` | Leveza, diversão, humor |

**Regras de geração:**
- A trilha é selecionada pela IA com base no histórico das últimas 4 trilhas completadas (evitar repetição)
- Gerado antes das 08:00 UTC de domingo
- Se geração falhar: `source = 'library'` (fallback de biblioteca pré-escrita)

---

### Tabela 3 — `journal_entries`

Diário privado/compartilhado do casal.

```sql
CREATE TABLE journal_entries (
  entry_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id           UUID NOT NULL REFERENCES couples(couple_id),
  author_id           UUID NOT NULL REFERENCES profiles(id),
  body                TEXT NOT NULL,
  type                TEXT NOT NULL
                        CHECK (type IN (
                          'free_write', 'ritual_reflection',
                          'ai_prompted', 'memory'
                        )),
  shared_with_partner BOOLEAN DEFAULT false,  -- CRÍTICO: padrão FALSE
  photos              TEXT[],                 -- URLs de Supabase Storage
  created_at          TIMESTAMP DEFAULT NOW()
  -- SEM campo read_at (parceiro não pode saber se você leu)
);
```

**Regra de privacidade crítica:** `shared_with_partner` tem padrão `FALSE`. O parceiro não lê nada até o autor mudar explicitamente para `TRUE`. Essa regra é aplicada no nível do RLS, não apenas no app.

**Tipos de entrada:**

| Tipo | Quando é criado |
|------|----------------|
| `free_write` | Usuário escreve livremente |
| `ritual_reflection` | Após completar um ritual |
| `ai_prompted` | Resposta a um prompt gerado pela IA |
| `memory` | Registro de uma memória/momento |

---

### Tabela 4 — `timeline_events`

Linha do tempo do relacionamento — marcos e memórias.

```sql
CREATE TABLE timeline_events (
  event_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  event_name  TEXT NOT NULL,
  event_date  DATE NOT NULL,
  category    TEXT NOT NULL
                CHECK (category IN (
                  'first_times', 'trips', 'milestones',
                  'everyday_magic', 'challenges', 'celebrations'
                )),
  note        TEXT,
  photos      TEXT[],
  created_at  TIMESTAMP DEFAULT NOW()
);
```

**Categorias:**

| Categoria | Exemplos |
|-----------|----------|
| `first_times` | Primeiro encontro, primeiro beijo |
| `trips` | Viagens juntos |
| `milestones` | 6 meses, 1 ano, morar juntos |
| `everyday_magic` | Momentos cotidianos especiais |
| `challenges` | Obstáculos superados juntos |
| `celebrations` | Conquistas, aniversários |

**Limites por plano:**
- Free: 10 eventos
- Premium: ilimitado
- Lido de `feature_config WHERE key = 'timeline_event_limit'`

---

### Tabela 5 — `check_ins`

Check-ins semanais de cada parceiro — com revelação assimétrica.

```sql
CREATE TABLE check_ins (
  checkin_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(couple_id),
  week_number     INT NOT NULL,
  responses_a     JSONB,           -- respostas de user_a
  responses_b     JSONB,           -- respostas de user_b
  completed_a_at  TIMESTAMP,
  completed_b_at  TIMESTAMP,
  visible_after   TIMESTAMP,       -- NOW() + 48h na criação (assimetria)
  both_completed  BOOLEAN DEFAULT false,

  CONSTRAINT unique_couple_checkin_week UNIQUE (couple_id, week_number)
);
```

**Lógica de visibilidade assimétrica:**
```
Quando check_in é criado:
  visible_after = NOW() + INTERVAL '48 hours'

Parceiro A vê respostas de B quando:
  NOW() > visible_after  OU  both_completed = true

Essa lógica é aplicada no RLS (não apenas no app):
  SELECT WHERE author_id = auth.uid()
          OR (NOW() > visible_after OR both_completed = true)
```

**Exemplo de `responses_a` (JSONB):**
```json
{
  "connection_score": 4,
  "highlight": "Our walk on Thursday",
  "challenge": "We didn't communicate well mid-week",
  "intention": "I want to be more present during dinner"
}
```

---

### Tabela 6 — `challenges`

Desafios de 15 dias com cards diários gerados por IA.

```sql
CREATE TABLE challenges (
  challenge_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id          UUID NOT NULL REFERENCES couples(couple_id),
  challenge_type     VARCHAR(60) NOT NULL,
  started_at         TIMESTAMP DEFAULT NOW(),
  days_completed     SMALLINT DEFAULT 0,
  status             TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active', 'paused', 'completed', 'failed')),
  daily_cards        JSONB,    -- array com os 15 cards pré-gerados
  completion_summary TEXT,     -- gerado pela IA ao concluir

  CONSTRAINT one_active_challenge_per_couple
    EXCLUDE (couple_id WITH =) WHERE (status = 'active')
);
```

**Regra de geração dos cards:**
- Todos os 15 cards são gerados em **uma única chamada de IA** ao iniciar o desafio
- Armazenados em `daily_cards` como array JSON
- Nunca chamar a IA por dia individual

**Estrutura de `daily_cards`:**
```json
[
  {
    "day": 1,
    "title": "The Mirror",
    "description": "Share one thing you admire about your partner that they might not know you notice.",
    "duration_minutes": 10
  },
  {
    "day": 2,
    "title": "...",
    ...
  }
]
```

**Lógica de status:**

| Situação | Status | Notificação |
|----------|--------|-------------|
| Em andamento | `active` | Card diário |
| 2+ dias perdidos | `paused` | "A vida aconteceu. Retome quando estiver pronto." |
| 15 dias completos | `completed` | Celebração + summary |
| — | `failed` | ❌ Nunca usar este estado para o usuário |

> O status `failed` existe no schema mas **nunca é exibido ao usuário**. Internamente pode ser usado para analytics, mas a comunicação é sempre `paused`.

---

### Tabela 7 — `credits`

Saldo de créditos por usuário. **Nunca editável pelo cliente.**

```sql
CREATE TABLE credits (
  credit_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID UNIQUE NOT NULL REFERENCES profiles(id),
  balance           INT DEFAULT 10,
  monthly_allowance INT DEFAULT 10,
  last_refreshed_at DATE,

  CONSTRAINT positive_balance CHECK (balance >= 0)
);
```

**Regra absoluta:** A tabela `credits` só pode ser modificada por Edge Functions. O cliente nunca faz INSERT, UPDATE ou DELETE nessa tabela. O RLS bloqueia qualquer tentativa do cliente de modificar o saldo.

**Política RLS:**
```sql
-- SELECT: usuário vê apenas o próprio saldo
-- INSERT/UPDATE/DELETE: apenas service role (Edge Functions)
ALTER TABLE credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "credits_select_own" ON credits
  FOR SELECT USING (user_id = auth.uid());
-- Sem policy de INSERT/UPDATE/DELETE para o cliente
```

---

### Tabela 8 — `badges`

Conquistas desbloqueadas pelo casal.

```sql
CREATE TABLE badges (
  badge_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  badge_type  VARCHAR(60) NOT NULL,
  earned_at   TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_badge_per_couple UNIQUE (couple_id, badge_type)
);
```

**Exemplos de `badge_type`:**
- `first_ritual_complete`
- `streak_4_weeks`
- `streak_12_weeks`
- `first_challenge_complete`
- `100_journal_entries`
- `timeline_10_events`
- `checkin_streak_8_weeks`

---

### Tabela 9 — `couple_insights`

Insights narrativos semanais e retrospectivas mensais gerados por IA (Premium).

```sql
CREATE TABLE couple_insights (
  insight_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(couple_id),
  week_number  INT NOT NULL,   -- semana ISO. 0 = retrospectiva mensal
  type         TEXT NOT NULL
                 CHECK (type IN ('weekly', 'retrospective')),
  content      TEXT NOT NULL,
  generated_at TIMESTAMP DEFAULT NOW(),
  ai_version   VARCHAR(10),

  CONSTRAINT unique_couple_insight UNIQUE (couple_id, week_number, type)
);
```

**Diferença entre weekly e retrospective:**

| Tipo | Frequência | `week_number` | Quando invalidar cache |
|------|-----------|---------------|----------------------|
| `weekly` | 1x por semana (Premium) | Semana ISO atual | Ao completar ritual ou check-in |
| `retrospective` | 1x por mês (Premium) | `0` | Nunca (gerado ao final do mês) |

---

### Tabela 10 — `feature_config`

Limites de funcionalidades free/premium. **Nunca hardcodar limites no código da aplicação.**

```sql
CREATE TABLE feature_config (
  key           VARCHAR(60) PRIMARY KEY,
  free_limit    INT,        -- NULL = ilimitado para free
  premium_limit INT,        -- NULL = ilimitado para premium
  credit_cost   INT,        -- NULL = sem custo de crédito
  enabled       BOOLEAN DEFAULT true
);
```

**Dados iniciais (seed — rodar uma vez):**

```sql
INSERT INTO feature_config (key, free_limit, premium_limit, credit_cost) VALUES
  ('journal_entry_limit',        30,   NULL, NULL),
  ('timeline_event_limit',       10,   NULL, NULL),
  ('weekly_rituals',              1,   NULL,    3),  -- 1 grátis, extra custa 3 créditos
  ('icebreaker_prompts_weekly',   3,   NULL, NULL),
  ('streak_protections_monthly',  0,      1,    3),  -- free = 0, premium = 1/mês
  ('challenge_access',            0,   NULL,    5),  -- free paga 5 créditos
  ('ai_journal_prompt',           0,   NULL,    1),
  ('timeline_photo_extra',        3,   NULL,    1),  -- 3 por evento free, extra = 1 crédito
  ('date_night_ai',               0,   NULL,    2),
  ('compatibility_deep_dive',     0,      1,   10),  -- free paga 10, premium tem 1 grátis
  ('partner_insight_reveal',      0,   NULL,    2),
  ('advanced_checkin',            0,   NULL,    2);
```

> **Como ler a tabela:**
> - `free_limit = 0` + `credit_cost = 5` → usuário free pode usar, mas paga 5 créditos
> - `free_limit = 30` + `credit_cost = NULL` → usuário free usa até 30, grátis
> - `premium_limit = NULL` → premium tem acesso ilimitado

---

## SEÇÃO 2 — Fluxo de Ativação do Modo Casal

### Dois Caminhos de Ativação

```
┌─────────────────────────────────────────────────────────────────┐
│  TELA DE ATIVAÇÃO DO MODO CASAL                                 │
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐│
│  │  We matched on Auro │    │     We met elsewhere            ││
│  │  (Caminho A)        │    │     (Caminho B — novo na Part A)││
│  └──────────┬──────────┘    └──────────────┬──────────────────┘│
└─────────────┼────────────────────────────  ┼ ──────────────────┘
              │                              │
              ▼                              ▼
   Cria registro de casal        Usuário insere email/telefone
   activation_source =           do parceiro
   'auro_match'                        │
              │                         ▼
              │              Edge Function gera token UUID
              │              (uso único, expira em 7 dias)
              │                         │
              │                         ▼
              │              Parceiro recebe convite
              │                         │
              └──────────────────────── ┼ ────────┐
                                        │         │
                                        ▼         │
                              Edge Function valida token
                              (não usado, não expirado)
                                        │
                                        ▼
                              Cria registro de casal
                              activation_source = 'imported'
                                        │
                                        │
                    ────────────────────┘
                    │
                    ▼
        Na criação do registro de casal:
          day_count = 1
          current_level = 1
          current_streak = 0
          Dispara geração do primeiro ritual
                    │
                    ▼
        Tela de boas-vindas para ambos:
        "Dia 1 — Sua jornada começa."
        Primeiro card de ritual visível.
```

### Edge Functions Envolvidas na Ativação

| Função | Responsabilidade |
|--------|-----------------|
| `create_couple_invite` | Gera token UUID, armazena com `expires_at = NOW() + 7 dias`, envia convite |
| `validate_couple_invite` | Valida token (não usado, não expirado), marca como usado, cria registro de casal |
| `generate_weekly_rituals` | Disparado imediatamente após criação do casal para gerar o primeiro ritual |

---

## SEÇÃO 3 — Pontos de Integração de IA

> **Regra absoluta:** O cliente FlutterFlow nunca chama a Claude API diretamente. Toda chamada de IA passa por Edge Functions. O cliente não tem chaves secretas.

### 3.1 — Gerador de Ritual Semanal

**Quando roda:** Cron todo domingo às 06:00 UTC (antes das 08:00 UTC limite)

**Entradas para o prompt:**
```typescript
{
  attachment_style_a: string,      // 'secure' | 'anxious' | 'avoidant' | 'fearful_avoidant'
  attachment_style_b: string,
  love_language_a: string,
  love_language_b: string,
  last_4_tracks: string[],         // trilhas das últimas 4 semanas (evitar repetição)
  day_count: number,               // dias juntos no app
  emotional_readiness_a: object,   // de profiles.emotional_readiness_json
  emotional_readiness_b: object,
}
```

**Saída esperada (JSON estruturado):**
```json
{
  "track": "emotional",
  "title": "The Unspoken Thank You",
  "insight": "Gratitude is most powerful when it names something specific. This week, you'll practice seeing each other in detail.",
  "practice": "Set aside 15 minutes on any evening this week...",
  "reflection_question": "What's something your partner does that you've never directly thanked them for?"
}
```

**System prompt padrão (otimização de custo):**
```
Respond ONLY with a valid JSON object. No preamble, no explanation, no markdown backticks.
{ "track": "...", "title": "...", "insight": "...", "practice": "...", "reflection_question": "..." }
```

**Fallback:** Se a chamada de IA falhar → buscar da biblioteca pré-escrita de 200 rituais e inserir com `source = 'library'`. Nunca retornar erro ao usuário.

---

### 3.2 — Gerador de Insights Semanais (Premium)

**Quando roda:** Cron de domingo, apenas para casais com `subscription_tier = 'premium'`

**Entradas para o prompt:**
```typescript
{
  // Tudo do ritual semanal +
  last_3_journal_themes: string[],    // temas extraídos das entradas (não o conteúdo)
  challenge_status: string,
  last_checkin_responses: object,     // respostas do check-in da semana anterior
}
```

**Invalidação do cache:**
- Ao completar novo ritual → invalidar insight da semana atual
- Ao submeter check-in → invalidar insight da semana atual
- Regenerar na próxima janela de domingo

---

### 3.3 — Prompt de IA para Diário (Sob Demanda)

**Quando roda:** Usuário toca "Me dê um prompt" na tela de diário

**Fluxo:**
```
1. Cliente chama Edge Function generate_journal_prompt
2. EF verifica: premium? Se sim, executar direto.
3. Se free: chamar check_credits({user_id, feature_key: 'ai_journal_prompt'})
4. Se has_access = false: retornar erro "insufficient_credits"
5. Se has_access = true: DEDUZIR 1 crédito ANTES de chamar a IA
6. Chamar Claude API com entradas abaixo
7. Armazenar resultado. Retornar prompt ao cliente.
```

**Entradas:**
```typescript
{
  last_3_entries_text: string[],      // texto das últimas 3 entradas
  emotional_readiness: object,        // de profiles.emotional_readiness_json
}
```

**Saída:** 1 pergunta, máximo 25 palavras.

**Regra:** Nunca fazer cache antecipado. Sempre chamar sob demanda.

---

### 3.4 — Cards Diários do Desafio (Geração em Lote)

**Quando roda:** Ao usuário desbloquear/iniciar um desafio

**Regra crítica:** Gerar **todos os 15 cards em uma única chamada de IA**. Nunca chamar a API por dia individual.

**Entradas:**
```typescript
{
  challenge_type: string,
  couple_context: {
    attachment_style_pair: string,
    day_count: number,
    completed_challenges: string[],  // tipos já completados (evitar repetição)
  }
}
```

**Saída:** Array JSON de 15 objetos de card, armazenado diretamente em `challenges.daily_cards`.

---

### 3.5 — Retrospectiva Mensal (Premium)

**Quando roda:** Fim de cada mês, assincronamente

**Entradas:**
```typescript
{
  rituals_this_month: Ritual[],
  checkin_responses_this_month: CheckIn[],
  journal_entry_count: number,
  journal_themes: string[],         // temas (não conteúdo)
  timeline_events_added: number,
  badges_earned: string[],
}
```

**Armazenamento:** `couple_insights` com `week_number = 0` e `type = 'retrospective'`

---

## SEÇÃO 4 — Lógica de Transação de Créditos

### Fluxo Completo

```
┌────────────────────────────────────────────────────────┐
│  Usuário tenta acessar feature com custo de créditos   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
          ┌────────────────────────────┐
          │ subscription_tier =        │
          │ 'premium'?                 │
          └───────┬────────────────────┘
                  │ Sim                │ Não
                  ▼                   ▼
           Executar direto    Edge Function check_credits
           (ignorar créditos) {user_id, feature_key}
                                       │
                              ┌────────┴────────────┐
                              │ has_access = false? │
                              └────────┬────────────┘
                                       │ Sim          │ Não
                                       ▼              ▼
                              Exibir prompt    Chamar deduct_credits
                              de upgrade       {user_id, feature_key, amount}
                                                       │ (débito atômico)
                                                       ▼
                                              Chamar API de IA
                                                       │
                                                       ▼
                                              Armazenar resultado
                                                       │
                                                       ▼
                                              Retornar ao usuário
```

### Edge Functions de Crédito

**`check_credits`**
```typescript
// Input
{ user_id: string, feature_key: string }

// Output
{
  has_access: boolean,
  cost: number,
  balance: number,
  is_premium: boolean
}
```

**`deduct_credits`**
```typescript
// Input
{ user_id: string, feature_key: string, amount: number }

// Lógica (atômica):
// 1. BEGIN TRANSACTION
// 2. SELECT balance FOR UPDATE
// 3. IF balance < amount → ROLLBACK, throw 'insufficient_credits'
// 4. UPDATE credits SET balance = balance - amount
// 5. INSERT INTO credit_transactions (log da operação)
// 6. COMMIT

// Output
{ new_balance: number, success: boolean }
```

**`add_credits`**
```typescript
// Input
{ user_id: string, amount: number, purchase_id: string, source: string }

// Idempotência: verificar se purchase_id já foi processado antes de adicionar
// Output
{ new_balance: number, success: boolean }
```

### Cron de Renovação Mensal

```sql
-- pg_cron: dia 1 de cada mês às 00:01 UTC
-- Nunca reduz o saldo existente (GREATEST)
UPDATE credits
SET
  balance = GREATEST(balance, monthly_allowance),
  last_refreshed_at = CURRENT_DATE
WHERE last_refreshed_at < DATE_TRUNC('month', CURRENT_DATE);
```

### Notificação de Saldo Baixo

- Disparar push quando `balance ≤ 2`
- Máximo 1 notificação a cada 7 dias por usuário
- Controlar com campo `low_balance_notified_at` na tabela `credits` (ou via tabela de controle de notificações)

---

## SEÇÃO 5 — Segurança Psicológica

> Estas regras são tão importantes quanto qualquer otimização de performance. Uma feature que faça os usuários se sentirem vigiados, julgados ou culpados vai destruir a retenção mais rápido do que qualquer bug técnico.

### Regra 1 — Privacidade do Diário

| O que | Como implementado |
|-------|------------------|
| `journal_entries.shared_with_partner` padrão = `FALSE` | Schema com `DEFAULT false` |
| Parceiro não pode ler entrada privada | RLS: `shared_with_partner = true` obrigatório para SELECT de outro usuário |
| Sem confirmação de leitura | Sem campo `read_at` na tabela — nunca adicionar |

```sql
-- RLS policy para journal_entries
CREATE POLICY "journal_read" ON journal_entries
  FOR SELECT USING (
    author_id = auth.uid()
    OR (
      shared_with_partner = true
      AND couple_id IN (
        SELECT couple_id FROM couples
        WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
      )
    )
  );
```

---

### Regra 2 — Assimetria do Check-in

| O que | Como implementado |
|-------|------------------|
| Respostas ocultas até 48h ou ambos completarem | `visible_after = NOW() + 48h` na criação |
| Aplicado no BD, não no app | RLS com condição de tempo |

```sql
-- RLS policy para check_ins (SELECT do parceiro)
CREATE POLICY "checkin_partner_read" ON check_ins
  FOR SELECT USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
    AND (
      both_completed = true
      OR NOW() > visible_after
    )
  );
```

---

### Regra 3 — Ritual Não Feito: Sem Culpa

| ❌ Nunca exibir | ✅ Exibir |
|----------------|---------|
| "Você ainda não fez o ritual desta semana." | "[Parceiro] completou o ritual desta semana." |
| "Faltam X dias para o prazo do ritual." | — |
| Qualquer badge de "ritual perdido" | — |

**Implementação:** Verificar `completed_a_at` e `completed_b_at` antes de exibir qualquer copy. Notificar apenas o que foi feito, nunca o que faltou.

---

### Regra 4 — Desafio Pausado: Sem Julgamento

| Evento | Status | Notificação |
|--------|--------|------------|
| 2+ dias sem completar card | `paused` | "A vida aconteceu. Seu desafio está pausado — retome quando estiver pronto." |
| Usuário retoma | `active` | "Bem-vindo(a) de volta! Continue de onde parou." |
| 15 dias completos | `completed` | Celebração |

**Nunca usar as palavras:** "failed", "perdeu", "falhou", "atrasado".

---

### Regra 5 — Saída do Modo Casal

```
Usuário encerra o Modo Casal:
  1. couples.status = 'ended'
  2. deletion_scheduled_at = NOW() + 30 dias
  3. NÃO deletar dados imediatamente
  4. Exibir opção de exportação de dados (journal, timeline, rituals)
  5. Após 30 dias: deletar dados via cron (cascata)
  6. Se usuário reativar antes dos 30 dias: deletion_scheduled_at = NULL, status = 'active'
```

---

## SEÇÃO 6 — Edge Functions Novas (Modo Casal)

| Função | Trigger | Descrição |
|--------|---------|-----------|
| `generate_weekly_rituals` | pg_cron domingo 06:00 UTC | Gera ritual para cada casal ativo sem ritual na semana atual. Lote. |
| `generate_ritual_on_demand` | Chamada manual do cliente | Usuário free usa 3 créditos para ritual extra. |
| `generate_journal_prompt` | Chamada manual do cliente | Sob demanda. 1 crédito (free). Nunca cachear antecipado. |
| `generate_challenge_cards` | Ao iniciar desafio | Pré-gera todos os 15 cards de uma vez. 1 chamada de IA total. |
| `generate_weekly_insights` | pg_cron domingo, apenas premium | Gera insight narrativo semanal. |
| `generate_monthly_retrospective` | pg_cron dia 1 do mês, apenas premium | Gera retrospectiva mensal. Async. |

---

## SEÇÃO 7 — Índices (Modo Casal)

Criar antes do lançamento do Modo Casal:

```sql
-- couples
CREATE INDEX idx_couples_user_a ON couples(user_a_id) WHERE status = 'active';
CREATE INDEX idx_couples_user_b ON couples(user_b_id) WHERE status = 'active';

-- rituals
CREATE INDEX idx_rituals_couple_week ON rituals(couple_id, week_number);
CREATE INDEX idx_rituals_pending_generation
  ON rituals(generated_at)
  WHERE completed_a_at IS NULL AND completed_b_at IS NULL;

-- journal_entries
CREATE INDEX idx_journal_couple ON journal_entries(couple_id, created_at DESC);
CREATE INDEX idx_journal_author ON journal_entries(author_id);
CREATE INDEX idx_journal_shared ON journal_entries(couple_id)
  WHERE shared_with_partner = true;

-- timeline_events
CREATE INDEX idx_timeline_couple ON timeline_events(couple_id, event_date DESC);

-- check_ins
CREATE INDEX idx_checkin_couple_week ON check_ins(couple_id, week_number);

-- challenges
CREATE INDEX idx_challenges_couple ON challenges(couple_id) WHERE status = 'active';

-- credits
CREATE INDEX idx_credits_user ON credits(user_id);

-- couple_insights
CREATE INDEX idx_insights_couple_week ON couple_insights(couple_id, week_number);
```

---

## Resumo — Checklist de Implementação (Part B)

### Schema (fazer antes de qualquer outra coisa)
- [ ] Criar tabela `couples` + RLS
- [ ] Criar tabela `credits` + RLS (bloquear UPDATE/DELETE do cliente)
- [ ] Criar tabela `feature_config` + seed dos 12 registros
- [ ] Criar tabela `rituals` + RLS
- [ ] Criar tabela `journal_entries` + RLS (política de shared_with_partner)
- [ ] Criar tabela `timeline_events` + RLS
- [ ] Criar tabela `check_ins` + RLS (política de visible_after)
- [ ] Criar tabela `challenges` + RLS
- [ ] Criar tabela `couple_insights` + RLS
- [ ] Criar tabela `badges` + RLS
- [ ] Criar tabela `couple_invites` (da Part A — E1)
- [ ] Criar todos os índices listados na Seção 7

### Lógica de Negócio
- [ ] Edge Function `create_couple_invite`
- [ ] Edge Function `validate_couple_invite`
- [ ] Edge Function `generate_weekly_rituals` (cron + lote)
- [ ] Edge Function `generate_ritual_on_demand` (créditos)
- [ ] Edge Function `generate_journal_prompt` (créditos)
- [ ] Edge Function `generate_challenge_cards` (15 cards, 1 chamada)
- [ ] Edge Function `generate_weekly_insights` (premium)
- [ ] Edge Function `generate_monthly_retrospective` (premium, async)
- [ ] Edge Function `check_credits`
- [ ] Edge Function `deduct_credits` (atômico)
- [ ] Edge Function `add_credits` (idempotente)
- [ ] pg_cron: geração de rituais (domingo 06:00 UTC)
- [ ] pg_cron: geração de insights premium (domingo)
- [ ] pg_cron: retrospectiva mensal (dia 1)
- [ ] pg_cron: renovação de créditos (dia 1, 00:01 UTC)
- [ ] pg_cron: `day_count++` para casais ativos (diário)

### Segurança Psicológica
- [ ] Verificar que `journal_entries.shared_with_partner` tem `DEFAULT false` e está no RLS
- [ ] Verificar que check_in tem `visible_after` e lógica de 48h
- [ ] Verificar que não há notificação "você não fez o ritual"
- [ ] Verificar que falha de desafio usa `paused`, nunca `failed` na UI
- [ ] Verificar que `deletion_scheduled_at = NOW() + 30 dias` ao encerrar casal

### UI (FlutterFlow)
- [ ] Namespace MODO CASAL: CoupleDashboardScreen, RitualScreen, JournalScreen, TimelineScreen, CheckInScreen, ChallengeScreen
- [ ] Tela de ativação com duas opções (Auro match vs "We met elsewhere")
- [ ] Seção de créditos (saldo, compra, histórico)
- [ ] Tela de badges/conquistas
- [ ] Fluxo de exportação de dados ao sair do Modo Casal

---

## Schema SQL Consolidado — Todas as Tabelas da Part B

```sql
-- ============================================================
-- PART B — Modo Casal: Schema Completo
-- Versão: v1.0 | Março 2026
-- Executar após: Part A schema changes
-- ============================================================

-- TABELA 1: CASAIS
CREATE TABLE couples (
  couple_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id             UUID NOT NULL REFERENCES profiles(id),
  user_b_id             UUID NOT NULL REFERENCES profiles(id),
  status                TEXT NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active', 'archived', 'ended')),
  created_at            TIMESTAMP DEFAULT NOW(),
  activation_source     TEXT NOT NULL
                          CHECK (activation_source IN ('auro_match', 'imported')),
  day_count             INT DEFAULT 1,
  current_level         SMALLINT DEFAULT 1,
  current_streak        SMALLINT DEFAULT 0,
  last_ritual_week      INT,
  deletion_scheduled_at TIMESTAMP
);
CREATE UNIQUE INDEX idx_couples_active_pair
  ON couples(LEAST(user_a_id, user_b_id), GREATEST(user_a_id, user_b_id))
  WHERE status = 'active';

-- TABELA 2: RITUAIS
CREATE TABLE rituals (
  ritual_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id           UUID NOT NULL REFERENCES couples(couple_id),
  week_number         INT NOT NULL,
  track               TEXT NOT NULL
                        CHECK (track IN ('emotional','communication','intellectual','adventure','gratitude','playful')),
  title               TEXT NOT NULL,
  insight             TEXT,
  practice            TEXT,
  reflection_question TEXT,
  completed_a_at      TIMESTAMP,
  completed_b_at      TIMESTAMP,
  generated_at        TIMESTAMP DEFAULT NOW(),
  ai_version          VARCHAR(10),
  source              TEXT DEFAULT 'ai' CHECK (source IN ('ai', 'library')),
  CONSTRAINT unique_couple_week UNIQUE (couple_id, week_number)
);

-- TABELA 3: DIÁRIO
CREATE TABLE journal_entries (
  entry_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id           UUID NOT NULL REFERENCES couples(couple_id),
  author_id           UUID NOT NULL REFERENCES profiles(id),
  body                TEXT NOT NULL,
  type                TEXT NOT NULL
                        CHECK (type IN ('free_write','ritual_reflection','ai_prompted','memory')),
  shared_with_partner BOOLEAN DEFAULT false,
  photos              TEXT[],
  created_at          TIMESTAMP DEFAULT NOW()
);

-- TABELA 4: TIMELINE
CREATE TABLE timeline_events (
  event_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  event_name  TEXT NOT NULL,
  event_date  DATE NOT NULL,
  category    TEXT NOT NULL
                CHECK (category IN ('first_times','trips','milestones','everyday_magic','challenges','celebrations')),
  note        TEXT,
  photos      TEXT[],
  created_at  TIMESTAMP DEFAULT NOW()
);

-- TABELA 5: CHECK-INS
CREATE TABLE check_ins (
  checkin_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(couple_id),
  week_number     INT NOT NULL,
  responses_a     JSONB,
  responses_b     JSONB,
  completed_a_at  TIMESTAMP,
  completed_b_at  TIMESTAMP,
  visible_after   TIMESTAMP,
  both_completed  BOOLEAN DEFAULT false,
  CONSTRAINT unique_couple_checkin_week UNIQUE (couple_id, week_number)
);

-- TABELA 6: DESAFIOS
CREATE TABLE challenges (
  challenge_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id          UUID NOT NULL REFERENCES couples(couple_id),
  challenge_type     VARCHAR(60) NOT NULL,
  started_at         TIMESTAMP DEFAULT NOW(),
  days_completed     SMALLINT DEFAULT 0,
  status             TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','paused','completed','failed')),
  daily_cards        JSONB,
  completion_summary TEXT
);

-- TABELA 7: CRÉDITOS
CREATE TABLE credits (
  credit_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID UNIQUE NOT NULL REFERENCES profiles(id),
  balance           INT DEFAULT 10,
  monthly_allowance INT DEFAULT 10,
  last_refreshed_at DATE,
  CONSTRAINT positive_balance CHECK (balance >= 0)
);

-- TABELA 8: BADGES
CREATE TABLE badges (
  badge_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  badge_type  VARCHAR(60) NOT NULL,
  earned_at   TIMESTAMP DEFAULT NOW(),
  CONSTRAINT unique_badge_per_couple UNIQUE (couple_id, badge_type)
);

-- TABELA 9: INSIGHTS DO CASAL
CREATE TABLE couple_insights (
  insight_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(couple_id),
  week_number  INT NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('weekly','retrospective')),
  content      TEXT NOT NULL,
  generated_at TIMESTAMP DEFAULT NOW(),
  ai_version   VARCHAR(10),
  CONSTRAINT unique_couple_insight UNIQUE (couple_id, week_number, type)
);

-- TABELA 10: FEATURE CONFIG
CREATE TABLE feature_config (
  key           VARCHAR(60) PRIMARY KEY,
  free_limit    INT,
  premium_limit INT,
  credit_cost   INT,
  enabled       BOOLEAN DEFAULT true
);

-- SEED: feature_config
INSERT INTO feature_config (key, free_limit, premium_limit, credit_cost) VALUES
  ('journal_entry_limit',        30,   NULL, NULL),
  ('timeline_event_limit',       10,   NULL, NULL),
  ('weekly_rituals',              1,   NULL,    3),
  ('icebreaker_prompts_weekly',   3,   NULL, NULL),
  ('streak_protections_monthly',  0,      1,    3),
  ('challenge_access',            0,   NULL,    5),
  ('ai_journal_prompt',           0,   NULL,    1),
  ('timeline_photo_extra',        3,   NULL,    1),
  ('date_night_ai',               0,   NULL,    2),
  ('compatibility_deep_dive',     0,      1,   10),
  ('partner_insight_reveal',      0,   NULL,    2),
  ('advanced_checkin',            0,   NULL,    2);

-- HABILITAR RLS EM TODAS AS TABELAS
ALTER TABLE couples         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rituals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges      ENABLE ROW LEVEL SECURITY;
ALTER TABLE credits         ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges          ENABLE ROW LEVEL SECURITY;
ALTER TABLE couple_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_config  ENABLE ROW LEVEL SECURITY;

-- ÍNDICES
CREATE INDEX idx_couples_user_a ON couples(user_a_id) WHERE status = 'active';
CREATE INDEX idx_couples_user_b ON couples(user_b_id) WHERE status = 'active';
CREATE INDEX idx_rituals_couple_week ON rituals(couple_id, week_number);
CREATE INDEX idx_journal_couple ON journal_entries(couple_id, created_at DESC);
CREATE INDEX idx_journal_shared ON journal_entries(couple_id) WHERE shared_with_partner = true;
CREATE INDEX idx_timeline_couple ON timeline_events(couple_id, event_date DESC);
CREATE INDEX idx_checkin_couple_week ON check_ins(couple_id, week_number);
CREATE INDEX idx_challenges_couple ON challenges(couple_id) WHERE status = 'active';
CREATE INDEX idx_credits_user ON credits(user_id);
CREATE INDEX idx_insights_couple_week ON couple_insights(couple_id, week_number);
```

---

*Documento de mudanças Part B — gerado em Março 2026*
*Referências: `docs/overview.md` · Auro Developer Handoff v1.0 Part B*

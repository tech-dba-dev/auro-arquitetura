# AURO — Base de Arquitetura Consolidada
**v2.0 · Março 2026 · Referência técnica para a equipe**

> Este documento consolida os docs de arquitetura existentes (`docs/`) com os requisitos do handoff técnico completo (Parts A–E). Cada seção indica o **estado atual** da arquitetura e **o que precisa mudar**, com prioridade explícita.

---

## Legenda de Prioridade

| Símbolo | Significado |
|---------|-------------|
| 🔴 CRÍTICO | Bloqueia o lançamento. Fazer antes de qualquer usuário real. |
| 🟡 IMPORTANTE | Implementar em 1–2 semanas após lançamento. Alto impacto em retenção. |
| 🟢 MELHORIA | Alvo v2. Desejável, não bloqueia. |
| ✅ OK | Já implementado corretamente na arquitetura atual. |
| ⚠️ CONFLITO | Divergência entre doc atual e novo spec. Precisa de decisão. |

---

## 🚨 DOIS BLOQUEADORES ABSOLUTOS DE LANÇAMENTO

Não avançar para QA ou beta sem confirmar os dois:

1. **Row Level Security (RLS) ativado em TODAS as tabelas do Supabase** antes de qualquer dado real ser armazenado.
2. **Detecção de CSAM integrada na Edge Function de upload de foto** antes de qualquer foto ser armazenada.

São obrigações legais, não preferências.

---

## ÍNDICE

- [Part A — Sistema de Compatibilidade](#part-a--sistema-de-compatibilidade)
- [Part B — Modo Casal](#part-b--modo-casal)
- [Part C — Privacidade e Segurança](#part-c--privacidade-e-segurança)
- [Part D — Arquitetura e Escalabilidade](#part-d--arquitetura-e-escalabilidade)
- [Part E — Analytics e Notificações](#part-e--analytics-e-notificações)
- [Apêndice — Schema Atual vs Schema Necessário](#apêndice--schema-atual-vs-schema-necessário)

---

# PART A — Sistema de Compatibilidade

## A — Exibição de Pontuação e Mudanças de UI

### 🔴 A1 — Remover Percentual de Toda a UI

**Estado atual:** O profile card envia `compatibility_score: 92` ao cliente. A UI exibe `87%`, `73% compatible` e variações numéricas em match cards, chat headers e notificações.

**O que mudar:**
- Remover qualquer exibição de número/percentual de compatibilidade para o usuário final
- O motor interno **continua calculando** percentuais para ranking e input de IA
- A pontuação numérica **nunca é exibida** ao usuário

**O que substitui:** Apenas o rótulo de compatibilidade (ver A2) + narrativa de IA em 3 blocos.

**Impacto no código:**
- Campo `compatibility_score` no profile card response: remover do payload enviado ao cliente (ou manter no servidor apenas)
- Chat list screen: remover `"compatibility_score": 87` do response JSON
- Notificações: revisar qualquer copy com percentual

---

### 🔴 A2 — Substituir Todos os Rótulos de Compatibilidade

**Estado atual** (`compatibility-algorithm.md`):

| Faixa | Rótulo Atual |
|-------|-------------|
| 85–100 | Rare Connection |
| 70–84 | High Compatibility |
| 50–69 | Compatible with Differences |
| 30–49 | Few Things in Common |
| 0–29 | **Unlikely** ← REMOVER |

**Novo rótulo obrigatório:**

| Faixa (Score Interno) | Rótulo Exibido |
|----------------------|----------------|
| 85–100 | ✨ Rare Connection |
| 70–84 | 💚 Strong Alignment |
| 50–69 | 💛 Compatible with Differences |
| 30–49 | 🟠 Different Foundations |
| 0–29 | 💬 Worth a Conversation |

**CRÍTICO:** Remover "Unlikely" completamente. O rótulo mais baixo é sempre um convite, nunca uma rejeição.

---

### 🔴 A3 — Renomear Terceiro Bloco da Narrativa de IA

**Estado atual** (`compatibility-algorithm.md`):
```json
{
  "strengths": "...",
  "complements": "...",
  "attention": "Different political views..."
}
```

**Mudança:**
- Campo `"attention"` → renomear para `"worth_exploring"` (ou equivalente no schema)
- Copy do bloco: deve soar como convite à curiosidade, não alerta/aviso

**Novo formato:**
```json
{
  "strengths": "...",
  "complements": "...",
  "worth_exploring": "Different political views — but you're both open to different perspectives."
}
```

**Impacto:** Edge Function `generate_explanation`, system prompt da IA, UI que renderiza os blocos.

---

### 🔴 A4 — Remover Barras de Sub-pontuação do Match Card

**Estado atual:** Profile card response inclui `score_breakdown: { love: 88, lifestyle: 72, values: 85, astrology: 90 }` implicitamente visível via barras visuais no card.

**O que remover:** Barras de progresso / visualizações de sub-scores no match card.

**O que permanece no card:** Foto + nome + rótulo de compatibilidade + distância/idade.

**Onde sub-scores podem aparecer:** Na tela de perfil completo (destrinchado ao tocar no card) — apenas como categorias de texto, nunca como barras de percentual.

---

## B — Mudanças no Motor de Pontuação

### 🔴 B1 — Mover Tipo de Relacionamento para Filtro Rígido da Fase 1

⚠️ **CONFLITO DIRETO com doc atual**

**Estado atual** (`compatibility-algorithm.md`, Phase 2 — Penalties):
```
Relationship Type Mismatch:
  monogamous vs polyamorous: -30 to -40 (penalty, não eliminatório)
```

**Novo spec:** Mover para **filtro eliminatório da Fase 1**, mesmo tratamento que orientação sexual.

**Lógica:** `monogamous ↔ polyamorous` é incompatibilidade fundamental, não diferença com score. Usuários incompatíveis em `relationship_type` nunca aparecem no pool um do outro.

**Enum a adicionar:**
```sql
-- Novo enum para relationship_type (mais preciso que o atual)
CREATE TYPE dating_style_type AS ENUM (
  'monogamous',
  'open',
  'polyamorous',
  'flexible'  -- pode fazer match com qualquer tipo
);
```

**Lógica de filtro:**
```
IF A.dating_style = 'monogamous' AND B.dating_style = 'polyamorous' → ELIMINADO
IF A.dating_style = 'flexible' → passa com qualquer tipo
```

**Impacto:** Phase 1 filter na Edge Function `calculate_compatibility_score` + remoção da penalty de Phase 2.

---

### 🔴 B2 — Corrigir Dupla Ponderação de Hobbies

⚠️ **BUG NO ALGORITMO ATUAL**

**Estado atual:** Hobbies aparecem em:
- Block 2 (Lifestyle): 25% do bloco ✅
- Block 3 (Values): implicitamente via `user_values.hobbies` ← **REMOVER DAQUI**

**Correção:** Remover hobbies completamente do Block 3. Hobbies pertencem **exclusivamente** ao Block 2 (Lifestyle).

**Block 3 após correção — nova distribuição de pesos:**

| Dimensão | Peso Atual | Peso Novo |
|----------|-----------|-----------|
| MBTI | 30% | **15%** |
| Visão Política | 25% | **20%** |
| Religião | 25% | **20%** |
| Situação de Vida + Área | 20% | **20%** |
| **Estilo de Apego** | — | **25% (NOVO)** |
| **Total** | 100% | 100% |

---

### 🔴 B3 — Adicionar Estilo de Apego ao Bloco de Valores (25%)

**Estado atual:** Não existe na arquitetura. Não há campo `attachment_style` em nenhuma tabela.

**Por que é prioritário:** É o principal diferencial — ciência com revisão por pares.

**Matriz de Pontuação do Estilo de Apego:**

| Par | Pontuação |
|-----|-----------|
| Seguro ↔ Seguro | 100 |
| Seguro ↔ Ansioso | 75 |
| Seguro ↔ Evitativo | 65 |
| Mesmo estilo ↔ Mesmo estilo (qualquer) | 70 |
| Evitativo-Medroso ↔ Qualquer | 45 |
| Ansioso ↔ Evitativo | 25 |

**Regra de nulo:** Se um dos usuários não completou a avaliação → usar **50 pontos** como fallback neutro. Não bloquear o matching.

**Mudanças no schema:**
```sql
-- Adicionar ao profiles ou user_personality
ALTER TABLE user_personality ADD COLUMN attachment_style attachment_style_type;

CREATE TYPE attachment_style_type AS ENUM (
  'secure',
  'anxious',
  'avoidant',
  'fearful_avoidant'
);
```

---

### 🟡 B4 — Adicionar Versionamento ao Motor de Pontuação

**Estado atual:** `compatibility_scores` não tem versão. Impossível auditar mudanças de peso ou fazer A/B test.

**Mudanças no schema:**
```sql
ALTER TABLE compatibility_scores
  ADD COLUMN scoring_version VARCHAR(10) DEFAULT 'v2.0',
  ADD COLUMN scored_at TIMESTAMP DEFAULT NOW();
```

**Regra:** Nunca sobrescrever uma pontuação — sempre inserir nova linha.

**Gatilhos de repontuação:** Quando usuário atualiza `attachment_style`, `mbti_type`, ou `dating_style`.

**Versão atual do motor:** `v2.0`

---

## C — Novas Dimensões de Onboarding

Três novas dimensões adicionadas ao onboarding. C1 alimenta o motor de scoring. C2 e C3 alimentam IA e personalização — nunca são pontuadas, nunca exibidas a outros usuários.

### 🔴 C1 — Avaliação de Estilo de Apego (8 Perguntas) — PONTUADA

**Posição no onboarding:** Após quiz de linguagem do amor. Antes das perguntas de valores.

**Formato:** 8 perguntas, escala de 4 pontos (Concordo Totalmente → Discordo Totalmente). Sem opção neutra.

**Resultado:** Um dos quatro estilos: `secure`, `anxious`, `avoidant`, `fearful_avoidant`

**Armazenamento:** `user_personality.attachment_style` ENUM. Editável nas configurações.

**Alimenta:** Score de compatibilidade (25% do Block 3) · IA do Modo Casal · Insights semanais · Tom dos ice-breakers.

**Exemplos de perguntas:**
- "Acho fácil depender de outras pessoas"
- "Fico preocupado(a) que meu parceiro(a) não me ame de verdade"
- "Prefiro não compartilhar meus sentimentos com os outros"

---

### 🔴 C2 — Check-in de Prontidão Emocional (3 Perguntas) — NÃO PONTUADA

**Posição:** Etapa final antes de completar o perfil.

**Perguntas:**
1. How open are you to a relationship right now? (Scale 1–5)
2. Are you in a place of healing from a previous relationship? (Yes / Mostly healed / No)
3. What are you most hoping Auro helps you with? (Multiple choice)

**Armazenamento:** `profiles.emotional_readiness_json JSONB`

**Alimenta:** Tom do onboarding · seleção de rituais no Modo Casal · motor de ice-breakers.

---

### 🔴 C3 — Estilo de Comunicação (4 Perguntas) — NÃO PONTUADA

**Perguntas:**
1. How do you prefer to stay in touch? (Texting / Calls / Voice notes / Mix)
2. How quickly do you typically respond to messages?
3. How do you handle conflict? (Talk it through / Need time to process / Avoid it / Depends)
4. How do you prefer to receive appreciation? (Words / Actions / Quality time / Gifts / Touch)

**Armazenamento:** `profiles.communication_style_json JSONB`

**Alimenta:** Motor de ice-breakers (prompts adaptados ao par) · sugestões de rituais do Modo Casal.

---

## D — Mudanças no Ciclo de Vida dos Matches

### 🔴 D1 — Substituir Auto-Desmatch por Arquivo + Reconexão

⚠️ **CONFLITO com doc atual** (`matching-engine.md` tem `archived` como estado de match mas sem lógica de reconexão)

**Estado atual:** Matches ficam ativos indefinidamente. Sem lógica de arquivamento automático após inatividade.

**Novo spec:**

| Estado | Descrição |
|--------|-----------|
| `active` | Ambos podem conversar |
| `archived` | 30 dias de inatividade → arquivado silenciosamente |
| `couple` | Casal ativou Modo Casal |
| `blocked` | Um usuário bloqueou o outro |

**Lógica de arquivamento:**
- Após 30 dias de inatividade: status → `archived` (nunca deletar)
- Match arquivado: oculto do feed principal, acessível na seção "Archived"
- Qualquer um dos dois pode reativar com um toque → status → `active`
- O outro usuário não é notificado até reativar também OU enviar mensagem

**Notificação ao arquivar:** `"Sua conexão com [Nome] foi arquivada silenciosamente. Você pode reativar a qualquer momento."` — nunca culpabilizante.

```sql
ALTER TABLE matches
  ADD COLUMN archived_at TIMESTAMP,
  ADD COLUMN reactivated_at TIMESTAMP;

-- Atualizar ENUM se necessário
ALTER TYPE match_status ADD VALUE 'couple';
```

---

### 🟡 D2 — Ajustes de Tom no Microcopy Místico

**O que mudar:** Copy que usa linguagem excessivamente mística/cósmica.

**Substituir:**
- ❌ "The stars aligned for you two"
- ❌ "Written in the stars"

**Por:**
- ✅ "You share a rare combination of values"
- ✅ "Your attachment styles create a stable foundation"

**Tom alvo:** Caloroso, específico, concreto. Como um amigo que leu Esther Perel, não um app de horóscopo.

---

## E — Importação Pós-Match

### 🟡 E1 — Post-Match Import Flow ("We Met Elsewhere")

**Expansão de mercado:** Qualquer casal, independente de onde se conheceu, pode usar o Modo Casal.

**Ponto de entrada:** Tela de ativação do Modo Casal:
- Opção A: "We matched on Auro"
- Opção B: "We met elsewhere"

**Fluxo (Opção B):**
1. Selecionar como se conheceram
2. Inserir e-mail ou telefone do parceiro
3. Personalizar mensagem de convite
4. Enviar token de convite (uso único, expira em 7 dias, validação server-side)

**Schema:**
```sql
ALTER TABLE couples
  ADD COLUMN activation_source couple_source DEFAULT 'auro_match';

CREATE TYPE couple_source AS ENUM ('auro_match', 'imported');
```

**Analytics:** Registrar `couple_activated_import` com campo `source`. Métrica crítica de funil.

---

## F — Performance de Cache

### 🟢 F1 — Estratégia de Cache v2

| Item | Regra |
|------|-------|
| Respostas de rituais de IA | Cachear na tabela `rituals` após primeira geração. Nunca regenerar para a mesma semana sem mudança de inputs. |
| Pontuações de compatibilidade | Cachear em `compatibility_scores`. Nunca recalcular a cada carregamento. |
| Mapa natal | Calcular UMA VEZ no onboarding via biblioteca open-source. Armazenar JSON em `user_astrology`. Nunca recalcular. |
| Insights semanais (Premium) | Cachear por casal em `couple_insights` com `week_number`. Invalidar ao completar novo ritual. |
| Pool de matches | Cachear resultado da query por 15 minutos por usuário. |

---

# PART B — Modo Casal

## Schema do Banco de Dados

Todas as tabelas abaixo requerem RLS ativado imediatamente na criação. Ver Part C para políticas por tabela.

### Tabelas Principais

```sql
-- CASAIS
CREATE TABLE couples (
  couple_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id         UUID NOT NULL REFERENCES profiles(id),
  user_b_id         UUID NOT NULL REFERENCES profiles(id),
  status            TEXT NOT NULL CHECK (status IN ('active', 'archived', 'ended')) DEFAULT 'active',
  created_at        TIMESTAMP DEFAULT NOW(),
  activation_source TEXT NOT NULL CHECK (activation_source IN ('auro_match', 'imported')),
  day_count         INT DEFAULT 1,
  current_level     SMALLINT DEFAULT 1,
  current_streak    SMALLINT DEFAULT 0,
  last_ritual_week  INT,
  deletion_scheduled_at TIMESTAMP  -- ao encerrar: NOW() + 30 dias
);

-- RITUAIS SEMANAIS
CREATE TABLE rituals (
  ritual_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id          UUID NOT NULL REFERENCES couples(couple_id),
  week_number        INT NOT NULL,
  track              TEXT NOT NULL CHECK (track IN ('emotional','communication','intellectual','adventure','gratitude','playful')),
  title              TEXT NOT NULL,
  insight            TEXT,           -- 2–3 frases geradas por IA
  practice           TEXT,           -- 100–200 palavras geradas por IA
  reflection_question TEXT,
  completed_a_at     TIMESTAMP,
  completed_b_at     TIMESTAMP,
  generated_at       TIMESTAMP DEFAULT NOW(),
  ai_version         VARCHAR(10)
);

-- DIÁRIO DO CASAL
CREATE TABLE journal_entries (
  entry_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id            UUID NOT NULL REFERENCES couples(couple_id),
  author_id            UUID NOT NULL REFERENCES profiles(id),
  body                 TEXT NOT NULL,
  type                 TEXT NOT NULL CHECK (type IN ('free_write','ritual_reflection','ai_prompted','memory')),
  shared_with_partner  BOOLEAN DEFAULT false,  -- CRÍTICO: padrão FALSE
  photos               TEXT[],
  created_at           TIMESTAMP DEFAULT NOW()
  -- SEM campo read_at: parceiro não pode saber se você leu a entrada
);

-- TIMELINE DO RELACIONAMENTO
CREATE TABLE timeline_events (
  event_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  event_name  TEXT NOT NULL,
  event_date  DATE NOT NULL,
  category    TEXT NOT NULL CHECK (category IN ('first_times','trips','milestones','everyday_magic','challenges','celebrations')),
  note        TEXT,
  photos      TEXT[],
  created_at  TIMESTAMP DEFAULT NOW()
);

-- CHECK-INS SEMANAIS
CREATE TABLE check_ins (
  checkin_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(couple_id),
  week_number     INT NOT NULL,
  responses_a     JSONB,
  responses_b     JSONB,
  completed_a_at  TIMESTAMP,
  completed_b_at  TIMESTAMP,
  visible_after   TIMESTAMP,  -- NOW() + 48h na criação. Assimetria de visibilidade.
  both_completed  BOOLEAN DEFAULT false
);

-- DESAFIOS DE 15 DIAS
CREATE TABLE challenges (
  challenge_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id          UUID NOT NULL REFERENCES couples(couple_id),
  challenge_type     VARCHAR(60) NOT NULL,
  started_at         TIMESTAMP DEFAULT NOW(),
  days_completed     SMALLINT DEFAULT 0,
  status             TEXT NOT NULL CHECK (status IN ('active','paused','completed','failed')) DEFAULT 'active',
  daily_cards        JSONB,  -- todos 15 cards pré-gerados no início
  completion_summary TEXT
);

-- CRÉDITOS
CREATE TABLE credits (
  credit_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID UNIQUE NOT NULL REFERENCES profiles(id),
  balance           INT DEFAULT 10,
  monthly_allowance INT DEFAULT 10,
  last_refreshed_at DATE
  -- CRÍTICO: jamais editável pelo cliente. Apenas Edge Functions.
);

-- BADGES
CREATE TABLE badges (
  badge_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(couple_id),
  badge_type  VARCHAR(60) NOT NULL,
  earned_at   TIMESTAMP DEFAULT NOW()
);

-- INSIGHTS DO CASAL (Premium)
CREATE TABLE couple_insights (
  insight_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(couple_id),
  week_number  INT NOT NULL,  -- 0 = retrospectiva mensal
  type         TEXT NOT NULL CHECK (type IN ('weekly','retrospective')),
  content      TEXT NOT NULL,
  generated_at TIMESTAMP DEFAULT NOW(),
  ai_version   VARCHAR(10)
);

-- CONFIGURAÇÃO DE FEATURES (limites free/premium)
CREATE TABLE feature_config (
  key           VARCHAR(60) PRIMARY KEY,
  free_limit    INT,
  premium_limit INT,
  credit_cost   INT,
  enabled       BOOLEAN DEFAULT true
);
```

### Dados Iniciais — `feature_config`

```sql
INSERT INTO feature_config (key, free_limit, premium_limit, credit_cost) VALUES
  ('journal_entry_limit',       30,    NULL, NULL),
  ('timeline_event_limit',      10,    NULL, NULL),
  ('weekly_rituals',             1,    NULL,    3),
  ('icebreaker_prompts_weekly',  3,    NULL, NULL),
  ('streak_protections_monthly', 0,       1,    3),
  ('challenge_access',           0,    NULL,    5),
  ('ai_journal_prompt',          0,    NULL,    1),
  ('timeline_photo_extra',       3,    NULL,    1),  -- 3 por evento para free
  ('date_night_ai',              0,    NULL,    2),
  ('compatibility_deep_dive',    0,       1,   10),  -- 1 grátis one-time para premium
  ('partner_insight_reveal',     0,    NULL,    2),
  ('advanced_checkin',           0,    NULL,    2);
```

> **Regra:** Nunca hardcodar limites no código da aplicação. Sempre ler de `feature_config`. Alterar sem novo deploy.

---

## Lógica de Ativação do Modo Casal

```
1. Usuário toca "Ativar Modo Casal" no match OU "Nos conhecemos em outro lugar"
       |
       v
2A. Caminho A (auro_match)           2B. Caminho B (imported)
   Cria registro de casal              Insere email/telefone do parceiro
   activation_source = auro_match      Edge Function gera token UUID (uso único)
   Envia notificação ao parceiro        expires_at = NOW() + 7 dias
                                        Envia link de convite
       |                                     |
       v                                     v
3. Parceiro aceita: Edge Function valida token (não usado, não expirado)
   Marca token como usado. Cria registro de casal.
       |
       v
4. Na criação do casal:
   day_count = 1, current_level = 1, current_streak = 0
   Dispara geração do primeiro ritual (Edge Function)
       |
       v
5. Tela de boas-vindas: "Dia 1 — Sua jornada começa."
   Primeiro card de ritual visível para ambos.
```

---

## Pontos de Integração de IA — Modo Casal

> **REGRA:** Todas as chamadas de IA passam pelas Edge Functions. O cliente FlutterFlow nunca chama a Claude API diretamente.

| Componente | Entradas | Saída | Regra Crítica |
|------------|----------|-------|---------------|
| **Gerador de Ritual Semanal** | attachment_style_pair · love_language_pair · últimas 4 trilhas completadas · day_count · emotional_readiness_json de ambos | `{ title, insight, practice, reflection_question }` (JSON) | Concluir antes das 08:00 UTC de domingo. Fallback: biblioteca pré-escrita. |
| **Insights Semanais (Premium)** | Tudo do ritual + últimos 3 temas de diário + status do desafio + respostas do check-in anterior | Insight narrativo | Invalidar cache ao completar ritual ou check-in. Regenerar no domingo seguinte. |
| **Prompt de IA para Diário** | Últimas 3 entradas (texto) + emotional_readiness_json | 1 pergunta, máx 25 palavras | Só sob demanda. NÃO fazer cache antecipado. Deduzir crédito ANTES de chamar a API. |
| **Cards Diários do Desafio** | challenge_type + day_number + status dos dias anteriores | Array de 15 cards | Pré-gerar TODOS os 15 cards de uma vez no início. Nunca chamar a API por dia. |
| **Retrospectiva Mensal (Premium)** | Todos rituais + check-ins + entradas de diário + timeline do mês | Narrativa mensal | Gerar assincronamente. Armazenar com `week_number = 0, type = 'retrospective'`. |

**System prompt padrão para saída JSON:**
```
Responda APENAS com um objeto JSON. Sem preâmbulo, sem explicação, sem backticks de markdown.
{ "title": "...", "insight": "...", "practice": "...", "reflection_question": "..." }
```

---

## Lógica de Transação de Créditos

> **REGRA DE SEGURANÇA:** A tabela `credits` NUNCA é editável pelo cliente. Apenas Edge Functions modificam saldos.

```
SEMPRE verificar premium PRIMEIRO:
  IF user.subscription_tier = 'premium' → ignorar toda lógica de créditos, executar direto

FLUXO para usuário free:
  1. Chamar check_credits({user_id, feature_key}) → { has_access, cost, balance }
  2. Se has_access = false → exibir prompt de upgrade
  3. Se has_access = true → chamar deduct_credits({user_id, feature_key, amount})
  4. Executar chamada de IA
  5. Armazenar resultado

Renovação mensal (cron: dia 1 às 00:01 UTC):
  SET balance = GREATEST(balance, monthly_allowance)  -- nunca reduz saldo existente

Notificação de saldo baixo:
  Disparar push quando balance ≤ 2. Máximo 1x a cada 7 dias por usuário.
```

---

## Segurança Psicológica — Regras Técnicas

| Regra | Implementação |
|-------|--------------|
| **Privacidade do diário** | `journal_entries.shared_with_partner` = `false` por padrão. Parceiro não lê até autor setar `true` explicitamente. Aplicado no RLS, não só no app. |
| **Assimetria do check-in** | `visible_after = NOW() + 48h` na criação. Respostas ocultas até `visible_after` passar OU `both_completed = true`. |
| **Ritual não feito — sem culpa** | Se apenas um completou: sem notificação ao outro. Mostrar "[Parceiro] completou o ritual desta semana" — nunca "Você ainda não fez o seu." |
| **Falha no desafio** | `status = paused`. Notificação: "A vida aconteceu. Seu desafio está pausado — retome quando estiver pronto." Nunca "failed". |
| **Sem confirmação de leitura** | `journal_entries`: sem campo `read_at`. Parceiro não sabe se você leu. |
| **Saída do Modo Casal** | `couples.status = ended`. NÃO deletar imediatamente. `deletion_scheduled_at = NOW() + 30 dias`. Usuário pode exportar dados antes. |

---

# PART C — Privacidade e Segurança

## Row Level Security (RLS)

🚨 **Por padrão, Supabase permite que qualquer usuário autenticado leia qualquer linha em qualquer tabela. Sem RLS, o Usuário A lê o diário do Usuário B. Isso é o estado padrão sem configuração.**

### Como Ativar
1. Supabase Dashboard → Database → Tables → selecionar tabela → ativar "Enable RLS"
2. Database → Policies → New Policy → aplicar políticas abaixo
3. Usar `auth.uid()` para referenciar o usuário autenticado
4. **Testar:** usar Supabase Table Editor com token de usuário não-proprietário. Verificar falha ao ler linhas de outro usuário.
5. **NUNCA** desativar RLS em produção, nem temporariamente.

### Políticas por Tabela

| Tabela | Política SELECT | Política INSERT/UPDATE | Notas |
|--------|----------------|----------------------|-------|
| `profiles` / `user_*` | `auth.uid() = id` | Própria linha apenas | Expor apenas campos públicos via VIEW separada para match cards |
| `compatibility_scores` / `matches` | `user_a_id = auth.uid() OR user_b_id = auth.uid()` | Edge Function apenas | Nunca expor scores numéricos brutos ao cliente |
| `messages` | `sender_id = auth.uid() OR receiver_id = auth.uid()` | `sender_id = auth.uid()` | Previne spoofing |
| `journal_entries` | Próprias entradas + compartilhadas onde `couple_id` corresponde E `shared_with_partner = true` | `author_id = auth.uid()` | Entradas privadas invisíveis no nível de RLS |
| `check_ins` | Próprias sempre. Do parceiro após `NOW() > visible_after` OU `both_completed = true` | Edge Function | Visibilidade assimétrica no BD |
| `couples` | `user_a_id = auth.uid() OR user_b_id = auth.uid()` | Edge Function apenas | — |
| `rituals` / `couple_insights` / `challenges` | `couple_id` do casal ativo do usuário | Edge Function apenas | Conteúdo de IA nunca escrito pelo cliente |
| `timeline_events` | `couple_id` do casal ativo | `created_by = auth.uid()` | Ambos podem ver e adicionar |
| `credits` | `user_id = auth.uid()` | **Edge Function apenas** | 🚨 CRÍTICO. Testar UPDATE pelo cliente — deve falhar. |
| `feature_config` | Todos os usuários autenticados (leitura) | Admin via dashboard | Configuração pública |

---

## Segurança das Chaves de API

| Chave | Regra |
|-------|-------|
| **Supabase ANON Key** | Usada no FlutterFlow. Associada ao RLS. Segura no cliente. |
| **Supabase SERVICE ROLE Key** | 🚨 NUNCA no FlutterFlow. NUNCA no git. Apenas em variáveis de ambiente das Edge Functions. Ignora RLS completamente. |
| **Claude API Key** | Apenas server-side. Variável de ambiente da Edge Function. |
| **Biblioteca de Astrologia** | Sem chave de API. Open-source, roda dentro da Edge Function. Sem chamada a terceiros. |

---

## Edge Functions Necessárias no MVP

| Função | Propósito | Modo |
|--------|-----------|------|
| `generate_weekly_rituals` | Cron domingo 06:00 UTC. Gera ritual para cada casal ativo sem ritual na semana. | Casal |
| `generate_ritual_on_demand` | Usuário free gasta 3 créditos por ritual extra. | Casal |
| `generate_journal_prompt` | Sob demanda ao tocar "Me dê um prompt". 1 crédito (free). | Casal |
| `generate_challenge_cards` | Ao desbloquear desafio. Pré-gera todos os 15 cards de uma vez. | Casal |
| `generate_weekly_insights` | Cron de domingo para casais premium. | Casal |
| `calculate_compatibility_score` | Na criação do match. Motor de pontuação completo. IP interno. | Namoro |
| `check_credits` | Antes de qualquer feature com créditos. Retorna `{has_access, cost, balance}`. | Compartilhado |
| `deduct_credits` | Após `check_credits` confirmar. Débito atômico. | Compartilhado |
| `add_credits` | No webhook de IAP e cron de renovação mensal. Idempotente. | Compartilhado |
| `create_couple_invite` | Gera token de convite criptograficamente seguro. | Casal |
| `validate_couple_invite` | Ao parceiro aceitar. Valida token, cria registro de casal. | Casal |
| `upload_photo` | CSAM detection → escrita no storage. NUNCA escrever fotos diretamente pelo cliente. | Compartilhado |
| `delete_account` | Marca `pending_deletion`, revoga sessões, enfileira exclusão definitiva. | Compartilhado |
| `handle_iap_webhook` | Callbacks de pagamento App Store + Play Store. Idempotente. | Compartilhado |

---

## Política de Retenção de Dados

| Tipo de Dado | Regra |
|-------------|-------|
| Dados de perfil | Conta ativa + 30 dias após exclusão solicitada |
| Entradas de diário | Conta ativa + 30 dias. Exportável. |
| Mensagens de chat | 90 dias após última mensagem OU exclusão da conta |
| Dados do casal (rituais, timeline, check-ins) | Duração da conta de casal. Exportável. |
| Eventos de analytics | 2 anos máx. Anonimizar user_id após 1 ano. |
| Logs de auth / segurança | 30 dias contínuos (Supabase Pro) |
| Inatividade | Aviso após 12 meses. Exclusão definitiva após 18 meses com 30 dias de aviso. |

---

## Checklist de Segurança Pré-Lançamento

### A — Supabase
- [ ] RLS ativado em TODAS as tabelas. Sem exceções.
- [ ] Testada cada política com usuário não-proprietário.
- [ ] Expiração do token de auth: 1 hora. Refresh tokens ativados.
- [ ] PgBouncer connection pooling ativado. Modo de transação. String pooled nas Edge Functions.
- [ ] Confirmado que SERVICE ROLE KEY não está em nenhuma variável do FlutterFlow.
- [ ] Supabase Pro ativo antes do primeiro usuário real. Backups diários confirmados.

### B — Documentos de Privacidade (Responsável: Founders)
- [ ] Política de Privacidade publicada. Conformidade CCPA/CPRA (EUA).
- [ ] Termos de Serviço publicados.
- [ ] URLs adicionadas ao App Store Connect e Google Play Console.

### C — Segurança da Aplicação
- [ ] Tokens de convite: expiração 7 dias, uso único, validação server-side.
- [ ] Edge Function `upload_photo` executa CSAM (PhotoDNA ou AWS Rekognition) antes de escrever no storage.
- [ ] Fluxo de exclusão de conta testado ponta a ponta.
- [ ] Todas as Edge Functions têm tratamento de erros. Falha de IA retorna fallback elegante, nunca erro bruto.
- [ ] Mapa natal calculado via biblioteca open-source dentro da Edge Function. Confirmado: sem chamada de API externa.
- [ ] MBTI implementado internamente. Confirmado: sem API, licença ou serviço externo de MBTI.

---

# PART D — Arquitetura e Escalabilidade

## D1 — Stack de 4 Camadas

```
┌─────────────────────────────────────────────────────────────┐
│ CAMADA 1: CLIENTE                                           │
│ FlutterFlow App (iOS + Android)                             │
│ • UI e navegação                                            │
│ • Apenas Supabase Anon Key · Apenas tokens de analytics     │
│ • Deep links (tokens de convite, universal links)           │
└──────────────────┬─────────────────────┬───────────────────┘
                   │ DB direto (Anon+RLS) │ Chamadas Edge Function
                   ↓                      ↓
┌──────────────────────────┐  ┌──────────────────────────────┐
│ CAMADA 2: BANCO DE DADOS │  │ CAMADA 3: EDGE FUNCTIONS     │
│ Supabase Postgres        │  │ Supabase (Deno/TypeScript)   │
│ • Todas as tabelas       │  │ • Geração de rituais de IA   │
│ • RLS em cada tabela  ↔  │  │ • Cálculo de score          │
│ • Supabase Storage       │  │ • Transações de créditos     │
│ • Supabase Auth          │  │ • Detecção de CSAM          │
│ • Realtime (chat)        │  └──────────────┬───────────────┘
└──────────────────────────┘                 │ Chamadas externas
                                             ↓
┌─────────────────────────────────────────────────────────────┐
│ CAMADA 4: APIs EXTERNAS                                     │
│ Claude API (Anthropic) · Push (FCM/APNs) · App Store IAP   │
│ PhotoDNA (CSAM) · PostHog/Mixpanel                          │
│ NÃO inclui: Astrologia (open-source local) · MBTI (interno)│
└─────────────────────────────────────────────────────────────┘
```

### Exemplos de Fluxo de Requisição

| Feature | Fluxo |
|---------|-------|
| Mensagem de chat | Cliente → Supabase DB (Anon + RLS). Realtime entrega ao destinatário. Sem Edge Function. |
| Completar ritual | Cliente → DB: `UPDATE rituals SET completed_a_at = NOW()`. RLS garante acesso apenas ao próprio casal. |
| Prompt de IA para diário | Cliente → Edge Function → verifica créditos → deduz → Claude API → armazena → retorna prompt. |
| Ritual de domingo (cron) | pg_cron 06:00 UTC → Edge Function → consulta casais sem ritual → Claude API em lotes → armazena. |
| Ativar Modo Casal | Cliente → Edge Function `create_couple_invite` → cria linha + gera token. |
| Compra de créditos | App Store → webhook → Edge Function `handle_iap_webhook` → valida → `add_credits`. |

---

## D2 — Arquitetura Multi-Modo: Construir Uma Vez, Expandir Para Sempre

**Decisão crítica:** Se Dating Mode e Couple Mode forem apps independentes, adicionar Wedding Mode custa 6 meses. Com o padrão abaixo, custa 6 semanas.

### Flags de Modo — Adicionar AGORA na tabela `profiles`

```sql
ALTER TABLE profiles
  ADD COLUMN active_mode         TEXT DEFAULT 'dating' CHECK (active_mode IN ('dating','couple','wedding','life')),
  ADD COLUMN dating_mode_enabled  BOOLEAN DEFAULT true,
  ADD COLUMN couple_mode_enabled  BOOLEAN DEFAULT false,
  ADD COLUMN wedding_mode_enabled BOOLEAN DEFAULT false,
  ADD COLUMN life_mode_enabled    BOOLEAN DEFAULT false,
  ADD COLUMN subscription_tier    TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free','premium','premium_plus'));
```

> Essas colunas não custam nada. Não tê-las depois custa uma migração completa.

### Namespaces de Telas no FlutterFlow

| Namespace | Telas |
|-----------|-------|
| MODO NAMORO | DiscoverScreen, MatchProfileScreen, ChatScreen, CompatibilityScreen |
| MODO CASAL | CoupleDashboardScreen, RitualScreen, JournalScreen, TimelineScreen, CheckInScreen, ChallengeScreen |
| MODO CASAMENTO | WeddingPlaceholderScreen (stub oculto) |
| MODO VIDA | LifePlaceholderScreen (stub oculto) |
| COMPARTILHADAS | ProfileScreen, SettingsScreen, CreditsScreen, NotificationsScreen |

---

## D3 — Índices do Banco de Dados — Criar Antes do Lançamento

> Uma query que leva 2ms com 1.000 linhas leva 8 segundos com 1.000.000 linhas.

```sql
-- profiles
CREATE INDEX idx_users_location ON profiles USING GIST(location);
CREATE INDEX idx_users_active ON profiles(last_active_at) WHERE active = true;

-- compatibility_scores / matches
CREATE INDEX idx_matches_user_a ON matches(user_a_id, status);
CREATE INDEX idx_matches_user_b ON matches(user_b_id, status);
CREATE INDEX idx_matches_score ON matches(score DESC);

-- messages
CREATE INDEX idx_messages_match ON messages(match_id, created_at DESC);
CREATE INDEX idx_messages_unread ON messages(receiver_id) WHERE read_at IS NULL;

-- rituals
CREATE INDEX idx_rituals_couple_week ON rituals(couple_id, week_number);
CREATE INDEX idx_rituals_pending ON rituals(generated_at) WHERE completed_a_at IS NULL;

-- journal_entries
CREATE INDEX idx_journal_couple ON journal_entries(couple_id, created_at DESC);
CREATE INDEX idx_journal_author ON journal_entries(author_id);

-- timeline_events
CREATE INDEX idx_timeline_couple ON timeline_events(couple_id, event_date DESC);

-- credits
CREATE INDEX idx_credits_user ON credits(user_id);
```

---

## D4 — Otimização de Custos de IA

| Estado (100K casais ativos) | Custo Semanal | Custo Anual |
|----------------------------|---------------|-------------|
| Baseline (cache + roteamento) | ~$400/semana | ~$20.800/ano |
| + Cache de prompt (system prompt) | ~$200/semana | −40–50% |
| + Saídas JSON estruturadas | ~$160/semana | −20% |
| + Geração em lote mensal | ~$65/semana | maior economia |
| + Fallback de biblioteca pré-escrita | **~$35/semana** | estado otimizado |

### Três Otimizações a Implementar Antes do Primeiro Cron de Domingo

**1. Saída JSON Estruturada**
```
System prompt: "Responda APENAS com um objeto JSON. Sem preâmbulo, sem explicação, sem backticks."
{ "title": "...", "insight": "...", "practice": "...", "reflection_question": "..." }
```
Resultado: ~30% de redução de tokens.

**2. Geração em Lote Mensal**
```
"Gere 4 rituais semanais para este casal para o próximo mês.
Retorne um array JSON de 4 objetos de ritual."
```
Resultado: ~65% de redução de custo por casal. Overhead de contexto pago uma vez.

**3. Fallback de Biblioteca Pré-Escrita**
- Construir biblioteca de 200 rituais pré-escritos de alta qualidade
- Para casais com < 3 rituais completados nos últimos 30 dias: servir da biblioteca
- IA apenas para casais ativamente engajados
- Resultado: ~50% dos casais com custo quase zero

---

## D5 — Regras de Ouro para a Equipe

| # | Regra | Por quê |
|---|-------|---------|
| 1 | RLS em toda tabela | Nunca tabela com dados de usuário sem RLS. Testar com não-proprietário antes de entregar. |
| 2 | Service role key = apenas servidor | Uma linha no cliente com essa chave = incidente crítico imediato. |
| 3 | Créditos = apenas Edge Function | Tabela de créditos não pode ser tocada pelo cliente. |
| 4 | Cache de saída de IA | Ritual gerado uma vez é cacheado. Regenerar a cada carregamento é desastre de custo. |
| 5 | Limites no `feature_config` | Nunca hardcodar "30 entradas" no código. Vive no BD. |
| 6 | Flags de modo no `profiles` | Adicionar as 4 colunas agora. Custo zero. Não ter depois custa migração. |
| 7 | Telas em namespaces | Stubs de Casamento e Vida existem no app desde o dia 1, ocultos. |
| 8 | Índices antes do lançamento | Todos os índices criados antes de qualquer usuário real. |
| 9 | Connection pooling ativado | PgBouncer ativado no Supabase Pro antes do lançamento. Modo de transação. |
| 10 | CSAM antes das fotos | Obrigação legal. Sem exceção. |
| 11 | Astrologia = sem API externa | Open-source dentro da Edge Function. Sem custo por chamada. |
| 12 | MBTI = construído internamente | Sem API, licença ou serviço externo de MBTI. |

---

# PART E — Analytics e Notificações

> **REGRA DE PRIVACIDADE:** Nunca registrar o CONTEÚDO do input do usuário. Textos de diário, respostas de rituais, respostas de check-in e mensagens NUNCA aparecem em eventos de analytics. Apenas estrutura e comportamento.

## Propriedades Globais (Enviar com Todos os Eventos)

| Propriedade | Definição |
|-------------|-----------|
| `user_id` | UUID interno pseudonimizado (não email, não nome) |
| `subscription_tier` | `free` \| `premium`. Atualizar imediatamente na mudança. |
| `active_mode` | `dating` \| `couple` |
| `has_active_couple` | BOOLEAN |
| `app_version` | String (ex: `'1.0.2'`) |
| `platform` | `ios` \| `android` |
| `days_since_signup` | Inteiro calculado no momento do evento |
| `couple_day_count` | Inteiro. Apenas se `has_active_couple = true` |

---

## Mapa de Eventos

### A — Onboarding

| Evento | Gatilho | Propriedades |
|--------|---------|-------------|
| `app_opened` | Primeiro abrir após instalação | `source: organic\|paid\|referral\|unknown` |
| `onboarding_started` | Toque em "Começar" | — |
| `onboarding_step_completed` | Completa cada etapa | `step_name: account_created\|photos_added\|bio_written\|love_language_completed\|attachment_style_completed\|...` |
| `onboarding_completed` | Chega ao app principal | `steps_completed: int, time_to_complete_seconds: int` |
| `onboarding_abandoned` | App fechado, não retomado em 24h | `last_step_completed: string` |
| `attachment_style_result` | Avaliação completada | `result: secure\|anxious\|avoidant\|fearful_avoidant` |
| `love_language_result` | Quiz completado | `primary: words\|acts\|gifts\|time\|touch` |

### B — Modo Namoro

| Evento | Gatilho | Propriedades |
|--------|---------|-------------|
| `dating_mode_opened` | Entra no Modo Namoro | — |
| `profile_viewed` | Visualiza perfil | `compatibility_label: string` |
| `profile_swiped` | Faz swipe | `direction: like\|pass, compatibility_label: string` |
| `match_created` | Like mútuo | `match_id (hash)` |
| `icebreaker_sent` | Envia icebreaker | `icebreaker_type: suggested\|custom, is_first_message: bool` |
| `conversation_started` | Primeira mensagem | `hours_since_match: int` |
| `compatibility_deep_dive_viewed` | Vê relatório completo | `is_premium: bool, used_credits: bool` |
| `couple_mode_activated_from_dm` | Toca "Somos um casal" no match | — |

### C — Ativação do Modo Casal

| Evento | Gatilho | Propriedades |
|--------|---------|-------------|
| `couple_mode_entry_viewed` | Vê tela de ativação | `entry_point: match_profile\|menu\|post_match_import` |
| `couple_invite_sent` | Envia convite | `activation_source: auro_match\|imported` |
| `couple_invite_accepted` | Parceiro aceita | `hours_to_accept: int` |
| `couple_invite_expired` | Convite expirou | `hours_elapsed: int` |
| `couple_activated` | Ambos confirmados | `activation_source: string, hours_from_invite: int` |
| `compatibility_offer_accepted` | Casal importado aceita avaliação | — |

### D — Engajamento do Modo Casal

**Rituais:**

| Evento | Propriedades |
|--------|-------------|
| `ritual_card_viewed` | `ritual_track: string, week_number: int` |
| `ritual_completed` | `ritual_track: string, partner_also_completed: bool, days_after_generation: int` |
| `ritual_both_completed` | `hours_between_completions: int` |
| `ritual_reflection_written` | `word_count: int` (NUNCA o conteúdo) |
| `ritual_extra_requested` | `credits_used: 3, balance_after: int` |
| `ritual_streak_updated` | `new_streak: int, previous_streak: int` |

**Diário:**

| Evento | Propriedades |
|--------|-------------|
| `journal_entry_created` | `type: free_write\|ritual_reflection\|ai_prompted\|memory, word_count: int` |
| `journal_entry_shared` | — |
| `journal_prompt_used` | `credits_used: 0\|1` |
| `journal_limit_reached` | `current_count: 30` |

**Check-in:**

| Evento | Propriedades |
|--------|-------------|
| `checkin_started` | `checkin_type: basic\|advanced` |
| `checkin_completed` | `checkin_type: string` |
| `checkin_both_completed` | `hours_between: int` |
| `checkin_results_viewed` | — |

**Desafio:**

| Evento | Propriedades |
|--------|-------------|
| `challenge_started` | `challenge_type: string, credits_used: 0\|5` |
| `challenge_day_completed` | `day_number: int, challenge_type: string` |
| `challenge_completed` | `days_taken: int` |
| `challenge_paused` | `day_number: int, days_missed: int` |

**Timeline:**

| Evento | Propriedades |
|--------|-------------|
| `timeline_event_added` | `category: string, has_photo: bool` |
| `timeline_viewed` | `events_count: int` |
| `timeline_limit_reached` | `current_count: 10` |

### E — Monetização

| Evento | Propriedades |
|--------|-------------|
| `upgrade_prompt_shown` | `trigger: journal_limit\|timeline_limit\|ritual_limit\|credits_low\|streak_day_25\|level_5` |
| `upgrade_prompt_dismissed` | `trigger: string` |
| `subscription_started` | `plan: individual_monthly\|couple_monthly\|individual_annual\|couple_annual` |
| `subscription_cancelled` | `days_subscribed: int, plan: string` |
| `credits_purchased` | `pack_size: 20\|50\|100\|250, balance_after: int` |
| `credit_spent` | `feature: ritual\|journal_prompt\|challenge\|deep_dive, credits_spent: int` |

### G — Retenção e Ciclo de Vida

| Evento | Propriedades |
|--------|-------------|
| `app_session_started` | `days_since_last_session: int` |
| `push_notification_tapped` | `notification_type: string, minutes_to_tap: int` |
| `push_notification_dismissed` | `notification_type: string` |
| `account_deletion_requested` | `days_since_signup: int, has_active_couple: bool` |

---

## Mapa de Notificações

### Regras Globais

| Regra | Detalhe |
|-------|---------|
| Limite — Modo Casal | Máx 3 notificações não-críticas por semana por usuário |
| Limite — Modo Namoro | Máx 7 por semana. Novo match nunca é limitado. |
| Horas silenciosas | Sem notificações entre 22:00–08:00 horário local. Agrupar para entrega matinal. |
| Opt-out granular | Usuário desativa cada categoria independentemente. Nunca desativar tudo. |

### Modo Namoro

| Gatilho | Copy Exato | Deep Link |
|---------|-----------|-----------|
| `new_match` | "Você fez match com [Nome] — veja o que têm em comum" | → perfil do match |
| `new_message` | "[Nome] enviou uma mensagem para você" | → chat |
| `icebreaker_received` | "[Nome] quebrou o gelo com uma pergunta para você 💬" | → chat |
| `match_archived` | "Sua conexão com [Nome] foi arquivada silenciosamente. Você pode reativar a qualquer momento." | → archived matches |
| `weekly_activity_nudge` | "Você tem [X] novos matches potenciais esta semana" | → descobrir (máx 1/semana) |

### Ativação do Modo Casal

| Gatilho | Copy Exato | Deep Link |
|---------|-----------|-----------|
| `invite_sent` | "Você convidou [Parceiro(a)] para iniciar sua jornada no Modo Casal 💚" | → modo casal |
| `invite_received` | "[Nome] quer começar a jornada do Modo Casal juntos 💚 Toque para aceitar." | → ativação |
| `couple_activated_sender` | "[Parceiro(a)] aceitou! Sua jornada começa hoje. 🎊" | → dashboard |
| `couple_activated_receiver` | "Sua jornada com [Nome] começa agora. 🎊" | → dashboard |

### Engajamento do Modo Casal

| Gatilho | Copy Exato | Frequência |
|---------|-----------|------------|
| `ritual_available` | "Seu ritual desta semana está pronto. ✨" | 1x/semana, domingo |
| `partner_completed_ritual` | "[Parceiro(a)] completou o ritual desta semana." | 1x por evento |
| `ritual_reminder` | "Ainda há tempo para completar o ritual desta semana com [Nome]." | Quinta-feira se não completou |
| `checkin_available` | "Seu check-in semanal está pronto." | 1x/semana |
| `checkin_results_ready` | "Seus resultados do check-in com [Nome] estão disponíveis." | Quando `both_completed = true` |
| `streak_milestone` | "Vocês chegaram a [X] semanas seguidas! 🔥" | Em marcos: 4, 8, 12, 26, 52 semanas |
| `challenge_day` | "Dia [X] do desafio! Seu card de hoje está esperando." | 1x/dia durante desafio ativo |
| `low_credits` | "Seus créditos estão acabando. Você tem [X] restantes." | 1x a cada 7 dias (saldo ≤ 2) |

---

# APÊNDICE — Schema Atual vs Schema Necessário

## Mudanças no Schema Existente

### Tabela `profiles` — Adicionar Colunas

```sql
-- Novas dimensões de onboarding
ALTER TABLE profiles
  ADD COLUMN emotional_readiness_json   JSONB,
  ADD COLUMN communication_style_json   JSONB;

-- Flags de modo (multi-modo)
ALTER TABLE profiles
  ADD COLUMN active_mode          TEXT DEFAULT 'dating',
  ADD COLUMN dating_mode_enabled  BOOLEAN DEFAULT true,
  ADD COLUMN couple_mode_enabled  BOOLEAN DEFAULT false,
  ADD COLUMN wedding_mode_enabled BOOLEAN DEFAULT false,
  ADD COLUMN life_mode_enabled    BOOLEAN DEFAULT false,
  ADD COLUMN subscription_tier    TEXT DEFAULT 'free';
```

### Tabela `user_personality` — Adicionar Estilo de Apego

```sql
CREATE TYPE attachment_style_type AS ENUM (
  'secure', 'anxious', 'avoidant', 'fearful_avoidant'
);

ALTER TABLE user_personality
  ADD COLUMN attachment_style attachment_style_type;
```

### Tabela `compatibility_scores` — Versionamento

```sql
ALTER TABLE compatibility_scores
  ADD COLUMN scoring_version VARCHAR(10) DEFAULT 'v2.0',
  ADD COLUMN scored_at       TIMESTAMP DEFAULT NOW();
```

### Tabela `matches` — Estados e Arquivamento

```sql
-- Adicionar novos estados ao enum de status
ALTER TABLE matches
  ADD COLUMN archived_at    TIMESTAMP,
  ADD COLUMN reactivated_at TIMESTAMP;

-- Se status for enum, adicionar valor 'couple':
-- ALTER TYPE match_status ADD VALUE 'couple';
-- Verificar se 'archived' já existe; se não, adicionar também.
```

### Tabela `user_relationship_prefs` — Ajuste de Tipo de Relacionamento

```sql
-- Verificar se dating_style já tem os valores corretos:
-- 'monogamous', 'open', 'polyamorous', 'flexible'
-- Adicionar 'flexible' se não existir
```

## Novas Tabelas a Criar (Modo Casal)

Todas definidas na Part B. Ordem de criação (respeitando FKs):
1. `couples`
2. `credits`
3. `feature_config`
4. `rituals`
5. `journal_entries`
6. `timeline_events`
7. `check_ins`
8. `challenges`
9. `couple_insights`
10. `badges`

## Mudanças no Algoritmo — Resumo de Impacto

| Mudança | Arquivo Impactado | Tipo de Mudança |
|---------|------------------|-----------------|
| Relationship type → Phase 1 | `calculate_compatibility_score` EF | Lógica de negócio |
| Remover hobbies do Block 3 | `calculate_compatibility_score` EF | Peso de scoring |
| Adicionar Attachment Style (25%) | `calculate_compatibility_score` EF + `compatibility_weights` | Novo bloco + peso |
| MBTI 30% → 15% | `compatibility_weights` table | Peso de scoring |
| Política → 25% → 20% | `compatibility_weights` table | Peso de scoring |
| Religião → 25% → 20% | `compatibility_weights` table | Peso de scoring |
| Labels de compatibilidade | UI + notificações | Copy/display |
| Remover score numérico da UI | Profile card payload + UI | Display |
| Bloco "attention" → "worth_exploring" | EF de explicação + UI | Copy/schema |

---

*Documento criado em Março 2026. Consolida: docs/overview.md · docs/compatibility-algorithm.md · docs/matching-engine.md · docs/onboarding-profile.md · docs/chat.md · docs/journey.md + Auro Developer Complete Handoff v1.0 (Parts A–E).*

# PART A — Mudanças: Sistema de Compatibilidade
**Status:** 11 mudanças críticas · 3 importantes · 1 melhoria
**Referência:** `docs/compatibility-algorithm.md` · `docs/onboarding-profile.md` · `docs/matching-engine.md`

> Este documento registra exatamente o que existia antes, o que muda e onde cada mudança impacta o código. Use como checklist de implementação.

---

## Legenda

| Símbolo | Prioridade |
|---------|-----------|
| 🔴 | Crítico — bloqueia lançamento |
| 🟡 | Importante — 1–2 semanas pós-lançamento |
| 🟢 | Melhoria — alvo v2 |

---

## SEÇÃO A — Exibição de Pontuação e UI

---

### 🔴 A1 — Remover Score Numérico de Toda a UI do Usuário

#### Antes
O profile card response enviava o score numérico ao cliente:
```json
{
  "compatibility_score": 92,
  "compatibility_label": "A strong connection!"
}
```
A UI exibia variações como `"87%"`, `"73% compatible"` em:
- Match cards (feed de descoberta)
- Header da tela de chat
- Chat list screen (`"compatibility_score": 87` no response)
- Copy de notificações

#### Depois
O score numérico **nunca chega ao cliente**. O campo é calculado internamente, usado para ranking e como input de IA, mas removido do payload antes de enviar ao FlutterFlow.

```json
{
  "compatibility_label": "Strong Alignment"
}
```

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function / query que monta o profile card | Remover `compatibility_score` do SELECT ou do JSON de resposta ao cliente |
| Chat list screen response | Remover campo `compatibility_score` do payload |
| Qualquer notificação com percentual | Reescrever copy sem número (ver Part E) |
| FlutterFlow UI | Remover todo componente que exiba número/percentual de compatibilidade |

> O motor interno **continua calculando e armazenando** o score em `compatibility_scores`. Ele só não vai mais para o cliente.

---

### 🔴 A2 — Substituir Todos os Rótulos de Compatibilidade

#### Antes (`compatibility-algorithm.md`)

| Faixa | Rótulo |
|-------|--------|
| 85–100 | Rare Connection |
| 70–84 | High Compatibility |
| 50–69 | Compatible with Differences |
| 30–49 | Few Things in Common |
| 0–29 | **Unlikely** |

#### Depois

| Faixa (score interno) | Rótulo exibido ao usuário |
|----------------------|--------------------------|
| 85–100 | ✨ Rare Connection |
| 70–84 | 💚 Strong Alignment |
| 50–69 | 💛 Compatible with Differences |
| 30–49 | 🟠 Different Foundations |
| 0–29 | 💬 Worth a Conversation |

**Regra crítica:** O rótulo "Unlikely" é removido permanentemente. O rótulo mais baixo (`"Worth a Conversation"`) é sempre um convite, nunca uma rejeição.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function `calculate_compatibility_score` | Atualizar a função/tabela que mapeia score → label |
| `compatibility_weights` ou lógica de label | Substituir os 5 rótulos pelos novos exatos acima |
| FlutterFlow UI | Atualizar todo componente que renderiza o rótulo (match card, perfil completo) |
| Notificações | Verificar se alguma notificação usa rótulos antigos — substituir |

---

### 🔴 A3 — Renomear Terceiro Bloco da Narrativa de IA

#### Antes
A Edge Function de explicação gerava e retornava:
```json
{
  "strengths": "You both share Physical Touch as your love language...",
  "complements": "Your MBTIs (INFJ and ENFP) are one of the most complementary pairs...",
  "attention": "Different political views — but you're both open to a different perspective."
}
```
O bloco `"attention"` era renderizado com linguagem de alerta/aviso na UI.

#### Depois
```json
{
  "strengths": "You both share Physical Touch as your love language...",
  "complements": "Your MBTIs (INFJ and ENFP) are one of the most complementary pairs...",
  "worth_exploring": "Different political views — but you're both open to exploring different perspectives together."
}
```

**Mudança de tom obrigatória:** O bloco deve soar como convite à curiosidade, não como alerta. Reescrever o system prompt da IA para refletir isso.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function que gera explicação de compatibilidade | Renomear campo `attention` → `worth_exploring` no JSON de saída |
| System prompt da IA (explicação) | Instruir: "O terceiro bloco é um convite à curiosidade, nunca um alerta. Tom: caloroso e curioso." |
| `compatibility_scores.explanation` (se armazenado como JSON) | Migrar campo nos scores já cacheados ou invalidar para regenerar |
| FlutterFlow UI | Renomear referências ao campo + atualizar título exibido ("Vale explorar juntos") |

---

### 🔴 A4 — Remover Barras de Sub-pontuação do Match Card

#### Antes
O profile card response incluía o breakdown de scores e a UI renderizava barras visuais de progresso no match card:
```json
"go_deeper": {
  "score_breakdown": {
    "love": 88,
    "lifestyle": 72,
    "values": 85,
    "astrology": 90
  }
}
```

#### Depois

**No match card (feed de descoberta):** Apenas foto + nome + rótulo de compatibilidade + distância/idade. Sem barras, sem sub-scores.

**Na tela de perfil completo** (destrinchado ao tocar no card): sub-scores podem aparecer como **categorias de texto**, nunca como barras de percentual.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Profile card payload | `score_breakdown` não enviado no card do feed (pode ser enviado apenas quando usuário abre o perfil completo) |
| FlutterFlow — match card UI | Remover componentes de barra de progresso / sub-scores |
| FlutterFlow — tela de perfil completo | Manter sub-scores apenas como texto/categorias, sem percentual visual |

---

## SEÇÃO B — Motor de Pontuação

---

### 🔴 B1 — Tipo de Relacionamento: de Penalty para Filtro Eliminatório

#### Antes (`compatibility-algorithm.md` — Phase 2: Penalties)
O tipo de relacionamento era tratado como **penalidade**, deduzida do score final:

```
Relationship Type Mismatch (Phase 2 — Penalty):
  monogamous vs polyamorous: -30 a -40 pontos
  long_term vs open_relation: -30 a -40 pontos
  casual vs long_term: -20 a -30 pontos
```
Ou seja: um usuário monogâmico **aparecia no feed** de um poliamoroso — só com score menor.

#### Depois
Tipo de relacionamento vai para **Phase 1 — Filtro Eliminatório**, com o mesmo tratamento de orientação sexual. Se incompatíveis: nunca aparecem no pool um do outro.

```
Phase 1 — Filtro Rígido (NOVO):
  IF A.dating_style = 'monogamous' AND B.dating_style = 'polyamorous' → ELIMINADO
  IF A.dating_style = 'flexible' → passa com qualquer tipo (nunca eliminado)
  Bidirecional: se qualquer direção elimina, o par é descartado
```

**Enum atualizado** (verificar se já existe ou precisa migrar):
```sql
-- Novo valor 'flexible' se não existir
-- 'flexible' pode fazer match com qualquer tipo
CREATE TYPE dating_style_type AS ENUM (
  'monogamous',
  'open',
  'polyamorous',
  'flexible'
);
```

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function `calculate_compatibility_score` | Mover verificação de `dating_style` da Phase 2 para Phase 1 (antes de qualquer scoring) |
| Phase 2 penalties | Remover a penalty de relationship type mismatch |
| `user_relationship_prefs` schema | Verificar se o campo `dating_style` tem o valor `'flexible'`. Adicionar se não tiver. |
| `compatibility_weights` table | Remover entrada de peso para relationship type mismatch se existir |

---

### 🔴 B2 — Corrigir Dupla Ponderação de Hobbies

#### Antes
Hobbies estavam presentes em **dois blocos simultaneamente**, gerando peso dobrado no score:

- **Block 2 — Lifestyle (25% do total):** `hobbies` com peso de 25% dentro do bloco ✅ correto
- **Block 3 — Values (25% do total):** `hobbies` também sendo considerado via `user_values` ← bug

**Distribuição antiga do Block 3:**
```
MBTI:            30%
Visão Política:  25%
Religião:        25%
Situação + Área: 20%
Total:          100%
```
(hobbies vazando do Block 2 para o Block 3 via query em `user_values`)

#### Depois
Hobbies pertencem **exclusivamente** ao Block 2. O Block 3 recebe uma nova dimensão (Estilo de Apego) e os pesos são redistribuídos:

**Nova distribuição do Block 3 — Values & Personality:**
```
Estilo de Apego: 25%  ← NOVO
MBTI:            15%  ← era 30%
Visão Política:  20%  ← era 25%
Religião:        20%  ← era 25%
Situação + Área: 20%  ← sem alteração
Total:          100%
```

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function `calculate_compatibility_score` — Block 3 | Remover qualquer referência a `hobbies` / `user_values.hobbies` do cálculo do Block 3 |
| `compatibility_weights` table | Atualizar pesos do Block 3: MBTI 0.30→0.15, Politics 0.25→0.20, Religion 0.25→0.20, adicionar attachment_style 0.25 |
| Documentação interna | Deixar explícito: hobbies = Block 2 only |

---

### 🔴 B3 — Adicionar Estilo de Apego ao Block 3 (25%)

#### Antes
Não existia. Nenhum campo `attachment_style` em qualquer tabela. O Block 3 tinha apenas 4 dimensões.

#### Depois
Estilo de Apego representa **25% do Block 3** (o maior peso individual do bloco). Calculado via matriz fixa de pontuação por par.

**Matriz de pontuação:**

| Par | Pontos |
|-----|--------|
| Seguro ↔ Seguro | 100 |
| Seguro ↔ Ansioso | 75 |
| Seguro ↔ Evitativo | 65 |
| Mesmo estilo ↔ Mesmo estilo (qualquer) | 70 |
| Evitativo-Medroso ↔ Qualquer | 45 |
| Ansioso ↔ Evitativo | 25 |

**Regra de fallback:** Se um dos usuários não completou a avaliação → usar **50 pontos** como fallback neutro. Não bloquear o matching.

**Schema — adicionar ao banco:**
```sql
CREATE TYPE attachment_style_type AS ENUM (
  'secure',
  'anxious',
  'avoidant',
  'fearful_avoidant'
);

ALTER TABLE user_personality
  ADD COLUMN attachment_style attachment_style_type;
```

**Lógica de pontuação na Edge Function:**
```typescript
function scoreAttachmentStyle(styleA: string | null, styleB: string | null): number {
  if (!styleA || !styleB) return 50; // fallback neutro

  const matrix: Record<string, number> = {
    'secure|secure': 100,
    'secure|anxious': 75,
    'anxious|secure': 75,
    'secure|avoidant': 65,
    'avoidant|secure': 65,
    'anxious|avoidant': 25,
    'avoidant|anxious': 25,
  };

  const key = `${styleA}|${styleB}`;
  const reverseKey = `${styleB}|${styleA}`;

  // Mesmo estilo
  if (styleA === styleB) return 70;

  // fearful_avoidant com qualquer
  if (styleA === 'fearful_avoidant' || styleB === 'fearful_avoidant') return 45;

  return matrix[key] ?? matrix[reverseKey] ?? 50;
}
```

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| `user_personality` table | Adicionar coluna `attachment_style attachment_style_type` |
| Edge Function `calculate_compatibility_score` — Block 3 | Implementar `scoreAttachmentStyle()` + aplicar peso de 25% |
| `compatibility_weights` table | Adicionar entrada `attachment_style: 0.25` no block 3 |
| Onboarding flow | Adicionar etapa C1 (ver seção C deste documento) |

---

### 🟡 B4 — Adicionar Versionamento ao Motor de Pontuação

#### Antes
A tabela `compatibility_scores` não tinha versionamento. Impossível saber com qual versão do algoritmo um score foi calculado, auditar mudanças ou fazer A/B test.

#### Depois
Dois novos campos na tabela. A regra é: **nunca sobrescrever um score** — sempre inserir nova linha.

```sql
ALTER TABLE compatibility_scores
  ADD COLUMN scoring_version VARCHAR(10) DEFAULT 'v2.0',
  ADD COLUMN scored_at       TIMESTAMP DEFAULT NOW();
```

**Versão atual do motor após estas mudanças:** `v2.0`

**Gatilhos de repontuação** (quando recalcular scores existentes do usuário):
- Usuário atualiza `attachment_style`
- Usuário atualiza `mbti_type`
- Usuário atualiza `dating_style`

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| `compatibility_scores` table | Adicionar colunas `scoring_version` e `scored_at` |
| Edge Function `calculate_compatibility_score` | Sempre INSERT nova linha (não UPDATE). Incluir `scoring_version = 'v2.0'`. |
| Trigger / lógica de invalidação | Ao detectar mudança nos campos acima, marcar scores como `is_stale = true` + enfileirar recálculo |

---

## SEÇÃO C — Novas Dimensões de Onboarding

> Três novas etapas adicionadas ao onboarding. **C1** alimenta o score de compatibilidade. **C2** e **C3** alimentam apenas IA e personalização — nunca são pontuadas e nunca exibidas a outros usuários.

---

### 🔴 C1 — Avaliação de Estilo de Apego (8 Perguntas) — PONTUADA

#### Antes
Não existia. O onboarding ia diretamente de Love Language para Values sem nenhuma dimensão de apego.

#### Depois
Nova etapa inserida **após o quiz de Love Language e antes das perguntas de valores**.

**Especificação da etapa:**
- 8 perguntas
- Escala de 4 pontos: Concordo Totalmente / Concordo / Discordo / Discordo Totalmente
- Sem opção neutra (forçar escolha)
- Resultado: um dos 4 estilos (`secure`, `anxious`, `avoidant`, `fearful_avoidant`)

**Exemplos de perguntas:**
1. "Acho fácil depender de outras pessoas" → seguro
2. "Fico preocupado(a) que meu parceiro(a) não me ame de verdade" → ansioso
3. "Prefiro não compartilhar meus sentimentos com os outros" → evitativo
4. "Me sinto desconfortável quando alguém fica próximo demais de mim" → evitativo
5. "Tenho facilidade em confiar nos meus parceiros" → seguro
6. "Às vezes quero intimidade, às vezes ela me assusta" → fearful_avoidant
7. "Fico ansioso(a) quando não recebo atenção suficiente" → ansioso
8. "Me sinto bem contando com os outros quando preciso" → seguro

**Cálculo do resultado:** Somar os pontos por estilo nas 8 respostas → estilo com maior pontuação = resultado.

**Armazenamento:**
```sql
-- Campo adicionado em B3
user_personality.attachment_style = 'secure' | 'anxious' | 'avoidant' | 'fearful_avoidant'
```

**Editável pelo usuário:** Sim, nas configurações de perfil.

**Alimenta:**
- Score de compatibilidade (25% do Block 3)
- IA do Modo Casal (gerador de rituais)
- Tom dos ice-breakers
- Insights semanais premium

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| FlutterFlow — onboarding flow | Inserir nova tela de avaliação entre Love Language e Values |
| `onboarding_progress` table | Adicionar step `attachment_style_assessment` ao tracking de progresso |
| Edge Function ou lógica de cálculo do resultado | Implementar algoritmo de scoring das 8 respostas → enum de estilo |
| `user_personality` table | Salvar resultado em `attachment_style` |

---

### 🔴 C2 — Check-in de Prontidão Emocional (3 Perguntas) — NÃO PONTUADA

#### Antes
Não existia. Nenhum dado sobre estado emocional atual do usuário era coletado no onboarding.

#### Depois
Etapa final antes de completar o perfil. Enquadrada como: *"Algumas perguntas rápidas para personalizar sua experiência."*

**As 3 perguntas:**
1. How open are you to a relationship right now? → Escala 1–5
2. Are you in a place of healing from a previous relationship? → Yes / Mostly healed / No
3. What are you most hoping Auro helps you with? → Múltipla escolha

**Armazenamento:**
```sql
ALTER TABLE profiles
  ADD COLUMN emotional_readiness_json JSONB;

-- Exemplo de valor armazenado:
-- {
--   "openness": 4,
--   "healing_status": "mostly_healed",
--   "goals": ["meaningful_connection", "self_discovery"]
-- }
```

**NUNCA:**
- Usada no score de compatibilidade
- Exibida a outros usuários

**Alimenta:** Tom do onboarding · seleção de rituais no Modo Casal · motor de ice-breakers.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| FlutterFlow — onboarding flow | Inserir nova tela como última etapa antes de concluir o perfil |
| `profiles` table | Adicionar coluna `emotional_readiness_json JSONB` |
| `onboarding_progress` table | Adicionar step `emotional_readiness` ao tracking |

---

### 🔴 C3 — Estilo de Comunicação (4 Perguntas) — NÃO PONTUADA

#### Antes
Não existia. Nenhum dado sobre preferências de comunicação era coletado.

#### Depois
Etapa inserida no onboarding (pode ser na mesma tela de C2 ou separada).

**As 4 perguntas:**
1. How do you prefer to stay in touch? → Texting / Calls / Voice notes / Mix
2. How quickly do you typically respond to messages? → Immediately / Within hours / When I can / Depends
3. How do you handle conflict? → Talk it through / Need time to process / Avoid it / Depends
4. How do you prefer to receive appreciation? → Words / Actions / Quality time / Gifts / Touch

**Armazenamento:**
```sql
ALTER TABLE profiles
  ADD COLUMN communication_style_json JSONB;

-- Exemplo de valor armazenado:
-- {
--   "contact_preference": "texting",
--   "response_speed": "within_hours",
--   "conflict_style": "need_time",
--   "appreciation_style": "words"
-- }
```

**NUNCA:**
- Usada no score de compatibilidade
- Exibida a outros usuários

**Alimenta:** Motor de ice-breakers (prompts adaptados ao par de comunicação) · sugestões de rituais do Modo Casal.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| FlutterFlow — onboarding flow | Inserir nova tela de comunicação |
| `profiles` table | Adicionar coluna `communication_style_json JSONB` |
| `onboarding_progress` table | Adicionar step `communication_style` ao tracking |

---

## SEÇÃO D — Ciclo de Vida dos Matches

---

### 🔴 D1 — Substituir Auto-Desmatch por Arquivo + Reconexão

#### Antes (`matching-engine.md`)
O campo `status` do match tinha os estados:
```
active     → ambos podem conversar
archived   → um usuário arquivou (sem lógica de reconexão definida)
unmatched  → um usuário desmatched (chat deletado para ambos)
```
Sem lógica de arquivamento automático por inatividade. Sem fluxo de reconexão.

#### Depois
O match nunca é deletado por inatividade. Vai para estado `archived` após 30 dias sem mensagem.

**Estados do match atualizados:**
```
active    → ambos podem conversar (estado normal)
archived  → 30 dias de inatividade → arquivado silenciosamente
couple    → casal ativou Modo Casal (novo estado)
blocked   → um usuário bloqueou o outro
```

**Lógica de arquivamento:**
```
Trigger / cron diário:
  IF match.status = 'active'
     AND last_message_at < NOW() - INTERVAL '30 days'
     AND (completed_a_at IS NULL OR completed_b_at IS NULL)
  → UPDATE matches SET status = 'archived', archived_at = NOW()
  → Enviar notificação (copy abaixo)
```

**Lógica de reconexão:**
```
Quando usuário toca "Reativar" em um match arquivado:
  → UPDATE matches SET status = 'active', reactivated_at = NOW()
  → O outro usuário NÃO é notificado até: reativar também OU enviar mensagem
```

**Notificação ao arquivar:**
> "Sua conexão com [Nome] foi arquivada silenciosamente. Você pode reativar a qualquer momento."

**Seção "Archived" na UI:** Match arquivado é oculto do feed principal mas acessível em seção dedicada "Archived Connections".

**Schema:**
```sql
-- Verificar se os novos estados existem no enum
-- Se status for texto/enum, adicionar 'couple' e garantir 'archived'
ALTER TABLE matches
  ADD COLUMN archived_at    TIMESTAMP,
  ADD COLUMN reactivated_at TIMESTAMP;

-- Se usar ENUM:
-- ALTER TYPE match_status ADD VALUE 'couple';
```

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| `matches` table | Adicionar colunas `archived_at`, `reactivated_at`. Garantir estados `archived` e `couple` no status. |
| Cron job / pg_cron | Criar job diário que arquiva matches inativos há 30+ dias |
| Edge Function ou lógica de push | Disparar notificação de arquivamento com copy exato |
| FlutterFlow — chat list | Criar seção "Archived" separada do feed principal |
| FlutterFlow — match arquivado | Botão "Reativar" que chama Edge Function de reconexão |

---

### 🟡 D2 — Ajustes de Tom no Microcopy Místico

#### Antes
Copy com linguagem excessivamente mística/cósmica em vários pontos do app:
- "The stars aligned for you two"
- "Written in the stars"
- Variações de "destino", "universo", "cosmos"

#### Depois
Tom caloroso, específico e concreto. Como um amigo que leu Esther Perel, não um app de horóscopo.

**Exemplos de substituição:**

| Antes | Depois |
|-------|--------|
| "The stars aligned for you two" | "You share a rare combination of values" |
| "Written in the stars" | "Your attachment styles create a stable foundation" |
| "The universe brought you together" | "You both prioritize the same things in a relationship" |

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| FlutterFlow — match card copy | Revisar e substituir microcopy místico |
| System prompts de IA | Instruir: "Tom: caloroso, específico, baseado em dados reais do perfil. Não usar linguagem cósmica ou mística." |
| Notificações | Revisar copy de push notifications com linguagem mística |
| Tela de match ("You matched!") | Revisar copy da tela de novo match |

---

## SEÇÃO E — Importação Pós-Match

---

### 🟡 E1 — Post-Match Import Flow ("We Met Elsewhere")

#### Antes
O Modo Casal só era acessível por usuários que fizeram match dentro do Auro. Sem fluxo para casais que se conheceram fora do app.

#### Depois
Qualquer casal pode usar o Modo Casal, independente de onde se conheceu. Isso expande dramaticamente o mercado endereçável.

**Ponto de entrada — tela de ativação do Modo Casal:**
- Opção A: "We matched on Auro" → fluxo atual
- Opção B: "We met elsewhere" → novo fluxo de importação

**Fluxo — Opção B:**
```
Step 1: Selecionar como se conheceram (opção educacional, não crítica)
Step 2: Inserir e-mail ou telefone do parceiro
Step 3: Personalizar mensagem de convite (texto editável)
Step 4: Enviar → Edge Function gera token (UUID, uso único, expira em 7 dias)
Step 5: Parceiro recebe link → abre app → Edge Function valida token → cria registro de casal
```

**Token de convite (server-side only):**
```typescript
// Edge Function: create_couple_invite
const token = crypto.randomUUID();
const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

await supabase.from('couple_invites').insert({
  token,
  created_by: userId,
  expires_at: expiresAt,
  used: false
});
```

**Schema:**
```sql
-- Nova tabela de convites
CREATE TABLE couple_invites (
  invite_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token       UUID UNIQUE NOT NULL,
  created_by  UUID NOT NULL REFERENCES profiles(id),
  expires_at  TIMESTAMP NOT NULL,
  used        BOOLEAN DEFAULT false,
  used_at     TIMESTAMP,
  used_by     UUID REFERENCES profiles(id)
);

-- Campo no registro de casal
ALTER TABLE couples
  ADD COLUMN activation_source TEXT NOT NULL DEFAULT 'auro_match'
  CHECK (activation_source IN ('auro_match', 'imported'));
```

**Analytics obrigatório:** Registrar evento `couple_activated_import` com campo `source`. Métrica crítica de funil de aquisição.

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| FlutterFlow — tela de ativação do Modo Casal | Adicionar as duas opções (Auro match vs "We met elsewhere") |
| Nova Edge Function `create_couple_invite` | Gerar token, armazenar com expiração, enviar convite |
| Nova Edge Function `validate_couple_invite` | Validar token (não usado, não expirado), criar registro de casal |
| `couples` table | Adicionar campo `activation_source` |
| Nova tabela `couple_invites` | Criar com token + expiração + controle de uso único |
| Analytics | Disparar evento `couple_activated_import` na ativação via importação |

---

## SEÇÃO F — Performance de Cache

---

### 🟢 F1 — Estratégia de Cache v2

#### Antes
Cache definido de forma incompleta. Pool de matches cacheado por 10 min. Score de compatibilidade cacheado em `compatibility_scores`. Sem regras explícitas para outros tipos de conteúdo.

#### Depois
Regras explícitas por tipo de conteúdo:

| Conteúdo | Regra de Cache | Invalidação |
|----------|---------------|-------------|
| Rituais de IA gerados | Cachear em `rituals` após geração. Nunca regenerar na mesma semana sem mudança de inputs. | Mudança no perfil do casal |
| Score de compatibilidade | Cachear em `compatibility_scores`. Nunca recalcular a cada page load. | `is_stale = true` quando perfil muda |
| Mapa natal (birth chart) | Calcular UMA VEZ no onboarding. Armazenar JSON em `user_astrology`. Nunca recalcular. | Nunca (exceto re-edição de birth data) |
| Insights semanais premium | Cachear por casal em `couple_insights` com `week_number`. | Ao completar novo ritual ou check-in |
| Pool de matches | Cachear por 15 minutos por usuário. | TTL ou mudança de filtros |

#### O que mudar

| Onde | O que fazer |
|------|-------------|
| Edge Function de rituais | Verificar se já existe ritual na semana antes de chamar a IA |
| `user_astrology` | Garantir que mapa natal é calculado apenas no onboarding (ou re-edição de birth data) |
| Pool de matches query | Implementar cache de 15 minutos (Redis ou tabela temporária) |
| `couple_insights` | Implementar invalidação ao completar ritual ou submeter check-in |

---

## Resumo — Checklist de Implementação (Part A)

### 🔴 Crítico (fazer antes do lançamento)

- [ ] **A1** — Remover `compatibility_score` do payload enviado ao cliente
- [ ] **A2** — Substituir os 5 rótulos de compatibilidade pelos novos (incluindo remover "Unlikely")
- [ ] **A3** — Renomear campo `attention` → `worth_exploring` na IA de explicação + atualizar system prompt
- [ ] **A4** — Remover barras de sub-pontuação do match card
- [ ] **B1** — Mover `dating_style` da Phase 2 (penalty) para Phase 1 (filtro eliminatório)
- [ ] **B2** — Remover `hobbies` do Block 3. Atualizar pesos: MBTI 15%, Politics 20%, Religion 20%
- [ ] **B3** — Adicionar `attachment_style` ao schema + implementar matriz de pontuação no Block 3 (25%)
- [ ] **C1** — Criar etapa de avaliação de estilo de apego no onboarding (8 perguntas)
- [ ] **C2** — Criar check-in de prontidão emocional no onboarding (3 perguntas) + campo `emotional_readiness_json`
- [ ] **C3** — Criar etapa de estilo de comunicação no onboarding (4 perguntas) + campo `communication_style_json`
- [ ] **D1** — Implementar arquivamento automático de matches + lógica de reconexão

### 🟡 Importante (1–2 semanas pós-lançamento)

- [ ] **B4** — Adicionar `scoring_version` e `scored_at` em `compatibility_scores`
- [ ] **D2** — Revisar e substituir microcopy místico em todo o app
- [ ] **E1** — Implementar fluxo "We met elsewhere" + Edge Functions de convite

### 🟢 Melhoria (v2)

- [ ] **F1** — Implementar estratégia completa de cache v2

---

## Schema SQL Consolidado — Todas as Mudanças da Part A

```sql
-- ============================================================
-- PART A — Mudanças de Schema
-- Versão: v2.0 | Março 2026
-- ============================================================

-- 1. Estilo de Apego
CREATE TYPE attachment_style_type AS ENUM (
  'secure', 'anxious', 'avoidant', 'fearful_avoidant'
);
ALTER TABLE user_personality
  ADD COLUMN attachment_style attachment_style_type;

-- 2. Novas colunas de onboarding em profiles
ALTER TABLE profiles
  ADD COLUMN emotional_readiness_json   JSONB,
  ADD COLUMN communication_style_json   JSONB;

-- 3. Versionamento de scores
ALTER TABLE compatibility_scores
  ADD COLUMN scoring_version VARCHAR(10) DEFAULT 'v2.0',
  ADD COLUMN scored_at       TIMESTAMP DEFAULT NOW();

-- 4. Arquivamento de matches
ALTER TABLE matches
  ADD COLUMN archived_at    TIMESTAMP,
  ADD COLUMN reactivated_at TIMESTAMP;
-- Garantir que 'couple' e 'archived' existem no status (verificar enum existente)

-- 5. Tabela de convites de casal
CREATE TABLE couple_invites (
  invite_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token       UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  created_by  UUID NOT NULL REFERENCES profiles(id),
  expires_at  TIMESTAMP NOT NULL,
  used        BOOLEAN DEFAULT false,
  used_at     TIMESTAMP,
  used_by     UUID REFERENCES profiles(id),
  created_at  TIMESTAMP DEFAULT NOW()
);

-- 6. Adicionar 'flexible' ao dating_style se não existir
-- (verificar enum atual antes de rodar)
-- ALTER TYPE dating_style_type ADD VALUE 'flexible';

-- 7. activation_source no casal (preparação para Part B)
-- Será criado com a tabela couples na Part B
```

---

*Documento de mudanças Part A — gerado em Março 2026*
*Referências: `docs/compatibility-algorithm.md` · `docs/onboarding-profile.md` · `docs/matching-engine.md` · Auro Developer Handoff v1.0 Part A*

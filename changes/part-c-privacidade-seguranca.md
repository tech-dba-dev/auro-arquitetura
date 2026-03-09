# PART C — Mudanças: Privacidade e Segurança
**Status:** RLS parcialmente implementado com falhas críticas · CSAM ausente · 10 tabelas novas sem política
**Referência:** `docs/schema.sql` (linhas 1007–1257) · Auro Developer Handoff v1.0 Part C

> O Auro coleta dados altamente sensíveis: orientação sexual, estilo de apego, entradas de diário, visão política, religião. Este documento registra exatamente o que existe no schema atual, o que está errado, o que falta e o SQL correto para cada situação.

---

## Estado Atual vs Novo — Visão Geral

| Área | Estado Atual | Problema | Prioridade |
|------|-------------|----------|-----------|
| RLS — `profiles` | Ativado, mas `SELECT` abre tudo para todos | Dados sensíveis expostos (orientação, deal breakers, apego) | 🔴 Crítico |
| RLS — tabelas `user_*` | Implementado corretamente | — | ✅ OK |
| RLS — `compatibility_scores` | Apenas SELECT. Sem bloqueio de INSERT/UPDATE do cliente | Motor de score pode ser manipulado | 🔴 Crítico |
| RLS — `matches` | SELECT + UPDATE. Sem bloqueio de INSERT do cliente | Matches podem ser criados fraudulentamente | 🔴 Crítico |
| RLS — `user_photos` | INSERT direto do cliente permitido | Fotos armazenadas sem CSAM detection | 🔴 Crítico (obrigação legal) |
| RLS — `reports` | Apenas INSERT. Sem SELECT | Usuário não consegue ver relatórios próprios | ⚠️ Verificar |
| RLS — 10 tabelas do Modo Casal | Não existem | Todas as tabelas de Couple Mode sem proteção | 🔴 Crítico |
| CSAM Detection | Não implementado | Fotos armazenadas sem verificação | 🔴 Crítico (bloqueador legal) |
| Service Role Key | Não documentado formalmente | Risco de exposição no FlutterFlow | 🔴 Crítico |
| Supabase Storage | Sem regras de acesso documentadas | URLs podem ser públicas inadvertidamente | 🔴 Crítico |
| Retenção de dados | Não implementada | Sem cron de exclusão, sem política formal | 🟡 Importante |

---

## SEÇÃO 1 — RLS: Correções nas Tabelas Existentes

### 1.1 — `profiles`: Política de SELECT Muito Aberta

#### Antes (`schema.sql` linha 1022)
```sql
CREATE POLICY "Profiles are viewable by all authenticated users"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);  -- ← PROBLEMA: expõe TUDO para qualquer usuário autenticado
```

**O que esta política expõe inadvertidamente para qualquer usuário autenticado:**
- `sexual_orientation` (dado sensível)
- `emotional_readiness_json` (adicionado na Part A — nunca deve ser visível a outros)
- `communication_style_json` (adicionado na Part A — nunca deve ser visível a outros)
- `bio` completa, `timezone`, `last_active_at`, etc.

#### Depois

**Estratégia:** Criar uma VIEW pública `public_profiles` com apenas os campos seguros para match cards. A tabela completa só é lida pelo próprio usuário.

```sql
-- 1. Corrigir política de SELECT na tabela profiles
DROP POLICY IF EXISTS "Profiles are viewable by all authenticated users" ON profiles;

CREATE POLICY "Users can read own full profile"
  ON profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- 2. Criar VIEW pública com apenas campos seguros (para match cards)
CREATE VIEW public_profiles AS
  SELECT
    id,
    display_name,
    birthdate,
    gender,
    occupation,
    education,
    bio,
    avatar_url,
    location,           -- apenas ponto geográfico, não endereço
    last_active_at,
    onboarding_complete,
    active_mode
    -- NÃO incluir: sexual_orientation, emotional_readiness_json,
    -- communication_style_json, subscription_tier, timezone
  FROM profiles;

-- RLS na VIEW: todos os autenticados podem ler (para match cards)
-- A VIEW herda o RLS da tabela base — verificar comportamento no Supabase
-- Alternativa: usar security_definer se necessário
```

**Tabelas de perfil específicas que expõem dados sensíveis a outros usuários:**

| Campo | Tabela | Visível a outros? |
|-------|--------|------------------|
| `sexual_orientation` | `profiles` | Apenas se o usuário optou por exibir |
| `attachment_style` | `user_personality` | Nunca — só o próprio usuário |
| `emotional_readiness_json` | `profiles` | Nunca — só o próprio usuário |
| `communication_style_json` | `profiles` | Nunca — só o próprio usuário |
| `deal_breakers_json` | `user_relationship_prefs` | Nunca — IP do algoritmo + dado privado |
| `preferences_json` | `user_relationship_prefs` | Nunca |
| `birth_time`, `birth_location` | `user_astrology` | Nunca |

---

### 1.2 — `compatibility_scores`: Bloqueio de Escrita do Cliente

#### Antes
```sql
-- Apenas SELECT existe. Nenhum bloqueio explícito de INSERT/UPDATE/DELETE do cliente.
CREATE POLICY "Users can view their own compatibility scores"
  ON compatibility_scores FOR SELECT TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);
```

#### Depois
```sql
-- Manter SELECT existente (apenas os próprios scores)
-- Sem policy de INSERT/UPDATE/DELETE para o cliente
-- Edge Function usa service_role key (ignora RLS) para escrever scores

-- Adicionar policy explícita de DENY para INSERT do cliente
-- (No Supabase, ausência de policy = negado para operações não cobertas)
-- Mas para clareza e auditoria, documentar que INSERT = service_role only

-- Opcional: adicionar comentário explícito no schema
COMMENT ON TABLE compatibility_scores IS
  'READ: user_a or user_b. WRITE: service_role (Edge Function) only.';
```

---

### 1.3 — `matches`: Bloqueio de INSERT do Cliente

#### Antes
```sql
-- INSERT não estava explicitamente bloqueado
CREATE POLICY "Users can view their own matches"
  ON matches FOR SELECT TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);
CREATE POLICY "Users can update their own matches"
  ON matches FOR UPDATE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);
-- Sem policy de INSERT = client pode tentar inserir match fraudulento
```

#### Depois
```sql
-- INSERT de match: apenas Edge Function (via service_role)
-- UPDATE de match: apenas para campos permitidos (ex: arquivar, bloquear)
-- Substituir a policy de UPDATE por uma mais restrita:

DROP POLICY IF EXISTS "Users can update their own matches" ON matches;

CREATE POLICY "Users can archive or block their own matches"
  ON matches FOR UPDATE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b)
  WITH CHECK (
    -- Usuário só pode mudar status para 'archived' ou 'blocked'
    -- Não pode criar match, não pode mudar user_a/user_b
    status IN ('archived', 'blocked')
  );

COMMENT ON TABLE matches IS
  'INSERT: service_role only. UPDATE: limited to status changes by participants.';
```

---

### 1.4 — `user_photos`: Bloquear INSERT Direto do Cliente

#### Antes
```sql
-- Cliente pode inserir fotos diretamente sem CSAM detection
CREATE POLICY "Users can upload their own photos"
  ON user_photos FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);  -- ← PROBLEMA: sem CSAM
```

#### Depois
Fotos **nunca** são inseridas diretamente pelo cliente. O fluxo obrigatório é:

```
Cliente → Edge Function upload_photo → CSAM Detection → Se aprovado → Supabase Storage → INSERT em user_photos
```

```sql
-- Remover policy de INSERT do cliente
DROP POLICY IF EXISTS "Users can upload their own photos" ON user_photos;

-- INSERT apenas via service_role (Edge Function upload_photo)
-- Manter: SELECT, UPDATE (reordenar), DELETE (remover foto)
COMMENT ON TABLE user_photos IS
  'INSERT: service_role only (via upload_photo Edge Function with CSAM check).';
```

---

### 1.5 — `reports`: Adicionar SELECT para o Próprio Reporter

#### Antes
```sql
-- Usuário pode criar report mas não pode ver o próprio report depois
CREATE POLICY "Users can create reports"
  ON reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);
-- Sem SELECT policy
```

#### Depois
```sql
CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);
```

---

## SEÇÃO 2 — RLS: Tabelas do Modo Casal (Novas — Part B)

Todas as 10 tabelas criadas na Part B precisam de políticas. Abaixo o SQL completo.

---

### 2.1 — `couples`

```sql
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;

-- SELECT: qualquer um dos dois parceiros pode ler o casal
CREATE POLICY "Couple members can view their couple"
  ON couples FOR SELECT TO authenticated
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

-- INSERT: apenas Edge Function (service_role)
-- UPDATE: apenas Edge Function (status, day_count, streaks, etc.)
-- DELETE: nunca (dados preservados por 30 dias após ended)

COMMENT ON TABLE couples IS
  'READ: both partners. WRITE: service_role only.';
```

---

### 2.2 — `rituals`

```sql
ALTER TABLE rituals ENABLE ROW LEVEL SECURITY;

-- SELECT: membros do casal
CREATE POLICY "Couple members can view rituals"
  ON rituals FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- UPDATE: apenas para marcar como completo (completed_a_at ou completed_b_at)
CREATE POLICY "Users can mark their ritual completion"
  ON rituals FOR UPDATE TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Apenas o campo do próprio usuário pode ser atualizado
    -- user_a_id atualiza completed_a_at, user_b_id atualiza completed_b_at
    -- Verificar via lógica na Edge Function, não via RLS puro
    true
  );

-- INSERT: apenas Edge Function (geração de rituais)
COMMENT ON TABLE rituals IS
  'READ: both partners. INSERT: service_role only. UPDATE: completion timestamps only.';
```

---

### 2.3 — `journal_entries` ⚠️ Mais Complexa

```sql
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

-- SELECT: próprias entradas SEMPRE + entradas do parceiro SÓ SE shared_with_partner = true
CREATE POLICY "Users can read own journal entries"
  ON journal_entries FOR SELECT TO authenticated
  USING (author_id = auth.uid());

CREATE POLICY "Users can read partner shared entries"
  ON journal_entries FOR SELECT TO authenticated
  USING (
    shared_with_partner = true
    AND couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
    AND author_id != auth.uid()
  );

-- INSERT: apenas o próprio autor
CREATE POLICY "Users can create own journal entries"
  ON journal_entries FOR INSERT TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
        AND status = 'active'
    )
  );

-- UPDATE: apenas o próprio autor (ex: toggle shared_with_partner)
CREATE POLICY "Users can update own journal entries"
  ON journal_entries FOR UPDATE TO authenticated
  USING (author_id = auth.uid());

-- DELETE: apenas o próprio autor
CREATE POLICY "Users can delete own journal entries"
  ON journal_entries FOR DELETE TO authenticated
  USING (author_id = auth.uid());

COMMENT ON TABLE journal_entries IS
  'Private by default (shared_with_partner = false). Partner access only when explicitly shared.';
```

---

### 2.4 — `timeline_events`

```sql
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;

-- SELECT: ambos os parceiros veem toda a timeline
CREATE POLICY "Couple members can view timeline"
  ON timeline_events FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- INSERT: qualquer um dos parceiros pode adicionar evento
CREATE POLICY "Couple members can add timeline events"
  ON timeline_events FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
        AND status = 'active'
    )
  );

-- UPDATE: apenas quem criou o evento
CREATE POLICY "Event creator can update timeline event"
  ON timeline_events FOR UPDATE TO authenticated
  USING (created_by = auth.uid());

-- DELETE: apenas quem criou o evento
CREATE POLICY "Event creator can delete timeline event"
  ON timeline_events FOR DELETE TO authenticated
  USING (created_by = auth.uid());
```

---

### 2.5 — `check_ins` ⚠️ Visibilidade Assimétrica

```sql
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

-- SELECT: próprias respostas sempre.
-- Respostas do parceiro: após 48h OU ambos completaram.
CREATE POLICY "Users can view own checkin responses"
  ON check_ins FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
    AND (
      -- Sempre pode ver o próprio
      (
        couple_id IN (SELECT couple_id FROM couples WHERE user_a_id = auth.uid())
        AND responses_a IS NOT NULL
      )
      OR
      (
        couple_id IN (SELECT couple_id FROM couples WHERE user_b_id = auth.uid())
        AND responses_b IS NOT NULL
      )
      -- Pode ver do parceiro após condição de tempo/completude
      OR both_completed = true
      OR NOW() > visible_after
    )
  );

-- INSERT: criado via Edge Function quando check-in é iniciado
-- UPDATE: usuário submete próprias respostas
CREATE POLICY "Users can submit own checkin responses"
  ON check_ins FOR UPDATE TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

COMMENT ON TABLE check_ins IS
  'Asymmetric visibility: partner responses hidden until 48h elapsed or both completed.';
```

---

### 2.6 — `challenges`

```sql
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couple members can view challenges"
  ON challenges FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- UPDATE: marcar dias como completos (cliente pode atualizar days_completed e status)
CREATE POLICY "Couple members can update challenge progress"
  ON challenges FOR UPDATE TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- INSERT: apenas Edge Function (ao desbloquear com créditos)
COMMENT ON TABLE challenges IS
  'INSERT: service_role only. UPDATE: progress by partners.';
```

---

### 2.7 — `credits` 🚨 Mais Crítica

```sql
ALTER TABLE credits ENABLE ROW LEVEL SECURITY;

-- SELECT: apenas o próprio saldo
CREATE POLICY "Users can view own credits"
  ON credits FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- INSERT/UPDATE/DELETE: NENHUMA POLICY PARA O CLIENTE
-- Apenas service_role (Edge Functions) pode modificar créditos
-- Ausência de policy = operação negada para o cliente autenticado

COMMENT ON TABLE credits IS
  'CRITICAL: No INSERT/UPDATE/DELETE policies for authenticated role.
   All modifications via service_role (Edge Functions) only.
   Test: attempt UPDATE as client — must fail with RLS violation.';
```

**Como testar que está correto:**
```sql
-- Executar como usuário autenticado no Supabase Table Editor
-- Deve retornar: "new row violates row-level security policy"
UPDATE credits SET balance = 9999 WHERE user_id = 'seu-user-id';
```

---

### 2.8 — `badges`

```sql
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couple members can view badges"
  ON badges FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- INSERT: apenas Edge Function (ao atingir marcos)
COMMENT ON TABLE badges IS 'INSERT: service_role only.';
```

---

### 2.9 — `couple_insights`

```sql
ALTER TABLE couple_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couple members can view insights"
  ON couple_insights FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- INSERT: apenas Edge Function (geração de IA)
COMMENT ON TABLE couple_insights IS 'INSERT: service_role only (AI generation).';
```

---

### 2.10 — `feature_config`

```sql
ALTER TABLE feature_config ENABLE ROW LEVEL SECURITY;

-- Todos os usuários autenticados podem LER os limites (para mostrar na UI)
CREATE POLICY "Feature config is readable by all authenticated users"
  ON feature_config FOR SELECT TO authenticated
  USING (true);

-- INSERT/UPDATE/DELETE: apenas admin via Supabase Dashboard (service_role)
COMMENT ON TABLE feature_config IS
  'READ: all authenticated. WRITE: admin via dashboard (service_role) only.';
```

---

## SEÇÃO 3 — CSAM Detection

🚨 **Bloqueador legal. Nenhuma foto é armazenada até essa verificação passar.**

### Antes
O schema atual permite INSERT direto em `user_photos` e upload direto para Supabase Storage pelo cliente. Nenhuma verificação de conteúdo é feita.

### Depois

**Fluxo obrigatório para toda foto:**
```
Cliente seleciona foto
       │
       ▼
Edge Function: upload_photo
       │
       ├─ 1. Validar tipo de arquivo (JPEG/PNG/WEBP apenas)
       ├─ 2. Validar tamanho (máx 10MB)
       ├─ 3. CSAM Detection (PhotoDNA ou AWS Rekognition)
       │         │
       │    ┌────┴────────────────────────────────────┐
       │    │ CSAM detectado?                         │
       │    │ SIM → Rejeitar. Logar. Reportar à NCMEC.│
       │    │ NÃO → Continuar                         │
       │    └────────────────────────────────────────┘
       │
       ├─ 4. Comprimir / redimensionar
       ├─ 5. Gerar path único no Storage
       ├─ 6. Fazer upload para Supabase Storage
       └─ 7. INSERT em user_photos (via service_role)
              │
              ▼
       Retornar URL ao cliente
```

**Opções de provider para CSAM:**

| Provider | Como usar | Custo |
|----------|-----------|-------|
| **PhotoDNA (Microsoft)** | API REST — requer aprovação da Microsoft | Gratuito para empresas qualificadas |
| **AWS Rekognition** | `detect-moderation-labels` API | ~$0.001 por imagem |
| **Google Cloud Vision SafeSearch** | API REST | ~$0.0015 por imagem |

> **Recomendação:** AWS Rekognition é o mais simples de integrar e não requer aprovação prévia. PhotoDNA é mais preciso para CSAM específico mas requer processo de onboarding com a Microsoft.

**Estrutura da Edge Function `upload_photo`:**
```typescript
// Edge Function: upload_photo
// Recebe: multipart/form-data com a imagem
// Retorna: { url: string } ou { error: string }

export async function uploadPhoto(req: Request) {
  const formData = await req.formData();
  const file = formData.get('file') as File;
  const userId = /* extrair de JWT */;

  // 1. Validar tipo e tamanho
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    return error('invalid_file_type');
  }
  if (file.size > 10 * 1024 * 1024) {
    return error('file_too_large');
  }

  // 2. CSAM Detection (AWS Rekognition)
  const csamResult = await detectCSAM(file);
  if (csamResult.flagged) {
    await logAndReport(userId, file, csamResult); // reportar à NCMEC
    return error('content_policy_violation');
  }

  // 3. Upload para Storage
  const path = `${userId}/${crypto.randomUUID()}.jpg`;
  const { data, error: storageError } = await supabase.storage
    .from('user-photos')
    .upload(path, file, { upsert: false });

  if (storageError) return error('upload_failed');

  // 4. INSERT em user_photos via service_role
  await supabase.from('user_photos').insert({
    user_id: userId,
    photo_url: data.path,
    position: /* próxima posição disponível */,
  });

  return { url: data.path };
}
```

---

## SEÇÃO 4 — Supabase Storage: Regras de Acesso

### Buckets e Políticas

| Bucket | Acesso de Leitura | Acesso de Escrita |
|--------|------------------|------------------|
| `user-photos` | Usuários autenticados (para match cards) | Apenas Edge Function `upload_photo` |
| `journal-photos` | Apenas o casal (via RLS) | Apenas Edge Function `upload_photo` |
| `chat-media` | Apenas os dois usuários do match | Apenas os dois usuários do match |
| `timeline-photos` | Apenas o casal | Apenas o casal |

**Configuração de Storage no Supabase:**
```sql
-- Bucket user-photos: público para leitura (necessário para match cards)
-- Mas escrita bloqueada via policy de Storage

INSERT INTO storage.buckets (id, name, public)
VALUES ('user-photos', 'user-photos', false);  -- NÃO público — usar signed URLs

-- Policy de Storage para user-photos
CREATE POLICY "Authenticated users can view photos"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'user-photos');

-- Escrita: apenas service_role (Edge Function upload_photo)
-- Sem INSERT policy para o cliente no bucket user-photos
```

> **Por que não público?** URLs públicas são permanentes e indexáveis. Usar signed URLs com expiração (1 hora) para proteger fotos de usuários que deletaram a conta.

---

## SEÇÃO 5 — Segurança das Chaves de API

### Regras por Tipo de Chave

| Chave | Onde vive | O que pode fazer | Onde NUNCA deve estar |
|-------|-----------|-----------------|----------------------|
| **Supabase ANON Key** | FlutterFlow / cliente | Operações permitidas pelo RLS | — (segura no cliente) |
| **Supabase SERVICE ROLE Key** | Apenas Edge Functions (env var) | Ignora RLS completamente | FlutterFlow · git · logs · Sentry |
| **Claude API Key** | Apenas Edge Functions (env var) | Chamar Claude API | FlutterFlow · git · qualquer cliente |
| **PhotoDNA / AWS Rekognition Key** | Apenas Edge Functions (env var) | CSAM detection | FlutterFlow · git |
| **Push notification keys (FCM/APNs)** | Apenas Edge Functions (env var) | Enviar notificações | FlutterFlow · git |

### Variáveis de Ambiente nas Edge Functions

```bash
# .env das Edge Functions (nunca commitado no git)
SUPABASE_SERVICE_ROLE_KEY=eyJ...
CLAUDE_API_KEY=sk-ant-...
AWS_ACCESS_KEY_ID=AKI...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
FCM_SERVER_KEY=...
```

**Verificação obrigatória antes do lançamento:**
```bash
# Buscar no repositório por chaves expostas
grep -r "service_role" --include="*.dart" .
grep -r "sk-ant-" --include="*.dart" .
grep -r "SERVICE_ROLE" --include="*.dart" .
# Nenhum resultado deve ser encontrado
```

### `.gitignore` Obrigatório
```gitignore
# Edge Functions
supabase/functions/.env
supabase/functions/**/.env.local
*.env
.env.*
!.env.example
```

---

## SEÇÃO 6 — Edge Functions: Por Que Cada Uma Deve Ser Server-Side

| Função | Por que não pode ser cliente |
|--------|------------------------------|
| `generate_weekly_rituals` | Usa SERVICE_ROLE key + Claude API key |
| `calculate_compatibility_score` | Contém pesos do algoritmo (IP) + escreve em `compatibility_scores` |
| `deduct_credits` / `add_credits` | Tabela `credits` não pode ser tocada pelo cliente |
| `upload_photo` | CSAM detection antes de qualquer armazenamento |
| `create_couple_invite` | Gera token criptograficamente seguro |
| `validate_couple_invite` | Valida token + cria registro de casal via service_role |
| `delete_account` | Lógica de exclusão em cascata + revogação de sessões |
| `handle_iap_webhook` | Valida recibos da App Store / Play Store (requer chave privada) |
| `check_credits` | Lógica de negócio + acesso à `feature_config` |
| `generate_journal_prompt` | Claude API key + deduz crédito antes de chamar IA |

---

## SEÇÃO 7 — Política de Retenção de Dados

### Por Tipo de Dado

| Tipo | Retenção | Implementação |
|------|----------|--------------|
| Perfil do usuário | Conta ativa + 30 dias após exclusão | Cron diário: deletar onde `deletion_scheduled_at < NOW()` |
| Entradas de diário | Conta ativa + 30 dias | Cascata via FK ao deletar perfil |
| Mensagens de chat | 90 dias após última msg OU exclusão da conta | Cron: `DELETE FROM messages WHERE created_at < NOW() - INTERVAL '90 days'` |
| Dados do casal (rituais, timeline, check-ins) | Conta de casal + 30 dias após `couples.ended` | `deletion_scheduled_at` na tabela `couples` |
| Eventos de analytics (PostHog/Mixpanel) | 2 anos máx. Anonimizar após 1 ano | Configurar no dashboard do provider |
| Logs de auth / segurança | 30 dias contínuos | Supabase Pro — configurar log retention |
| Fotos (Storage) | Deletar junto com perfil | Trigger ao deletar `user_photos` → deletar do Storage |

### Implementação: Cron de Exclusão Definitiva

```sql
-- pg_cron: executar diariamente às 02:00 UTC
-- Deletar perfis agendados para exclusão
SELECT cron.schedule(
  'delete-scheduled-accounts',
  '0 2 * * *',
  $$
    -- Deletar usuários com exclusão agendada vencida
    DELETE FROM profiles
    WHERE deletion_scheduled_at IS NOT NULL
      AND deletion_scheduled_at < NOW();
    -- FK CASCADE deve limpar todas as tabelas relacionadas
  $$
);

-- pg_cron: excluir mensagens antigas (90 dias)
SELECT cron.schedule(
  'purge-old-messages',
  '0 3 * * *',
  $$
    DELETE FROM messages
    WHERE created_at < NOW() - INTERVAL '90 days';
  $$
);

-- pg_cron: encerrar casais com exclusão agendada
SELECT cron.schedule(
  'delete-ended-couples',
  '0 4 * * *',
  $$
    DELETE FROM couples
    WHERE status = 'ended'
      AND deletion_scheduled_at IS NOT NULL
      AND deletion_scheduled_at < NOW();
  $$
);
```

### Inatividade: Aviso e Exclusão Automática

```sql
-- Adicionar campo para controle de inatividade
ALTER TABLE profiles
  ADD COLUMN inactivity_warning_sent_at TIMESTAMP,
  ADD COLUMN deletion_scheduled_at      TIMESTAMP;

-- pg_cron: avisar usuários inativos há 12 meses
SELECT cron.schedule(
  'warn-inactive-users',
  '0 10 * * 1',  -- toda segunda às 10:00 UTC
  $$
    UPDATE profiles
    SET inactivity_warning_sent_at = NOW()
    WHERE last_active_at < NOW() - INTERVAL '12 months'
      AND inactivity_warning_sent_at IS NULL
      AND deletion_scheduled_at IS NULL;
    -- Após UPDATE: disparar push/email de aviso (via Edge Function)
  $$
);

-- pg_cron: agendar exclusão após 18 meses de inatividade (com 30 dias de aviso)
SELECT cron.schedule(
  'schedule-inactive-deletions',
  '0 11 * * 1',
  $$
    UPDATE profiles
    SET deletion_scheduled_at = NOW() + INTERVAL '30 days'
    WHERE last_active_at < NOW() - INTERVAL '18 months'
      AND deletion_scheduled_at IS NULL;
  $$
);
```

---

## SEÇÃO 8 — Fluxo de Exclusão de Conta

```
Usuário solicita exclusão:
       │
       ▼
Edge Function: delete_account
       │
       ├─ 1. Revogar todas as sessões ativas (Supabase Auth)
       ├─ 2. Cancelar assinatura ativa (App Store / Play Store)
       ├─ 3. profiles.deletion_scheduled_at = NOW() + 30 dias
       ├─ 4. profiles.account_status = 'pending_deletion'
       ├─ 5. Remover do pool de matches (ocultar imediatamente)
       ├─ 6. Se tem casal ativo: couples.deletion_scheduled_at = NOW() + 30 dias
       └─ 7. Enviar e-mail de confirmação com link para cancelar exclusão

Durante os 30 dias:
  - Usuário pode exportar dados (journal, timeline, rituais)
  - Usuário pode cancelar exclusão (reativa a conta)
  - Perfil já não aparece no feed de ninguém

Após 30 dias (cron):
  - DELETE em cascata: profiles → todas as tabelas FK
  - Deletar fotos do Supabase Storage
  - Deletar dados do casal se deletion_scheduled_at venceu
  - Anonimizar eventos de analytics (substituir user_id por hash)
```

---

## SEÇÃO 9 — Configuração do Supabase Pro

Antes do primeiro usuário real, garantir:

```
Supabase Dashboard → Project Settings:

1. Auth:
   ✓ JWT expiry: 3600 (1 hora)
   ✓ Refresh token enabled: true
   ✓ Email confirmations: enabled

2. Database:
   ✓ PgBouncer: ENABLED
   ✓ Pooling mode: Transaction
   ✓ Use pooled connection string nas Edge Functions

3. Storage:
   ✓ Buckets criados: user-photos, journal-photos, chat-media, timeline-photos
   ✓ Nenhum bucket em modo público sem política
   ✓ Signed URL expiry: 3600 (1 hora)

4. Backups:
   ✓ Daily backups: ON (disponível no Supabase Pro)
   ✓ Point-in-time recovery: verificar disponibilidade no plano

5. Logs:
   ✓ Log retention: 30 dias (configurar no Supabase Pro)
```

---

## Checklist de Segurança Pré-Lançamento

### A — RLS (Banco de Dados)

- [ ] Tabelas existentes com RLS corrigido:
  - [ ] `profiles`: DROP policy `USING (true)` + criar VIEW `public_profiles`
  - [ ] `compatibility_scores`: documentar que INSERT = service_role only
  - [ ] `matches`: restringir UPDATE (apenas status changes)
  - [ ] `user_photos`: DROP policy de INSERT do cliente
  - [ ] `reports`: adicionar policy de SELECT
- [ ] 10 tabelas do Modo Casal com RLS ativado e políticas criadas:
  - [ ] `couples`
  - [ ] `rituals`
  - [ ] `journal_entries` (política de `shared_with_partner`)
  - [ ] `timeline_events`
  - [ ] `check_ins` (política de `visible_after`)
  - [ ] `challenges`
  - [ ] `credits` (sem nenhuma policy de escrita para o cliente)
  - [ ] `badges`
  - [ ] `couple_insights`
  - [ ] `feature_config`
- [ ] **Teste obrigatório:** Logar como Usuário A e tentar ler dados do Usuário B. Cada operação abaixo deve falhar:
  - [ ] `SELECT * FROM journal_entries WHERE author_id = 'user-b-id'`
  - [ ] `UPDATE credits SET balance = 9999`
  - [ ] `INSERT INTO compatibility_scores VALUES (...)`
  - [ ] `SELECT * FROM check_ins` (antes do `visible_after` do parceiro)

### B — Chaves de API e Secrets

- [ ] SERVICE_ROLE key: não presente em nenhuma variável do FlutterFlow
- [ ] Claude API Key: não presente em nenhum arquivo do cliente
- [ ] Busca por chaves expostas no repositório (grep acima) retorna zero resultados
- [ ] `.gitignore` configurado para excluir arquivos `.env`
- [ ] Edge Functions: todas as variáveis de ambiente configuradas no Supabase Dashboard

### C — CSAM e Upload de Fotos

- [ ] Edge Function `upload_photo` implementada
- [ ] CSAM detection integrada (PhotoDNA ou AWS Rekognition)
- [ ] Policy de INSERT do cliente em `user_photos` removida
- [ ] Policy de Storage: sem INSERT direto do cliente em `user-photos`
- [ ] Fluxo testado ponta a ponta: upload → CSAM → Storage → `user_photos`
- [ ] Procedimento de report à NCMEC documentado (caso CSAM seja detectado)

### D — Aplicação e Fluxos

- [ ] Tokens de convite: uso único, expiração 7 dias, validação server-side
- [ ] Fluxo de exclusão de conta: testado ponta a ponta
- [ ] Todas as Edge Functions: tratamento de erro implementado (nunca retornar erro bruto ao cliente)
- [ ] Fallback de ritual: biblioteca pré-escrita funcionando quando Claude API falha
- [ ] Mapa natal: confirmado que usa biblioteca open-source local (sem chamada de API externa)
- [ ] MBTI: confirmado que é implementação interna (sem API ou licença externa)

### E — Documentos de Privacidade (Responsável: Founders)

- [ ] Política de Privacidade publicada em URL pública
- [ ] Conformidade CCPA/CPRA (EUA) — seção "Informações Pessoais Sensíveis" ativada
- [ ] Toggle "Não Vender ou Compartilhar" presente
- [ ] Termos de Serviço publicados em URL pública
- [ ] Ambas as URLs adicionadas ao App Store Connect e Google Play Console

### F — Supabase Pro

- [ ] Plano Pro ativo antes do primeiro usuário real
- [ ] Backups diários confirmados como ativos
- [ ] PgBouncer ativado em modo Transaction
- [ ] String de conexão pooled sendo usada nas Edge Functions
- [ ] Log retention: 30 dias configurado

---

## SQL Consolidado — Correções e Adições de RLS

```sql
-- ============================================================
-- PART C — Correções de Segurança e RLS
-- Versão: v1.0 | Março 2026
-- ATENÇÃO: Executar com cuidado em produção.
-- ============================================================

-- ============================================================
-- 1. CORREÇÕES EM TABELAS EXISTENTES
-- ============================================================

-- 1.1 profiles: restringir SELECT (remover acesso aberto)
DROP POLICY IF EXISTS "Profiles are viewable by all authenticated users" ON profiles;

CREATE POLICY "Users can read own full profile"
  ON profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- VIEW pública para match cards (apenas campos seguros)
CREATE OR REPLACE VIEW public_profiles AS
  SELECT
    id,
    display_name,
    birthdate,
    gender,
    occupation,
    education,
    bio,
    avatar_url,
    location,
    last_active_at,
    onboarding_complete,
    active_mode
  FROM profiles;

-- 1.2 matches: restringir UPDATE
DROP POLICY IF EXISTS "Users can update their own matches" ON matches;

CREATE POLICY "Users can archive or block their own matches"
  ON matches FOR UPDATE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b)
  WITH CHECK (status IN ('archived', 'blocked'));

-- 1.3 user_photos: remover INSERT do cliente
DROP POLICY IF EXISTS "Users can upload their own photos" ON user_photos;
-- INSERT agora apenas via Edge Function upload_photo (service_role)

-- 1.4 reports: adicionar SELECT
CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

-- ============================================================
-- 2. RLS PARA TABELAS DO MODO CASAL (Part B)
-- ============================================================

-- 2.1 couples
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view their couple"
  ON couples FOR SELECT TO authenticated
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

-- 2.2 rituals
ALTER TABLE rituals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view rituals"
  ON rituals FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));
CREATE POLICY "Couple members can update ritual completion"
  ON rituals FOR UPDATE TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));

-- 2.3 journal_entries
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own journal entries"
  ON journal_entries FOR SELECT TO authenticated
  USING (author_id = auth.uid());
CREATE POLICY "Users can read partner shared entries"
  ON journal_entries FOR SELECT TO authenticated
  USING (
    shared_with_partner = true
    AND author_id != auth.uid()
    AND couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "Users can create own journal entries"
  ON journal_entries FOR INSERT TO authenticated
  WITH CHECK (author_id = auth.uid());
CREATE POLICY "Users can update own journal entries"
  ON journal_entries FOR UPDATE TO authenticated
  USING (author_id = auth.uid());
CREATE POLICY "Users can delete own journal entries"
  ON journal_entries FOR DELETE TO authenticated
  USING (author_id = auth.uid());

-- 2.4 timeline_events
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view timeline"
  ON timeline_events FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));
CREATE POLICY "Couple members can add timeline events"
  ON timeline_events FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "Event creator can update timeline event"
  ON timeline_events FOR UPDATE TO authenticated
  USING (created_by = auth.uid());
CREATE POLICY "Event creator can delete timeline event"
  ON timeline_events FOR DELETE TO authenticated
  USING (created_by = auth.uid());

-- 2.5 check_ins
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view checkins"
  ON check_ins FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
    AND (both_completed = true OR NOW() > visible_after)
  );
CREATE POLICY "Couple members can update checkin responses"
  ON check_ins FOR UPDATE TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));

-- 2.6 challenges
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view challenges"
  ON challenges FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));
CREATE POLICY "Couple members can update challenge progress"
  ON challenges FOR UPDATE TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));

-- 2.7 credits (CRÍTICO — sem escrita do cliente)
ALTER TABLE credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own credits"
  ON credits FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- SEM INSERT/UPDATE/DELETE policy para authenticated

-- 2.8 badges
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view badges"
  ON badges FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));

-- 2.9 couple_insights
ALTER TABLE couple_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Couple members can view insights"
  ON couple_insights FOR SELECT TO authenticated
  USING (couple_id IN (
    SELECT couple_id FROM couples
    WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
  ));

-- 2.10 feature_config
ALTER TABLE feature_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Feature config readable by all authenticated"
  ON feature_config FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- 3. CAMPOS DE RETENÇÃO DE DADOS
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS deletion_scheduled_at      TIMESTAMP,
  ADD COLUMN IF NOT EXISTS inactivity_warning_sent_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS account_status             TEXT DEFAULT 'active'
    CHECK (account_status IN ('active', 'pending_deletion', 'deleted'));
```

---

*Documento de mudanças Part C — gerado em Março 2026*
*Referências: `docs/schema.sql` linhas 1007–1257 · Auro Developer Handoff v1.0 Part C*

# Couple Mode Architecture

> Status: **v2.0** — new module introduced March 2026.

## Overview

Couple Mode is a distinct app mode for existing couples who want to strengthen their relationship with structure, AI-powered insights, and shared activities. It activates when two users who matched in Dating Mode both choose to enter Couple Mode, or when two users register directly as a couple.

This document covers the full architecture: database tables, activation flow, AI integration, credit system, and psychological safety rules.

---

## Activation Flow

### Path 1: From a Dating Match

```
Dating Mode
  → User A opens profile → taps "Enter Couple Mode"
  → App sends invite to User B (push notification)
  → User B accepts
  → match.status = 'couple'
  → couple record created
  → Both users see Couple Mode dashboard
```

### Path 2: Direct Couple Registration

```
Registration
  → User selects active_mode = 'couple'
  → Enters partner's email or invite code
  → Partner registers or accepts invite
  → couple record created
  → profiles.is_dating = false, profiles.is_couple = true
```

### Activation constraints:
- Both users must be 18+
- Both must complete basic profile (steps 1–3 of onboarding minimum)
- One couple record per user at a time
- Deactivation: either user can leave (soft delete, data retained 90 days)

---

## Database Tables (10 tables)

### 1. `couples`

The root record for a couple. All other Couple Mode tables reference this.

```sql
CREATE TABLE couples (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_b_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  activated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  anniversary_date  DATE,
  relationship_name TEXT,              -- Optional: "The Garcias", "Team Us"
  status            TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'paused', 'ended')),
  ended_at          TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_a_id, user_b_id)
);
```

---

### 2. `couple_rituals`

AI-generated or library-sourced daily/weekly activities for the couple.

```sql
CREATE TABLE couple_rituals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  ritual_type     TEXT NOT NULL CHECK (ritual_type IN ('daily', 'weekly', 'special')),
  category        TEXT NOT NULL CHECK (category IN (
                    'connection', 'communication', 'adventure',
                    'intimacy', 'growth', 'gratitude'
                  )),
  source          TEXT NOT NULL CHECK (source IN ('ai_generated', 'library', 'user_created')),
  library_id      UUID REFERENCES ritual_library(id),
  scheduled_for   DATE,
  completed_at    TIMESTAMPTZ,
  completed_by    UUID REFERENCES profiles(id),
  credits_awarded SMALLINT DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### 3. `couple_journal_entries`

Shared or private journal entries for relationship reflection.

```sql
CREATE TABLE couple_journal_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES profiles(id),
  title       TEXT,
  content     TEXT NOT NULL,
  is_shared   BOOLEAN NOT NULL DEFAULT false,  -- false = private to author
  mood        TEXT CHECK (mood IN ('joyful', 'grateful', 'conflicted', 'sad', 'hopeful', 'neutral')),
  tags        TEXT[],
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### 4. `couple_timeline_events`

Relationship milestones and memories on a shared timeline.

```sql
CREATE TABLE couple_timeline_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  created_by   UUID NOT NULL REFERENCES profiles(id),
  event_type   TEXT NOT NULL CHECK (event_type IN (
                 'milestone', 'memory', 'trip', 'achievement',
                 'challenge_completed', 'anniversary', 'custom'
               )),
  title        TEXT NOT NULL,
  description  TEXT,
  event_date   DATE NOT NULL,
  photo_urls   TEXT[],
  is_pinned    BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### 5. `couple_check_ins`

Structured emotional check-ins (daily or weekly).

```sql
CREATE TABLE couple_check_ins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id),
  check_in_date   DATE NOT NULL,
  frequency       TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly')),
  energy_level    SMALLINT CHECK (energy_level BETWEEN 1 AND 5),
  connection_feel SMALLINT CHECK (connection_feel BETWEEN 1 AND 5),
  stress_level    SMALLINT CHECK (stress_level BETWEEN 1 AND 5),
  highlight       TEXT,                -- "Best moment this period"
  needs           TEXT,                -- "What I need from you right now"
  gratitude       TEXT,                -- "Something I appreciate about you"
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, user_id, check_in_date, frequency)
);
```

---

### 6. `couple_challenges`

7-day structured relationship challenges.

```sql
CREATE TABLE couple_challenges (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id      UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  description    TEXT NOT NULL,
  category       TEXT NOT NULL CHECK (category IN (
                   'communication', 'intimacy', 'adventure',
                   'gratitude', 'growth', 'fun'
                 )),
  duration_days  SMALLINT NOT NULL DEFAULT 7,
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at   TIMESTAMPTZ,
  credits_reward SMALLINT NOT NULL DEFAULT 50,
  status         TEXT NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active', 'completed', 'abandoned')),
  progress       JSONB DEFAULT '{}',  -- {"day_1": true, "day_2": false, ...}
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### 7. `couple_credits`

Credit balance and transaction ledger. Credits are earned through engagement and spent on premium features.

```sql
CREATE TABLE couple_credits (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id        UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id          UUID REFERENCES profiles(id),  -- NULL if system-generated
  transaction_type TEXT NOT NULL CHECK (transaction_type IN (
                     'earned_ritual', 'earned_checkin', 'earned_challenge',
                     'earned_streak', 'earned_milestone',
                     'spent_ritual_extra', 'spent_insight', 'spent_custom',
                     'bonus_onboarding', 'admin_adjustment'
                   )),
  amount           SMALLINT NOT NULL,  -- positive = earned, negative = spent
  balance_after    INT NOT NULL,
  description      TEXT,
  reference_id     UUID,  -- ID of ritual/challenge/insight that generated this
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Credit earning rules:**
| Action | Credits |
|--------|---------|
| Complete daily ritual | +10 |
| Complete weekly ritual | +25 |
| Complete check-in (both partners) | +15 |
| Complete 7-day challenge | +50 |
| 7-day streak (no missed rituals) | +30 bonus |
| First Couple Mode month | +100 bonus |
| Timeline milestone added | +5 |

**Credit spending rules:**
| Feature | Cost |
|---------|------|
| Extra AI ritual (beyond free quota) | 20 credits |
| AI relationship insight | 30 credits |
| Custom challenge creation | 15 credits |

---

### 8. `couple_badges`

Achievement badges earned by completing milestones.

```sql
CREATE TABLE couple_badges (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  badge_type   TEXT NOT NULL,  -- 'first_ritual', '30_day_streak', 'all_categories', etc.
  earned_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, badge_type)
);
```

**Badge catalog (examples):**
| Badge | Trigger |
|-------|---------|
| `first_ritual` | Complete first ritual |
| `first_checkin` | Complete first check-in |
| `7_day_streak` | 7 consecutive days of rituals |
| `30_day_streak` | 30 consecutive days |
| `first_challenge` | Complete first 7-day challenge |
| `explorer` | Try all 6 ritual categories |
| `time_capsule` | Create 10 timeline events |
| `journal_habit` | Write 7 journal entries |
| `anniversary_1` | 1-year anniversary in Couple Mode |

---

### 9. `couple_insights`

AI-generated monthly relationship insights based on check-in data, ritual patterns, and journal entries.

```sql
CREATE TABLE couple_insights (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  period_month DATE NOT NULL,  -- First day of the month this covers
  title        TEXT NOT NULL,
  summary      TEXT NOT NULL,
  strengths    TEXT[],
  growth_areas TEXT[],
  suggestion   TEXT,
  data_points  JSONB,  -- Aggregated stats used to generate this insight
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  viewed_at    TIMESTAMPTZ,
  UNIQUE (couple_id, period_month)
);
```

---

### 10. `feature_config`

All free/premium feature limits stored in DB. Never hardcoded.

```sql
CREATE TABLE feature_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key  TEXT NOT NULL UNIQUE,
  free_limit   INT,          -- NULL = unlimited for free
  premium_limit INT,         -- NULL = unlimited for premium
  unit         TEXT,         -- 'count', 'per_day', 'per_month', etc.
  description  TEXT,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Seed data (examples):**
```sql
INSERT INTO feature_config (feature_key, free_limit, premium_limit, unit, description) VALUES
  ('dating_likes_per_day',       10,    NULL, 'per_day',   'Likes in Dating Mode'),
  ('dating_super_likes_per_day',  1,       5, 'per_day',   'Super likes in Dating Mode'),
  ('couple_rituals_ai_per_month', 4,    NULL, 'per_month', 'AI-generated rituals'),
  ('couple_insights_per_month',   1,       4, 'per_month', 'Monthly AI insights'),
  ('couple_journal_private',      5,    NULL, 'count',     'Private journal entries'),
  ('chat_ice_breakers_per_match', 3,       9, 'count',     'Ice-breakers per match');
```

---

### Supporting Tables

#### `ritual_library`
Pre-written rituals used as fallback and for batch generation.

```sql
CREATE TABLE ritual_library (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  ritual_type TEXT NOT NULL CHECK (ritual_type IN ('daily', 'weekly', 'special')),
  category    TEXT NOT NULL,
  tags        TEXT[],
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

#### `ritual_library_used`
Tracks which library rituals were shown to each couple (prevents repetition).

```sql
CREATE TABLE ritual_library_used (
  couple_id  UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  library_id UUID NOT NULL REFERENCES ritual_library(id) ON DELETE CASCADE,
  shown_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (couple_id, library_id)
);
```

---

## AI Integration

### AI Components in Couple Mode

| Component | Trigger | Model | Output |
|-----------|---------|-------|--------|
| Ritual Generator | Monthly batch + on-demand | `claude-sonnet-4-6` | 4 weekly + 30 daily rituals |
| Check-in Prompt | Weekly | `claude-sonnet-4-6` | 3 personalized questions |
| Monthly Insight | Monthly batch | `claude-sonnet-4-6` | Insight report (JSON) |
| Challenge Creator | On-demand | `claude-sonnet-4-6` | 7-day challenge plan |
| Journal Reflection | On-demand | `claude-sonnet-4-6` | Reflective prompt suggestion |

### AI Cost Optimization

**Strategy 1 — JSON structured output:**
All AI calls use `response_format: { type: "json_object" }` to avoid post-processing overhead.

**Strategy 2 — Monthly batch generation:**
Rituals and prompts are generated once per month for the entire month. Individual calls only for on-demand features.

**Strategy 3 — Pre-written library fallback:**
If AI generation fails or quota is exceeded, the system uses the `ritual_library` table. 200+ hand-curated rituals ensure users always have content.

```javascript
// Edge Function: generate-monthly-rituals
const response = await anthropic.messages.create({
  model: "claude-sonnet-4-6",
  max_tokens: 2000,
  system: `You are a relationship coach generating personalized rituals for couples.
  Output ONLY valid JSON. No markdown, no explanation.`,
  messages: [{
    role: "user",
    content: `Generate rituals for this couple:
    - Together since: ${couple.activated_at}
    - Partner A attachment style: ${profileA.attachment_style}
    - Partner B attachment style: ${profileB.attachment_style}
    - Categories already covered: ${recentCategories}

    Return JSON: { "weekly": [{title, description, category, credits_awarded}] × 4,
                   "daily": [{title, description, category, credits_awarded}] × 30 }`
  }]
});
```

---

## Psychological Safety Rules

These rules ensure AI-generated content does not trigger or harm users.

### Content rules for all AI outputs:
1. **Never reference trauma** — no prompts about past relationships, childhood, or painful memories
2. **Never assign blame** — no "your partner should..." framing. Use "as a couple, you might..."
3. **Keep intimacy optional** — physical/sexual suggestions always marked optional and behind a filter
4. **Positive framing only** — focus on strengths and growth, not deficits
5. **Crisis detection** — if journal or check-in entries contain distress keywords (loneliness, hopeless, harm), surface a gentle resource prompt (not a diagnosis)

### Content sensitivity levels:
```
Level 1 (default): All content — no filters needed
Level 2: Physical touch suggestions — shown only if both users opted in
Level 3: Deep vulnerability prompts — shown only after 30 days in Couple Mode
```

---

## Edge Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `activate-couple-mode` | Manual | Creates couple record, sends invites |
| `generate-monthly-rituals` | pg_cron (1st of month) | Batch AI ritual generation |
| `generate-monthly-insight` | pg_cron (last day of month) | AI insight from check-in data |
| `process-credit-transaction` | On ritual/check-in completion | Award/deduct credits, check streaks |
| `check-badge-eligibility` | After credit transaction | Award any newly earned badges |
| `couple-check-in-reminder` | pg_cron (daily 18:00 local) | Push notification if check-in missed |

---

## Indexes

```sql
-- couples
CREATE INDEX idx_couples_user_a ON couples(user_a_id);
CREATE INDEX idx_couples_user_b ON couples(user_b_id);

-- rituals
CREATE INDEX idx_rituals_couple_scheduled ON couple_rituals(couple_id, scheduled_for);
CREATE INDEX idx_rituals_completed ON couple_rituals(couple_id, completed_at) WHERE completed_at IS NULL;

-- journal
CREATE INDEX idx_journal_couple ON couple_journal_entries(couple_id, created_at DESC);
CREATE INDEX idx_journal_author ON couple_journal_entries(author_id);

-- check-ins
CREATE INDEX idx_checkins_couple_date ON couple_check_ins(couple_id, check_in_date DESC);

-- credits
CREATE INDEX idx_credits_couple ON couple_credits(couple_id, created_at DESC);

-- insights
CREATE INDEX idx_insights_couple ON couple_insights(couple_id, period_month DESC);
```

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0*

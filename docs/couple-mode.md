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

*This document evolves as the project grows. Last updated: 2026-03-10 — v2.1*

---
---

# v2.1 Additions — Product Logic Addendum (March 2026)

> Source: Product Logic Addendum (Alix Liasse). Approved by CEO (Dércio da Barca).
> This section documents all changes introduced by the addendum.
> For the complete SQL changes, see `docs/schema.sql` (v2.1 section).
> For the detailed changelog, see `changes/part-f-product-logic-addendum.md`.

---

## Weekly Ritual Card — 3-Section Format

The Weekly Ritual Card has three sections, all generated by AI in a single API call, personalised to the couple's current state.

### The three sections

| Section | Definition | Length | Tone |
|---------|-----------|--------|------|
| **INSIGHT** | Emotional framing for the week. A truth that makes the couple pause. Not advice, not instruction. | 2–3 sentences | Resonant, universal, warm |
| **PRACTICE** | Specific action to take together this week. Calibrated to the couple's energy level from journal. | 100–200 words | Clear, actionable, human |
| **REFLECTION QUESTION** | One question the couple answers together after the practice. Opens a conversation that wouldn't happen naturally. | Max 25 words | Open, safe, curious |

### What the AI receives

| Input Layer | What It Contains | Source |
|-------------|-----------------|--------|
| Base profile (static) | Attachment style, love language, communication style, time together, completed tracks | Onboarding |
| Journal input (dynamic) | Mood state (5-point selector) + optional free text from each partner this week | Individual journal — private |

### How ritual adapts to journal input

| Scenario | Without Journal | With Journal |
|----------|----------------|-------------|
| Partner A: Exhausted, B: Good | Standard ritual | Lighter ritual. Practice falls more on Partner B. |
| Both: Tense | May be emotionally demanding | Decompression ritual. Gratitude and lightness. |
| One partner: "Missing time together" | Based on previous tracks | Oriented toward quality of presence. |
| Both: Great, high energy | Standard ritual | More challenging. Intellectual or adventure track. |
| One: Anxious, Other: Good | No adjustment possible | Includes space for calm partner to show support. |

### API output format (JSON)

```json
{
  "title": "Arriving before speaking",
  "insight": "This week one of you arrived with less to give. That is not failure — that is a week. This ritual is about how the other can receive that well.",
  "practice": "This week, when you get home, let 10 minutes pass before talking about anything. No questions, no updates. Just presence. Partner B initiates — a simple gesture, a drink, a silent hug. Let the silence do the work.",
  "reflection_question": "What is one small thing your partner did this week that you felt but did not say?"
}
```

### Updated ritual generation prompt

```javascript
// Edge Function: generate-weekly-ritual
const response = await anthropic.messages.create({
  model: "claude-sonnet-4-6",
  max_tokens: 1000,
  system: `You are a relationship coach generating a personalised weekly ritual.
  Output ONLY valid JSON. No markdown, no explanation.
  Format: { "title": "...", "insight": "2-3 sentences", "practice": "100-200 words", "reflection_question": "max 25 words" }`,
  messages: [{
    role: "user",
    content: `Generate a weekly ritual for this couple:
    Partner A — ${profileA.attachment_style} attachment, love language: ${profileA.love_language}, communication: ${profileA.communication_style}.
    Journal this week: mood = ${journalA.mood}. Free text: ${journalA.free_text || '[empty]'}.
    Partner B — ${profileB.attachment_style} attachment, love language: ${profileB.love_language}, communication: ${profileB.communication_style}.
    Journal this week: mood = ${journalB.mood}. Free text: ${journalB.free_text || '[empty]'}.
    Together ${couple.weeks_together} weeks. Last completed tracks: ${lastTracks.join(', ')}.
    ${energyCalibrationInstruction}`
  }]
});
```

### Privacy in ritual generation

The AI receives journal text via **Edge Function (service_role)**:

1. Edge Function reads journal entries from both partners (service_role bypasses RLS)
2. AI receives mood + free text (or empty) from each partner
3. AI generates ritual based on themes — NOT literal text
4. Ritual stored in `couple_rituals`
5. Journal text NEVER appears in ritual output
6. Raw journal NEVER accessible to partner

---

## Journal — Individual Only, Always Private

AURO has one journal. It is individual and private. There is no shared couple journal.

### Design decisions

| Decision | Rationale |
|----------|-----------|
| Individual journal only — no shared journal | Shared journal creates complexity (who adds, who confirms, who sees what). Blurs privacy boundary. Simpler product, clearer privacy, stronger ritual. |
| Timeline replaces shared journal | Timeline covers what shared journal would do — milestones, memories, events. More structured and lower friction. |

### Input 1 — Mood selector (required, one tap)

Five states. One tap. No text required.

```
How are you today?
😴    😤    😐    🙂    ✨
Exhausted  Tense  OK  Good  Great
```

### Input 2 — Free text (optional)

Rotating prompt shapes the response. Rotates weekly.

```
Something on your mind? (optional)
[rotating prompt — from journal_prompts table]

Only AURO reads this.
Your partner never sees your responses — and they help
make this week's ritual more relevant for both of you.
```

### 12 rotating prompts (from `journal_prompts` table)

| Week | Prompt | Vulnerable |
|------|--------|-----------|
| 1 | What has been taking up most of your headspace this week? | No |
| 2 | How are you arriving to this ritual — present or distracted? | No |
| 3 | Is there something you didn't say but wanted to? | No |
| 4 | What do you need most this week — space or closeness? | No |
| 5 | How do you feel about the two of you right now? | No |
| 6 | What gave you energy this week? What took it away? | No |
| 7 | Is there something your partner doesn't know you're feeling? | **Yes** |
| 8 | One word about your day? | No |
| 9 | What do you want to bring to this ritual today? | No |
| 10 | Is there anything you want AURO to know before we begin? | **Yes** |
| 11 | How do you feel about the week ahead? | No |
| 12 | Something small you'd like your partner to know? | **Yes** |

Weeks 1-6: neutral. Weeks 7, 10, 12: vulnerable — only after trust. After week 12: repeats.

### Disclaimers (3 locations)

| Location | Format | When | Copy |
|----------|--------|------|------|
| Onboarding | Full text card | Once | "Your journal is completely private. Your partner never sees what you write — ever. AURO uses what you share to understand how you're arriving to each week. Not to analyse you — to make that week's ritual more relevant for both of you." |
| Journal screen | Small grey text below field | Always | "Only AURO reads this. Your responses are never shared with your partner — and they help make this week's ritual more relevant for both of you." |
| First entry | Tooltip, one time only | Once | "What you share here helps AURO personalise your weekly ritual. Your partner never has access to these responses." |

### Edge states

| Scenario | Behaviour |
|----------|----------|
| Partner A filled in, B did not | Ritual from A's input + base profile. B not penalised. |
| Neither filled in | Ritual from base profile only. |
| B fills in after ritual generated | Not retroactive. Enters next week's cycle. |
| Journal conflicts with profile | Journal takes precedence. More recent. |

### Free vs Premium — Journal

| Feature | Free | Premium |
|---------|------|---------|
| Journal entries | Up to 30 total | Unlimited |
| Mood selector | Included | Included |
| Free text field | Included | Included |
| Rotating prompts | Standard rotating library | + AI-personalised prompts |
| Journal history | Last 30 entries | Full history + patterns |

---

## Milestones — Not Level Ratings

AURO does **not** use a numbered level system. A level rating on a relationship is reductive. Instead: milestone celebrations. They mark time invested together — not a judgement of relationship quality.

### Milestone framework

| Milestone | Trigger | Celebration | Available |
|-----------|---------|-------------|-----------|
| 4 Weeks | 4 consecutive weeks — ritual completed by both | Special screen + badge. "One month of showing up." | Free + Premium |
| 3 Months | 12 consecutive weeks | AI-generated ritual reflecting the 12-week journey | Free + Premium |
| 6 Months | 26 consecutive weeks | Monthly retrospective — patterns, rituals, growth moments | Premium only |
| 1 Year | 52 consecutive weeks | Personalised anniversary ritual from full year of data | Premium only |

### Progression points

| Action | Points | Condition |
|--------|--------|-----------|
| Weekly ritual completed — both partners | 50 | Both must complete for full points |
| Ritual completed — one partner only | 25 | — |
| Reflection Question answered — both | 20 | Both must respond |
| Journal entry (per partner) | 20 | Per partner per week. Max 40/week. |
| Challenge completed | 10 | Bonus — does not gate progression. |

### The two-partner rule

Milestones are **couple** milestones — not individual. Both partners must show up for full progression.

---

## Streak — Weekly, Never Resets

### Core philosophy

AURO does not create pressure. No guilt mechanism. No streak lost because life got in the way.

The streak is **weekly** — not daily. A couple that doesn't open AURO for a week is not punished. Their streak **pauses**. When they return, it continues.

### Streak features

| Feature | Free | Premium |
|---------|------|---------|
| Streak tracking | Weekly count visible | Weekly count visible |
| When app not used | Streak pauses. Does not reset. | Same |
| Milestone badges (4, 8, 12 weeks) | Celebration screen | Celebration screen |
| Streak Protection | No | 1 grace week per month |
| Streak Recovery | No | Recover within 48h |
| Streak Insights | No | Patterns over time |
| Extended milestones (6 months, 1 year) | No | AI-generated ritual + retrospective |

---

## Paywall — 11 Trigger Points

Each trigger has a defined context, emotional state, and message type. Principle: **show value, never guilt**.

| # | Trigger | Context | Type | Copy Principle |
|---|---------|---------|------|----------------|
| 1 | Journal limit (30) | High consistency signal | Soft banner | "Unlock unlimited journaling." |
| 2 | Timeline limit (10) | Adding memories | Soft banner | "Keep building your story together." |
| 3 | Extra ritual request | Wants more than 1/week | Feature preview | "Want another ritual this week?" |
| 4 | Credits low (≤2) | Mid-funnel | Soft banner | "2 credits left. Upgrade for unlimited." |
| 5 | Streak Protection | Highest emotional investment | Modal | "Protect what you've built." |
| 6 | Challenge unlock | Premium-only challenge | Feature preview | Show challenge preview |
| 7 | AI journal prompt | Tapped personalised prompt | Soft banner | "This prompt was made for you." |
| 8 | Streak Week 25 | Celebration moment | Celebration → upsell | Celebrate first. Then offer protection. |
| 9 | Milestone 3 months | Peak positive emotion | Celebration → upsell | Celebrate. Show what 6-month unlocks. |
| 10 | Milestone challenge completed | Peak positive emotion | Celebration → soft upsell | "More milestone challenges unlock with Premium." |
| 11 | Partner already premium | Social trigger | Personal nudge | "[Name] upgraded. Join them on Premium." |

### Conversion model

Free is good enough to prove value and reach the 4-week milestone. Premium protects, deepens, and extends what the couple has built. The paywall appears at the **moment of highest emotional investment** — never before.

---

## Updated Edge Functions (v2.1)

| Function | Trigger | Purpose |
|----------|---------|---------|
| `activate-couple-mode` | Manual | Creates couple record, sends invites |
| `generate-weekly-ritual` | pg_cron (Sunday 06:00 UTC) | Generates ritual for each active couple using journal + profile |
| `generate-ritual-on-demand` | Manual (premium/credits) | Extra ritual beyond 1/week |
| `generate-monthly-insight` | pg_cron (last day of month) | AI insight from check-in data |
| `process-credit-transaction` | On completion events | Award/deduct credits |
| `process-weekly-streak` | pg_cron (Sunday 23:59 UTC) | Update streak, check protection, handle pauses |
| `check-milestones` | pg_cron (Monday 00:05 UTC) | Check and register milestones |
| `track-paywall-event` | On trigger moments | Record paywall presentations |
| `get-journal-prompt` | On journal screen load | Return rotating prompt for current week |
| `check-badge-eligibility` | After credit/progression update | Award newly earned badges |
| `couple-check-in-reminder` | pg_cron (weekly, local time) | Push notification |

---

## Updated Indexes (v2.1)

```sql
-- milestones
CREATE INDEX idx_milestones_couple ON couple_milestones(couple_id);

-- progression
CREATE INDEX idx_progression_couple_week ON couple_progression(couple_id, week_number);

-- journal by week (replaces idx_journal_shared which no longer applies)
CREATE INDEX idx_journal_couple_week ON couple_journal_entries(couple_id, week_number);

-- rituals by week
CREATE INDEX idx_rituals_couple_week_v2 ON couple_rituals(couple_id, week_number);

-- paywall analytics
CREATE INDEX idx_paywall_user ON paywall_events(user_id, presented_at DESC);
CREATE INDEX idx_paywall_trigger ON paywall_events(trigger_type);
CREATE INDEX idx_paywall_conversion ON paywall_events(trigger_type, converted_at)
  WHERE converted_at IS NOT NULL;
```

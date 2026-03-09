# Onboarding & Profile Architecture

## Overview

The onboarding is a multi-step flow that collects user data progressively. Each step maps to a specific data domain. The architecture is designed so that:

- Fields can be **added or removed** without schema migrations (JSONB fallback for extensible data)
- The **compatibility algorithm** can reference any field with configurable weights
- Users can **edit** all onboarding data later from their profile settings

---

## Onboarding Flow (Step by Step)

### Step 1: Registration
**Screen:** "Ready to Begin?"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| name | text | yes | Display name |
| email | text | yes | Used for auth |
| password | text | yes | Min 8 chars, 1 special char, 1 number |
| oauth_provider | enum | no | `apple`, `google` (alternative to email/pass) |

**Table:** `auth.users` (Supabase native) + `profiles`

---

### Step 2: Basic Info
**Screen:** "Greetings, {name}! Let's start with the basics"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| birthdate | date | yes | Month / Day / Year |
| gender | enum | yes | `male`, `female`, `non_binary`, `gender_fluid`, `rather_not_say` |
| sexual_orientation | enum[] | yes | Multi-select: `heterosexual`, `gay`, `lesbian`, `bisexual`, `pansexual`, `ace`, `demisexual`, `queer`, `sapiosexual`, `rather_not_say_unsure` |
| sexual_orientation_other | text | no | Free text if "Other" selected |
| occupation | text | no | Job title / role (e.g. "Head chef") |
| education | text | no | School / university (e.g. "UCLA") |

**Table:** `profiles`

> **Note:** `occupation` and `education` are optional but visible on the profile card. They can be filled during onboarding or later via edit profile.

---

### Step 3: Mode Selection
**Screen:** "Choose where to begin"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| active_mode | enum | yes | `dating`, `couple` (expandable) |

Users can switch modes anytime. This is stored in `user_modes`.

**Table:** `user_modes`

---

### Step 4: Astrological Insights (Optional)
**Screen:** "Add optional insights"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| birth_location | text | no | City/region for chart calculation |
| birth_time | time | no | Exact time for rising sign |

**Table:** `user_astrology`

---

### Step 5: Birth Chart Display
**Screen:** "Ellie's birthchart"

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| sun_sign | enum | calculated | Star sign (from birthdate) |
| moon_sign | enum | calculated | Requires birth_time + birth_location |
| rising_sign | enum | calculated | Requires birth_time + birth_location |
| mercury_sign | enum | calculated | Planetary placement |
| venus_sign | enum | calculated | Planetary placement |
| chart_summary | text | generated | AI-generated overall summary |

**Table:** `user_astrology` (calculated fields populated by astrology engine)

---

### Step 6: Profile - About Relationships
**Screen:** "Let's build your profile - About relationships"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| relationship_type | enum[] | yes | Multi-select chips: `long_term`, `open_relation`, etc. |
| has_kids | enum | yes | `yes`, `no`, `rather_not_say` |
| who_to_see | enum | yes | `male`, `female`, `everyone`, etc. |
| dating_style | enum | yes | `monogamous`, `non_monogamous`, `polyamorous`, `open`, `other` |
| attraction_factors | enum[] | yes | Multi-select chips: `intelligence`, `humor`, `looks`, `kindness`, `ambition` |
| attraction_other | text | no | Free text |
| deal_breakers | text | no | Free text: things you can't accept. AI processes into structured JSON |
| preferences | text | no | Free text: what you're looking for in a person. AI processes into structured JSON |

**Table:** `user_relationship_prefs`

---

### Step 7: Profile - Personal Habits
**Screen:** "Let's build your profile - Personal habits"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| smokes | enum | yes | `yes`, `no`, `occasionally` |
| drinks | enum | yes | `never`, `socially`, `often`, `occasionally` |
| exercises | enum | yes | `yes`, `no`, `occasionally` |
| exercise_types | enum[] | no | Multi-select: `cycling`, `dancing`, `gym`, `crossfit`, `pilates`, `gymnastics`, `swimming`, `running`, `yoga` |
| exercise_other | text | no | Free text |
| diet | enum | yes | `omnivore`, `vegetarian`, `vegan`, `pescatarian`, `keto`, `other` |
| diet_other | text | no | Free text |
| online_availability | enum | yes | `during_the_day`, `evening`, `night`, `flexible`, `anytime` |

**Table:** `user_habits`

---

### Step 8: Profile - Values and Lifestyle (Part 1)
**Screen:** "Let's build your profile - Values and lifestyle"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| hobbies | enum[] | yes | Multi-select chips: `music`, `traveling`, `coffee`, `art`, `gastronomy`, `movies`, `sports`, `reading`, `gaming`, `bars`, `photography`, `fashion` |
| follows_religion | enum | yes | `yes`, `no`, `rather_not_say` |
| religion_name | text | no | If yes, which? |
| current_situation | enum | yes | `student`, `employed`, `self_employed`, `unemployed`, `retired` |
| expertise_area | text | no | Free text |
| political_views | enum | yes | `liberal`, `conservative`, `moderate`, `apolitical`, `other` |
| date_different_politics | enum | yes | `yes`, `no`, `depends` |

**Table:** `user_values`

---

### Step 9: Profile - Values and Lifestyle (Part 2 - Personality Tests)
**Screen:** "Values and lifestyle" (continued)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| mbti_type | enum | yes | 16 types: `ISTJ`, `ISFJ`, `INFJ`, `INTJ`, `ISTP`, `ISFP`, `INFP`, `INTP`, `ESTP`, `ESFP`, `ENFP`, `ENTP`, `ESTJ`, `ESFJ`, `ENFJ`, `ENTJ` |
| love_language | enum[] | yes | Multi-select: `words_of_affirmation`, `acts_of_service`, `receiving_gifts`, `physical_touch`, `quality_time` |

Users can retake MBTI and Love Language tests within the app.

**Table:** `user_personality`

---

### Step 10: Attachment Style *(New — v2.0)*
**Screen:** "How do you connect in relationships?"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| attachment_style | enum | yes | `secure`, `anxious`, `avoidant`, `fearful_avoidant` |

Users answer a short quiz (4–6 questions). The app calculates the style from responses. Result is shown with a brief, empathetic explanation of what it means.

**Table:** `user_personality`

> **Why collect this:** Attachment Style is the highest-impact new variable in Block 3 (25% weight). Research shows it's highly predictive of relationship dynamics.

---

### Step 11: Emotional Readiness *(New — v2.0)*
**Screen:** "Where are you emotionally?"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| emotional_readiness | enum | yes | `ready`, `almost_ready`, `taking_it_slow`, `just_exploring` |

Simple single-choice step. No quiz. Used to contextualize other compatibility factors and set expectations.

**Table:** `user_personality`

---

### Step 12: Communication Style *(New — v2.0)*
**Screen:** "How do you communicate?"

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| communication_style | enum | yes | `direct`, `indirect`, `empathetic`, `analytical` |

4-option chip selection. Feeds into match explanation copy and AI conversation context.

**Table:** `user_personality`

---

## Data Model Summary

```
profiles                        -- Core identity (name, birthdate, gender, orientation, occupation, education, location)
  |
  |-- user_modes                -- Active mode(s) per user
  |-- user_astrology            -- Birth details + calculated chart
  |-- user_relationship_prefs   -- Relationship goals, attraction, deal breakers, preferences
  |     |-- deal_breakers_text  -- Original free text
  |     |-- deal_breakers_json  -- AI-structured rules
  |     |-- preferences_text    -- Original free text
  |     |-- preferences_json    -- AI-structured preferences
  |-- user_habits               -- Smoking, drinking, exercise, diet
  |-- user_values               -- Hobbies, religion, politics, situation
  |-- user_personality          -- MBTI, love languages, attachment_style (v2.0),
  |                             --   emotional_readiness (v2.0), communication_style (v2.0)
  |-- user_photos               -- Profile images (up to 6, ordered by position)
  |-- onboarding_progress       -- Tracks steps + profile completion (filled_fields / total_fields)
  |
  |-- compatibility_scores      -- Cached scores between user pairs (see compatibility-algorithm.md)
```

---

## Photos

Users can upload up to **6 photos**, with position 1 as the main/avatar photo. At least 1 photo is required to complete onboarding.

| Field | Type | Notes |
|-------|------|-------|
| photo_url | text | Supabase Storage URL |
| position | smallint | 1–6 (1 = main photo, shown on profile card) |
| is_verified | boolean | Photo verification flag (future) |

**Table:** `user_photos`

**Behavior:**
- Position 1 is synced to `profiles.avatar_url` (denormalized for fast profile card loading)
- Users can reorder photos by swapping position values
- Photos stored in Supabase Storage with signed URLs
- Edit profile screen shows "3 out of 6" progress

---

## Profile Completion Tracking

The edit profile screen shows a completion percentage based on how many fields the user has filled. This is tracked in `onboarding_progress`:

| Field | Type | Notes |
|-------|------|-------|
| total_fields | smallint | Total possible fields (default: 35) |
| filled_fields | smallint | Fields the user has completed |
| photo_count | smallint | Photos uploaded (out of 6) |

**Completion percentage** = `(filled_fields / total_fields) * 100`

**Sections displayed on edit profile:**
| Section | Example | Fields counted |
|---------|---------|----------------|
| Bio | "Tell us about you" | 1 field (bio text) |
| Photos | "3 out of 6" | 6 slots |
| About you | "23 out of 35" | All profile fields across all tables |
| Zodiac | Birth chart display | birth_location, birth_time |

> **Note:** `filled_fields` is recalculated whenever any profile table is updated (via trigger or application logic). This avoids expensive cross-table counts on every profile view.

---

## Edit Profile vs Onboarding

All onboarding fields are editable from the profile settings screen. The edit profile screen groups fields into sections:

| Edit Section | Source Tables | Editable Fields |
|-------------|--------------|----------------|
| **Bio & Basic** | `profiles` | bio, display_name, occupation, education |
| **Photos** | `user_photos` | Up to 6 photos with reorder |
| **About Relationships** | `user_relationship_prefs` | relationship_type, has_kids, who_to_see, dating_style, attraction_factors, deal_breakers, preferences |
| **Personal Habits** | `user_habits` | smokes, drinks, exercises, exercise_types, diet, online_availability |
| **Values & Lifestyle** | `user_values` | hobbies, religion, politics, situation |
| **Personality** | `user_personality` | MBTI (retake test), Love Language (retake test), Attachment Style (retake quiz), Emotional Readiness, Communication Style |
| **Zodiac** | `user_astrology` | birth_location, birth_time (recalculates chart) |

> **Important:** Editing any field that feeds the compatibility algorithm triggers `is_stale = true` on all cached `compatibility_scores` involving this user.

---

## Design Decisions

### Why separate tables instead of one giant profile?

1. **Modularity** - Each domain (habits, values, astrology) evolves independently
2. **Performance** - Queries only join what they need
3. **Compatibility algorithm** - Can weight entire categories, not just individual fields
4. **Privacy** - Different visibility rules per category (e.g., hide astrology but show habits)
5. **Extensibility** - Adding a new category = new table, zero impact on existing ones

### Why enums + JSONB hybrid?

- **Enum columns** for fields with known, stable options (gender, MBTI types)
- **JSONB `extras` column** on each table for experimental / future fields
- This lets us add new fields without migrations during rapid iteration

### Onboarding Progress Tracking

The `onboarding_progress` table tracks which steps a user has completed. This allows:
- Resuming onboarding if the user leaves mid-flow
- Showing a progress indicator
- Validating that all required steps are done before entering the app

---

## Compatibility Algorithm Integration Points

> Full algorithm details: see [compatibility-algorithm.md](compatibility-algorithm.md)

Every profile field feeds into the **3-phase compatibility pipeline**:

### Phase 1: Filters (eliminate before scoring)
- Gender/orientation cross-check (bidirectional)
- **Relationship type incompatibility** — hard filter v2.0 (was Phase 2 penalty)
- Hard deal breakers from AI-processed JSON

### Phase 2: Penalties (deduct from score)
- Medium deal breakers from AI-processed JSON (-15 to -40)
- Preference mismatches (configurable)

### Phase 3: Scoring (4 weighted blocks)
```
Block 1: Love (35%)           -- love_language + attraction_factors
Block 2: Lifestyle (25%)      -- smokes, drinks, exercises, diet, hobbies, availability
Block 3: Values (25%)         -- attachment_style (25%), politics (20%), religion (20%),
                              --   situation (20%), MBTI (15%)  [v2.0 weights]
Block 4: Astrology (15%)      -- sun sign (always) or full chart (if available)

score_final = max(0, score_bruto - penalties)
```

### Key design principles:
- All weights stored in `compatibility_weights` table (tunable without deploy)
- Deal breakers are **not always eliminatory** — AI classifies severity per item
- Preferences feed the same AI pipeline as deal breakers (positive scoring)
- Mode-specific weight overrides supported (dating vs couple)
- Scores cached in `compatibility_scores` and invalidated when profiles change

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0 (Steps 10–12 added: Attachment Style, Emotional Readiness, Communication Style)*

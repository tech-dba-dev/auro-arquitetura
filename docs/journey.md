# Journey Tab Architecture

> Status: **Work in progress** — core structure defined.

## Overview

The Journey tab is the **daily wellness and self-awareness** hub. It encourages users to check in with themselves, explore personality/astrology insights, and develop emotional awareness — which feeds back into better relationship outcomes.

This tab is NOT about matching or dating — it's the personal growth side of Auro.

---

## Components

### 1. Explore Cards (Horizontal Carousel)

Educational content cards that help users understand personality frameworks:

| Card | Description | Content Source |
|------|-------------|---------------|
| **Explore Zodiac** | "See what the stars say about love, chemistry, and compatibility" | Static/CMS content |
| **Explore MBTI** | "Discover how you connect and communicate" | Static/CMS content |

- Tapping "Discover More" opens a detail screen with articles/explanations
- Content is not user-specific — it's editorial/educational
- Can be expanded with new card types over time (Love Languages, Attachment Styles, etc.)

> **No user table needed** — content served from CMS or static data.

---

### 2. Daily Alignment (Daily Ritual)

A short guided routine (audio/meditation) to start the day:

```
"Your Daily Ritual"
⏱ 10min routine
▶ Play button
"A short moment to realign your energy before connecting."
```

**Behavior:**
- One ritual per day, refreshed daily
- Audio content stored in Supabase Storage or external CDN
- User can mark as completed (optional tracking)
- Ritual content can be personalized based on zodiac sign or mood trend (future)

> **No user table needed for MVP** — completion tracking can be added later if needed.

---

### 3. Mood Tracker

The main interactive element. Users log how they feel each day.

```
"How you feel today?"
😊 Good  |  😐 Fine  |  😔 Low  |  😢 Bad  |  😤 Stressed
```

**Behavior:**
- One entry per day (based on user's local date, derived from timezone)
- User taps an emoji/mood — saved immediately
- Optional: user can add a short note
- NOT mandatory — the app nudges but doesn't force
- Daily reminder notification at a user-preferred time (future)

**Mood options:**

| Value | Emoji | Label |
|-------|-------|-------|
| `great` | 😁 | Great |
| `good` | 😊 | Good |
| `fine` | 😐 | Fine |
| `low` | 😔 | Low |
| `bad` | 😢 | Bad |
| `stressed` | 😤 | Stressed |

> **Note:** Options may evolve. Using a text enum (not integer scale) so we can add/rename moods without breaking historical data.

**Data stored in:** `mood_entries` table

**Insights (future):**
- Weekly/monthly mood trend chart
- Correlation between mood and matching activity
- "You tend to feel best on weekends" type insights

---

### 4. Zodiac Prediction

Daily horoscope-style content personalized to the user's sun sign:

```
"Zodiac Prediction"
"See what the stars have in store for you"

📅 Fri 8  |  Sat 9  |  Sun 10  (date selector)

"Today – Emotional Alignment ☆"

"You're learning that sensitivity isn't weakness — it's awareness.
Listen to what your emotions are really asking for before reacting.
Ground yourself in honesty, and connection will follow naturally."

💡 Tip: Breathe before you speak.
```

**Behavior:**
- One prediction per day per sun sign
- Date selector allows viewing past predictions (up to 7 days back)
- Content generated or curated (AI-generated based on astrological transits, or editorial)
- Personalized by user's `sun_sign` from `user_astrology`
- Can be favorited/saved (future)

> **No user table needed for MVP** — predictions served from a content table or generated on-demand. User's sun sign comes from `user_astrology`.

---

## Data Table

### `mood_entries`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| id | UUID | auto | Primary key |
| user_id | UUID | yes | FK → profiles |
| mood | enum | yes | `great`, `good`, `fine`, `low`, `bad`, `stressed` |
| note | text | no | Optional short text (max 280 chars) |
| entry_date | date | yes | User's local date (derived from timezone) |
| created_at | timestamptz | auto | Server timestamp |

**Constraints:**
- `UNIQUE(user_id, entry_date)` — one mood per day per user
- If user logs again same day, it **updates** (not inserts)

---

## Timezone Awareness

> **Critical design decision:** Auro launches in the US but is designed for global use. ALL time-dependent features must respect the user's timezone.

The mood tracker is the first feature where this matters directly:
- "Today" = the user's local date, NOT server UTC date
- A user in Tokyo logging at 1am local = still "today" for them, even though it's "yesterday" in UTC

This is handled by storing the user's timezone in `profiles.timezone` and deriving `entry_date` from it.

See the **Timezone Awareness** section in [overview.md](overview.md) for the full project-wide policy.

---

## Open Questions

- [ ] Exact mood emoji options — need final design confirmation
- [ ] Should mood tracker have a reminder notification? At what default time?
- [ ] Zodiac prediction: AI-generated vs editorial content?
- [ ] Daily ritual: audio content pipeline (who creates, how often refreshed?)
- [ ] Should mood history be visible to a partner in Couple Mode?
- [ ] Mood data retention policy (keep forever? anonymize after X months?)

---

*This document evolves as the project grows. Last updated: 2026-03-01*

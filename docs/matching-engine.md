# Matching Engine Architecture

> Status: **Work in progress** — core structure defined, tuning values will evolve.

## Overview

The matching engine is the brain that decides **which profiles appear in a user's swipe feed, in what order**. It is NOT just a compatibility filter — it's an intelligent discovery system that balances multiple factors to create a feed that feels natural, diverse, and keeps users engaged.

The key insight: **a good matching engine is not a simple sort by compatibility score.** If it were, everyone would see the same few highly-compatible profiles, those profiles would be overwhelmed, and lower-scored but potentially great matches would never get seen.

---

## Core Principles

1. **Everything is multifactorial** — no single factor (compatibility, distance, randomness) operates alone. Every profile in the feed passed through ALL factors simultaneously. A distant profile only appears if it's ALSO highly compatible. A random profile still needs a minimum compatibility. There is no "random slot that ignores compatibility".
2. **Compatibility is the base, not the whole picture** — high compatibility profiles appear more often, but they don't monopolize the feed
3. **Controlled randomness, not chaos** — randomness introduces serendipity but never overrides quality. A random factor can bump a 70% match above a 75% match, but it will never surface a 30% match
4. **Distance is elastic, not absolute** — nearby profiles get priority. But the system can stretch distance ONLY when quality justifies it (high compatibility). It will never send someone 500km away with low compatibility just because nearby profiles ran out
5. **Scarcity is handled gracefully** — when profiles run out in a region, the system doesn't panic-fill with garbage. It expands gradually, shows fewer profiles, or tells the user honestly
6. **Every profile gets seen** — the system ensures all users get minimum exposure regardless of popularity
7. **Refused profiles can return** — a "pass" today doesn't mean gone forever, but it takes time
8. **Freshness matters** — new users get a visibility boost, recently active users rank higher

---

## Feed Generation Pipeline

```
Step 1: CANDIDATE POOL
  Filter out: blocked users, completed matches, hard deal breakers, gender mismatch
  Result: all potentially eligible profiles
      |
      v
Step 2: SCORING
  Calculate/fetch compatibility score for each candidate
  Add distance score, freshness score, activity score
      |
      v
Step 3: SLOT ALLOCATION
  Divide feed into "slots" with different selection strategies
      |
      v
Step 4: ORDERING & DIVERSITY
  Interleave slots, avoid clusters of similar profiles
      |
      v
Step 5: DELIVERY
  Serve batch of ~20 profiles, preload next batch
```

---

## Step 1: Candidate Pool

Before any scoring, eliminate profiles that should NEVER appear:

```sql
-- Excluded from pool:
WHERE user_id != current_user
  AND user_id NOT IN (blocked_by_me)
  AND user_id NOT IN (blocked_me)
  AND user_id NOT IN (active_matches)       -- already matched & chatting
  AND user_id NOT IN (blocked_users)        -- blocked (either direction)
  AND gender_orientation_passes(me, them)    -- Phase 1 filter from compatibility
  AND relationship_type_compatible(me, them)  -- Phase 1 filter (v2.0)
  AND hard_deal_breakers_pass(me, them)      -- Phase 1 filter
  AND onboarding_complete = true
  AND account_active = true
```

**Important:** Passed/rejected profiles are NOT permanently excluded. See "Recycling" below.

---

## Step 2: Composite Score

Each candidate gets a **composite score** that blends multiple factors:

```
composite_score = (compatibility × W_compat)
               + (distance_score × W_distance)
               + (freshness_score × W_fresh)
               + (activity_score × W_activity)
               + (exposure_balance × W_exposure)
               + (random_factor × W_random)
```

### Factor breakdown:

### 2.1 Compatibility Score (W_compat = 0.45)
The pre-calculated score from `compatibility_scores` table (0–100).
This is the biggest single factor but deliberately not dominant.

### 2.2 Distance Score (W_distance = 0.20)

```
IF distance <= user_max_distance:
  distance_score = 100 - (distance / user_max_distance × 60)
  // Within range: 40-100 points (closer = higher)

ELSE IF distance <= user_max_distance × 3:
  distance_score = 30 - (overflow_ratio × 20)
  // Outside range but not far: 10-30 points (for "wildcard" slots)

ELSE:
  distance_score = 5
  // Very far: minimal but not zero (for exceptional compatibility)
```

The user sets a max distance in filters (e.g., 10km). The system respects this as a **strong preference** but not an absolute wall — a 95% compatible profile at 50km can still appear in wildcard slots.

### 2.3 Freshness Score (W_fresh = 0.10)

New users get a temporary visibility boost:

```
days_since_signup = now() - created_at

IF days_since_signup <= 3:
  freshness = 100      -- "New user" boost
ELIF days_since_signup <= 14:
  freshness = 60       -- Still fresh
ELIF days_since_signup <= 30:
  freshness = 30       -- Settling in
ELSE:
  freshness = 10       -- Established user (baseline)
```

### 2.4 Activity Score (W_activity = 0.10)

Active users rank higher than dormant ones:

```
hours_since_last_active = now() - last_active_at

IF hours_since_last_active <= 1:
  activity = 100       -- Online now
ELIF hours_since_last_active <= 6:
  activity = 80        -- Recently active
ELIF hours_since_last_active <= 24:
  activity = 50        -- Active today
ELIF hours_since_last_active <= 72:
  activity = 25        -- Active this week
ELSE:
  activity = 5         -- Dormant
```

### 2.5 Exposure Balance (W_exposure = 0.05)

Prevents popular profiles from monopolizing feeds and ensures everyone gets seen:

```
times_shown_today = count of times this profile appeared in ANY feed today

IF times_shown_today <= 5:
  exposure = 100       -- Under-exposed, boost
ELIF times_shown_today <= 20:
  exposure = 60        -- Normal exposure
ELIF times_shown_today <= 50:
  exposure = 30        -- Getting saturated
ELSE:
  exposure = 10        -- Over-exposed, slow down
```

### 2.6 Random Factor (W_random = 0.10)

A random number (0–100) injected per candidate per feed generation. This ensures:
- The same search never returns the exact same order
- "Surprising" profiles occasionally appear high in the feed
- The feed feels organic, not robotic

```
random_factor = random(0, 100)
```

---

## Step 3: Slot Allocation

Instead of pure score sorting, the feed is built with **slots** — each slot has a strategy. But critically, **every slot has BOTH a compatibility minimum AND a distance rule**. No slot ignores quality.

For a batch of **20 profiles**:

| Slot | Count | Compatibility | Distance | Extra rule | Why |
|------|-------|--------------|----------|------------|-----|
| **High Match** | 6-8 | 60+ | user's max | — | Core value — best overall matches |
| **Nearby** | 3-4 | 50+ | < 5km | — | "Meet someone close" — still needs quality |
| **Discovery** | 2-3 | 50-75 | user's max × 1.5 | random boost | Serendipity, but NEVER low quality |
| **Rising Star** | 2-3 | 50+ | user's max | account < 7 days old | New users need visibility |
| **Second Chance** | 1-2 | 60+ | user's max | passed 30+ days ago | People change, second look |
| **Unicorn** | 0-1 | **85+** | any (but shown) | — | The "rare find" — ONLY if exceptionally compatible |

### The multifactorial rule:

```
EVERY profile in the feed must satisfy:
  1. compatibility_score >= slot.min_score     (ALWAYS enforced)
  2. distance <= slot.max_distance             (ALWAYS enforced, per slot)
  3. passed all Phase 1 filters                (gender, hard deal breakers)
  4. not blocked, not active match

There is NO slot that says "ignore compatibility" or "ignore everything".
The Unicorn slot stretches distance but DEMANDS 85%+ compatibility.
The Discovery slot adds randomness but DEMANDS 50%+ compatibility.
```

### Why this matters:

- **User asks: "why am I seeing someone from 200km away?"** → Because they're 92% compatible (Unicorn slot). The distance is shown on the card so the user decides.
- **User asks: "why is this low-match person here?"** → They shouldn't be. Every slot has a floor. If someone is 40% compatible, they don't appear in ANY slot.

### Slot distribution is configurable:

```json
{
  "batch_size": 20,
  "slots": {
    "high_match":    {"min": 6, "max": 8, "min_score": 60, "max_distance": "user_setting"},
    "nearby":        {"min": 3, "max": 4, "min_score": 50, "max_distance_km": 5},
    "discovery":     {"min": 2, "max": 3, "min_score": 50, "max_distance": "user_setting × 1.5"},
    "rising_star":   {"min": 2, "max": 3, "min_score": 50, "max_distance": "user_setting", "max_days_old": 7},
    "second_chance": {"min": 1, "max": 2, "min_score": 60, "max_distance": "user_setting", "min_days_since_pass": 30},
    "unicorn":       {"min": 0, "max": 1, "min_score": 85, "max_distance": "unlimited"}
  }
}
```

---

## Step 4: Ordering & Diversity

After slot allocation, profiles are interleaved to prevent clustering:

### Rules:
1. **Never 3+ same-slot profiles in a row** — mix high match with wildcard with distance
2. **Start strong** — first 3 profiles should be from "high match" or "unicorn"
3. **Sprinkle wildcards** — place at positions 5, 10, 15 (roughly)
4. **End with intrigue** — last 2 profiles should include a rising star or second chance
5. **No duplicate traits in a row** — avoid showing 3 Leos or 3 vegans sequentially (use profile diversity signals)

### Diversity signals:
- Don't show 3+ profiles of the same zodiac sign in a row
- Vary age range (don't cluster all same-age)
- Mix compatibility ranges (don't show 5 scores of "78%" in a row)

---

## Step 5: Delivery & Pagination

- Feed is served in batches of **20 profiles**
- When user reaches profile ~15, **preload next batch** in background
- Each batch is generated fresh (not pre-cached) to account for real-time changes
- Track which profiles have been shown in this session to avoid repeats

---

## Scarcity Handling: When Profiles Run Out

This is one of the most important parts of the algorithm. In small cities or after heavy swiping, profiles **will** run out. The system must handle this intelligently, not desperately.

### The Problem:
User is in a small city, set distance to 10km. They've already seen everyone within range. What now?

### BAD approach (what we DON'T do):
- Silently expand to 500km and show random distant people → feels broken
- Show the same people again immediately → feels spammy
- Show low-compatibility filler → degrades trust in the algorithm

### GOOD approach (what we DO):

The system uses **graduated expansion** with clear communication:

```
Phase 1: NORMAL OPERATION
  Pool has enough profiles for full 20-card batch
  → Normal slot allocation

Phase 2: THINNING (pool has 10-19 eligible profiles)
  → Reduce batch size to match available pool
  → Prioritize High Match + Nearby slots
  → Drop Discovery and Unicorn slots
  → No expansion yet

Phase 3: SCARCE (pool has 3-9 eligible profiles)
  → Show all available profiles (no slot system, just sort by composite score)
  → Trigger "soft expansion": increase distance by 50% silently
  → Accelerate Second Chance recycling (reduce cooldown to 14 days)
  → Show a subtle UI hint: "We're finding more people for you"

Phase 4: DEPLETED (pool has 0-2 eligible profiles)
  → Show remaining profiles if any
  → Trigger "hard expansion": increase distance by 100%
  → BUT still enforce minimum compatibility (50%+)
  → Show UI message: "You've seen everyone nearby! We're expanding your search."
  → Include a "distance expanded" badge on profiles from outside original range
  → Offer to adjust filters

Phase 5: TRULY EMPTY (0 profiles even after expansion)
  → Honest UI: "No new profiles right now. We'll notify you when someone new joins!"
  → Push notification when new matching profiles sign up in their area
  → DO NOT fabricate or lower quality — honesty > engagement tricks
```

### Expansion rules:

```
EXPANSION NEVER:
  - Drops compatibility below 50%
  - Bypasses gender/orientation filters
  - Bypasses hard deal breakers
  - Shows profiles that were permanently passed (3x)

EXPANSION CAN:
  - Increase distance (graduated: +50%, then +100%, max 3x original)
  - Reduce Second Chance cooldown (30d → 14d → 7d)
  - Include dormant users (last active > 72h)
  - Include profiles from adjacent age ranges (±2 years from filter)
```

### Distance expansion transparency:

When the system expands distance, the user SEES it:
- Each profile card shows distance: "12km" or "85km"
- Expanded profiles get a subtle label: "Outside your usual range"
- The user can tap it to adjust their distance setting
- They are never surprised — the distance is always visible

### Config:

```json
{
  "scarcity": {
    "thinning_threshold": 10,
    "scarce_threshold": 3,
    "depleted_threshold": 0,
    "soft_expansion_multiplier": 1.5,
    "hard_expansion_multiplier": 2.0,
    "max_expansion_multiplier": 3.0,
    "expanded_min_compatibility": 50,
    "accelerated_cooldown_days": 14,
    "emergency_cooldown_days": 7
  }
}
```

---

## Swipe Actions

### Like (right swipe / heart)
```
→ Record in swipe_actions (action = 'like')
→ Check if other user has also liked me
  → YES: Create match (see Match section)
  → NO: Wait (they'll see the like indicator)
```

### Pass (left swipe / X)
```
→ Record in swipe_actions (action = 'pass')
→ Profile enters "cooldown" period (30 days default)
→ After cooldown, eligible for "Second Chance" slot
→ After 3 passes on same profile, removed permanently
```

### Super Like (optional, future)
```
→ Record in swipe_actions (action = 'super_like')
→ Notify the other user immediately
→ Boosted visibility in their feed
→ Limited quantity per day
```

### Undo (rewind button)
```
→ Can undo ONLY the last action
→ Must be within 30 seconds
→ Removes the swipe_action record
→ Profile reappears at top of feed
```

---

## Recycling: How Passed Profiles Come Back

A "pass" is not permanent. The system has a recycling mechanism:

```
Pass #1 → Cooldown: 30 days → Can reappear in "Second Chance" slot
Pass #2 → Cooldown: 90 days → Can reappear (lower priority)
Pass #3 → Permanent removal → Never shown again
```

**Why recycling matters:**
- People's moods change — bad day ≠ permanent rejection
- Profile photos/bios get updated — the person might look different
- The user's own preferences might evolve
- Prevents running out of profiles in smaller cities

---

## Match Creation

When both users like each other:

```
IF A liked B AND B liked A:
  → Create match record
  → Remove both from each other's feed
  → Send push notification to both
  → Open chat with ice-breaker prompts
  → Show "You matched!" screen
```

### Match states:
```
active      → Both users can chat
archived    → One user archived (hidden but not deleted)
unmatched   → One user unmatched (chat deleted for both)
couple      → Both users activated Couple Mode together (Dating Mode match graduated)
blocked     → One user blocked the other (permanent, mutual, no recovery)
```

> **Change v2.0:** Added `couple` state (match graduates when both activate Couple Mode) and `blocked` state (stronger than `unmatched` — no recycling, no recovery).

### Auto-archive logic (new in v2.0):
```
IF match.created_at < now() - interval '30 days'
   AND last_message_at IS NULL           -- never sent a message
→ auto-archive (state = 'archived')

IF match.created_at < now() - interval '90 days'
   AND last_message_at < now() - interval '60 days'  -- inactive for 60 days
→ auto-archive (state = 'archived')
```

Archived matches are hidden from the main list but accessible via an "archived" tab. Users are notified before archiving via push notification ("Heads up — your match with {name} will be archived in 7 days").


---

## User Filters

The user can set discovery filters (from the filter screen):

| Filter | Type | Default | Notes |
|--------|------|---------|-------|
| Looking for | multi-select | all | `long_term`, `casual`, `open_relationship` |
| Show me | multi-select | from profile | `male`, `female`, `both` |
| Age range | range slider | 18-99 | Min/max age |
| Max distance | slider | 50km | In km, minimum 1km |
| Min compatibility | slider | 0% | Minimum score to appear in feed |

Filters are **hard filters** — they exclude from the candidate pool entirely (Step 1). The matching algorithm only works within the filtered set.

```sql
-- Applied in candidate pool query:
WHERE age BETWEEN filter_age_min AND filter_age_max
  AND distance_km <= filter_max_distance  -- except for unicorn slots
  AND compatibility_score >= filter_min_compatibility
  AND relationship_types && filter_looking_for  -- array overlap
```

**Exception:** Unicorn slots can bypass the distance filter (but not age or compatibility filters).

---

## Profile Card Data

What gets sent to the client for each swipe card:

```json
{
  "user_id": "uuid",
  "display_name": "Ellie",
  "age": 32,
  "photos": ["url1", "url2"],
  "bio": "Short personality line or interest hint",
  "compatibility_score": 92,
  "compatibility_label": "Rare Connection",
  "distance_km": 3.2,
  "slot_type": "high_match",

  "quick_peek": {
    "core_identity": {
      "sun_sign": "taurus",
      "moon_sign": "cancer",
      "rising_sign": "leo",
      "love_language": "physical_touch",
      "mbti": "INFJ"
    },
    "relationship": {
      "looking_for": ["long_term"],
      "dating_style": "monogamous",
      "top_attraction": "humor"
    },
    "lifestyle": {
      "exercises": "gym",
      "diet": "vegan",
      "availability": "night_owl",
      "smokes": "no",
      "drinks": "socially"
    },
    "values_interests": {
      "hobbies": ["gym", "vegan", "night_owl"],
      "situation": "employed"
    },
    "personality_hint": "Short personality line based on MBTI + signs",
    "shared_tags": ["sun_sign", "monogamous", "long_term", "love_language", "mbti"]
  },

  "go_deeper": {
    "explanation": {
      "strengths": "You share emotional depth and similar outlooks on relationships.",
      "complements": "Your MBTIs are highly complementary...",
      "worth_exploring": "Different exercise habits..."
    },
    "score_breakdown": {
      "love": 88,
      "lifestyle": 72,
      "values": 85,
      "astrology": 90
    }
  }
}
```

---

## Performance Considerations

### Pre-computation
- Compatibility scores are **pre-calculated** in background jobs when profiles are created/updated
- Only stale scores need recalculation at feed time
- For a user with 10k potential matches, pre-calc happens in batch overnight

### Geospatial
- User location stored as PostGIS `GEOGRAPHY(POINT)` in `profiles`
- Distance calculated with `ST_DStWithin` for fast index-based filtering
- Location updated when app is opened (not continuous GPS drain)

### Feed caching
- Generated feed stored temporarily (10 min TTL)
- If user reopens within TTL, resume where they left off
- On new session, generate fresh feed

### Scaling
- Slot allocation can run in Supabase Edge Function (< 50ms)
- Compatibility score lookup is indexed (O(1) per pair)
- Batch of 20 profiles = ~20 indexed lookups + 1 geospatial query

---

## Data Tables (Summary)

| Table | Purpose |
|-------|---------|
| `swipe_actions` | Records every like/pass/super_like with timestamps |
| `matches` | Created when mutual like, tracks match lifecycle |
| `user_discovery_filters` | User's filter settings (age, distance, etc.) |
| `feed_impressions` | Tracks which profiles were shown (for exposure balance) |
| `matching_config` | Admin-tunable weights and slot distribution |

> SQL definitions: see [schema.sql](schema.sql)

---

## Open Questions

- [ ] Super Like: implement in v1 or defer?
- [ ] Undo: free or premium feature?
- [ ] Should compatibility minimum filter default to 0% or some baseline (30%)?
- [ ] Feed batch size: 20 good for performance? Too many/few?
- [ ] Recycling: 30-day cooldown appropriate? Should it depend on compatibility?
- [ ] Exposure balance: per-day or per-session counting?
- [ ] Should Unicorn slot bypass age filter too, or only distance?

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0 (couple/blocked states, auto-archive, relationship type Phase 1 filter)*

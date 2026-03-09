# Compatibility Algorithm Architecture

> Status: **v2.0** — updated March 2026. Relationship type moved to Phase 1 filter; Attachment Style added to Block 3; score labels revised.

## Overview

The compatibility system operates in **3 sequential phases**. Each phase is a gate: if a profile doesn't pass, it's discarded before reaching the next phase. This optimizes performance (no scoring for eliminated profiles) and respects user preferences.

```
PHASE 1 — FILTERS (eliminatory)
    |
    v  passed
PHASE 2 — PENALTIES (deductions)
    |
    v  adjusted score
PHASE 3 — SCORING (4 weighted blocks)
    |
    v  final score
AI EXPLANATION GENERATION
    |
    v  display to user
```

---

## Phase 1: Filters

Filters run **before** any scoring. Zero computation cost — simple field comparisons.

### Filter 1: Gender / Sexual Orientation

Bidirectional check. Both users must accept each other's gender.

```
IF A.who_to_see INCLUDES B.gender
   AND B.who_to_see INCLUDES A.gender
→ PASS

ELSE → ELIMINATED (never appears)
```

**Edge cases:**
- `who_to_see = "everyone"` → accepts any gender, always passes
- `gender = "rather_not_say"` → only appears for users who want to see "everyone"
- `non_binary` and `gender_fluid` → treated as their own gender categories, not as "everyone"
- Check is **always bidirectional** — both must accept

### Filter 2: Relationship Type Compatibility

Bidirectional check. Incompatible relationship intentions are eliminated before scoring.

```
INCOMPATIBLE_PAIRS = [
  ("long_term", "open_relation"),
  ("long_term", "casual"),
  ("monogamous", "polyamorous"),
]

IF (A.relationship_type, B.relationship_type) IN INCOMPATIBLE_PAIRS (either direction)
→ ELIMINATED

ELSE → PASS
```

> **Change from v1:** Relationship type was a Phase 2 penalty (-20 to -40 pts). It is now a Phase 1 hard filter. Fundamentally incompatible intentions should not generate matches at all.

### Filter 3: Hard Deal Breakers

The AI has already processed the user's free text into structured JSON. This phase reads **only items where the AI determined high severity**.

> **Important change from initial design:** Deal breakers are NOT always eliminatory. The AI classifies each one with a severity level. Only the hardest ones eliminate — the rest become penalties in Phase 2.

```
FOR EACH deal_breaker IN A.deal_breakers_json:
  IF deal_breaker.severity == "hard"
     AND B[deal_breaker.field] == deal_breaker.eliminatory_value
  → ELIMINATED

// Then repeat: B's deal breakers against A's profile
// Bidirectional — if either direction eliminates, the pair is discarded
```

---

## Phase 2: Penalties

Penalties are **deducted from the final score** after the 4 blocks are calculated. They don't eliminate, they reduce.

> **Note v2.0:** Relationship type mismatch is no longer a penalty — it was promoted to a Phase 1 hard filter. Only genuine soft mismatches remain as penalties.

### Penalty: Medium Deal Breakers
Items from `deal_breakers_json` where severity is "medium". These are near-misses — the user doesn't want it, but it's not a hard no.

```json
// Example: user wrote "I prefer non-smokers"
{
  "field": "smokes",
  "severity": "medium",
  "eliminatory_value": null,
  "penalty_rules": [
    {"value": "yes", "points": -35},
    {"value": "occasionally", "points": -15}
  ],
  "original_text": "I prefer non-smokers"
}
```

### Penalty: Preference Mismatches
Items from `preferences_json` can also generate small penalties when there's a clear mismatch. This is the **same AI pipeline** as deal breakers but with softer output.

---

## Phase 3: Scoring (4 Blocks)

Each block produces a score from 0 to 100. The final score is a weighted sum minus penalties.

```
score_bruto = (block1 × 0.35) + (block2 × 0.25) + (block3 × 0.25) + (block4 × 0.15)
score_final = max(0, score_bruto - total_penalties)
```

---

### Block 1: Love — 35% of total

Two sub-components: Love Language (60%) + Attraction Tags (40%).

#### Love Language Match

| Scenario | Points | Example |
|----------|--------|---------|
| Direct match (same language) | 100 | Both: Physical Touch |
| Complementary pair | 70 | Acts of Service + Quality Time |
| Neutral (no known relation) | 40 | — |
| Opposite pair | 20 | Receiving Gifts + Physical Touch |

> Note: The complementary/opposite pairings are configurable and may evolve based on research.

#### Attraction Tags Overlap

```
score = (tags_in_common / max(tags_A, tags_B)) × 100
```

Example: A has [intelligence, humor, kindness], B has [humor, kindness, ambition] → 2 common / 3 max = 67 pts

#### Block 1 formula:
```
score_love = (love_language_score × 0.6) + (attraction_score × 0.4)
```

---

### Block 2: Lifestyle — 25% of total

Uses **gradual scoring** — not binary. Close values score partially.

| Sub-field | Weight | Scoring Logic |
|-----------|--------|---------------|
| Smoking | 15% | Same = 100, close = 50, opposite = 0 |
| Drinking | 15% | Same = 100, close = 60, opposite = 10 |
| Exercise | 20% | Both yes = 100, one yes = 40, both no = 70. Bonus if same type |
| Diet | 15% | Same = 100, close = 60, opposite = 10 |
| Hobbies | 25% | `(common / total_unique) × 100` |
| Availability | 10% | Same = 100, adjacent = 60, opposite = 20 |

#### Block 2 formula:
```
score_lifestyle = weighted_average(smoking×15, drinking×15, exercise×20, diet×15, hobbies×25, availability×10)
```

---

### Block 3: Values & Personality — 25% of total

> **Change v2.0:** Attachment Style added (25%). MBTI weight reduced from 30% → 15%. Politics and Religion each reduced from 25% → 20%. Situation unchanged at 20%.

| Sub-field | Weight | Scoring Logic |
|-----------|--------|---------------|
| Attachment Style | 25% | Compatibility matrix based on secure/anxious/avoidant/fearful_avoidant pairs |
| Political views | 20% | Same = 100, different + both open = 60, different + one closed = 25, both closed = 0 |
| Religion | 20% | Same = 100, different with tolerance = 55, opposite without tolerance = 10 |
| Situation + Area | 20% | Same situation + similar area = 100, same situation diff area = 60, diff situation = 40 |
| MBTI | 15% | Known complementary pairs = 90, same type = 70, neutral = 50, friction pairs = 20 |

#### Attachment Style Compatibility Matrix:

| A \ B | Secure | Anxious | Avoidant | Fearful-Avoidant |
|-------|--------|---------|----------|-----------------|
| Secure | 100 | 75 | 65 | 55 |
| Anxious | 75 | 50 | 20 | 30 |
| Avoidant | 65 | 20 | 60 | 25 |
| Fearful-Avoidant | 55 | 30 | 25 | 40 |

> Rationale: Secure attachment is the most adaptive — it pairs well with all types. Anxious + Avoidant is the most problematic pairing (pursuer-distancer dynamic).

#### MBTI Known Pairs (examples, not exhaustive):
- Complementary: INFJ-ENFP, INTJ-ENTP, INFP-ENFJ
- Friction: ESTJ-INFP, ISTJ-ENFP

#### Block 3 formula:
```
score_values = (attachment×0.25) + (politics×0.20) + (religion×0.20) + (situation×0.20) + (mbti×0.15)
```

---

### Block 4: Astrology — 15% of total

Two levels depending on available data:

#### Level 1: Sun Sign Only (always available)
Uses elemental compatibility table:

| Element Pair | Points |
|-------------|--------|
| Fire + Air | 90 |
| Earth + Water | 90 |
| Same element | 85 |
| Fire + Earth | 40 |
| Air + Water | 40 |
| Fire + Water | 25 |

Elements:
- Fire: Aries, Leo, Sagittarius
- Earth: Taurus, Virgo, Capricorn
- Air: Gemini, Libra, Aquarius
- Water: Cancer, Scorpio, Pisces

#### Level 2: Full Chart (when both users have birth_time + location)
Replaces Level 1 when **both** users have complete data.

| Planetary Point | Weight | What it represents |
|----------------|--------|-------------------|
| Sun | 25% | Identity, ego — how they see each other |
| Moon | 25% | Emotions, intimacy — how they handle feelings |
| Venus | 20% | Love style — romance, affection, priorities |
| Mars | 12% | Attraction, drive — sexual tension |
| Rising | 10% | First impression — initial attraction |
| Mercury | 8% | Communication — how they talk and resolve conflict |

Each point uses the same elemental compatibility table.

**Fallback:** If only one user has full chart data → both fall back to Level 1 (sun sign only).

#### Block 4 formula:
```
// Level 1:
score_astro = elemental_score(A.sun_sign, B.sun_sign)

// Level 2:
score_astro = (sun×0.25) + (moon×0.25) + (venus×0.20) + (mars×0.12) + (rising×0.10) + (mercury×0.08)
```

---

## AI Pipeline: Deal Breakers & Preferences Processing

Two AI calls that share the same pipeline structure:

### AI #1: Deal Breaker Parser (+ Preferences Parser)

| Aspect | Detail |
|--------|--------|
| **When** | Onboarding submission, profile edit, or batch reprocessing |
| **Input** | User's free text + system field map (all available fields and their values) |
| **Output** | Structured JSON with severity classification |
| **Frequency** | 1x per user (+ re-edits) |
| **Runs** | Asynchronously (background job) |

**Output format (deal breakers):**
```json
{
  "deal_breakers": [
    {
      "field": "smokes",
      "severity": "hard",
      "eliminatory_value": "yes",
      "penalty_rules": [
        {"value": "occasionally", "points": -35}
      ],
      "original_text": "I absolutely can't stand smokers"
    },
    {
      "field": "political_views",
      "severity": "medium",
      "eliminatory_value": null,
      "penalty_rules": [
        {"value": "conservative", "points": -30},
        {"value": "moderate", "points": -10}
      ],
      "original_text": "I'd rather not date someone too conservative"
    }
  ]
}
```

**Output format (preferences):**
```json
{
  "preferences": [
    {
      "field": "exercises",
      "desired_values": ["yes"],
      "bonus_points": 10,
      "original_text": "I'd love someone who works out"
    },
    {
      "field": "hobbies",
      "desired_values": ["traveling", "music"],
      "bonus_points": 5,
      "original_text": "Someone who loves to travel and enjoy music"
    }
  ]
}
```

> Key design: The AI receives the complete **field map** — all system fields and their possible values. It can only reference fields that exist. This means when we add new fields, we just update the field map and reprocess.

### AI #2: Explanation Generator

| Aspect | Detail |
|--------|--------|
| **When** | After score calculation |
| **Input** | Detailed scores per block + both user profiles |
| **Output** | 3 text blocks (strengths, complements, attention points) |
| **Frequency** | 1x per pair (cacheable) |
| **Runs** | Can be pre-calculated or on-demand |

Output:
```json
{
  "strengths": "You both share Physical Touch as your love language and value humor and intelligence...",
  "complements": "Your MBTIs (INFJ and ENFP) are one of the most complementary pairs...",
  "worth_exploring": "Different political views — but you're both open to dating someone with a different perspective."
}
```

> **Change v2.0:** Key renamed from `"attention"` → `"worth_exploring"`. Framing is now explicitly positive — it's an invitation to explore, not a warning.

Rules for AI #2:
- Friendly, personal language
- Max 3 sentences per block
- Never reveal internal score numbers
- Always give positive context even for attention points

---

## Score Display

> **Change v2.0:** Labels revised to be friendlier and less discouraging. "Unlikely" replaced with "Worth a Conversation" — every match shown to the user passed Phases 1 and 2 and deserves consideration.

| Range | Label | Description |
|-------|-------|-------------|
| 85–100 | Rare Connection | Exceptional match in almost every aspect |
| 70–84 | Strong Compatibility | Deep affinity with few divergences |
| 50–69 | Good Match | Solid base with points worth exploring |
| 30–49 | Interesting Differences | Different perspectives that could complement |
| 0–29 | Worth a Conversation | Divergent profiles — sometimes opposites surprise you |

---

## Data Storage

| What | Where | Lifecycle |
|------|-------|-----------|
| Original texts | `user_relationship_prefs.deal_breakers_text`, `preferences_text` | Permanent, editable |
| AI-processed JSONs | `user_relationship_prefs.deal_breakers_json`, `preferences_json` | Reprocessed on edit or field map change |
| Calculated scores | `compatibility_scores` | Cached, invalidated (`is_stale`) when either profile changes |
| AI explanations | `compatibility_scores.explanation` | Cached with scores |
| Algorithm weights | `compatibility_weights` | Admin-configurable, no deploy needed |
| Algorithm version | `compatibility_scores.scoring_version` | Tracks which algorithm version generated the score (e.g. `"2.0"`) — allows selective invalidation when algorithm changes |

---

## Open Questions (to be refined)

- [ ] Exact complementary/opposite love language pairings
- [ ] Full MBTI compatibility matrix (16×16)
- [ ] How preferences_json feeds into positive scoring (bonus points vs block boost)
- [ ] Cache invalidation strategy (immediate recalc vs lazy on next view)
- [ ] Couple mode: different weight distribution?
- [ ] Should preferences also have severity levels like deal breakers?
- [ ] Batch reprocessing frequency when field map changes

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0*

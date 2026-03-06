# Auro - Project Overview

## What is Auro?

Auro is a revolutionary relationship app that combines modern dating mechanics with deep personality insights, astrology-based compatibility, and structured relationship growth tools. The entire app is in **English**.

## Core Concept

Unlike traditional dating apps that rely primarily on photos and surface-level bios, Auro builds comprehensive personality profiles through a detailed onboarding process. These profiles feed into a proprietary **compatibility algorithm** that considers:

- Personality traits (MBTI, Love Languages)
- Astrological compatibility (birth chart analysis)
- Lifestyle alignment (habits, values, interests)
- Relationship goals and preferences
- Deal breakers and must-haves

## App Modes

Auro operates in multiple modes, each serving a different relationship need:

### 1. Dating Mode
- *"Meet with clarity"*
- For singles looking for meaningful connections
- Intelligent matching engine with slot-based feed (not just sorted by score)
- Swipe mechanics with compatibility breakdown on each profile

### 2. Couple Mode
- *"Grow with structure"*
- For existing couples wanting to strengthen their relationship
- Provides insights into compatibility strengths and growth areas
- Tools for communication, conflict resolution, and relationship development

### 3. Future Modes (Planned)
- Additional modes will be introduced over time (e.g., friendship, networking, etc.)
- Architecture must support adding new modes without breaking existing ones

## Technical Stack

| Layer | Technology |
|-------|-----------|
| Backend / Database | **Supabase** (PostgreSQL + Auth + Storage + Edge Functions + Realtime) |
| Auth | Supabase Auth (Email/Password + Apple + Google OAuth) |
| Geospatial | **PostGIS** extension (distance calculations) |
| Real-time Chat | **Supabase Realtime** (PostgreSQL LISTEN/NOTIFY) |
| Compatibility Engine | Supabase Edge Functions (deterministic scoring, < 5ms per pair) |
| AI Pipeline | External LLM (deal breaker parsing, explanation generation, ice-breakers) |
| Astrology Engine | Custom calculation service (TBD) |
| Media Storage | Supabase Storage (photos, voice notes) |

## Architecture Principles

1. **Modular by design** - Each feature area (onboarding, profile, matching, astrology, chat, journey) is a self-contained module
2. **Schema flexibility** - Profile fields can be added, removed, or modified without breaking the compatibility algorithm
3. **Weighted scoring** - The compatibility engine uses configurable weights so different factors can be tuned over time
4. **Intelligent discovery** - Matching feed uses slot allocation (not pure sorting) with randomness, distance, freshness, and exposure balancing
5. **Mode-agnostic profiles** - A user's profile data is shared across modes; mode-specific behavior lives in separate tables
6. **Privacy-first** - Sensitive data (birth details, orientation) has granular visibility controls via RLS
7. **Admin-tunable** - Algorithm weights, slot distribution, cooldowns all stored in DB, changeable without deploy
8. **Timezone-aware** - All time-dependent features (mood tracker, notifications, daily content, zodiac predictions) use the user's local timezone (`profiles.timezone`, IANA format). The app launches in the US but is designed for global use from day one. Never assume UTC = user's "today"

## High-Level Modules

```
auro/
  |-- Auth & Registration         (sign up, login, OAuth)
  |-- Onboarding Flow             (multi-step profile builder)
  |-- Profile Management          (view/edit profile data)
  |-- Astrology Engine            (birth chart calculation)
  |-- Compatibility Algorithm     (3-phase scoring: filters → penalties → 4 blocks)
  |-- Matching Engine             (feed generation: slots, randomness, distance, recycling)
  |-- Swipe System                (like, pass, super_like, undo, match creation)
  |-- Chat System                 (messages, ice-breakers, media, realtime)
  |-- Discovery Filters           (age, distance, compatibility, relationship type)
  |-- User Safety                 (block, report, moderation)
  |-- Journey Tab                 (mood tracker, daily rituals, zodiac predictions)
  |-- Mode: Dating                (swipe feed + chat)
  |-- Mode: Couple                (relationship tools — TBD)
  |-- Notifications               (push, in-app — TBD)
  |-- Admin / Config              (weights, slots, feature flags)
```

## Database Tables (20 total)

### Profile & Onboarding (10 tables)
| Table | Purpose |
|-------|---------|
| `profiles` | Core identity + location + occupation + education + activity |
| `user_modes` | Active mode(s) per user |
| `user_astrology` | Birth details + calculated chart |
| `user_relationship_prefs` | Relationship goals, deal breakers (AI-processed), preferences |
| `user_habits` | Smoking, drinking, exercise, diet |
| `user_values` | Hobbies, religion, politics, situation |
| `user_personality` | MBTI, love languages |
| `user_photos` | Profile photos (up to 6, ordered by position) |
| `onboarding_progress` | Step tracking + profile completion counters |
| `compatibility_weights` | Tunable algorithm weights |

### Matching & Discovery (5 tables)
| Table | Purpose |
|-------|---------|
| `compatibility_scores` | Cached scores between user pairs |
| `user_discovery_filters` | User filter settings (age, distance, etc.) |
| `swipe_actions` | Every like/pass/super_like with recycling counter |
| `matches` | Mutual likes, match lifecycle |
| `feed_impressions` | Exposure tracking for feed balancing |

### Chat & Safety (4 tables)
| Table | Purpose |
|-------|---------|
| `messages` | All chat messages (text, media, voice, system) |
| `chat_ice_breakers` | AI-generated conversation starters per match |
| `blocked_users` | Block relationships |
| `reports` | User reports for moderation |

### Journey (1 table)
| Table | Purpose |
|-------|---------|
| `mood_entries` | Daily mood log (mood tracker) |

### Config (1 table)
| Table | Purpose |
|-------|---------|
| `matching_config` | Admin-tunable matching engine parameters |

## Document Index

| Document | Description |
|----------|------------|
| [overview.md](overview.md) | This file - project summary and vision |
| [onboarding-profile.md](onboarding-profile.md) | Onboarding flow architecture and profile data model |
| [compatibility-algorithm.md](compatibility-algorithm.md) | Compatibility engine: 3 phases, 4 blocks, AI pipeline |
| [matching-engine.md](matching-engine.md) | Matching feed: slot allocation, composite scoring, recycling, swipe system |
| [chat.md](chat.md) | Chat system: messages, ice-breakers, realtime, moderation |
| [journey.md](journey.md) | Journey tab: mood tracker, daily rituals, zodiac predictions |
| [schema.sql](schema.sql) | Supabase SQL schema v4.0 (ready to run) |

---

*This document evolves as the project grows. Last updated: 2026-03-01*

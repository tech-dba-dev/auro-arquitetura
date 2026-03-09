# Analytics & Notifications Architecture

> Status: **v2.0** — March 2026. New module.

## Overview

This document covers the analytics event taxonomy (40+ events), notification system (FCM/APNs with granular opt-out), provider setup, and the 5 critical funnels to configure.

---

## Analytics

### Provider

**Recommended: PostHog** (self-hostable, generous free tier, session recordings, funnel analytics)
**Alternative: Mixpanel** (better mobile SDKs, higher cost)

### Setup

```dart
// FlutterFlow — initialize once on app start
import 'package:posthog_flutter/posthog_flutter.dart';

await Posthog().setup(
  'YOUR_POSTHOG_API_KEY',
  host: 'https://app.posthog.com',
);
```

### Identify & Super Properties

Every event must include global super properties attached to the user identity. Set on login and profile update.

```dart
// On successful login / profile load
Posthog().identify(
  userId: user.id,
  userProperties: {
    // Identity
    'user_id': user.id,
    'account_created_at': user.createdAt.toIso8601String(),
    'active_mode': user.activeMode,          // 'dating' | 'couple'
    'is_premium': user.isPremium,
    'onboarding_complete': user.onboardingComplete,

    // Profile completeness
    'profile_completion_pct': user.filledFields / user.totalFields * 100,
    'has_photos': user.photoCount > 0,
    'photo_count': user.photoCount,

    // Demographics (for cohort analysis — no PII)
    'age_bucket': getAgeBucket(user.birthdate),   // '18-24' | '25-34' | ...
    'gender': user.gender,
    'location_country': user.locationCountry,

    // Personality
    'mbti_type': user.mbtiType,
    'attachment_style': user.attachmentStyle,
    'love_language_primary': user.loveLanguage.first,
    'sun_sign': user.sunSign,

    // App state
    'app_version': packageInfo.version,
    'platform': Platform.isIOS ? 'ios' : 'android',
    'days_since_signup': DateTime.now().difference(user.createdAt).inDays,
  }
);
```

---

### Event Taxonomy

#### Group 1: Onboarding Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `onboarding_started` | `platform`, `oauth_method` | First screen shown |
| `onboarding_step_completed` | `step_number`, `step_name`, `time_spent_seconds` | Each step completion |
| `onboarding_step_skipped` | `step_number`, `step_name` | Optional step skipped |
| `onboarding_completed` | `total_time_minutes`, `steps_skipped`, `photos_added` | Full onboarding done |
| `onboarding_abandoned` | `last_step`, `time_in_flow_minutes` | User left mid-onboarding |
| `profile_photo_uploaded` | `position`, `upload_method` | Photo added at any point |
| `profile_photo_removed` | `position` | Photo deleted |

---

#### Group 2: Dating Mode Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `feed_opened` | `profiles_in_feed`, `pool_phase` | Feed loaded (track scarcity phase) |
| `profile_card_viewed` | `viewed_user_id`, `slot_type`, `compatibility_score_bucket`, `distance_km`, `time_spent_seconds` | Card seen in feed |
| `profile_expanded` | `viewed_user_id`, `section` (`quick_peek` \| `go_deeper`) | Tapped for more info |
| `swipe_like` | `liked_user_id`, `compatibility_score_bucket`, `slot_type` | Right swipe |
| `swipe_pass` | `passed_user_id`, `compatibility_score_bucket`, `time_spent_seconds` | Left swipe |
| `super_like_sent` | `liked_user_id`, `compatibility_score_bucket` | Super like used |
| `match_created` | `match_id`, `compatibility_score`, `days_since_both_joined` | Mutual like |
| `match_viewed` | `match_id`, `hours_since_match` | Opened a match |
| `ice_breaker_viewed` | `match_id`, `breaker_index` | AI ice-breaker seen |
| `ice_breaker_used` | `match_id`, `breaker_index` | Ice-breaker sent as message |
| `message_sent` | `match_id`, `message_type`, `is_first_message`, `hours_since_match` | Message sent |
| `match_unmatched` | `match_id`, `initiator` (`self` \| `other`), `days_active` | Unmatched |
| `filter_changed` | `filter_name`, `old_value`, `new_value` | Discovery filter updated |

---

#### Group 3: Couple Mode Activation Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `couple_mode_entry_tapped` | `source` (`match_profile` \| `menu` \| `onboarding`) | Intent to activate |
| `couple_invite_sent` | `invite_method` (`push` \| `email` \| `link`) | Partner invited |
| `couple_invite_accepted` | `hours_since_sent` | Partner accepted |
| `couple_mode_activated` | `activation_path` (`from_match` \| `direct`), `days_since_match` | Couple record created |
| `couple_mode_left` | `initiator`, `days_in_couple_mode` | Either partner left |

---

#### Group 4: Couple Mode Engagement Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `ritual_viewed` | `ritual_id`, `ritual_type`, `category`, `source` | Ritual opened |
| `ritual_completed` | `ritual_id`, `ritual_type`, `category`, `credits_earned` | Ritual marked done |
| `ritual_skipped` | `ritual_id`, `ritual_type`, `category` | Ritual dismissed |
| `check_in_completed` | `check_in_id`, `frequency`, `connection_score`, `stress_level` | Check-in submitted |
| `journal_entry_created` | `is_shared`, `mood`, `word_count` | Journal entry written |
| `timeline_event_added` | `event_type` | Milestone/memory added |
| `challenge_started` | `challenge_id`, `category` | Challenge begun |
| `challenge_completed` | `challenge_id`, `category`, `duration_days` | Challenge finished |
| `badge_earned` | `badge_type`, `days_in_couple_mode` | Badge awarded |
| `insight_viewed` | `insight_id`, `period_month`, `days_after_generated` | Monthly insight opened |
| `credits_spent` | `transaction_type`, `amount`, `balance_after` | Credits used |

---

#### Group 5: Monetization Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `paywall_viewed` | `feature_attempted`, `current_plan` | Hit a premium limit |
| `subscription_started` | `plan`, `price`, `platform` (`ios` \| `android`) | Subscription begun |
| `subscription_cancelled` | `plan`, `days_subscribed`, `cancellation_reason` | Cancelled |
| `subscription_renewed` | `plan`, `renewal_number` | Auto-renewed |
| `credit_pack_purchased` | `pack_size`, `price` | One-time credit purchase |

---

#### Group 6: Funnel-Critical Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `app_opened` | `session_number`, `days_since_signup`, `notification_triggered` | Every app open |
| `notification_received` | `notification_type`, `category` | Push received |
| `notification_tapped` | `notification_type`, `category`, `time_to_tap_hours` | Push tapped |
| `notification_dismissed` | `notification_type`, `category` | Push dismissed |
| `deep_link_opened` | `deep_link_type`, `source` | Deep link navigated |

---

#### Group 7: Retention Events

| Event | Properties | Notes |
|-------|-----------|-------|
| `streak_updated` | `streak_days`, `streak_type` | Daily ritual streak |
| `streak_broken` | `streak_days`, `streak_type` | Streak missed |
| `profile_updated` | `fields_changed` | Profile edit saved |
| `compatibility_score_viewed` | `viewed_user_id`, `score_bucket`, `section_expanded` | Score breakdown opened |
| `account_deleted` | `days_since_signup`, `had_matches`, `had_couple_mode` | Account deletion |

---

### 5 Critical Funnels to Configure

#### Funnel 1: Onboarding Completion
```
app_opened → onboarding_started → onboarding_step_completed (×12) → onboarding_completed
```
**Goal:** 70%+ completion rate. Drop-off by step identifies friction.

#### Funnel 2: First Match
```
onboarding_completed → feed_opened → swipe_like → match_created
```
**Goal:** First match within 7 days of signup.

#### Funnel 3: Conversation Start
```
match_created → match_viewed → message_sent (first)
```
**Goal:** 60%+ of matches result in at least one message within 24 hours.

#### Funnel 4: Couple Mode Activation
```
couple_mode_entry_tapped → couple_invite_sent → couple_invite_accepted → couple_mode_activated
```
**Goal:** 50%+ of invites convert to activation.

#### Funnel 5: Paywall Conversion
```
paywall_viewed → subscription_started
```
**Goal:** Track conversion rate by `feature_attempted` to identify highest-leverage premium features.

---

## Notifications

### Tables

#### `push_tokens`
```sql
CREATE TABLE push_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  device_id  TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);
```

#### `notification_preferences`
```sql
CREATE TABLE notification_preferences (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  new_match       BOOLEAN NOT NULL DEFAULT true,
  new_message     BOOLEAN NOT NULL DEFAULT true,
  match_expiring  BOOLEAN NOT NULL DEFAULT true,
  ritual_reminder BOOLEAN NOT NULL DEFAULT true,
  check_in_reminder BOOLEAN NOT NULL DEFAULT true,
  couple_badge    BOOLEAN NOT NULL DEFAULT true,
  couple_insight  BOOLEAN NOT NULL DEFAULT true,
  marketing       BOOLEAN NOT NULL DEFAULT false,
  quiet_hours_start TIME NOT NULL DEFAULT '22:00',
  quiet_hours_end   TIME NOT NULL DEFAULT '08:00',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

#### `notification_log`
```sql
CREATE TABLE notification_log (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  category          TEXT NOT NULL,
  title             TEXT NOT NULL,
  body              TEXT NOT NULL,
  deep_link         TEXT,
  sent_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at      TIMESTAMPTZ,
  tapped_at         TIMESTAMPTZ,
  status            TEXT NOT NULL DEFAULT 'sent'
                    CHECK (status IN ('sent', 'delivered', 'tapped', 'failed'))
);
```

---

### Notification Catalog

All notifications with exact copy and deep links:

#### Dating Mode Notifications

| Type | Category | Title | Body | Deep Link |
|------|----------|-------|------|-----------|
| `new_match` | `new_match` | "It's a match! ✨" | "You and {name} liked each other. Start the conversation!" | `auro://matches/{match_id}` |
| `new_message` | `new_message` | "{name} sent you a message" | "{message_preview}" | `auro://chat/{match_id}` |
| `match_expiring` | `match_expiring` | "Don't let this fade..." | "Your match with {name} will be archived in 7 days. Send a message?" | `auro://chat/{match_id}` |
| `super_like_received` | `new_match` | "{name} really likes you!" | "They sent you a Super Like. See their profile?" | `auro://profile/{user_id}` |
| `ice_breaker_suggestion` | `new_message` | "Need a conversation starter?" | "We have some ideas to help you connect with {name}" | `auro://chat/{match_id}` |

#### Couple Mode Notifications

| Type | Category | Title | Body | Deep Link |
|------|----------|-------|------|-----------|
| `ritual_reminder` | `ritual_reminder` | "Your daily ritual is ready" | "{ritual_title} — takes just a few minutes" | `auro://couple/rituals` |
| `partner_completed_ritual` | `ritual_reminder` | "{partner_name} completed today's ritual!" | "Join them — it's more fun together" | `auro://couple/rituals` |
| `check_in_reminder` | `check_in_reminder` | "Weekly check-in time" | "How are you both feeling this week? Take 2 minutes to connect" | `auro://couple/checkin` |
| `partner_submitted_checkin` | `check_in_reminder` | "{partner_name} shared their check-in" | "See how they're feeling and add yours" | `auro://couple/checkin` |
| `new_badge_earned` | `couple_badge` | "You earned a badge! 🏅" | "{badge_name} — {badge_description}" | `auro://couple/badges` |
| `streak_milestone` | `couple_badge` | "{streak_days}-day streak! 🔥" | "You and {partner_name} have been consistent. Keep it up!" | `auro://couple/dashboard` |
| `monthly_insight_ready` | `couple_insight` | "Your monthly insight is here" | "See how your relationship has grown this {month}" | `auro://couple/insights` |
| `challenge_reminder` | `ritual_reminder` | "Day {day} of your challenge" | "{challenge_title} — {today_task}" | `auro://couple/challenges` |

#### System Notifications

| Type | Category | Title | Body | Deep Link |
|------|----------|-------|------|-----------|
| `profile_incomplete` | `marketing` | "Your profile is {pct}% complete" | "Add more to get better matches" | `auro://profile/edit` |
| `new_users_nearby` | `marketing` | "New people joined near you" | "Check who's new in your area" | `auro://feed` |

---

### Frequency Caps

```
new_message:          Max 1 per match per hour (batch if multiple messages arrive quickly)
ritual_reminder:      Once per day, at user's preferred time or 09:00 local default
check_in_reminder:    Once per week (Monday 09:00 local)
match_expiring:       Once, 7 days before auto-archive
marketing:            Max 1 per week, only if user opted in
```

### Quiet Hours

All notifications respect quiet hours (default 22:00–08:00 local time):
- Notification is queued if triggered during quiet hours
- Delivered at `quiet_hours_end` on the user's local time (from `profiles.timezone`)
- Exception: `new_message` is delivered immediately regardless of quiet hours (user chose to be reachable)

### Edge Function: send-notification

```typescript
// supabase/functions/send-notification/index.ts
serve(async (req) => {
  const { userId, type, category, title, body, deepLink, data } = await req.json()

  // 1. Check opt-out preferences
  const { data: prefs } = await supabase
    .from('notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (!prefs[category]) return new Response('User opted out', { status: 200 })

  // 2. Check quiet hours
  const userTimezone = await getUserTimezone(userId)
  if (isQuietHours(prefs.quiet_hours_start, prefs.quiet_hours_end, userTimezone)) {
    await scheduleForLater(userId, type, category, title, body, deepLink, prefs.quiet_hours_end)
    return new Response('Scheduled for quiet hours end', { status: 200 })
  }

  // 3. Get device tokens
  const { data: tokens } = await supabase
    .from('push_tokens')
    .select('token, platform')
    .eq('user_id', userId)

  // 4. Send via FCM (Android) / APNs (iOS)
  for (const { token, platform } of tokens) {
    await sendPush({ token, platform, title, body, deepLink, data })
  }

  // 5. Log
  await supabase.from('notification_log').insert({
    user_id: userId,
    notification_type: type,
    category,
    title,
    body,
    deep_link: deepLink,
    status: 'sent'
  })
})
```

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0*

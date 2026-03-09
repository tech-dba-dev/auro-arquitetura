# Security Architecture

> Status: **v2.0** — March 2026. Covers RLS policies, API key rules, CSAM, Storage, data retention, and pre-launch checklist.

## Overview

Security in Auro is enforced at 4 layers:

```
Layer 1: CLIENT (FlutterFlow)
  → ANON key only. Never secret keys. Never admin bypass.

Layer 2: SUPABASE AUTH
  → JWT tokens. auth.uid() available in all RLS policies.

Layer 3: ROW LEVEL SECURITY (RLS)
  → Every table has RLS enabled. Policies restrict reads/writes at DB level.
  → Client never bypasses RLS — only Edge Functions with service_role key can.

Layer 4: EDGE FUNCTIONS
  → Service role key for admin operations (CSAM scan, AI calls, notifications).
  → ANON key never used in Edge Functions.
```

---

## API Key Rules

| Key | Used by | Can bypass RLS? | Rule |
|-----|---------|-----------------|------|
| `ANON` key | FlutterFlow client | No | ONLY key in client code |
| `SERVICE_ROLE` key | Edge Functions only | Yes | NEVER in client, NEVER in git |
| Claude API key | Edge Functions only | N/A | NEVER in client, NEVER in git |
| FCM server key | Edge Functions only | N/A | NEVER in client |

**Enforcement:**
- FlutterFlow environment variables must contain ONLY `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- All admin operations (score calculation, AI calls, photo upload, push notifications) route through Edge Functions
- Edge Functions receive the service_role key via Supabase Secrets (not env vars in code)

---

## Row Level Security (RLS)

### Critical bugs fixed in v2.0

| Bug | Old policy | Fix |
|-----|-----------|-----|
| `profiles` SELECT `USING (true)` | All authenticated users could read all profiles | `USING (id = auth.uid() OR id IN (mutual matches))` |
| `user_photos` INSERT from client | Client could upload photos directly, bypassing CSAM | INSERT removed from client; goes through Edge Function |
| `matches` UPDATE unrestricted | User could modify `user_a`/`user_b` fields | Restrict UPDATE to `status` and `archived_at` only |
| `reports` no SELECT policy | Reporters could not see their own reports | Added `USING (reporter_id = auth.uid())` |

---

### Core Profile Tables

```sql
-- profiles: user reads own profile + profiles in their match list
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (
    id = auth.uid()
    OR id IN (
      SELECT CASE
        WHEN user_a_id = auth.uid() THEN user_b_id
        ELSE user_a_id
      END
      FROM matches
      WHERE (user_a_id = auth.uid() OR user_b_id = auth.uid())
        AND status IN ('active', 'couple')
    )
  );

CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- user_photos: SELECT for profiles visible to user; INSERT through Edge Function only
ALTER TABLE user_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "photos_select" ON user_photos
  FOR SELECT USING (
    user_id = auth.uid()
    OR user_id IN (
      SELECT CASE WHEN user_a_id = auth.uid() THEN user_b_id ELSE user_a_id END
      FROM matches WHERE (user_a_id = auth.uid() OR user_b_id = auth.uid())
        AND status IN ('active', 'couple')
    )
  );
-- No INSERT/UPDATE/DELETE from client — all through Edge Function (CSAM required)

-- matches: users see only their own matches; can only update status
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "matches_select" ON matches
  FOR SELECT USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

CREATE POLICY "matches_update_status" ON matches
  FOR UPDATE USING (user_a_id = auth.uid() OR user_b_id = auth.uid())
  WITH CHECK (
    user_a_id = (SELECT user_a_id FROM matches WHERE id = matches.id)
    AND user_b_id = (SELECT user_b_id FROM matches WHERE id = matches.id)
  );
-- user_a_id and user_b_id are immutable after creation (enforced by WITH CHECK)

-- reports: reporter sees own reports; no UPDATE from client
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports_select" ON reports
  FOR SELECT USING (reporter_id = auth.uid());

CREATE POLICY "reports_insert" ON reports
  FOR INSERT WITH CHECK (reporter_id = auth.uid());
```

---

### Other Profile Tables (user_ prefix)

```sql
-- All user_ tables follow the same pattern: only owner can read/write
-- user_astrology, user_habits, user_values, user_personality,
-- user_relationship_prefs, onboarding_progress

CREATE POLICY "owner_only_select" ON user_astrology
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "owner_only_insert" ON user_astrology
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner_only_update" ON user_astrology
  FOR UPDATE USING (user_id = auth.uid());

-- (Same pattern for all user_ tables)
```

---

### Compatibility Tables

```sql
-- compatibility_scores: user sees scores where they are one of the pair
ALTER TABLE compatibility_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "compat_scores_select" ON compatibility_scores
  FOR SELECT USING (user_a_id = auth.uid() OR user_b_id = auth.uid());
-- No INSERT/UPDATE from client — written by Edge Function only

-- compatibility_weights: read-only for all authenticated users
ALTER TABLE compatibility_weights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "compat_weights_select" ON compatibility_weights
  FOR SELECT USING (auth.uid() IS NOT NULL);
-- No INSERT/UPDATE from client — admin only via service_role
```

---

### Matching Tables

```sql
-- swipe_actions: user sees and creates their own swipes
ALTER TABLE swipe_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "swipes_select" ON swipe_actions
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "swipes_insert" ON swipe_actions
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- messages: sender or receiver of the match
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select" ON messages
  FOR SELECT USING (
    match_id IN (
      SELECT id FROM matches
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "messages_insert" ON messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

-- blocked_users: user manages their own block list
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "blocked_select" ON blocked_users
  FOR SELECT USING (blocker_id = auth.uid());
CREATE POLICY "blocked_insert" ON blocked_users
  FOR INSERT WITH CHECK (blocker_id = auth.uid());
CREATE POLICY "blocked_delete" ON blocked_users
  FOR DELETE USING (blocker_id = auth.uid());
```

---

### Couple Mode Tables

```sql
-- couples: both partners can read; only system creates
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;

CREATE POLICY "couples_select" ON couples
  FOR SELECT USING (user_a_id = auth.uid() OR user_b_id = auth.uid());
-- INSERT via Edge Function (activate-couple-mode)

-- couple_rituals: both partners read; Edge Function writes
ALTER TABLE couple_rituals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rituals_select" ON couple_rituals
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "rituals_update_completed" ON couple_rituals
  FOR UPDATE USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  )
  WITH CHECK (completed_by = auth.uid());

-- couple_journal_entries: author always sees own; shared entries visible to partner
ALTER TABLE couple_journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "journal_select" ON couple_journal_entries
  FOR SELECT USING (
    author_id = auth.uid()
    OR (
      is_shared = true
      AND couple_id IN (
        SELECT id FROM couples
        WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
      )
    )
  );
CREATE POLICY "journal_insert" ON couple_journal_entries
  FOR INSERT WITH CHECK (author_id = auth.uid());
CREATE POLICY "journal_update" ON couple_journal_entries
  FOR UPDATE USING (author_id = auth.uid());

-- couple_check_ins: both partners see each other's check-ins
ALTER TABLE couple_check_ins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checkins_select" ON couple_check_ins
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "checkins_insert" ON couple_check_ins
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- couple_credits, couple_badges, couple_insights: both partners read
-- (same pattern as couple_check_ins SELECT)
```

---

### Notifications Tables

```sql
-- push_tokens: user manages own tokens
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_tokens_select" ON push_tokens
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "push_tokens_insert" ON push_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "push_tokens_delete" ON push_tokens
  FOR DELETE USING (user_id = auth.uid());

-- notification_preferences: user manages own preferences
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_prefs_select" ON notification_preferences
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notif_prefs_upsert" ON notification_preferences
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- notification_log: user reads own log; Edge Function writes
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_log_select" ON notification_log
  FOR SELECT USING (user_id = auth.uid());
-- No INSERT from client — Edge Function only
```

---

## CSAM Detection

CSAM (Child Sexual Abuse Material) detection is a **legal requirement** before launching any photo storage feature.

### Upload Flow

```
Client (FlutterFlow)
  → Calls Edge Function: upload-photo
  → Edge Function:
      1. Receives image bytes
      2. Sends to CSAM scanner (PhotoDNA or AWS Rekognition)
      3. IF flagged → reject + log + report to NCMEC (legal requirement)
      4. IF clean → upload to Supabase Storage
      5. Returns photo URL to client
  → Client NEVER writes directly to Supabase Storage
```

### Scanner options:
| Option | Cost | Notes |
|--------|------|-------|
| **PhotoDNA** (Microsoft) | Free for qualifying apps | Best-in-class, industry standard |
| **AWS Rekognition** | ~$1/1000 images | Easier integration, slightly less accurate |

### Edge Function skeleton:

```typescript
// supabase/functions/upload-photo/index.ts
import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js"

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const { imageBase64, userId, position } = await req.json()

  // 1. CSAM scan (MUST happen before storage)
  const scanResult = await scanForCSAM(imageBase64)
  if (scanResult.flagged) {
    await logViolation(userId, scanResult)
    return new Response(JSON.stringify({ error: "Image rejected" }), { status: 400 })
  }

  // 2. Upload to Storage
  const fileName = `${userId}/${position}_${Date.now()}.jpg`
  const { data, error } = await supabase.storage
    .from("user-photos")
    .upload(fileName, decode(imageBase64), { contentType: "image/jpeg" })

  if (error) return new Response(JSON.stringify({ error }), { status: 500 })

  // 3. Save to user_photos table
  await supabase.from("user_photos").upsert({
    user_id: userId,
    photo_url: data.path,
    position,
    is_verified: true
  })

  return new Response(JSON.stringify({ url: data.path }), { status: 200 })
})
```

---

## Storage Bucket Rules

```sql
-- user-photos bucket: private, accessed only via signed URLs
INSERT INTO storage.buckets (id, name, public) VALUES ('user-photos', 'user-photos', false);

-- Allow Edge Function (service_role) to read/write anything
-- Allow authenticated users to read only their own photos (fallback, primary is via Edge Function)
CREATE POLICY "photos_user_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'user-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
-- No client INSERT/UPDATE/DELETE — all through Edge Function
```

**Signed URL TTL:** 24 hours (FlutterFlow fetches fresh URLs on each session open)

---

## Data Retention

### Automated deletion (pg_cron):

```sql
-- Delete soft-deleted accounts after 30 days
SELECT cron.schedule('delete-soft-deleted-accounts', '0 3 * * *', $$
  DELETE FROM profiles
  WHERE deleted_at IS NOT NULL
    AND deleted_at < now() - interval '30 days';
$$);

-- Delete unmatched chat messages after 90 days
SELECT cron.schedule('delete-old-unmatched-messages', '0 4 * * *', $$
  DELETE FROM messages
  WHERE match_id IN (
    SELECT id FROM matches WHERE status = 'unmatched'
  )
  AND created_at < now() - interval '90 days';
$$);

-- Delete stale swipe actions (passed profiles, 1-year old)
SELECT cron.schedule('cleanup-old-swipes', '0 5 * * 0', $$
  DELETE FROM swipe_actions
  WHERE action = 'pass'
    AND pass_count >= 3
    AND created_at < now() - interval '365 days';
$$);

-- Purge notification log after 60 days
SELECT cron.schedule('purge-notification-log', '0 6 * * *', $$
  DELETE FROM notification_log
  WHERE created_at < now() - interval '60 days';
$$);
```

### User-initiated deletion:
- Account deletion: soft delete (`profiles.deleted_at = now()`), hard delete after 30 days
- Photo deletion: removes from Storage and `user_photos` immediately
- Couple Mode exit: couple record status = 'ended', data retained 90 days then purged

---

## Pre-Launch Security Checklist

### Database
- [ ] RLS enabled on ALL tables (`SELECT relname FROM pg_tables WHERE schemaname = 'public'` — verify none are missing)
- [ ] No `USING (true)` policies on tables with sensitive fields
- [ ] `service_role` key NOT in any client code
- [ ] Anon key exposed only to FlutterFlow client
- [ ] pg_cron jobs registered and tested

### Edge Functions
- [ ] All Edge Functions use `SUPABASE_SERVICE_ROLE_KEY` from Supabase Secrets
- [ ] CSAM scanner integrated and tested with sample images
- [ ] Claude API key in Supabase Secrets, never in code
- [ ] FCM/APNs keys in Supabase Secrets
- [ ] All Edge Functions have auth validation (`req.headers.get('Authorization')`)

### Storage
- [ ] `user-photos` bucket is NOT public
- [ ] Signed URLs configured with 24h TTL
- [ ] No direct client upload path exists

### Auth
- [ ] Password min requirements enforced (8 chars, 1 special, 1 number)
- [ ] Email verification required before accessing app
- [ ] OAuth (Apple/Google) tested on both platforms
- [ ] JWT expiry configured (7 days default, refresh token 30 days)

### Compliance
- [ ] CSAM scanner live and logging to audit table
- [ ] NCMEC reporting flow tested (legal requirement in US)
- [ ] Privacy Policy includes data retention terms
- [ ] Terms of Service include age verification (18+)
- [ ] GDPR/CCPA data export endpoint exists

---

*This document evolves as the project grows. Last updated: 2026-03-09 — v2.0*

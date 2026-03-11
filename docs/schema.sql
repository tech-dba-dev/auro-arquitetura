-- ============================================================
-- AURO - Supabase SQL Schema
-- Module: Onboarding & Profile + Compatibility + Matching + Chat
-- Version: 2.0 (was 4.0 — renamed to align with architecture versioning)
-- Last updated: 2026-03-09
-- v2.0 changes appended at the bottom of this file
-- ============================================================
-- Run this in Supabase SQL Editor (or via migrations)
-- Depends on: Supabase Auth (auth.users), PostGIS extension
-- ============================================================

-- Enable PostGIS for geospatial queries (distance calculation)
CREATE EXTENSION IF NOT EXISTS postgis;


-- ============================================================
-- CUSTOM TYPES (ENUMS)
-- ============================================================

-- Gender options
CREATE TYPE gender_type AS ENUM (
  'male',
  'female',
  'non_binary',
  'gender_fluid',
  'rather_not_say'
);

-- Sexual orientation options
CREATE TYPE orientation_type AS ENUM (
  'heterosexual',
  'gay',
  'lesbian',
  'bisexual',
  'pansexual',
  'ace',
  'demisexual',
  'queer',
  'sapiosexual',
  'rather_not_say_unsure'
);

-- App modes
CREATE TYPE app_mode AS ENUM (
  'dating',
  'couple'
  -- future modes added here
);

-- Zodiac signs (for astrology)
CREATE TYPE zodiac_sign AS ENUM (
  'aries', 'taurus', 'gemini', 'cancer',
  'leo', 'virgo', 'libra', 'scorpio',
  'sagittarius', 'capricorn', 'aquarius', 'pisces'
);

-- Relationship type options
CREATE TYPE relationship_type AS ENUM (
  'long_term',
  'open_relation',
  'casual',
  'friendship',
  'not_sure'
);

-- Kids preference
CREATE TYPE kids_pref AS ENUM (
  'yes',
  'no',
  'rather_not_say'
);

-- Who to see
CREATE TYPE see_pref AS ENUM (
  'male',
  'female',
  'everyone'
);

-- Dating style
CREATE TYPE dating_style_type AS ENUM (
  'monogamous',
  'non_monogamous',
  'polyamorous',
  'open',
  'other'
);

-- Attraction factors
CREATE TYPE attraction_type AS ENUM (
  'intelligence',
  'humor',
  'looks',
  'kindness',
  'ambition'
);

-- Smoking preference
CREATE TYPE smoking_pref AS ENUM (
  'yes',
  'no',
  'occasionally'
);

-- Drinking preference
CREATE TYPE drinking_pref AS ENUM (
  'never',
  'socially',
  'often',
  'occasionally'
);

-- Exercise preference
CREATE TYPE exercise_pref AS ENUM (
  'yes',
  'no',
  'occasionally'
);

-- Exercise types
CREATE TYPE exercise_type AS ENUM (
  'cycling',
  'dancing',
  'gym',
  'crossfit',
  'pilates',
  'gymnastics',
  'swimming',
  'running',
  'yoga'
);

-- Diet types
CREATE TYPE diet_type AS ENUM (
  'omnivore',
  'vegetarian',
  'vegan',
  'pescatarian',
  'keto',
  'other'
);

-- Online availability
CREATE TYPE availability_type AS ENUM (
  'during_the_day',
  'evening',
  'night',
  'flexible',
  'anytime'
);

-- Hobby types
CREATE TYPE hobby_type AS ENUM (
  'music',
  'traveling',
  'coffee',
  'art',
  'gastronomy',
  'movies',
  'sports',
  'reading',
  'gaming',
  'bars',
  'photography',
  'fashion'
);

-- Religion preference
CREATE TYPE religion_pref AS ENUM (
  'yes',
  'no',
  'rather_not_say'
);

-- Current life situation
CREATE TYPE situation_type AS ENUM (
  'student',
  'employed',
  'self_employed',
  'unemployed',
  'retired'
);

-- Political views
CREATE TYPE political_view AS ENUM (
  'liberal',
  'conservative',
  'moderate',
  'apolitical',
  'other'
);

-- Date different politics
CREATE TYPE politics_dating_pref AS ENUM (
  'yes',
  'no',
  'depends'
);

-- MBTI types
CREATE TYPE mbti_type AS ENUM (
  'ISTJ', 'ISFJ', 'INFJ', 'INTJ',
  'ISTP', 'ISFP', 'INFP', 'INTP',
  'ESTP', 'ESFP', 'ENFP', 'ENTP',
  'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ'
);

-- Love language types
CREATE TYPE love_language_type AS ENUM (
  'words_of_affirmation',
  'acts_of_service',
  'receiving_gifts',
  'physical_touch',
  'quality_time'
);

-- Onboarding steps
CREATE TYPE onboarding_step AS ENUM (
  'basic_info',
  'mode_selection',
  'astrology_input',
  'birth_chart',
  'relationships',
  'habits',
  'values_lifestyle',
  'personality_tests',
  'completed'
);

-- Swipe action types
CREATE TYPE swipe_action_type AS ENUM (
  'like',
  'pass',
  'super_like'
);

-- Match status
CREATE TYPE match_status AS ENUM (
  'active',
  'archived',
  'unmatched'
);

-- Message types
CREATE TYPE message_type AS ENUM (
  'text',
  'image',
  'voice',
  'gif',
  'ice_breaker',
  'system'
);

-- Mood options (Journey tab)
CREATE TYPE mood_type AS ENUM (
  'great',
  'good',
  'fine',
  'low',
  'bad',
  'stressed'
);

-- Report reasons
CREATE TYPE report_reason AS ENUM (
  'inappropriate_content',
  'fake_profile',
  'harassment',
  'spam',
  'underage',
  'other'
);


-- ============================================================
-- TABLE: profiles
-- Core user identity data (linked to auth.users)
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Basic info (Step 1 & 2)
  display_name TEXT NOT NULL,
  birthdate DATE NOT NULL,
  gender gender_type NOT NULL,
  sexual_orientation orientation_type[] NOT NULL DEFAULT '{}',
  sexual_orientation_other TEXT,

  -- Profile display
  avatar_url TEXT,
  bio TEXT,

  -- Professional / Education
  occupation TEXT,           -- e.g. "Head chef"
  education TEXT,            -- e.g. "UCLA"

  -- Location (for distance-based matching)
  location GEOGRAPHY(POINT, 4326),  -- PostGIS point (lng, lat)
  location_text TEXT,                -- Display text: "Sunnyvale, California, USA"
  location_updated_at TIMESTAMPTZ,

  -- Timezone (for daily features: mood tracker, notifications, zodiac predictions)
  timezone TEXT DEFAULT 'America/New_York',  -- IANA timezone (e.g. 'America/Los_Angeles', 'Asia/Tokyo')

  -- Activity tracking
  last_active_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,  -- account active/deactivated

  -- Extensibility
  extras JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE profiles IS 'Core user profile. One row per user, linked to auth.users.';


-- ============================================================
-- TABLE: user_modes
-- Tracks which mode(s) the user has activated
-- ============================================================

CREATE TABLE user_modes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  mode app_mode NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- For couple mode: link to partner
  partner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, mode)
);

CREATE TRIGGER user_modes_updated_at
  BEFORE UPDATE ON user_modes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_modes IS 'User mode selections. A user can have multiple modes but only one active at a time.';


-- ============================================================
-- TABLE: user_astrology
-- Birth details + calculated chart data
-- ============================================================

CREATE TABLE user_astrology (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  -- User input (optional)
  birth_location TEXT,
  birth_time TIME,

  -- Calculated by astrology engine
  sun_sign zodiac_sign,
  moon_sign zodiac_sign,
  rising_sign zodiac_sign,
  mercury_sign zodiac_sign,
  venus_sign zodiac_sign,
  mars_sign zodiac_sign,
  jupiter_sign zodiac_sign,
  saturn_sign zodiac_sign,

  -- Full chart data (for detailed analysis)
  full_chart JSONB DEFAULT '{}',
  chart_summary TEXT,

  extras JSONB DEFAULT '{}',
  calculated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_astrology_updated_at
  BEFORE UPDATE ON user_astrology
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_astrology IS 'Astrological data. Input fields + calculated chart.';


-- ============================================================
-- TABLE: user_relationship_prefs
-- Relationship goals, attractions, deal breakers, preferences
-- ============================================================

CREATE TABLE user_relationship_prefs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  relationship_types relationship_type[] NOT NULL DEFAULT '{}',
  has_kids kids_pref,
  who_to_see see_pref,
  dating_style dating_style_type,

  -- Attraction factors (multi-select chips)
  attraction_factors attraction_type[] NOT NULL DEFAULT '{}',
  attraction_other TEXT,

  -- Deal breakers: user writes free text, AI processes into structured JSON
  deal_breakers_text TEXT,                -- Original free text (kept for reprocessing)
  deal_breakers_json JSONB DEFAULT '[]',  -- AI-structured rules (see compatibility-algorithm.md)

  -- Preferences: what you're looking for in a person
  preferences_text TEXT,                  -- Original free text
  preferences_json JSONB DEFAULT '[]',    -- AI-structured preferences (same pipeline as deal breakers)

  -- Processing status
  ai_processed_at TIMESTAMPTZ,            -- When AI last processed the texts

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_relationship_prefs_updated_at
  BEFORE UPDATE ON user_relationship_prefs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_relationship_prefs IS 'Relationship preferences, attractions, deal breakers, and what user is looking for.';


-- ============================================================
-- TABLE: user_habits
-- Personal habits: smoking, drinking, exercise, diet
-- ============================================================

CREATE TABLE user_habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  smokes smoking_pref,
  drinks drinking_pref,
  exercises exercise_pref,
  exercise_types exercise_type[] DEFAULT '{}',
  exercise_other TEXT,

  diet diet_type,
  diet_other TEXT,

  online_availability availability_type,

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_habits_updated_at
  BEFORE UPDATE ON user_habits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_habits IS 'Personal lifestyle habits.';


-- ============================================================
-- TABLE: user_values
-- Values, hobbies, religion, politics, life situation
-- ============================================================

CREATE TABLE user_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  hobbies hobby_type[] NOT NULL DEFAULT '{}',

  follows_religion religion_pref,
  religion_name TEXT,

  current_situation situation_type,
  expertise_area TEXT,

  political_views political_view,
  date_different_politics politics_dating_pref,

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_values_updated_at
  BEFORE UPDATE ON user_values
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_values IS 'Values, hobbies, religion, politics, and life situation.';


-- ============================================================
-- TABLE: user_personality
-- MBTI type and Love Languages
-- ============================================================

CREATE TABLE user_personality (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  mbti mbti_type,
  love_languages love_language_type[] NOT NULL DEFAULT '{}',

  -- Store test results for retake history
  mbti_test_results JSONB DEFAULT '[]',
  love_language_test_results JSONB DEFAULT '[]',

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_personality_updated_at
  BEFORE UPDATE ON user_personality
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_personality IS 'Personality test results: MBTI and Love Languages.';


-- ============================================================
-- TABLE: user_photos
-- Profile photos (up to 6 per user, ordered)
-- ============================================================

CREATE TABLE user_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  photo_url TEXT NOT NULL,          -- Supabase Storage URL
  position SMALLINT NOT NULL,       -- 1-6 (display order, 1 = main/avatar)
  is_verified BOOLEAN DEFAULT false, -- photo verification (future)

  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, position),
  CHECK (position BETWEEN 1 AND 6)
);

COMMENT ON TABLE user_photos IS 'Profile photos. Up to 6 per user, position 1 = main/avatar.';


-- ============================================================
-- TABLE: onboarding_progress
-- Tracks which onboarding steps the user has completed
-- ============================================================

CREATE TABLE onboarding_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  current_step onboarding_step NOT NULL DEFAULT 'basic_info',
  completed_steps onboarding_step[] NOT NULL DEFAULT '{}',
  is_complete BOOLEAN NOT NULL DEFAULT false,

  -- Profile completion tracking (for edit profile screen: "23 out of 35")
  total_fields SMALLINT NOT NULL DEFAULT 35,        -- total possible profile fields
  filled_fields SMALLINT NOT NULL DEFAULT 0,        -- fields the user has filled
  photo_count SMALLINT NOT NULL DEFAULT 0,           -- photos uploaded (out of 6)

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER onboarding_progress_updated_at
  BEFORE UPDATE ON onboarding_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE onboarding_progress IS 'Tracks user onboarding flow progress. Allows resume if user leaves mid-flow.';


-- ============================================================
-- TABLE: compatibility_weights
-- Configurable weights for the compatibility algorithm
-- ============================================================

CREATE TABLE compatibility_weights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Category grouping
  category TEXT NOT NULL,          -- e.g. 'astrology', 'personality', 'lifestyle'
  field_name TEXT NOT NULL,        -- e.g. 'sun_sign_match', 'mbti_compatibility'

  -- Weight config
  weight DECIMAL(4,3) NOT NULL DEFAULT 0.500,  -- 0.000 to 1.000
  is_filter BOOLEAN NOT NULL DEFAULT false,     -- true = eliminates (like deal_breakers)

  -- Mode-specific weights (null = applies to all modes)
  mode app_mode,

  description TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(category, field_name, mode)
);

CREATE TRIGGER compatibility_weights_updated_at
  BEFORE UPDATE ON compatibility_weights
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE compatibility_weights IS 'Configurable weights for the compatibility scoring algorithm. Supports per-mode overrides.';


-- ============================================================
-- TABLE: compatibility_scores
-- Cached compatibility results between user pairs
-- ============================================================

CREATE TABLE compatibility_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The pair (always stored as user_a < user_b to avoid duplicates)
  user_a UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Final result
  score_total SMALLINT NOT NULL,  -- 0-100

  -- Per-block scores (the 4 scoring blocks)
  score_love SMALLINT,            -- Block 1: Love Language + Attraction (35%)
  score_lifestyle SMALLINT,       -- Block 2: Lifestyle habits (25%)
  score_values SMALLINT,          -- Block 3: Values & Personality (25%)
  score_astrology SMALLINT,       -- Block 4: Astrology (15%)

  -- Penalties applied
  penalties_total SMALLINT DEFAULT 0,
  penalties_detail JSONB DEFAULT '[]',  -- [{reason, points}, ...]

  -- AI-generated explanation (3 blocks of text)
  explanation JSONB,
  -- Structure: {
  --   "strengths": "text...",       -- What you have in common
  --   "complements": "text...",     -- Differences that enrich
  --   "attention": "text..."        -- Points of attention
  -- }

  -- Lifecycle
  mode app_mode,                          -- Which mode this score is for
  is_stale BOOLEAN NOT NULL DEFAULT false, -- Flagged when either profile changes
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  explanation_generated_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_a, user_b, mode)
);

CREATE TRIGGER compatibility_scores_updated_at
  BEFORE UPDATE ON compatibility_scores
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE compatibility_scores IS 'Cached compatibility scores between user pairs. Invalidated (is_stale) when either profile changes.';


-- ============================================================
-- TABLE: user_discovery_filters
-- User's swipe filter preferences
-- ============================================================

CREATE TABLE user_discovery_filters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  -- Filter settings
  looking_for relationship_type[] DEFAULT '{}',  -- empty = all
  show_me see_pref DEFAULT 'everyone',
  age_min SMALLINT DEFAULT 18,
  age_max SMALLINT DEFAULT 99,
  max_distance_km SMALLINT DEFAULT 50,           -- in kilometers
  min_compatibility SMALLINT DEFAULT 0,           -- minimum score to appear (0-100)

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_discovery_filters_updated_at
  BEFORE UPDATE ON user_discovery_filters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE user_discovery_filters IS 'User-configurable discovery filters for the swipe feed.';


-- ============================================================
-- TABLE: swipe_actions
-- Records every like, pass, super_like
-- ============================================================

CREATE TABLE swipe_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  target_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  action swipe_action_type NOT NULL,

  -- Recycling tracking
  pass_count SMALLINT DEFAULT 0,  -- incremented on each pass (for permanent removal after 3)

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, target_id)
);

CREATE TRIGGER swipe_actions_updated_at
  BEFORE UPDATE ON swipe_actions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE swipe_actions IS 'Records swipe actions. pass_count tracks recycling (3 passes = permanent removal).';


-- ============================================================
-- TABLE: matches
-- Created when two users mutually like each other
-- ============================================================

CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_a UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  status match_status NOT NULL DEFAULT 'active',

  -- Who initiated (liked first)
  initiated_by UUID REFERENCES profiles(id),

  -- Match quality snapshot (at time of match)
  compatibility_score SMALLINT,

  -- Lifecycle
  matched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_at TIMESTAMPTZ,
  archived_by UUID REFERENCES profiles(id),
  unmatched_at TIMESTAMPTZ,
  unmatched_by UUID REFERENCES profiles(id),

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_a, user_b)
);

CREATE TRIGGER matches_updated_at
  BEFORE UPDATE ON matches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE matches IS 'Mutual likes create a match. Tracks lifecycle: active → archived/unmatched.';


-- ============================================================
-- TABLE: messages
-- Chat messages between matched users
-- ============================================================

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Content
  type message_type NOT NULL DEFAULT 'text',
  content TEXT,                        -- text content or caption
  media_url TEXT,                      -- URL for image/voice/gif (Supabase Storage)
  media_metadata JSONB DEFAULT '{}',   -- dimensions, duration, file_size, etc.

  -- Reply threading (future)
  reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,

  -- Status
  read_at TIMESTAMPTZ,                 -- when recipient opened/saw the message
  deleted_at TIMESTAMPTZ,              -- soft delete (shows "message deleted")

  extras JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE messages IS 'Chat messages. Delivered via Supabase Realtime. Soft-deletable.';


-- ============================================================
-- TABLE: chat_ice_breakers
-- AI-generated conversation starters per match
-- ============================================================

CREATE TABLE chat_ice_breakers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,

  prompts JSONB NOT NULL DEFAULT '[]',
  -- Structure: [
  --   {"emoji": "heart", "title": "Shared love language", "prompt": "You both value..."},
  --   {"emoji": "star", "title": "Astrology", "prompt": "Two earth signs..."},
  --   {"emoji": "music", "title": "Common hobby", "prompt": "You're both into..."}
  -- ]

  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  used_prompt_id TEXT,  -- which prompt was selected (if any)

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE chat_ice_breakers IS 'AI-generated conversation starters. Created async when match happens.';


-- ============================================================
-- TABLE: feed_impressions
-- Tracks which profiles were shown to whom (for exposure balance)
-- ============================================================

CREATE TABLE feed_impressions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  shown_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  slot_type TEXT,  -- 'high_match', 'wildcard', 'unicorn', etc.
  session_id TEXT, -- groups impressions per feed session

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE feed_impressions IS 'Tracks feed impressions for exposure balancing. Partitioned/pruned by date.';


-- ============================================================
-- TABLE: blocked_users
-- Block relationships between users
-- ============================================================

CREATE TABLE blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, blocked_id)
);

COMMENT ON TABLE blocked_users IS 'Block relationships. Bidirectional exclusion from feed and chat.';


-- ============================================================
-- TABLE: reports
-- User reports for moderation
-- ============================================================

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  reason report_reason NOT NULL,
  description TEXT,
  evidence_urls TEXT[] DEFAULT '{}',  -- screenshots, etc.

  -- Admin handling
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  action_taken TEXT,  -- 'warned', 'suspended', 'banned', 'dismissed'

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reports IS 'User reports for moderation. Preserves chat context for admin review.';


-- ============================================================
-- TABLE: mood_entries
-- Daily mood tracking (Journey tab)
-- ============================================================

CREATE TABLE mood_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  mood mood_type NOT NULL,
  note TEXT,                          -- optional short text (max 280 chars)
  entry_date DATE NOT NULL,           -- user's local date (derived from timezone)

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- One mood per day per user (update if re-logged same day)
  UNIQUE(user_id, entry_date)
);

COMMENT ON TABLE mood_entries IS 'Daily mood log. One entry per user per local date. Used for Journey tab mood tracker.';


-- ============================================================
-- TABLE: matching_config
-- Admin-tunable matching algorithm parameters
-- ============================================================

CREATE TABLE matching_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL,
  description TEXT,

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER matching_config_updated_at
  BEFORE UPDATE ON matching_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE matching_config IS 'Admin-configurable matching engine parameters. Weights, slot distribution, cooldowns.';


-- ============================================================
-- INDEXES
-- ============================================================

-- Profile lookups
CREATE INDEX idx_profiles_gender ON profiles(gender);
CREATE INDEX idx_profiles_birthdate ON profiles(birthdate);

-- Mode lookups
CREATE INDEX idx_user_modes_user_active ON user_modes(user_id, is_active);
CREATE INDEX idx_user_modes_mode ON user_modes(mode);

-- Astrology lookups (for compatibility matching)
CREATE INDEX idx_user_astrology_sun ON user_astrology(sun_sign);
CREATE INDEX idx_user_astrology_moon ON user_astrology(moon_sign);
CREATE INDEX idx_user_astrology_venus ON user_astrology(venus_sign);

-- Relationship pref lookups
CREATE INDEX idx_user_rel_prefs_dating_style ON user_relationship_prefs(dating_style);
CREATE INDEX idx_user_rel_prefs_who_to_see ON user_relationship_prefs(who_to_see);

-- Personality lookups
CREATE INDEX idx_user_personality_mbti ON user_personality(mbti);

-- Photos
CREATE INDEX idx_user_photos_user ON user_photos(user_id, position);

-- Compatibility weight lookups
CREATE INDEX idx_compat_weights_category ON compatibility_weights(category);
CREATE INDEX idx_compat_weights_mode ON compatibility_weights(mode);

-- Onboarding
CREATE INDEX idx_onboarding_complete ON onboarding_progress(is_complete);

-- Profile location (geospatial index)
CREATE INDEX idx_profiles_location ON profiles USING GIST(location);
CREATE INDEX idx_profiles_active ON profiles(is_active, last_active_at DESC);

-- Compatibility scores
CREATE INDEX idx_compat_scores_user_a ON compatibility_scores(user_a);
CREATE INDEX idx_compat_scores_user_b ON compatibility_scores(user_b);
CREATE INDEX idx_compat_scores_stale ON compatibility_scores(is_stale) WHERE is_stale = true;
CREATE INDEX idx_compat_scores_total ON compatibility_scores(score_total DESC);

-- Swipe actions
CREATE INDEX idx_swipe_user ON swipe_actions(user_id);
CREATE INDEX idx_swipe_target ON swipe_actions(target_id);
CREATE INDEX idx_swipe_user_action ON swipe_actions(user_id, action);
CREATE INDEX idx_swipe_mutual_check ON swipe_actions(target_id, action) WHERE action = 'like';

-- Matches
CREATE INDEX idx_matches_user_a ON matches(user_a) WHERE status = 'active';
CREATE INDEX idx_matches_user_b ON matches(user_b) WHERE status = 'active';
CREATE INDEX idx_matches_status ON matches(status);

-- Messages
CREATE INDEX idx_messages_match ON messages(match_id, created_at DESC);
CREATE INDEX idx_messages_unread ON messages(match_id, read_at) WHERE read_at IS NULL;
CREATE INDEX idx_messages_sender ON messages(sender_id);

-- Feed impressions (date-based for pruning)
CREATE INDEX idx_feed_impressions_shown ON feed_impressions(shown_profile_id, created_at);
CREATE INDEX idx_feed_impressions_user ON feed_impressions(user_id, created_at);

-- Blocked users
CREATE INDEX idx_blocked_user ON blocked_users(user_id);
CREATE INDEX idx_blocked_target ON blocked_users(blocked_id);

-- Reports
CREATE INDEX idx_reports_reported ON reports(reported_id);
CREATE INDEX idx_reports_unreviewed ON reports(reviewed_at) WHERE reviewed_at IS NULL;

-- Mood entries
CREATE INDEX idx_mood_entries_user ON mood_entries(user_id, entry_date DESC);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_modes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_astrology ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_relationship_prefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_personality ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE compatibility_weights ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all profiles, but only edit their own
CREATE POLICY "Profiles are viewable by all authenticated users"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- User-owned tables: users can only see and edit their own data
-- (Repeat this pattern for each user_* table)

CREATE POLICY "Users can view their own modes"
  ON user_modes FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own modes"
  ON user_modes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own modes"
  ON user_modes FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own astrology"
  ON user_astrology FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own astrology"
  ON user_astrology FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own astrology"
  ON user_astrology FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own relationship prefs"
  ON user_relationship_prefs FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own relationship prefs"
  ON user_relationship_prefs FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own relationship prefs"
  ON user_relationship_prefs FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own habits"
  ON user_habits FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own habits"
  ON user_habits FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own habits"
  ON user_habits FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own values"
  ON user_values FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own values"
  ON user_values FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own values"
  ON user_values FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own personality"
  ON user_personality FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own personality"
  ON user_personality FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own personality"
  ON user_personality FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own onboarding progress"
  ON onboarding_progress FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own onboarding progress"
  ON onboarding_progress FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own onboarding progress"
  ON onboarding_progress FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Photos: visible to all authenticated (shown on profile cards), editable by owner
ALTER TABLE user_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Photos are viewable by all authenticated users"
  ON user_photos FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "Users can upload their own photos"
  ON user_photos FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own photos"
  ON user_photos FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own photos"
  ON user_photos FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Compatibility scores: users can only see scores that involve them
ALTER TABLE compatibility_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own compatibility scores"
  ON compatibility_scores FOR SELECT TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Discovery filters: own data only
ALTER TABLE user_discovery_filters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own filters"
  ON user_discovery_filters FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own filters"
  ON user_discovery_filters FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own filters"
  ON user_discovery_filters FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Swipe actions: own data only (insert and read own swipes)
ALTER TABLE swipe_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own swipes"
  ON swipe_actions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own swipes"
  ON swipe_actions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own swipes"
  ON swipe_actions FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Matches: users can see matches they're part of
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own matches"
  ON matches FOR SELECT TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);
CREATE POLICY "Users can update their own matches"
  ON matches FOR UPDATE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Messages: users can see messages from their matches
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages from their matches"
  ON messages FOR SELECT TO authenticated
  USING (
    match_id IN (
      SELECT id FROM matches
      WHERE (user_a = auth.uid() OR user_b = auth.uid())
        AND status = 'active'
    )
  );
CREATE POLICY "Users can send messages to their matches"
  ON messages FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND match_id IN (
      SELECT id FROM matches
      WHERE (user_a = auth.uid() OR user_b = auth.uid())
        AND status = 'active'
    )
  );
CREATE POLICY "Users can update messages they sent"
  ON messages FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id);

-- Chat ice breakers: viewable by match participants
ALTER TABLE chat_ice_breakers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ice breakers for their matches"
  ON chat_ice_breakers FOR SELECT TO authenticated
  USING (
    match_id IN (
      SELECT id FROM matches
      WHERE user_a = auth.uid() OR user_b = auth.uid()
    )
  );

-- Feed impressions: own data only (written by service_role, readable by user)
ALTER TABLE feed_impressions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own impressions"
  ON feed_impressions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Blocked users: own data only
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own blocks"
  ON blocked_users FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can block other users"
  ON blocked_users FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unblock"
  ON blocked_users FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Reports: users can insert reports
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create reports"
  ON reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- Matching config: readable by all authenticated, writable by service_role only
ALTER TABLE matching_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Matching config is viewable by authenticated users"
  ON matching_config FOR SELECT TO authenticated
  USING (true);

-- Compatibility weights: readable by all authenticated, writable by service_role only
CREATE POLICY "Compatibility weights are viewable by authenticated users"
  ON compatibility_weights FOR SELECT TO authenticated
  USING (true);

-- Mood entries: own data only
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own mood entries"
  ON mood_entries FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own mood entries"
  ON mood_entries FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own mood entries"
  ON mood_entries FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);


-- ============================================================
-- SEED DATA: Default Compatibility Weights
-- ============================================================

-- ============================================================
-- SEED DATA
-- Aligned with the 4-block scoring algorithm:
--   Block 1: Love (love_language + attraction) = 35%
--   Block 2: Lifestyle (habits + hobbies) = 25%
--   Block 3: Values & Personality (MBTI, politics, religion, situation) = 25%
--   Block 4: Astrology = 15%
--   + Penalties (relationship type mismatch, deal breakers)
--   + Filters (gender/orientation, hard deal breakers)
-- ============================================================

-- Block-level weights (the 4 scoring blocks)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('_block', 'love',       0.350, 'Block 1: Love Language + Attraction tags'),
  ('_block', 'lifestyle',  0.250, 'Block 2: Lifestyle habits'),
  ('_block', 'values',     0.250, 'Block 3: Values & Personality'),
  ('_block', 'astrology',  0.150, 'Block 4: Astrology');

-- Block 1: Love (35% of total)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('love', 'love_language_match',  0.600, 'Love language compatibility (direct/complementary/opposite)'),
  ('love', 'attraction_overlap',   0.400, 'Shared attraction tags (tags_common / max_tags)');

-- Block 2: Lifestyle (25% of total)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('lifestyle', 'smoking_match',       0.150, 'Smoking habit alignment (gradual scale)'),
  ('lifestyle', 'drinking_match',      0.150, 'Drinking habit alignment (gradual scale)'),
  ('lifestyle', 'exercise_match',      0.200, 'Exercise habit + type bonus'),
  ('lifestyle', 'diet_match',          0.150, 'Diet preference alignment'),
  ('lifestyle', 'hobbies_overlap',     0.250, 'Shared hobbies (common / total_unique)'),
  ('lifestyle', 'availability_match',  0.100, 'Online schedule overlap');

-- Block 3: Values & Personality (25% of total)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('values', 'mbti_compatibility',       0.300, 'MBTI type pairing (complementary/equal/neutral/friction)'),
  ('values', 'politics_match',           0.250, 'Political alignment + cross-dating tolerance'),
  ('values', 'religion_match',           0.250, 'Religious alignment + tolerance'),
  ('values', 'situation_area_match',     0.200, 'Life situation + expertise area similarity');

-- Block 4: Astrology (15% of total)
-- Level 1: Sun sign only (always available)
-- Level 2: Full chart (when both users have birth_time + location)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('astrology', 'sun_sign_match',      0.250, 'Sun sign elemental compatibility (identity/ego)'),
  ('astrology', 'moon_sign_match',     0.250, 'Moon sign emotional compatibility (intimacy)'),
  ('astrology', 'venus_sign_match',    0.200, 'Venus sign love style (romance)'),
  ('astrology', 'mars_sign_match',     0.120, 'Mars sign attraction/drive'),
  ('astrology', 'rising_sign_match',   0.100, 'Rising sign first impression'),
  ('astrology', 'mercury_sign_match',  0.080, 'Mercury sign communication style');

-- Penalties (applied on top of score, not a block)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('_penalty', 'relationship_type_mismatch', 0.000, 'Penalty: -30 to -40 when relationship types conflict'),
  ('_penalty', 'deal_breaker_medium',        0.000, 'Penalty: -15 to -40 from AI-processed deal breaker near-misses'),
  ('_penalty', 'preference_mismatch',        0.000, 'Penalty: configurable, from AI-processed preference mismatches');

-- Filters (eliminate before scoring, not scored)
INSERT INTO compatibility_weights (category, field_name, weight, is_filter, description) VALUES
  ('_filter', 'gender_orientation',    0.000, true, 'FILTER: who_to_see must include other gender (bidirectional)'),
  ('_filter', 'deal_breaker_hard',     0.000, true, 'FILTER: AI deal breakers marked as eliminatory (configurable)');


-- ============================================================
-- SEED DATA: Matching Engine Config
-- ============================================================

INSERT INTO matching_config (key, value, description) VALUES
  -- Composite score weights
  ('composite_weights', '{
    "compatibility": 0.45,
    "distance": 0.20,
    "freshness": 0.10,
    "activity": 0.10,
    "exposure_balance": 0.05,
    "random": 0.10
  }', 'Weights for composite feed score calculation'),

  -- Slot distribution per batch of 20
  ('slot_distribution', '{
    "batch_size": 20,
    "slots": {
      "high_match":    {"min": 6, "max": 8, "min_score": 60, "max_distance": "user_setting"},
      "nearby":        {"min": 3, "max": 4, "min_score": 50, "max_distance_km": 5},
      "discovery":     {"min": 2, "max": 3, "min_score": 50, "max_distance_mult": 1.5},
      "rising_star":   {"min": 2, "max": 3, "min_score": 50, "max_distance": "user_setting", "max_days_old": 7},
      "second_chance": {"min": 1, "max": 2, "min_score": 60, "max_distance": "user_setting", "min_days_since_pass": 30},
      "unicorn":       {"min": 0, "max": 1, "min_score": 85, "max_distance": "unlimited"}
    }
  }', 'Feed slot allocation strategy. EVERY slot has min_score — no quality bypass.'),

  -- Recycling / pass cooldowns
  ('pass_cooldowns', '{
    "pass_1_cooldown_days": 30,
    "pass_2_cooldown_days": 90,
    "pass_3_permanent": true
  }', 'How long before a passed profile can reappear'),

  -- Freshness boost thresholds
  ('freshness_thresholds', '{
    "new_user_days": 3,
    "fresh_days": 14,
    "settling_days": 30
  }', 'Days thresholds for new user visibility boost'),

  -- Exposure balance limits
  ('exposure_limits', '{
    "under_exposed_max": 5,
    "normal_max": 20,
    "saturated_max": 50
  }', 'Daily impression count thresholds for exposure balancing'),

  -- Scarcity handling
  ('scarcity', '{
    "thinning_threshold": 10,
    "scarce_threshold": 3,
    "depleted_threshold": 0,
    "soft_expansion_multiplier": 1.5,
    "hard_expansion_multiplier": 2.0,
    "max_expansion_multiplier": 3.0,
    "expanded_min_compatibility": 50,
    "accelerated_cooldown_days": 14,
    "emergency_cooldown_days": 7
  }', 'How the system handles running out of profiles in a region');


-- ============================================================
-- ============================================================
-- SCHEMA v2.0 ADDITIONS
-- March 2026
-- ============================================================
-- Sections:
--   1. New ENUMs
--   2. ALTER TABLE (existing tables — new columns)
--   3. RLS fixes (bugs found in v1)
--   4. New tables: Couple Mode (10)
--   5. New tables: Notifications (3)
--   6. New tables: Ritual Library (2)
--   7. New table: feature_config
--   8. New indexes
--   9. RLS for new tables
--  10. Updated seed data (compatibility_weights v2.0)
--  11. feature_config seed data
--  12. pg_cron data retention jobs
-- ============================================================


-- ============================================================
-- 1. NEW ENUMS
-- ============================================================

CREATE TYPE attachment_style_type AS ENUM (
  'secure',
  'anxious',
  'avoidant',
  'fearful_avoidant'
);

CREATE TYPE emotional_readiness_type AS ENUM (
  'ready',
  'almost_ready',
  'taking_it_slow',
  'just_exploring'
);

CREATE TYPE communication_style_type AS ENUM (
  'direct',
  'indirect',
  'empathetic',
  'analytical'
);

-- Extended match status (was TEXT in original, now includes couple + blocked)
-- Note: if matches.status is already TEXT CHECK, just update the CHECK constraint.
-- If it was an ENUM, create and alter:
CREATE TYPE match_status_type AS ENUM (
  'active',
  'archived',
  'unmatched',
  'couple',
  'blocked'
);


-- ============================================================
-- 2. ALTER TABLE — existing tables, new columns
-- ============================================================

-- profiles: mode flags (replaces sole reliance on user_modes join)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_dating  BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_couple  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_wedding BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_life    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;   -- soft delete

-- user_personality: 3 new fields from Steps 10–12
ALTER TABLE user_personality
  ADD COLUMN IF NOT EXISTS attachment_style     attachment_style_type,
  ADD COLUMN IF NOT EXISTS emotional_readiness  emotional_readiness_type,
  ADD COLUMN IF NOT EXISTS communication_style  communication_style_type;

-- compatibility_scores: track which algorithm version generated the score
ALTER TABLE compatibility_scores
  ADD COLUMN IF NOT EXISTS scoring_version TEXT NOT NULL DEFAULT '1.0';

-- matches: extend status to include couple + blocked
-- If status is TEXT with CHECK constraint, update it:
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_status_check;
ALTER TABLE matches
  ADD CONSTRAINT matches_status_check
  CHECK (status IN ('active', 'archived', 'unmatched', 'couple', 'blocked'));

-- Add auto-archive metadata
ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;


-- ============================================================
-- 3. RLS FIXES (bugs from v1 identified in security audit)
-- ============================================================

-- BUG 1: profiles SELECT USING (true) — exposes all profiles to all authenticated users
-- Fix: restrict to own profile + mutual matches
DROP POLICY IF EXISTS "Profiles are viewable by all authenticated users" ON profiles;

CREATE POLICY "profiles_select_v2"
  ON profiles FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR id IN (
      SELECT CASE
        WHEN user_a = auth.uid() THEN user_b
        ELSE user_a
      END
      FROM matches
      WHERE (user_a = auth.uid() OR user_b = auth.uid())
        AND status IN ('active', 'couple')
    )
  );

-- BUG 2: user_photos INSERT from client — bypasses CSAM detection
-- Fix: remove client INSERT. All uploads go through Edge Function (upload-photo).
DROP POLICY IF EXISTS "Users can upload their own photos" ON user_photos;
DROP POLICY IF EXISTS "Photos are viewable by all authenticated users" ON user_photos;

-- Photos SELECT: same restriction as profiles (match participants only)
CREATE POLICY "photos_select_v2"
  ON user_photos FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR user_id IN (
      SELECT CASE
        WHEN user_a = auth.uid() THEN user_b
        ELSE user_a
      END
      FROM matches
      WHERE (user_a = auth.uid() OR user_b = auth.uid())
        AND status IN ('active', 'couple')
    )
  );
-- No INSERT from client. Edge Function uses service_role.

-- BUG 3: matches UPDATE unrestricted — user could change user_a/user_b
DROP POLICY IF EXISTS "Users can update their own matches" ON matches;

CREATE POLICY "matches_update_status_only"
  ON matches FOR UPDATE TO authenticated
  USING (user_a = auth.uid() OR user_b = auth.uid())
  WITH CHECK (
    -- Prevent changing who is in the match
    user_a = (SELECT user_a FROM matches m2 WHERE m2.id = matches.id)
    AND user_b = (SELECT user_b FROM matches m2 WHERE m2.id = matches.id)
  );

-- BUG 4: reports — no SELECT policy, reporter can't see own reports
CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());


-- ============================================================
-- 4. NEW TABLES: COUPLE MODE
-- ============================================================

CREATE TABLE couples (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_b_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  activated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  anniversary_date  DATE,
  relationship_name TEXT,
  status            TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'paused', 'ended')),
  ended_at          TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_a_id, user_b_id)
);

CREATE TABLE ritual_library (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  ritual_type TEXT NOT NULL CHECK (ritual_type IN ('daily', 'weekly', 'special')),
  category    TEXT NOT NULL CHECK (category IN (
                'connection', 'communication', 'adventure',
                'intimacy', 'growth', 'gratitude'
              )),
  tags        TEXT[],
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ritual_library_used (
  couple_id  UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  library_id UUID NOT NULL REFERENCES ritual_library(id) ON DELETE CASCADE,
  shown_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (couple_id, library_id)
);

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

CREATE TABLE couple_journal_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES profiles(id),
  title       TEXT,
  content     TEXT NOT NULL,
  is_shared   BOOLEAN NOT NULL DEFAULT false,
  mood        TEXT CHECK (mood IN ('joyful','grateful','conflicted','sad','hopeful','neutral')),
  tags        TEXT[],
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE couple_check_ins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id),
  check_in_date   DATE NOT NULL,
  frequency       TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly')),
  energy_level    SMALLINT CHECK (energy_level BETWEEN 1 AND 5),
  connection_feel SMALLINT CHECK (connection_feel BETWEEN 1 AND 5),
  stress_level    SMALLINT CHECK (stress_level BETWEEN 1 AND 5),
  highlight       TEXT,
  needs           TEXT,
  gratitude       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, user_id, check_in_date, frequency)
);

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
  progress       JSONB DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE couple_credits (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id        UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  user_id          UUID REFERENCES profiles(id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN (
                     'earned_ritual', 'earned_checkin', 'earned_challenge',
                     'earned_streak', 'earned_milestone',
                     'spent_ritual_extra', 'spent_insight', 'spent_custom',
                     'bonus_onboarding', 'admin_adjustment'
                   )),
  amount           SMALLINT NOT NULL,
  balance_after    INT NOT NULL,
  description      TEXT,
  reference_id     UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE couple_badges (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id  UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  badge_type TEXT NOT NULL,
  earned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, badge_type)
);

CREATE TABLE couple_insights (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id    UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  period_month DATE NOT NULL,
  title        TEXT NOT NULL,
  summary      TEXT NOT NULL,
  strengths    TEXT[],
  growth_areas TEXT[],
  suggestion   TEXT,
  data_points  JSONB,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  viewed_at    TIMESTAMPTZ,
  UNIQUE (couple_id, period_month)
);


-- ============================================================
-- 5. NEW TABLES: NOTIFICATIONS
-- ============================================================

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

CREATE TABLE notification_preferences (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  new_match         BOOLEAN NOT NULL DEFAULT true,
  new_message       BOOLEAN NOT NULL DEFAULT true,
  match_expiring    BOOLEAN NOT NULL DEFAULT true,
  ritual_reminder   BOOLEAN NOT NULL DEFAULT true,
  check_in_reminder BOOLEAN NOT NULL DEFAULT true,
  couple_badge      BOOLEAN NOT NULL DEFAULT true,
  couple_insight    BOOLEAN NOT NULL DEFAULT true,
  marketing         BOOLEAN NOT NULL DEFAULT false,
  quiet_hours_start TIME NOT NULL DEFAULT '22:00',
  quiet_hours_end   TIME NOT NULL DEFAULT '08:00',
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

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


-- ============================================================
-- 6. NEW TABLE: FEATURE CONFIG
-- ============================================================

CREATE TABLE feature_config (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key   TEXT NOT NULL UNIQUE,
  free_limit    INT,
  premium_limit INT,
  unit          TEXT,
  description   TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================
-- 7. NEW INDEXES
-- ============================================================

-- profiles v2.0
CREATE INDEX idx_profiles_mode_dating ON profiles(is_dating) WHERE is_dating = true;
CREATE INDEX idx_profiles_mode_couple ON profiles(is_couple) WHERE is_couple = true;
CREATE INDEX idx_profiles_deleted ON profiles(deleted_at) WHERE deleted_at IS NOT NULL;

-- personality new fields
CREATE INDEX idx_personality_attachment ON user_personality(attachment_style);

-- compatibility scores with version
CREATE INDEX idx_compat_scores_version ON compatibility_scores(scoring_version);

-- matches v2.0
CREATE INDEX idx_matches_couple ON matches(status) WHERE status = 'couple';
CREATE INDEX idx_matches_last_message ON matches(last_message_at DESC);

-- couples
CREATE INDEX idx_couples_user_a ON couples(user_a_id);
CREATE INDEX idx_couples_user_b ON couples(user_b_id);
CREATE INDEX idx_couples_status ON couples(status) WHERE status = 'active';

-- couple_rituals
CREATE INDEX idx_rituals_couple_scheduled ON couple_rituals(couple_id, scheduled_for);
CREATE INDEX idx_rituals_pending ON couple_rituals(couple_id, completed_at) WHERE completed_at IS NULL;

-- couple_journal_entries
CREATE INDEX idx_journal_couple ON couple_journal_entries(couple_id, created_at DESC);
CREATE INDEX idx_journal_author ON couple_journal_entries(author_id);

-- couple_check_ins
CREATE INDEX idx_checkins_couple_date ON couple_check_ins(couple_id, check_in_date DESC);

-- couple_credits
CREATE INDEX idx_credits_couple ON couple_credits(couple_id, created_at DESC);

-- couple_insights
CREATE INDEX idx_insights_couple ON couple_insights(couple_id, period_month DESC);

-- push_tokens
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id);

-- notification_log
CREATE INDEX idx_notif_log_user ON notification_log(user_id, sent_at DESC);
CREATE INDEX idx_notif_log_status ON notification_log(status) WHERE status = 'sent';


-- ============================================================
-- 8. RLS FOR NEW TABLES
-- ============================================================

-- couples
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
CREATE POLICY "couples_select" ON couples FOR SELECT TO authenticated
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

-- ritual_library (public read — curated content, no user data)
ALTER TABLE ritual_library ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ritual_library_select" ON ritual_library FOR SELECT TO authenticated
  USING (is_active = true);

-- ritual_library_used
ALTER TABLE ritual_library_used ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ritual_library_used_select" ON ritual_library_used FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_rituals
ALTER TABLE couple_rituals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "couple_rituals_select" ON couple_rituals FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "couple_rituals_update_complete" ON couple_rituals FOR UPDATE TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  )
  WITH CHECK (completed_by = auth.uid());

-- couple_journal_entries
ALTER TABLE couple_journal_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "journal_select" ON couple_journal_entries FOR SELECT TO authenticated
  USING (
    author_id = auth.uid()
    OR (
      is_shared = true
      AND couple_id IN (
        SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
      )
    )
  );
CREATE POLICY "journal_insert" ON couple_journal_entries FOR INSERT TO authenticated
  WITH CHECK (author_id = auth.uid());
CREATE POLICY "journal_update" ON couple_journal_entries FOR UPDATE TO authenticated
  USING (author_id = auth.uid());

-- couple_timeline_events
ALTER TABLE couple_timeline_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "timeline_select" ON couple_timeline_events FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "timeline_insert" ON couple_timeline_events FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_check_ins
ALTER TABLE couple_check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "checkins_select" ON couple_check_ins FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
CREATE POLICY "checkins_insert" ON couple_check_ins FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- couple_challenges
ALTER TABLE couple_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "challenges_select" ON couple_challenges FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_credits
ALTER TABLE couple_credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "credits_select" ON couple_credits FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_badges
ALTER TABLE couple_badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "badges_select" ON couple_badges FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- couple_insights
ALTER TABLE couple_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "insights_select" ON couple_insights FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );

-- push_tokens
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "push_tokens_select" ON push_tokens FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "push_tokens_insert" ON push_tokens FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "push_tokens_delete" ON push_tokens FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- notification_preferences
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notif_prefs_all" ON notification_preferences FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- notification_log (read own; Edge Function writes)
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notif_log_select" ON notification_log FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- feature_config (public read — no user data)
ALTER TABLE feature_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "feature_config_select" ON feature_config FOR SELECT TO authenticated
  USING (true);


-- ============================================================
-- 9. UPDATED SEED DATA: compatibility_weights v2.0
-- Block 3 weights changed:
--   OLD: MBTI 30%, Politics 25%, Religion 25%, Situation 20%
--   NEW: Attachment Style 25%, Politics 20%, Religion 20%, Situation 20%, MBTI 15%
-- Relationship type promoted from penalty to Phase 1 filter
-- ============================================================

-- Update Block 3 weights
UPDATE compatibility_weights SET
  weight = 0.150,
  description = 'MBTI type pairing (complementary/equal/neutral/friction) — reduced from 0.30 in v2.0'
WHERE category = 'values' AND field_name = 'mbti_compatibility';

UPDATE compatibility_weights SET
  weight = 0.200,
  description = 'Political alignment + cross-dating tolerance — reduced from 0.25 in v2.0'
WHERE category = 'values' AND field_name = 'politics_match';

UPDATE compatibility_weights SET
  weight = 0.200,
  description = 'Religious alignment + tolerance — reduced from 0.25 in v2.0'
WHERE category = 'values' AND field_name = 'religion_match';

-- Add Attachment Style (new sub-field in Block 3)
INSERT INTO compatibility_weights (category, field_name, weight, description) VALUES
  ('values', 'attachment_style_match', 0.250,
   'Attachment style compatibility matrix (secure/anxious/avoidant/fearful_avoidant) — new in v2.0');

-- Update relationship_type from penalty to filter
UPDATE compatibility_weights SET
  category = '_filter',
  is_filter = true,
  description = 'FILTER (v2.0): Incompatible relationship intentions are eliminated before scoring. Was a Phase 2 penalty in v1.'
WHERE category = '_penalty' AND field_name = 'relationship_type_mismatch';

-- Add scoring_version to seed context
INSERT INTO matching_config (key, value, description) VALUES
  ('scoring_version', '"2.0"',
   'Current algorithm version. Stored with each compatibility_scores row to allow selective invalidation.');


-- ============================================================
-- 10. FEATURE CONFIG SEED DATA
-- ============================================================

INSERT INTO feature_config (feature_key, free_limit, premium_limit, unit, description) VALUES
  ('dating_likes_per_day',        10,    NULL, 'per_day',   'Likes per day in Dating Mode'),
  ('dating_super_likes_per_day',   1,       5, 'per_day',   'Super likes per day in Dating Mode'),
  ('dating_rewinds_per_day',       1,    NULL, 'per_day',   'Undo last swipe (rewind)'),
  ('couple_rituals_ai_per_month',  4,    NULL, 'per_month', 'AI-generated rituals per month'),
  ('couple_insights_per_month',    1,       4, 'per_month', 'Monthly AI relationship insights'),
  ('couple_journal_private',       5,    NULL, 'count',     'Max private journal entries (free tier)'),
  ('couple_challenges_active',     1,       3, 'count',     'Max simultaneous active challenges'),
  ('chat_ice_breakers_per_match',  3,       9, 'count',     'Ice-breakers per match');


-- ============================================================
-- 11. pg_cron DATA RETENTION JOBS
-- (Requires pg_cron extension enabled in Supabase project)
-- ============================================================

-- Delete soft-deleted accounts after 30 days
SELECT cron.schedule(
  'delete-soft-deleted-accounts',
  '0 3 * * *',
  $$DELETE FROM profiles WHERE deleted_at IS NOT NULL AND deleted_at < now() - interval '30 days'$$
);

-- Delete messages from unmatched chats after 90 days
SELECT cron.schedule(
  'delete-old-unmatched-messages',
  '0 4 * * *',
  $$DELETE FROM messages
    WHERE match_id IN (SELECT id FROM matches WHERE status = 'unmatched')
    AND created_at < now() - interval '90 days'$$
);

-- Delete stale 3x-passed swipe records after 1 year
SELECT cron.schedule(
  'cleanup-old-swipes',
  '0 5 * * 0',
  $$DELETE FROM swipe_actions
    WHERE action = 'pass'
    AND pass_count >= 3
    AND created_at < now() - interval '365 days'$$
);

-- Purge notification log after 60 days
SELECT cron.schedule(
  'purge-notification-log',
  '0 6 * * *',
  $$DELETE FROM notification_log WHERE created_at < now() - interval '60 days'$$
);

-- Auto-archive stale matches (never messaged after 30 days)
SELECT cron.schedule(
  'auto-archive-never-messaged',
  '0 2 * * *',
  $$UPDATE matches
    SET status = 'archived'
    WHERE status = 'active'
    AND last_message_at IS NULL
    AND created_at < now() - interval '30 days'$$
);

-- Auto-archive inactive matches (no messages for 60 days)
SELECT cron.schedule(
  'auto-archive-inactive-matches',
  '30 2 * * *',
  $$UPDATE matches
    SET status = 'archived'
    WHERE status = 'active'
    AND last_message_at < now() - interval '60 days'$$
);

-- Purge ended couple data after 90 days
SELECT cron.schedule(
  'purge-ended-couples',
  '0 7 * * 0',
  $$DELETE FROM couples WHERE status = 'ended' AND ended_at < now() - interval '90 days'$$
);

-- ============================================================
-- END OF v2.0 ADDITIONS
-- ============================================================


-- ############################################################
-- ############################################################
--
-- v2.1 ADDITIONS — Product Logic Addendum (March 2026)
--
-- Source: Product Logic Addendum (Alix Liasse, March 2026)
-- Approved by: CEO (Dércio da Barca)
--
-- Changes:
--   1. New enums: journal_mood_type, milestone_type, paywall_trigger_type
--   2. ALTER couples: remove current_level, add streak pause/protection
--   3. ALTER couple_journal_entries: private-only, new mood, remove shared
--   4. ALTER couple_rituals: add 3-section format, weekly-only
--   5. New tables: couple_milestones, couple_progression,
--      paywall_events, journal_prompts
--   6. Updated RLS: journal author-only
--   7. Updated feature_config seed data
--   8. New indexes
--   9. New pg_cron jobs (streak, milestones)
--
-- ############################################################
-- ############################################################


-- ============================================================
-- 1. NEW ENUMS (v2.1)
-- ============================================================

-- Journal mood — 5 states, one tap
CREATE TYPE journal_mood_type AS ENUM (
  'exhausted',   -- 😴
  'tense',       -- 😤
  'ok',          -- 😐
  'good',        -- 🙂
  'great'        -- ✨
);

-- Couple milestone types
CREATE TYPE milestone_type AS ENUM (
  '4_weeks',
  '3_months',
  '6_months',
  '1_year'
);

-- Paywall trigger types (11 defined moments)
CREATE TYPE paywall_trigger_type AS ENUM (
  'journal_limit',
  'timeline_limit',
  'extra_ritual',
  'credits_low',
  'streak_protection',
  'challenge_unlock',
  'ai_journal_prompt',
  'streak_week_25',
  'milestone_3_months',
  'milestone_challenge',
  'partner_premium'
);


-- ============================================================
-- 2. ALTER TABLE — couples (v2.1)
-- Remove level system, add weekly streak with pause behavior
-- ============================================================

-- Level system removed — replaced by milestones (celebrations, not ratings)
-- Note: if column existed in Part B changes schema, drop it here
-- ALTER TABLE couples DROP COLUMN IF EXISTS current_level;

-- Add streak pause/protection fields
ALTER TABLE couples
  ADD COLUMN IF NOT EXISTS streak_paused_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS streak_protection_used TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS streak_recovered_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notification_day       SMALLINT DEFAULT 0
    CHECK (notification_day BETWEEN 0 AND 6);
    -- 0 = Sunday, 1 = Monday... Couple sets at onboarding.

-- current_streak semantics change:
--   BEFORE: counted consecutive DAYS of ritual completion
--   NOW: counts consecutive WEEKS with ritual completed by BOTH partners
-- The column type (SMALLINT/INT) remains the same. Logic changes in Edge Functions.


-- ============================================================
-- 3. ALTER TABLE — couple_journal_entries (v2.1)
-- Journal is ALWAYS private. Partner NEVER sees entries.
-- ============================================================

-- Remove sharing column — journal is individual only, no shared journal
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS is_shared;

-- Remove title — journal is mood + text, not a traditional diary
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS title;

-- Remove tags — not used in new model
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS tags;

-- Remove updated_at — entries are not editable
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS updated_at;

-- Replace old mood (joyful/grateful/conflicted/sad/hopeful/neutral)
-- with new 5-state mood (exhausted/tense/ok/good/great)
ALTER TABLE couple_journal_entries DROP COLUMN IF EXISTS mood;
ALTER TABLE couple_journal_entries
  ADD COLUMN mood journal_mood_type NOT NULL DEFAULT 'ok';

-- Rename content to free_text and make optional
-- (mood selector is required, text is optional)
ALTER TABLE couple_journal_entries RENAME COLUMN content TO free_text;
ALTER TABLE couple_journal_entries ALTER COLUMN free_text DROP NOT NULL;

-- Add prompt week (1-12) — which rotating prompt was shown
ALTER TABLE couple_journal_entries
  ADD COLUMN IF NOT EXISTS prompt_week SMALLINT
    CHECK (prompt_week BETWEEN 1 AND 12);

-- Add ISO week number — links journal entry to that week's ritual
ALTER TABLE couple_journal_entries
  ADD COLUMN IF NOT EXISTS week_number INT;


-- ============================================================
-- 4. ALTER TABLE — couple_rituals (v2.1)
-- Add 3-section format: Insight + Practice + Reflection Question
-- Weekly only (no daily rituals)
-- ============================================================

-- Add 3-section fields
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS insight             TEXT,
  ADD COLUMN IF NOT EXISTS practice            TEXT,
  ADD COLUMN IF NOT EXISTS reflection_question TEXT;

-- Add week number for journal linkage
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS week_number INT;

-- Add per-partner completion tracking (both must complete)
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS completed_a_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_b_at TIMESTAMPTZ;

-- Store partner moods at generation time (for audit/traceability)
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS journal_mood_a journal_mood_type,
  ADD COLUMN IF NOT EXISTS journal_mood_b journal_mood_type;

-- AI model/prompt version used for generation
ALTER TABLE couple_rituals
  ADD COLUMN IF NOT EXISTS ai_version TEXT;

-- One ritual per couple per week
-- (Use DO block to avoid error if constraint already exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_couple_ritual_week'
  ) THEN
    ALTER TABLE couple_rituals
      ADD CONSTRAINT unique_couple_ritual_week UNIQUE (couple_id, week_number);
  END IF;
END $$;

-- Update ritual_type to remove 'daily' — rituals are WEEKLY only now
ALTER TABLE couple_rituals DROP CONSTRAINT IF EXISTS couple_rituals_ritual_type_check;
ALTER TABLE couple_rituals
  ADD CONSTRAINT couple_rituals_ritual_type_check
  CHECK (ritual_type IN ('weekly', 'special'));


-- ============================================================
-- 5. NEW TABLES (v2.1)
-- ============================================================

-- ----- 5a. couple_milestones -----
-- Milestones are celebrations, NOT ratings. They never block features.
-- Triggered by consecutive weeks of ritual completion by both partners.
CREATE TABLE couple_milestones (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  milestone       milestone_type NOT NULL,
  weeks_required  SMALLINT NOT NULL,
  reached_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  celebrated_at   TIMESTAMPTZ,   -- when couple saw the celebration screen
  is_premium_only BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, milestone)
);

-- Milestone definitions:
-- 4_weeks:  4 consecutive weeks, both completed ritual.  Free + Premium.
--           "One month of showing up."
-- 3_months: 12 consecutive weeks.  Free + Premium.
--           AI-generated ritual reflecting the 12-week journey.
-- 6_months: 26 consecutive weeks.  Premium only.
--           Monthly retrospective — patterns, rituals, growth moments.
-- 1_year:   52 consecutive weeks.  Premium only.
--           Personalised anniversary ritual from full year of data.


-- ----- 5b. couple_progression -----
-- Weekly progression points. Points accumulate for milestones and analytics.
CREATE TABLE couple_progression (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id   UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  week_number INT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN (
    'ritual_completed_both',     -- 50 pts
    'ritual_completed_one',      -- 25 pts
    'reflection_answered_both',  -- 20 pts
    'journal_entry_a',           -- 20 pts
    'journal_entry_b',           -- 20 pts
    'challenge_completed'        -- 10 pts
  )),
  points      SMALLINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Point rules:
-- ritual_completed_both:     50 pts — BOTH partners must complete
-- ritual_completed_one:      25 pts — only ONE partner completed
-- reflection_answered_both:  20 pts — BOTH must respond to reflection question
-- journal_entry_a/b:         20 pts each — per partner per week (max 40/week)
-- challenge_completed:       10 pts — bonus, does not gate progression


-- ----- 5c. paywall_events -----
-- Tracks every paywall trigger shown to the user. For conversion analytics.
CREATE TABLE paywall_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  couple_id    UUID REFERENCES couples(id) ON DELETE SET NULL,
  trigger_type paywall_trigger_type NOT NULL,
  context      JSONB,         -- contextual data (e.g. streak_week, milestone)
  presented_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  converted_at TIMESTAMPTZ,   -- if user converted at this moment
  dismissed_at TIMESTAMPTZ    -- if user dismissed
);

-- The 11 paywall triggers:
--  1. journal_limit       — 30 entries reached
--  2. timeline_limit      — 10 events reached
--  3. extra_ritual        — requested extra ritual in same week
--  4. credits_low         — balance <= 2
--  5. streak_protection   — tried to protect streak (highest investment)
--  6. challenge_unlock    — premium-only challenge
--  7. ai_journal_prompt   — tapped AI-personalised prompt
--  8. streak_week_25      — celebration moment at 25 weeks
--  9. milestone_3_months  — 3-month milestone reached
-- 10. milestone_challenge — milestone challenge completed
-- 11. partner_premium     — partner already upgraded


-- ----- 5d. journal_prompts -----
-- Rotating prompt library (12 weeks). Weeks 1-6 neutral, 7/10/12 vulnerable.
CREATE TABLE journal_prompts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_number   SMALLINT NOT NULL UNIQUE CHECK (week_number BETWEEN 1 AND 12),
  prompt_text   TEXT NOT NULL,
  is_vulnerable BOOLEAN NOT NULL DEFAULT false,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed: 12 rotating prompts
INSERT INTO journal_prompts (week_number, prompt_text, is_vulnerable) VALUES
  (1,  'What has been taking up most of your headspace this week?', false),
  (2,  'How are you arriving to this ritual — present or distracted?', false),
  (3,  'Is there something you didn''t say but wanted to?', false),
  (4,  'What do you need most this week — space or closeness?', false),
  (5,  'How do you feel about the two of you right now?', false),
  (6,  'What gave you energy this week? What took it away?', false),
  (7,  'Is there something your partner doesn''t know you''re feeling?', true),
  (8,  'One word about your day?', false),
  (9,  'What do you want to bring to this ritual today?', false),
  (10, 'Is there anything you want AURO to know before we begin?', true),
  (11, 'How do you feel about the week ahead?', false),
  (12, 'Something small you''d like your partner to know?', true);

-- Prompt sequence rules:
--   Weeks 1-6: neutral prompts. User is building trust with the product.
--   Weeks 7, 10, 12 (is_vulnerable = true): more vulnerable. Only after consistency.
--   After week 12: sequence repeats. Library can be expanded over time.


-- ============================================================
-- 6. RLS FOR NEW TABLES + UPDATED POLICIES (v2.1)
-- ============================================================

-- ----- Journal: ALWAYS private (updated policy) -----
-- Remove old policy that allowed shared reading
DROP POLICY IF EXISTS "journal_select" ON couple_journal_entries;
DROP POLICY IF EXISTS "journal_insert" ON couple_journal_entries;
DROP POLICY IF EXISTS "journal_update" ON couple_journal_entries;

-- New: ONLY the author can read their own entries
-- Partner NEVER sees. AI extracts themes via Edge Function (service_role).
CREATE POLICY "journal_select_author_only"
  ON couple_journal_entries FOR SELECT TO authenticated
  USING (author_id = auth.uid());

-- INSERT: only own entries
CREATE POLICY "journal_insert_own"
  ON couple_journal_entries FOR INSERT TO authenticated
  WITH CHECK (author_id = auth.uid());

-- No UPDATE policy = blocked by RLS. Journal entries are not editable.
-- No DELETE policy = blocked by RLS. Only service_role can delete.

-- Privacy model:
--   User sees:     their own journal entries (history)
--   Partner sees:  NOTHING. Never. Not text, not mood, not even that entry exists.
--   AI sees:       text + mood from BOTH via service_role → extracts THEMES only
--   AURO team:     aggregated, anonymised data only. Never individual entries.


-- ----- couple_milestones -----
ALTER TABLE couple_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "milestones_select" ON couple_milestones
  FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
-- INSERT/UPDATE: service_role only (Edge Functions check milestones)

-- ----- couple_progression -----
ALTER TABLE couple_progression ENABLE ROW LEVEL SECURITY;
CREATE POLICY "progression_select" ON couple_progression
  FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT id FROM couples WHERE user_a_id = auth.uid() OR user_b_id = auth.uid()
    )
  );
-- INSERT: service_role only (Edge Functions track progression)

-- ----- paywall_events -----
ALTER TABLE paywall_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paywall_select_own" ON paywall_events
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "paywall_insert_own" ON paywall_events
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ----- journal_prompts (public read — curated content, no user data) -----
ALTER TABLE journal_prompts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "journal_prompts_select" ON journal_prompts
  FOR SELECT TO authenticated
  USING (is_active = true);


-- ============================================================
-- 7. UPDATED FEATURE_CONFIG SEED DATA (v2.1)
-- ============================================================

-- New entries for Product Logic Addendum
INSERT INTO feature_config (feature_key, free_limit, premium_limit, unit, description) VALUES
  -- Journal
  ('couple_journal_entries',     30,    NULL, 'count',     'Max journal entries (free tier). Unlimited for premium.'),
  ('couple_journal_ai_prompts',   0,    NULL, 'per_week',  'AI-personalised journal prompts. Free = standard rotating only.'),
  ('couple_journal_history',     30,    NULL, 'count',     'Visible journal history. Free = last 30. Premium = full + patterns.'),
  -- Timeline
  ('couple_timeline_events',     10,    NULL, 'count',     'Max timeline events (free tier). Unlimited for premium.'),
  -- Streak
  ('couple_streak_protection',    0,       1, 'per_month', 'Grace weeks per month. Free = 0. Premium = 1.'),
  ('couple_streak_recovery',      0,       1, 'count',     'Streak recovery within 48h. Free = no. Premium = yes.'),
  ('couple_streak_insights',      0,    NULL, 'boolean',   'Streak pattern insights. Premium only.'),
  -- Milestones
  ('couple_milestone_extended',   0,    NULL, 'boolean',   '6-month + 1-year milestones with AI retrospective. Premium only.'),
  -- Rituals
  ('couple_ritual_extra',         0,    NULL, 'per_week',  'Extra on-demand rituals beyond 1/week. Premium only.'),
  -- Insights
  ('couple_weekly_insight_full',  0,    NULL, 'boolean',   'Full weekly insight. Free = first sentence teaser only.')
ON CONFLICT (feature_key) DO NOTHING;

-- Update existing entries that changed
UPDATE feature_config
SET free_limit = 30,
    unit = 'count',
    description = 'Max private journal entries (free tier) — updated from 5 to 30 per addendum'
WHERE feature_key = 'couple_journal_private';


-- ============================================================
-- 8. NEW INDEXES (v2.1)
-- ============================================================

-- couple_milestones
CREATE INDEX idx_milestones_couple ON couple_milestones(couple_id);

-- couple_progression
CREATE INDEX idx_progression_couple_week ON couple_progression(couple_id, week_number);

-- couple_journal_entries — updated for new model
DROP INDEX IF EXISTS idx_journal_shared;  -- is_shared column no longer exists
CREATE INDEX IF NOT EXISTS idx_journal_couple_week
  ON couple_journal_entries(couple_id, week_number);

-- couple_rituals — by week_number
CREATE INDEX IF NOT EXISTS idx_rituals_couple_week_v2
  ON couple_rituals(couple_id, week_number);

-- paywall_events — for conversion analytics
CREATE INDEX idx_paywall_user ON paywall_events(user_id, presented_at DESC);
CREATE INDEX idx_paywall_trigger ON paywall_events(trigger_type);
CREATE INDEX idx_paywall_conversion
  ON paywall_events(trigger_type, converted_at)
  WHERE converted_at IS NOT NULL;


-- ============================================================
-- 9. NEW pg_cron JOBS (v2.1)
-- ============================================================

-- Process weekly streak (Sunday 23:59 UTC)
-- Checks if each active couple completed ritual that week
SELECT cron.schedule(
  'process-weekly-streak',
  '59 23 * * 0',
  $$
  -- Couples who completed ritual this week: increment streak
  UPDATE couples SET
    current_streak = current_streak + 1,
    streak_paused_at = NULL
  WHERE status = 'active'
  AND id IN (
    SELECT couple_id FROM couple_rituals
    WHERE week_number = (EXTRACT(ISOYEAR FROM now())::int * 100
                        + EXTRACT(WEEK FROM now())::int)
    AND completed_a_at IS NOT NULL
    AND completed_b_at IS NOT NULL
  );
  -- Note: couples who did NOT complete are handled by a separate
  -- Edge Function that checks streak_protection eligibility.
  -- The streak PAUSES — it never resets to zero.
  $$
);

-- Check milestones after streak update (Monday 00:05 UTC)
SELECT cron.schedule(
  'check-milestones',
  '5 0 * * 1',
  $$
  -- 4 weeks
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '4_weeks', 4, false FROM couples
  WHERE status = 'active' AND current_streak >= 4
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '4_weeks')
  ON CONFLICT DO NOTHING;

  -- 3 months (12 weeks)
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '3_months', 12, false FROM couples
  WHERE status = 'active' AND current_streak >= 12
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '3_months')
  ON CONFLICT DO NOTHING;

  -- 6 months (26 weeks) — premium only
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '6_months', 26, true FROM couples
  WHERE status = 'active' AND current_streak >= 26
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '6_months')
  ON CONFLICT DO NOTHING;

  -- 1 year (52 weeks) — premium only
  INSERT INTO couple_milestones (couple_id, milestone, weeks_required, is_premium_only)
  SELECT id, '1_year', 52, true FROM couples
  WHERE status = 'active' AND current_streak >= 52
  AND id NOT IN (SELECT couple_id FROM couple_milestones WHERE milestone = '1_year')
  ON CONFLICT DO NOTHING;
  $$
);


-- ============================================================
-- END OF v2.1 ADDITIONS — Product Logic Addendum
-- ============================================================

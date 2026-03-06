-- ============================================================
-- AURO - Supabase SQL Schema
-- Module: Onboarding & Profile + Compatibility + Matching + Chat
-- Version: 4.0
-- Last updated: 2026-03-01
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

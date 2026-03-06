# Chat System Architecture

> Status: **Work in progress** — core structure defined.

## Overview

Chat is unlocked when two users match (mutual like). The system supports text messages, media, voice notes, ice-breaker prompts, and real-time presence. Built on **Supabase Realtime** for instant delivery.

---

## Chat Flow

```
MATCH CREATED
    |
    v
CHAT ROOM CREATED (linked to match)
    |
    v
ICE-BREAKER PROMPTS shown (first time only)
    |
    v
MESSAGES (text, media, voice)
    |
    v
ONGOING CONVERSATION
```

---

## Chat Features

### 1. Ice-Breakers (First Message)

When a chat opens for the first time, the user sees **3 AI-generated conversation starters** based on shared profile data:

```json
{
  "ice_breakers": [
    {
      "emoji": "heart",
      "title": "Shared love language",
      "prompt": "You both value Quality Time — what's your ideal weekend plan?"
    },
    {
      "emoji": "star",
      "title": "Astrology connection",
      "prompt": "Two earth signs! Do you feel grounded in relationships?"
    },
    {
      "emoji": "music",
      "title": "Common hobby",
      "prompt": "You're both into music — what's the last concert you went to?"
    }
  ]
}
```

**Generation:**
- AI generates prompts when match is created (async, cached)
- Based on: compatibility explanation + shared traits + high-scoring blocks
- User can tap a prompt to auto-fill the message input, or type freely
- Ice-breakers only show on first visit to the chat

### 2. Message Types

| Type | Description | Storage |
|------|-------------|---------|
| `text` | Regular text message | `content` field |
| `image` | Photo (from gallery or camera) | Supabase Storage → URL in `media_url` |
| `voice` | Voice note | Supabase Storage → URL in `media_url` |
| `gif` | GIF from picker | External URL in `media_url` |
| `ice_breaker` | Auto-generated prompt | `content` + `metadata.ice_breaker_id` |
| `system` | System message (match created, etc.) | `content` + `type = system` |

### 3. Real-Time Features

Built on **Supabase Realtime** (PostgreSQL LISTEN/NOTIFY):

| Feature | Implementation |
|---------|---------------|
| **Message delivery** | INSERT on `messages` → Realtime broadcast to channel |
| **Typing indicator** | Supabase Realtime Presence (ephemeral, not stored) |
| **Online status** | Realtime Presence channel per user |
| **Read receipts** | UPDATE `read_at` on messages → Realtime broadcast |

### 4. Online Status

```
online     → Green dot, "Online"
recent     → "Active X minutes ago" (< 30 min)
away       → No indicator (> 30 min)
```

Status is derived from Realtime Presence — not stored in DB. When a user connects to any Realtime channel, they're "online".

### 5. Message Status

```
sent       → Message saved to DB
delivered  → Recipient's device received via Realtime (future)
read       → Recipient opened the chat (read_at set)
```

---

## Chat List Screen

The "Your matches" screen shows:

```json
{
  "recent_matches": [
    {"user_id": "...", "avatar": "...", "name": "Ariana", "matched_at": "..."}
  ],
  "conversations": [
    {
      "match_id": "...",
      "other_user": {"name": "Ariana", "avatar": "...", "is_online": true},
      "compatibility_score": 87,
      "last_message": {"content": "Nice to meet you, darling", "sent_at": "7:09 pm", "is_mine": false},
      "unread_count": 1
    }
  ]
}
```

### Sorting:
1. Unread messages first (most recent unread on top)
2. Then by last message timestamp (most recent first)
3. New matches with no messages appear in "Recent match" horizontal strip

### Search:
- Search by user name within matches
- Filters conversations list in real-time

---

## Chat Room Features

### Header:
- Other user's avatar + name
- Online status indicator (green dot)
- Video call button (future)
- Voice call button (future)
- Menu (report, block, unmatch, mute)

### Message Input:
- Text input field
- Attachment button (photo, gallery)
- Reply button (reply to specific message — future)
- Voice note button (hold to record)
- Send button

### Message Display:
- Bubbles: mine (right, colored) vs theirs (left, gray)
- Timestamp per message
- Read receipt indicator (checkmarks)
- Date separators ("Today", "Yesterday", date)
- Scroll to bottom on new message

---

## Moderation & Safety

### Block User
```
→ Removes match
→ Deletes chat history for blocker
→ Blocked user's messages show as "deleted"
→ Neither appears in each other's feed again
→ No notification to blocked user
```

### Report User
```
→ Creates report record with reason + optional evidence
→ Chat preserved for admin review
→ Reported user not notified
→ Admin can: warn, suspend, ban
```

### Unmatch
```
→ Match status → 'unmatched'
→ Chat becomes read-only for both
→ Both users removed from each other's chat list
→ Profile re-enters feed pool (after cooldown)
```

---

## Data Tables (Summary)

| Table | Purpose |
|-------|---------|
| `messages` | All chat messages with type, content, media, timestamps |
| `matches` (from matching) | Links two users, tracks match lifecycle |
| `chat_ice_breakers` | AI-generated conversation starters per match |
| `reports` | User reports for moderation |
| `blocked_users` | Block relationships between users |

> SQL definitions: see [schema.sql](schema.sql)

---

## Performance & Scaling Notes

- Messages use **Supabase Realtime channels** — one channel per match (`match:{match_id}`)
- Media uploaded to **Supabase Storage** with signed URLs (expiring)
- Message history paginated (50 messages per load, infinite scroll up)
- Ice-breakers generated async when match is created, stored in `chat_ice_breakers`
- Online status via Realtime Presence (no DB writes for status updates)
- Unread count maintained via DB trigger or computed at query time

---

## Open Questions

- [ ] Video/voice calls: integrate or defer to v2?
- [ ] Message reactions (emoji responses): v1 or v2?
- [ ] Reply to specific message: v1 or v2?
- [ ] Media size limits and compression strategy
- [ ] Message retention policy (keep forever or auto-delete after unmatch?)
- [ ] Should ice-breakers refresh if neither user messages within 48h?
- [ ] Push notification strategy for messages (every message vs batched)

---

*This document evolves as the project grows. Last updated: 2026-03-01*

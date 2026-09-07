# Ardent Community — Backend API Reference

A complete endpoint reference for frontend developers integrating with the Ardent Community
backend. Generated from the current state of the codebase (routes + controllers) — every endpoint
listed here actually exists in `src/routes/*.routes.js` / `src/controllers/*.controller.js`.

## Base URL

```
http://localhost:4000/api   (development default; PORT is configurable)
```

All routes below are relative to this base (e.g. `/auth/login` = `POST {baseUrl}/auth/login`).

## Response envelope

Every response uses one consistent shape:

```json
// success
{ "success": true, "data": <payload> }

// error
{ "success": false, "error": { "message": "...", "details": {...} } }
```

`details` is only present for some validation errors. In development, 5xx errors also include an
`error.stack` field (omitted in production).

## Authentication

- **Scheme:** `Authorization: Bearer <JWT>`
- **Obtaining a token:** `POST /auth/login`, `POST /auth/register`, `POST /auth/reset-password`, or
  completing SSO (`GET /auth/sso/login` → Authentik → redirected back to the frontend with
  `?accessToken=<JWT>`).
- **Token contents:** user id (`sub`) and slug only — no roles/permissions are embedded; the server
  always re-reads the current user record, so a deactivated account's token stops working immediately.
- **Auth levels used throughout this doc:**
  - **None** — public, no token needed.
  - **Optional** — works without a token; if a valid token *is* sent, the response is personalized
    (e.g. `savedByMe`, `myRsvp`, viewer-specific flags).
  - **Required** — returns `401 Unauthorized` without a valid token.
  - **Required + `module:<key>`** — requires a valid token AND the named feature-module permission
    (see [Permissions / modules](#permissions--modules) below). Returns `403 Forbidden` if the
    module isn't granted.

## Permissions / modules

Every account has an `accessRole` (`admin`, `hr`, `executive`, `employee`) which grants a default set
of feature modules; an admin may override an individual user's module list. Endpoints marked
`module:<key>` require that key in the caller's effective module list.

| Module key | Grants |
| --- | --- |
| `feed.view` | View the social feed |
| `feed.post` | Post to the shared feed |
| `stories.view` | View My-Day stories |
| `stories.post` | Post a My-Day story |
| `marketplace.view` | Browse the marketplace |
| `marketplace.sell` | Create marketplace listings |
| `people.view` | Browse the people directory |
| `groups.view` | Use groups / direct messages |
| `events.view` | Browse events |
| `events.create` | Create events |
| `saved.view` | View saved items |
| `ashtrid.use` | Use the Ashtrid AI assistant |
| `calls.use` | Make/receive voice & video calls (1:1 and group). **Feature-flagged off by default** — stripped from every user, even admins, unless `CALLS_ENABLED=true` and LiveKit is fully configured server-side; see [Voice Calls](#voice-calls) |
| `appraisal.view` | View own appraisals / rate where assigned |
| `appraisal.manage` | Run the appraisal programme (HR/admin) |
| `ethics.report` | Report an ethics concern (everyone) |
| `ethics.manage` | Review ethics complaints (HR/admin) |
| `bookings.view` | View vans & rooms / schedule |
| `bookings.book` | Book a van or room |
| `bookings.manage` | Manage the fleet/room list (HR/admin) |
| `admin.users` | System Settings — manage users, roles, categories, and view the audit/error log |

Default role → module mapping and full details: `src/config/modules.js`.

## Common error responses

| Status | Meaning |
| --- | --- |
| 400 | Bad request — missing/invalid fields (message explains which) |
| 401 | Missing, invalid, or expired token |
| 403 | Authenticated but not permitted (missing module, not the resource owner, recused, etc.) |
| 404 | Resource not found |
| 409 | Conflict — e.g. duplicate email/unique constraint |
| 429 | Too many attempts — rate limited (see below) |
| 500 | Unexpected server error |

## Security headers & rate limiting

- **Helmet** is applied to every response (`src/app.js`). Content-Security-Policy is deliberately
  disabled (this API serves JSON/file streams, not HTML — CSP belongs on the frontend), and
  `Cross-Origin-Resource-Policy` is set to `cross-origin` so media can be embedded from the frontend's
  own origin.
- **Credential endpoints are rate limited** (`src/middleware/rateLimit.middleware.js`), 15-minute
  sliding window, successful requests don't count against the quota (except where noted):

  | Endpoint | Limit | Keyed by |
  | --- | --- | --- |
  | `POST /auth/login` | 20 failed attempts / 15 min | Per IP |
  | `POST /auth/login` | 8 failed attempts / 15 min | Per account (email) |
  | `POST /auth/register` | 10 attempts / 15 min | Per IP |
  | `POST /auth/forgot-password` | 5 attempts / 15 min (successes count too) | Per account (email) |
  | `POST /auth/reset-password` | 20 attempts / 15 min | Per IP |

  A blocked request gets `429` with `{ "success": false, "error": { "message": "Too many attempts. Please wait a few minutes and try again." } }`.

## File uploads

Uploads use `multipart/form-data` and are handled in-memory (Multer) then pushed to MinIO; the API
never touches local disk. Limits and accepted types by preset (`src/middleware/upload.middleware.js`):

| Preset | Field name(s) | Accepted types | Max size | Used by |
| --- | --- | --- | --- | --- |
| `imageUpload(field)` | variable (`avatar`, `cover`, `photo`, `cover`) | JPEG, PNG, WEBP, GIF | 10 MB | avatars, covers, listing/event/group/booking-resource photos |
| `postUpload` | `media[]` (up to 10 images), `files[]` (up to 10 documents) — plus legacy singular `photo` (1) / `file` (1), still accepted | images + documents (PDF/Office/text/zip) | 10 MB | post composer |
| `storyUpload` | `media` (up to 10) | images + video (MP4/WEBM/MOV/OGG) | 100 MB | My-Day stories |
| `listingUpload` | `media` (up to 10) | images + video | 100 MB | marketplace listings |
| `chatUpload` | `file` (1) | images + documents | 10 MB | group chat attachment |
| `appraisalUpload` | `file` (1) | images + documents | 10 MB | appraisal evidence (private) |
| `ethicsUpload` | `file` (1) | images + documents | 10 MB | ethics evidence (private) |
| `certificateUpload` | `file` (1) | images + PDF | 10 MB | profile certificates |

All returned media URLs point back at this API (`/api/media/<folder>/<key>`), never at the storage
backend directly. **Exceptions:** appraisal evidence and ethics evidence are never exposed as public
URLs — they're only readable via their own authenticated `GET .../attachments/:attachmentId` stream
route.

## Real-time (Socket.IO)

Connect with a JWT to receive live "who's online" presence and group chat events:

```js
import { io } from 'socket.io-client';
const socket = io('http://localhost:4000', { auth: { token } });

socket.on('presence:snapshot', ({ online }) => {});   // ids online right now
socket.on('presence:update',   ({ online }) => {});   // ids changed
```

Presence is also available over REST: `GET /presence` and the `onlineUsers` count in `GET /health`.
Every `user` object returned by the API carries a live `online` boolean.

Group chat (`src/realtime/groupChat.js`) shares the same authenticated connection and is scoped to
group membership — see the Groups section below for its REST counterpart.

1:1 voice calling (`src/realtime/call.js`) also shares this connection — see
[Voice Calls](#voice-calls) below for the full socket event contract.

---

## Table of contents

1. [Health & Presence](#health--presence)
2. [Auth](#auth)
3. [SSO](#sso)
4. [Users / People](#users--people)
5. [Posts / Feed](#posts--feed)
6. [Marketplace (Listings)](#marketplace-listings)
7. [Media](#media)
8. [Events](#events)
9. [Stories (My-Day)](#stories-my-day)
10. [Groups](#groups)
11. [Voice Calls](#voice-calls)
12. [Categories](#categories)
13. [Celebrations](#celebrations)
14. [Notifications](#notifications)
15. [Search](#search)
16. [Bookings](#bookings)
17. [Booking Admin](#booking-admin)
18. [Ethics](#ethics)
19. [Ethics Admin](#ethics-admin)
20. [Appraisals](#appraisals)
21. [Appraisal Admin](#appraisal-admin)
22. [Ashtrid (AI Assistant)](#ashtrid-ai-assistant)
23. [Admin](#admin)
24. [System Log (Audit & Errors)](#system-log-audit--errors)
25. [Background Jobs](#background-jobs)

---

## Health & Presence

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/health` | None | Liveness + DB connectivity + current online-user count |
| GET | `/presence` | None | `{ online: [userId, ...] }` — ids currently connected via WebSocket |

---

## Auth

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| POST | `/auth/login` | None (rate limited) | `{ email, password }` | Password login. Returns `{ token, user }`. 401 on bad credentials, 403 if deactivated, 429 if rate limited |
| POST | `/auth/register` | None (rate limited) | `{ name, email, password, role?, department? }` (password ≥ 6 chars) | Self-registration. Returns `{ token, user }`, 201. 409 if email exists |
| GET | `/auth/me` | Required | — | Current user profile (`present.user` shape) |
| POST | `/auth/change-password` | Required | `{ currentPassword?, newPassword }` (newPassword ≥ 6 chars) | Change own password; emails a "password changed" notice |
| POST | `/auth/forgot-password` | None (rate limited) | `{ email }` | Always responds the same way regardless of whether the account exists (anti-enumeration). Emails a reset link if the account exists and is active |
| GET | `/auth/reset-token` | None | Query: `?token=` | Validates a reset/invite token before showing the reset form. Returns `{ valid, reason? }` or `{ valid: true, purpose, name, email }` |
| POST | `/auth/reset-password` | None (rate limited) | `{ token, password }` (password ≥ 8 chars) | Consumes a single-use reset/invite token, sets the new password, and signs the user in — returns `{ token, user }` |

**Notes:**
- Passwords are bcrypt-hashed (never stored/returned in plaintext).
- Reset/invite tokens are single-use and time-limited (`RESET_TOKEN_TTL_MINUTES` / `INVITE_TOKEN_TTL_HOURS`).
- `forgot-password` never reveals whether an email is registered.
- `login`, `register`, `forgot-password`, and `reset-password` are all rate limited — see
  [Security headers & rate limiting](#security-headers--rate-limiting) above for exact thresholds.

---

## SSO

Enterprise single sign-on via Authentik (OIDC + PKCE). Entirely optional — password login above
always works independently. An account must already exist locally; SSO never auto-creates one.

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/auth/sso/status` | None | `{ enabled, reason, issuer, redirectUri }` — lets the frontend show/hide the SSO button |
| GET | `/auth/sso/login` | None | Browser-navigation only. 302-redirects to Authentik to begin the flow. 503 if SSO isn't configured |
| GET | `<OIDC_REDIRECT_URI path>` (NOT under `/api`) | None | Authentik's callback. Exchanges the code, matches the verified email to an existing local account, mints a normal JWT, and 302-redirects the browser to `{FRONTEND_APP_URL}/sso/callback?accessToken=<token>` (or `...?ssoError=<message>` on failure) |

**Failure modes surfaced via `ssoError` query param (never a raw 500 for user-facing failures):** no
local account for that email, account deactivated, SSO identity mismatch with a previously-linked
account, expired/invalid SSO transaction, provider-reported error.

---

## Users / People

Base path: `/users`. `:id` in these routes accepts either a user's `slug` or UUID.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/users` | Optional | Query: `?search=` (matches name/role/department) | Directory listing |
| GET | `/users/:id` | Optional | — | One user's public profile |
| GET | `/users/:id/posts` | Optional | — | Posts authored by that user |
| GET | `/users/:id/certificates` | Optional | — | That user's profile certificates |
| PATCH | `/users/me` | Required | JSON: any of `name, role, department, bio, phone, location, manager, color, initials, avatarPosition, coverPosition, isPrivate, showEmail, emailNotifs, pushNotifs, notifyComments, notifyKudos` | Update own profile/privacy fields |
| GET | `/users/me/hr` | Required | — | Own HR-linked details: `{ employeeId, dateHired, birthMonth, birthDay, linked }` (degrades to nulls if HR system unreachable; never returns birth year) |
| POST | `/users/me/avatar` | Required | multipart: `avatar` (image, `imageUpload`) | Upload/replace avatar; deletes the old file |
| POST | `/users/me/cover` | Required | multipart: `cover` (image, `imageUpload`) | Upload/replace cover photo |
| GET | `/users/me/certificates` | Required | — | List own certificates |
| POST | `/users/me/certificates` | Required | multipart: `file` (image/PDF, `certificateUpload`) + `title` (required), `issuer?`, `issuedOn?` | Add a certificate. 201 |
| PATCH | `/users/me/certificates/:certificateId` | Required | JSON: `title?, issuer?, issuedOn?` | Update own certificate (403 if not the owner) |
| DELETE | `/users/me/certificates/:certificateId` | Required | — | Delete own certificate + its file |

**Notes:** `role`/`department`/`manager` on the public profile are free-text display fields — the
real reporting line (`supervisorId`) and system link (`employeeId`) are admin-only and never editable
via `PATCH /users/me`.

---

## Posts / Feed

Base path: `/posts`.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/posts` | Optional | Query: `?type=&limit=(≤100,default 20)&offset=&before=` | Company feed, pinned first then newest. `before` (an ISO `createdAt` from the oldest unpinned post already held) is the cursor for scrolling further back, as an alternative to `offset` |
| GET | `/posts/:id` | Optional | — | One post, with its full comment list attached (comments include reaction counts/your own reaction) |
| GET | `/posts/:id/comments` | Optional | — | Comments for a post. A group post's comments require membership (404 if you're not a member — same as the post itself) |
| POST | `/posts` | Required + `module:feed.post` | multipart (`postUpload`): `media[]` (up to 10 images, new — replaces the old singular `photo`), `files[]` (up to 10 documents, new — replaces the old singular `file`); `photo`/`file` (singular, still accepted for older clients) + JSON fields: `type` (`text\|photo\|file\|poll\|kudos\|announcement\|share`), `text?, title?, note?, signoff?, lines?, details?, pinned?, kudosTo?` (slug/id/name), `groupId?` (post into a group's own feed instead of the company feed), `pollOptions?` (≥2, distinct), `pollMultiple?`, `sharedPostId?`, `mentions?` (array of user ids, or JSON string when sent via multipart) | Create a post. 201. Notifies kudos recipient + mentioned users (+ the group, if `groupId` set) |
| PATCH | `/posts/:id` | Required | JSON: any post field | Edit — owner or `admin.users` only. Setting `pinned` requires `admin.users` even for the post's own owner (403 otherwise) — pinning puts a post at the top of everyone's feed, so it's treated as an administrative action |
| DELETE | `/posts/:id` | Required | — | Delete — owner or `admin.users` only |
| POST | `/posts/:id/comments` | Required | `{ text (required), parentId?, mentions? }` | Add a comment/reply. On a group post, only group members may be mentioned (others are silently dropped). Notifies post owner (+ parent comment author on a reply, + mentioned users) |
| PATCH | `/posts/:id/comments/:commentId` | Required | `{ text (required), mentions? }` | Edit your own comment (author only, 403 otherwise). Stamps `editedAt`; only newly-added mentions are notified |
| DELETE | `/posts/:id/comments/:commentId` | Required | — | Delete a comment — author, the post's owner, or `admin.users`. Tombstoned (blanked, kept in place) if it has replies; hard-deleted otherwise. Returns `{ outcome: 'tombstoned'\|'removed', commentId, post }` (the whole post, so the client can update its comment count in one step) |
| PUT | `/posts/:id/comments/:commentId/reaction` | Required | `{ type: like\|celebrate\|support\|insightful }` | Set/replace your reaction to a comment |
| DELETE | `/posts/:id/comments/:commentId/reaction` | Required | — | Remove your reaction to a comment |
| GET | `/posts/:id/comments/:commentId/reactions` | Required | — | `{ commentId, total, people: [{...author, reaction}] }` — who reacted to a comment |
| PUT | `/posts/:id/reaction` | Required | `{ type: like\|celebrate\|support\|insightful }` | Set/replace your reaction |
| DELETE | `/posts/:id/reaction` | Required | — | Remove your reaction |
| GET | `/posts/:id/reactions` | Required | — | `{ total, byType: {like: [...], celebrate: [...]}, people: [{...author, reaction}] }` — who reacted to the post, grouped and flat |
| PUT | `/posts/:id/save` | Required | — | Save the post |
| DELETE | `/posts/:id/save` | Required | — | Unsave |
| POST | `/posts/:id/share` | Required | — | Share the post (creates a `share`-type record) |
| GET | `/posts/:id/sharers` | Required | — | `{ total, unattributed, people: [{...author, sharedAt}] }` — who shared the post (deduped per user; `unattributed` counts legacy share rows with no user recorded) |
| GET | `/posts/:id/poll/voters` | Required | — | `{ [optionId]: [author, ...] }` — who voted for each option |
| POST | `/posts/:id/vote` | Required | `{ optionId (required) }` | Vote (or add a choice, if `pollMultiple`) |
| DELETE | `/posts/:id/vote` | Required | — | Withdraw your vote(s) |

**Post type payload notes:**
- `announcement`: use `title, lines, details, note, signoff`.
- `kudos`: set `kudosTo` (accepts slug, id, or display name).
- `poll`: `pollOptions` must have ≥2 distinct (case/whitespace-insensitive) options.
- **Group posts:** setting `groupId` posts into that group's own feed instead of the company feed —
  requires active (non-pending, non-blocked) membership in the group. Every interaction endpoint
  above (comment, react, save, share, vote, and the "who reacted/shared" lists) enforces the same
  membership check on a group post — holding the post id is not enough. A group post is fetched via
  `GET /groups/:id/posts` (see [Groups](#groups)), not through the company `GET /posts` feed.
- **Attachments:** a post with multiple photos/files returns `media: [{id, url}]` and/or
  `files: [{id, fileName, fileSize, fileUrl}]` arrays; the older single-attachment `photoUrl`/`fileUrl`
  fields are still emitted for posts created before multi-attachment support, so the client can fall
  back to either shape (a post never has both).
- **Comments:** a comment now carries `deleted`, `editedAt`, `reaction` (your own), `reactionCount`,
  and `reactionCounts` (`{like: 2, celebrate: 1}`). A tombstoned (deleted-with-replies) comment has
  `deleted: true`, empty `text`, and `author: null`, but keeps its place in the thread.

---

## Marketplace (Listings)

Base path: `/listings`.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/listings` | Optional | Query: `?category=&search=` | Browse listings |
| GET | `/listings/:id` | Optional | — | One listing |
| POST | `/listings` | Required + `module:marketplace.sell` | multipart (`listingUpload`): `media[]` (up to 10, image/video) + JSON: `title` (required), `price` or `priceCents`, `category?, description?, sold?` | Create a listing. 201 |
| PATCH | `/listings/:id` | Required | multipart: `media[]` to add + JSON: `title?, category?, description?, sold?, price\|priceCents?, removeMediaIds?` (array or JSON string) | Edit — owner only |
| DELETE | `/listings/:id` | Required | — | Delete — owner only; cleans up stored media |
| PATCH | `/listings/:id/sold` | Required | `{ sold? }` (defaults `true`) | Mark sold/unsold — owner only |
| PUT | `/listings/:id/like` | Required | — | Like |
| DELETE | `/listings/:id/like` | Required | — | Unlike |
| PUT | `/listings/:id/save` | Required | — | Save |
| DELETE | `/listings/:id/save` | Required | — | Unsave |

`price` is accepted in whole currency units and converted to `priceCents` server-side; either field
works.

---

## Media

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/media/:folder/:key` | None (by necessity — `<img>` tags can't send headers) | Streams an uploaded file. `folder` is allow-listed to public buckets only — appraisal/ethics evidence is excluded here and served only via its own authenticated route. 404 for an unknown folder/key or a traversal attempt |

Response headers set correctly per file: `Content-Type`, `Content-Disposition` (inline for images/
video/audio/text/PDF, attachment otherwise), long-lived `Cache-Control` (object keys never change),
and `X-Content-Type-Options: nosniff`.

**Range requests & caching (new):** the route now supports HTTP range requests and conditional
caching, which matters for video/audio scrubbing and for repeat page loads:
- `ETag` and `Last-Modified` are set from storage metadata; a request carrying a matching
  `If-None-Match` or `If-Modified-Since` gets a bodyless `304 Not Modified`.
- `Accept-Ranges: bytes` is advertised; a `Range: bytes=start-end` request (including the
  `bytes=-N` "last N bytes" form) returns `206 Partial Content` with `Content-Range` and
  `Content-Length` set to the requested slice — this is what lets a video/audio player seek without
  redownloading the whole file.
- An unsatisfiable range returns `416 Range Not Satisfiable` with `Content-Range: bytes */<size>`.

---

## Events

Base path: `/events`.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/events` | Optional | — | List all events (viewer's RSVP attached if logged in) |
| GET | `/events/:id` | Optional | — | Get one event (404 if not found) |
| POST | `/events` | Required + `module:events.create` | multipart: `cover?` (image); JSON: `title` (required), `description?, location?, startsAt`/`startAt`/`date` (required, parseable date), `endsAt?` (must be ≥ start), `featured?` | Create an event |
| PATCH | `/events/:id` | Required | multipart: `cover?`; JSON: `title?, description?, location?, startsAt`/`date?, endsAt?, featured?` | Update — creator or `admin.users` only |
| DELETE | `/events/:id` | Required | — | Delete — creator or `admin.users` only |
| GET | `/events/:id/attendees` | Required | — | List "going" and "interested" users |
| PUT | `/events/:id/rsvp` | Required | `{ status: 'going' \| 'interested' }` (defaults `going`) | Set/replace your RSVP (400 on invalid status) |
| DELETE | `/events/:id/rsvp` | Required | — | Clear your RSVP |

**Notes:** `featured` is silently forced to `false` on create/update unless the caller has `admin.users`.

---

## Stories (My-Day)

Base path: `/stories`.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/stories` | Optional | `?limit=` (default 7, capped at 30) | List recent stories, newest first |
| POST | `/stories` | Required + `module:stories.post` | multipart (`storyUpload`): `media` (1–10 files, image/video, required); JSON: `caption?`, `newMediaCaptions?` (JSON array parallel to `media`) | Create a story |
| PATCH | `/stories/:id` | Required | multipart: `media?` (add more); JSON: `caption?, removeMediaIds?` (array/JSON/single value), `newMediaCaptions?`, `mediaCaptions?` (`{mediaId: caption}` for kept items) | Edit — owner or `admin.users` only; must retain ≥1 media item after edit (400 otherwise); removed media is deleted from storage |
| DELETE | `/stories/:id` | Required | — | Delete a story and all its media — owner or `admin.users` only |
| POST | `/stories/:id/media/:mediaId/view` | Required | — | Record that you saw this item. Idempotent (re-watching doesn't move the original timestamp); no-op on your own story (`{ counted: false, reason: 'own' }`) |
| POST | `/stories/:id/media/:mediaId/react` | Required | `{ emoji }` — one of 👍 ❤️ 😆 😮 😢 🙏 | Set/change your reaction to one item; sending the same emoji again clears it. Reacting also counts as a view |
| GET | `/stories/:id/media/:mediaId/viewers` | Required | — | Who watched this item and what they reacted with — **author-only** (403 for anyone else) |

**Response notes:** every returned story includes `media[].myReaction` (your own reaction, if any) and,
only when you are the author, `media[].viewCount`. `story.isMine` tells the client whether the viewer
is the author (and therefore whether `viewCount`/the viewers endpoint are usable).

---

## Groups

Base path: `/groups`. All routes require `module:groups.view`.

| Method | Path | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/groups` | — | List groups visible to the viewer | — |
| GET | `/groups/direct` | — | List the caller's direct-message threads | — |
| POST | `/groups/direct` | `{ userId }` (required) | Open or find an existing 1:1 DM thread | Can't DM yourself; target must exist |
| GET | `/groups/unread` | — | Unread totals across every conversation the caller belongs to, in one call | Returns `{ conversations: [{groupId, isDirect, count, lastMessageAt}], counts: {[groupId]: count}, total }`; call on load and on socket reconnect so the badge survives a refresh |
| GET | `/groups/:id` | — | Get one group/thread | 404 if not found |
| POST | `/groups` | multipart: `photo?`; JSON: `name` (required), `description?`, `color?` (default `var(--navy-700)`), `adminIds?` (array/JSON, co-admins) | Create a group | Creator is auto-added as first admin |
| PATCH | `/groups/:id` | multipart: `photo?`; JSON: `name?, description?, color?` | Rename/re-describe/re-photo | Not allowed on direct threads; requires group-admin or site-admin |
| DELETE | `/groups/:id` | — | Delete a group | Not allowed on direct threads; requires group-admin or site-admin |
| PUT | `/groups/:id/join` | — | Request to join a closed group | Blocked users get 403; already-member returns status `member` |
| DELETE | `/groups/:id/join` | — | Leave a group | Blocked if caller is the group's only admin |
| DELETE | `/groups/:id/request` | — | Cancel a pending join request | 400 if none pending |
| GET | `/groups/:id/members` | — | List members | Requires active membership (or site admin) |
| POST | `/groups/:id/members` | `{ userId, isGroupAdmin? }` | Admin adds a member directly | Requires group-admin/site-admin; notifies the added member |
| PATCH | `/groups/:id/members/:userId` | `{ isGroupAdmin }` | Promote/demote a member | Requires group-admin/site-admin; can't demote the last admin |
| DELETE | `/groups/:id/members/:userId` | — | Remove a member | Requires group-admin/site-admin; can't remove the last admin |
| GET | `/groups/:id/requests` | — | List pending join requests | Requires group-admin/site-admin |
| POST | `/groups/:id/requests/:userId/approve` | — | Approve a join request | 404 if none pending; notifies new member |
| POST | `/groups/:id/requests/:userId/reject` | — | Reject a join request | 404 if none pending |
| GET | `/groups/:id/blocked` | — | List blocked users | Requires group-admin/site-admin |
| POST | `/groups/:id/members/:userId/block` | — | Block a member | Can't block self or the last admin |
| DELETE | `/groups/:id/blocked/:userId` | — | Unblock a user | Requires group-admin/site-admin |
| GET | `/groups/:id/shared` | — | Files/media/links shared in chat, with counts | Requires active membership |
| GET | `/groups/:id/messages` | `?limit=`, `?before=` (cursor) | List chat messages | Requires active membership |
| POST | `/groups/:id/messages` | multipart (`chatUpload`): `file?` (single attachment); JSON: `text?` (required if no attachment), `mentions?` (JSON array of user ids), `replyToId?` | Send a chat message | Requires active membership; mentions filtered to actual group members; broadcasts over websocket |
| DELETE | `/groups/:id/messages/:messageId` | — | Soft-delete a message | Author may delete their own; deleting others' requires group-admin/site-admin |
| POST | `/groups/:id/messages/:messageId/react` | `{ emoji }` (required, ≤8 chars) | Toggle an emoji reaction | Broadcasts over websocket |
| POST | `/groups/:id/read` | — | Mark this conversation read up to now (call when the user opens/focuses it) | Returns `{ groupId, count: 0, lastReadAt }`; 403 if not a member; broadcasts a `read` event over the socket so open "Seen" markers update live |
| GET | `/groups/:id/receipts` | — | How far each other member has read — the "Seen" markers under sent messages | Returns `{ groupId, receipts: [{...author, lastReadAt}] }`; requires active membership |
| GET | `/groups/:id/posts` | `?limit=(≤100,default 20)&before=` (cursor) | The group's own post feed (separate from its chat) | Requires active membership; pinned-first ordering only applies on the first page (no `before`) |
| POST | `/groups/:id/mute` | `{ muted: true\|false }` | Mute/unmute this group's **post** notifications, for yourself only | Returns `{ groupId, muted }`; 403 if not a member |

**Notes:** Sending a message now also pushes a direct socket event to each member's own connection
(`realtime.notifyIncoming`), not just to the chat room — so it reaches someone who doesn't currently
have that conversation open. Sending a message also marks it read for the sender (you don't badge
your own conversation). A `group` object now also carries `muted` (whether the current viewer has
muted its post notifications).

---

## Voice Calls

Voice/video calling, covering both 1:1 and group calls. Requires `module:calls.use` — **but that key
is stripped from every user, admins included, unless the server has `CALLS_ENABLED=true` AND a fully
configured LiveKit media server (`LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`)**. Ask a
backend dev whether calling is actually live in your environment before wiring up the UI — if it
isn't, `calls.use` simply won't appear in anyone's `modules` list and the routes/socket events below
still exist but nobody can reach them.

**Architecture changed in this update** — media now runs through **LiveKit**, an SFU (selective
forwarding unit), instead of peer-to-peer WebRTC. This replaced the ICE-server endpoint and the
`call:offer`/`call:answer`/`call:ice` relay events entirely (removed, not deprecated — a client built
against the old contract will not work). The socket's job is now only *ringing* — who's being called,
accepted, declined, missed — while joining the actual audio/video room is a signed token handed to
LiveKit directly. This is also what makes **group calls** possible, which 1:1 peer-to-peer never
supported.

```
Ringing / accept / decline / hang up  →  Socket.IO (src/realtime/call.js)
Actually joining the room (media)     →  LiveKit, via a token from POST /calls/:id/token
Room lifecycle (who joined/left,
the room emptying out)                →  LiveKit webhooks → POST /calls/webhook
```

### REST

Base path: `/calls`.

| Method | Path | Auth | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- | --- |
| POST | `/calls/webhook` | None (LiveKit signature) | Raw LiveKit webhook body | LiveKit telling the API what happened in a room (`participant_joined`, `participant_left`, `room_finished`) | Mounted **before** the auth middleware — LiveKit has no user session, so its HMAC signature (verified against the raw request bytes) is the only authentication. `room_finished` is how a group call ever actually ends, since nobody "hangs up" a room — the last person just leaves |
| POST | `/calls/:id/token` | Required + `module:calls.use` | — | A short-lived token letting this browser join the call's LiveKit room | Eligibility re-checked every time (direct call: caller or callee; group call: active group membership — 404, not 403, for a non-member so they can't even learn the call exists); 400 if the call has already ended. Returns `{ token, url, room }` where `url` is the LiveKit server URL and `room` is the derived room name. Also records a `CallParticipant` row (`outcome: 'invited'`) — the webhook later confirms whether they actually joined |
| GET | `/calls` | Required + `module:calls.use` | `?before=` (ISO `startedAt` cursor), `?limit=` (default 30, max 100), `?userId=` (**admin only**) | Your call history — direct calls you were on, and group calls you were a participant in, newest first | Everyone but an admin only ever sees calls they were actually on, regardless of what `userId` is passed |

**Call history row shape — direct call:**

```json
{
  "id": "...", "kind": "direct",
  "direction": "outgoing" | "incoming",
  "hasVideo": false,
  "peer": { "id": "...", "slug": "...", "name": "...", "avatarUrl": "...", "online": true },
  "status": "ended" | "declined" | "missed" | "busy" | "failed",
  "endReason": "hangup" | "declined" | "timeout" | "disconnected" | "failed",
  "startedAt": "...", "answeredAt": "...", "endedAt": "...", "durationSec": 42
}
```

**Call history row shape — group call:**

```json
{
  "id": "...", "kind": "group",
  "direction": "outgoing" | "incoming",
  "group": { "id": "...", "slug": "...", "name": "..." },
  "groupName": "...",
  "participantCount": 4,
  "participants": [{ "id": "...", "name": "...", "outcome": "joined" | "invited" | "declined" | "left" }],
  "status": "ended" | "failed",
  "endReason": "hangup" | "disconnected" | "failed",
  "hasVideo": false,
  "startedAt": "...", "answeredAt": "...", "endedAt": "...", "durationSec": 42
}
```

`peer` on a direct call names the *other* party regardless of which side you were on. If that account
has since been deleted, it falls back to `{ id: null, name: "<snapshotted name>" }`. A group call has
no single "other person" — it's described by the group and its roster instead.

### Socket.IO events

All events are on the same authenticated connection used for presence/chat. Client → server events
take an acknowledgement callback `(response) => {}` where `response` is `{ ok: true, ... }` or
`{ ok: false, error: '<code>' }`.

**Direct (1:1) calls:**

| Direction | Event | Payload | Notes |
| --- | --- | --- | --- |
| Client → server | `call:invite` | `{ calleeId }` | Ack: `{ ok, callId, status: 'ringing'\|'missed' }` or `{ ok: false, error }` — `not_allowed`, `invalid_callee`, `no_such_user`, `busy`, `failed`. If the callee isn't online at all, the call is recorded as missed immediately instead of ringing into nothing |
| Server → callee | `call:incoming` | `{ callId, caller: {id, name, slug} }` | Pushed to every tab the callee has open |
| Client → server | `call:accept` | `{ callId }` | Callee only. Ack `{ ok: false, error: 'too_late' }` if another of the callee's own tabs already answered. **After accepting, call `POST /calls/:id/token` to actually join the room** — accepting no longer triggers a WebRTC offer |
| Server → caller | `call:accepted` | `{ callId }` | Tells the caller the callee is joining — the caller should now also request a token and join |
| Server → callee's other tabs | `call:taken` | `{ callId }` | Tells the callee's other open tabs to stop ringing (excludes the tab that just acted) |
| Client → server | `call:decline` | `{ callId }` | Callee only |
| Client → server | `call:end` | `{ callId }` | Either party; hangs up an active or ringing call |
| Server → both parties | `call:ended` | `{ callId, status, endReason, durationSec }` | Sent exactly once per call, however it ended (decline/hangup/timeout/disconnect/failure/LiveKit `room_finished`) |

**Group calls** (a room tied to a group; there is no single callee — declining dismisses only your
own ring, and the room stays open for whoever's left; nothing "misses" a group call the way a 1:1
ring can):

| Direction | Event | Payload | Notes |
| --- | --- | --- | --- |
| Client → server | `call:group-start` | `{ groupId }` | Requires active group membership. Starts a new group call, **or** if one is already running for that group, rejoins it and re-rings the group (calling "again" is still "call these people", not silently joining a room nobody else was told about). Ack `{ ok, callId, joined: bool, invited? }` or `{ ok: false, error }` — `not_allowed`, `invalid_group`, `not_a_member`, `busy`, `failed`. No ring timeout — a group call is never "missed" |
| Server → each invited member | `call:incoming` | `{ callId, kind: 'group', group: {id, name}, caller: {id, name, slug} }` | Sent to every active, non-muted member except the one who started it — muting a group (`POST /groups/:id/mute`) silences its calls too |
| Client → server | `call:group-join` | `{ groupId }` | Join a group call already in progress without having been freshly invited. Ack `{ ok, callId }` or `{ ok: false, error: 'not_a_member'\|'no_call'\|'failed' }` |
| Client → server | `call:decline` | `{ callId }` | On a group call, dismisses **only your own** invitation (`CallParticipant.outcome = 'declined'`) — does not end the call for anyone else |
| Client → server | `call:end` | `{ callId }` | On a group call, this means "I'm leaving" (`outcome: 'left'`), not "hang up for everyone" — the room only actually closes when LiveKit reports it empty via the webhook |

**Call lifecycle / statuses:** `ringing → answered → ended` (normal direct call), or `ringing →
declined` / `ringing → missed` / `ringing → busy` / `→ failed`. A direct call's ring that isn't
answered within `CALL_RING_TIMEOUT_MS` (default 35s) is recorded as missed and the callee gets a
"missed call" notification — **group calls have no ring timeout**, since going unanswered isn't a
failure state for a room. Only one active call (direct or group) is allowed per person at a time;
for a group call, "active" specifically means still holding an un-left participant row, so someone
who joined and later left is free to be called again. A server restart force-closes any call left
mid-flight. A background job, `call-reconcile` (every 5 minutes, only runs when LiveKit is
configured — see [Background Jobs](#background-jobs)), is the safety net for group calls
specifically: since nothing else ever closes an abandoned group room, this job asks LiveKit which
rooms are actually still live and closes any of ours (past a 2-minute grace period) that aren't.

---

## Categories

Base path: `/categories`. Marketplace category management.

| Method | Path | Auth | Body / Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/categories` | Optional | `?all=1` (only honored for `admin.users` holders) | List categories — active only by default; `?all=1` + admin includes inactive |
| POST | `/categories` | Required + `module:admin.users` | `{ name }` (required) | Create a category (rejects duplicate name) |
| PATCH | `/categories/:id` | Required + `module:admin.users` | `{ name?, isActive?, position? }` | Update (rejects duplicate name; 404 if missing) |
| DELETE | `/categories/:id` | Required + `module:admin.users` | — | Delete a category |

---

## Celebrations

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/celebrations` | Required | This month's birthdays/work anniversaries (Asia/Manila) for linked, active accounts |

Sourced from the external HR system, joined via `employeeId`. Degrades gracefully to an empty list
with a `warnings` message if the HR lookup fails or is unconfigured (never a 500). No birth year is
ever returned, only day-of-month.

---

## Notifications

Base path: `/notifications`. Always scoped to `req.user.id` — a user only ever sees/marks their own.

| Method | Path | Auth | Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/notifications` | Required | `?limit=` (default 20), `?before=` (cursor) | List notifications + current unread count |
| GET | `/notifications/unread-count` | Required | — | Unread count only |
| POST | `/notifications/:id/read` | Required | — | Mark one notification read (404 if not found) |
| POST | `/notifications/read-all` | Required | — | Mark all read |

---

## Search

| Method | Path | Auth | Query | Description |
| --- | --- | --- | --- | --- |
| GET | `/search` | Optional | `?q=` | Cross-entity search across people, posts, and listings |

An empty `q` returns empty result sets rather than erroring. `viewerId` (if logged in) is passed
through so post/listing results carry per-viewer flags.

---

## Bookings

Base path: `/bookings` (van/meeting-room self-service). All routes require `module:bookings.view`;
writes additionally require `module:bookings.book`.

| Method | Path | Query / Body | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/bookings/meta` | — | Resource type labels/icons + `maxDurationDays` (30) for the form | — |
| GET | `/bookings/resources` | `?type=` (`van`\|`room`) | List active bookable resources | — |
| GET | `/bookings/availability` | `?type=, ?from=` (ISO, required), `?to=` (ISO, required) | Resources + bookings touching the window (powers the day view) | 400 if invalid or `to <= from` |
| GET | `/bookings/mine` | `?scope=` (`upcoming`\|`past`\|`all`, default `upcoming`) | The caller's own bookings | — |
| POST | `/bookings` | `resourceId` (required), `purpose` (required), `startsAt`/`endsAt` (required, ≤30-day window, not in the past unless caller has `bookings.manage`), `occupants?` (array of `{userId, name, note}`, defaults to booker), `notes?`; van-only: `destination?, pickupPoint?, driverName?, driverUserId?` | Create a booking | Row-locks the resource to prevent double-booking; rejects an inactive resource, a clashing `booked` row, or occupant count over capacity; auto-generates a reference (e.g. `VAN-2026-0007`); sends a confirmation notification |
| GET | `/bookings/:id` | — | Get one booking | Readable by the booker, any occupant, or a `bookings.manage` holder — else 403 |
| PATCH | `/bookings/:id` | Any of `resourceId, startsAt, endsAt, purpose, notes, occupants`, van fields | Update/move a booking | Only owner or manager; re-checks window/clash/capacity if time/resource changed; notifies on time moves and occupant changes; can't edit a cancelled booking |
| POST | `/bookings/:id/cancel` | `{ reason? }` | Cancel a booking | Only owner or manager; already-cancelled is rejected; sends a cancellation notification |

---

## Booking Admin

Base path: `/booking-admin`. All routes require `module:bookings.manage`.

| Method | Path | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/booking-admin/resources` | `?type=` | List all resources, including inactive | — |
| POST | `/booking-admin/resources` | multipart: `photo?`; JSON: `type` (`van`\|`room`, default `van`), `name` (required), `code?, description?, capacity?` (int ≥1, blank = unlimited), `location?`; van-only `plateNumber?`; room-only `facilities?` (comma-separated → array) | Create a bookable resource | Rejects duplicate name within the same type |
| PATCH | `/booking-admin/resources/:id` | Same fields as create, plus `isActive?` | Update a resource | Replacing `photo` deletes the old stored file |
| GET | `/booking-admin/resources/:id/impact` | — | Preview how many/which future bookings a deactivation would affect | Shown before confirming deactivation |
| POST | `/booking-admin/resources/:id/deactivate` | — | Take a resource out of service | Existing bookings are kept, not cancelled; occupants notified |
| DELETE | `/booking-admin/resources/:id` | — | Permanently delete a resource | 409 if it has booking history — deactivate instead |
| GET | `/booking-admin/bookings` | `?type=, ?resourceId=, ?status=` (`booked`\|`cancelled`), `?from=, ?to=` | Full booking log with filters | — |
| GET | `/booking-admin/stats` | — | Utilization (count + hours) per resource, last 30 days | — |
| POST | `/booking-admin/bookings/:id/cancel` | `{ reason? }` | Admin-cancel any booking | Manager override of the user-side cancel |

---

## Ethics

Base path: `/ethics` (reporter side). All routes require `module:ethics.report`. Per-case access is
additionally enforced record-by-record (`services/ethicsAccess.js`).

| Method | Path | Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/ethics/categories` | — | List complaint categories (`harassment, discrimination, retaliation, fraud, safety, conflict_of_interest, policy_violation, other`) | — |
| GET | `/ethics/mine` | — | The caller's own filed complaints | — |
| POST | `/ethics/complaints` | `title` (required), `description` (required), `isAnonymous?`, `subjectUserId?` (can't be self), `subjectFreeText?`, `category?` (default `other`), `incidentDate?`, `location?` | File a new complaint | Starts in `submitted` status; auto-generates a case code; notifies reviewers |
| GET | `/ethics/complaints/:id` | — | View one case, shaped for the viewer | Access re-checked per record |
| POST | `/ethics/complaints/:id/messages` | `{ body }` (message text) | Post a message on the case thread | Reporter must still have access (e.g. not withdrawn) |
| POST | `/ethics/complaints/:id/withdraw` | `{ reason? }` | Withdraw the complaint | Sets status `withdrawn`; HR retains the case; reviewers notified |
| POST | `/ethics/complaints/:id/read` | — | Mark the case thread read | — |
| GET | `/ethics/complaints/:id/attachments` | — | List evidence attachments | — |
| POST | `/ethics/complaints/:id/attachments` | multipart (`ethicsUpload`): `file` (required); `fileName?` (rename override) | Upload evidence | — |
| GET | `/ethics/complaints/:id/attachments/:attachmentId` | — | Stream one evidence file | Access re-checked every read; never a public URL; `Cache-Control: private, no-store` |

---

## Ethics Admin

Base path: `/ethics-admin` (HR/reviewer side). All routes require `module:ethics.manage`. A reviewer
who is the subject of, or filed, a case is **recused per record** — a recused case returns 404, not
403 (indistinguishable from not existing).

| Method | Path | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/ethics-admin/cases` | `?status=, ?category=, ?assignee=` | List cases visible to this reviewer | — |
| GET | `/ethics-admin/stats` | — | Case counts/stats for this reviewer | — |
| GET | `/ethics-admin/cases/:id` | — | View one case | Recusal → 404 |
| GET | `/ethics-admin/cases/:id/events` | — | Full audit-event history | — |
| GET | `/ethics-admin/cases/:id/reviewers` | — | Who this case can be assigned to (subject & reporter excluded) | — |
| POST | `/ethics-admin/cases/:id/acknowledge` | — | Transition: HR acknowledges the case | Logs status change; notifies |
| POST | `/ethics-admin/cases/:id/start-investigation` | — | Transition: begin investigation | Notifies |
| POST | `/ethics-admin/cases/:id/request-info` | `{ body }` | Transition: request more info from reporter | Posts a message on the thread |
| POST | `/ethics-admin/cases/:id/resume` | — | Transition: resume after info request | Notifies |
| POST | `/ethics-admin/cases/:id/resolve` | `{ outcome, note? }` (outcome must be a valid enum) | Transition: resolve the case | Validates `outcome`; notifies |
| POST | `/ethics-admin/cases/:id/dismiss` | `{ note? }` | Transition: dismiss the case | Notifies |
| POST | `/ethics-admin/cases/:id/reopen` | — | Transition: reopen a closed case | Notifies |
| POST | `/ethics-admin/cases/:id/assign` | `{ assigneeId }` | Reassign the case | — |
| POST | `/ethics-admin/cases/:id/messages` | `{ body, isInternal? }` | Post a message/internal note | `isInternal: true` notes are HR-only — the reporter is never notified |
| POST | `/ethics-admin/cases/:id/read` | — | Mark thread read for this reviewer | — |
| GET | `/ethics-admin/cases/:id/attachments` | — | List evidence attachments | — |
| POST | `/ethics-admin/cases/:id/attachments` | multipart (`ethicsUpload`): `file` (required); `fileName?`, `isInternal?` (`"true"`) | Upload HR-side evidence | Can be flagged internal-only |
| GET | `/ethics-admin/cases/:id/attachments/:attachmentId` | — | Stream one evidence file | Access re-checked every read; never a public URL |

---

## Appraisals

Base path: `/appraisals` (employee/rater side). All routes require `module:appraisal.view`.
Per-appraisal visibility is further gated record-by-record (`services/appraisalAccess.js`).

| Method | Path | Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/appraisals/mine` | — | Own appraisals ("mine") + appraisals where caller is a rater ("toRate") | Final score shown only on the caller's own card, and only once released |
| GET | `/appraisals/:id` | — | Get one appraisal, shaped for the viewer | Access-checked |
| GET | `/appraisals/:id/form` | — | The template form + the viewer's saved answers | HR/admin see everything; once `released`, everyone with a rater role on it (not just the subject) sees everything; otherwise each viewer sees only questions their own rater role answers. Includes any per-employee custom items (see below), merged into their section |
| POST | `/appraisals/:id/items` | `{ label (required), sectionId (required), helpText? }` | Add a KPI/KRA row for this specific employee (e.g. PARS forms that ship with blank indicator tables) | Only the appraisal's supervisor or `appraisal.manage`; the target section must belong to this form and have `allowsCustomItems`; 400 if the appraisal is already `released`/`acknowledged`/`closed`. Returns 201 with the created item |
| DELETE | `/appraisals/:id/items/:itemId` | — | Remove a custom KPI/KRA row | Same permission as adding; also deletes any responses already recorded against it and recomputes the score |
| PATCH | `/appraisals/:id/responses` | `{ role, responses: [{itemId?, customItemId?, numericValue, optionId, textValue, comment, isNa}] }` | Autosave answers (bulk upsert) | Only items belonging to this form and this rater's role are accepted (custom items included); first save flips status to `in_progress`. Each response references exactly one of `itemId` (template item) or `customItemId` (per-employee row) |
| POST | `/appraisals/:id/submit` | `{ role, overallComment? }` | Submit/lock this rater's responses | Requires an active rater row matching the role; runs required-field validation |
| GET | `/appraisals/:id/result` | — | View the final score/result | 403 until the cycle has released results |
| POST | `/appraisals/:id/acknowledge` | `{ comment? }` | Employee acknowledges their released result | — |
| GET | `/appraisals/:id/attachments` | — | List evidence attachments | — |
| POST | `/appraisals/:id/attachments` | multipart (`appraisalUpload`): `file` (required) | Attach supporting evidence | Only an active rater on this appraisal, or `appraisal.manage`, may attach |
| GET | `/appraisals/:id/attachments/:attachmentId` | — | Stream one evidence file | Access re-checked every read; never a public URL |

**Response notes:** an appraisal now carries `scoreScale: {min, max}` (defaults `{0, 100}` for
templates predating this) and `displayScore` — the final score converted into that scale's own units
(e.g. PARS forms report 1.00–4.00, not a 0–100 percentage) — alongside the existing `computedScore`/
`finalScore`. `customItems` on the appraisal lists any per-employee KPI/KRA rows added via the
endpoints above.

---

## Appraisal Admin

Base path: `/appraisal-admin` (HR/admin side). All routes require `module:appraisal.manage`.

**Rating scales**

| Method | Path | Body | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/appraisal-admin/scales` | — | List rating scales + options | — |
| POST / PUT | `/appraisal-admin/scales` / `/scales/:id` | `name` (required if new), `description?, allowNa?, isActive?, options?` (`{label, description, value, sortOrder, isNa}[]`) | Create/update a scale | If `options` sent: needs ≥2 non-N/A options, all finite numeric values, no duplicates; options replaced wholesale |

**Templates & versions**

| Method | Path | Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/appraisal-admin/templates` | — | List templates with their versions | — |
| POST | `/appraisal-admin/templates` | `name` (required), `description?` | Create a template + its first draft version (v1) | — |
| GET | `/appraisal-admin/versions/:versionId` | — | Get one version (sections/items/bands) | — |
| POST | `/appraisal-admin/versions/:versionId/structure/preview` | Proposed sections/items | Dry-run impact report | No writes performed |
| PUT | `/appraisal-admin/versions/:versionId/structure` | `sections` (nested items, each optionally `allowsCustomItems`/`objective`/`defaultScaleId`), `bands`, `scoreScaleMin?/scoreScaleMax?`, `force?` | Bulk-save the section/item tree | A breaking edit to a published version with real saved answers is refused (400) unless `force: true`; orphaned answers are archived, not lost; logs a change-log entry. A section marked `allowsCustomItems` may ship with no template items — per-employee rows are added later via `POST /appraisals/:id/items` |
| GET | `/appraisal-admin/versions/:versionId/validate` | — | Check if version is ready to publish | Returns `{ ready, errors }` |
| POST | `/appraisal-admin/versions/:versionId/publish` | — | Publish a version | Rejected if already published or validation fails |
| POST | `/appraisal-admin/versions/:versionId/clone` | — | Clone a version into a new draft | — |
| GET | `/appraisal-admin/versions/:versionId/changes` | — | Change-log history (last 200) | — |

**Competency library**

| Method | Path | Body | Description |
| --- | --- | --- | --- |
| GET | `/appraisal-admin/item-library` | — | List active library items |
| POST | `/appraisal-admin/item-library` | `code` (required), `label` (required), `helpText?, category?, defaultScaleId?` | Upsert a reusable library item |

**Cycles**

| Method | Path | Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/appraisal-admin/cycles` | — | List appraisal cycles | — |
| POST / PUT | `/appraisal-admin/cycles` / `/cycles/:id` | `name, versionId` (must be published, required on create), `periodStart/periodEnd`, `selfOpensAt/selfClosesAt`, `supervisorOpensAt/supervisorClosesAt`, `hrClosesAt, releaseAt`, `weightSelf/weightSupervisor/weightHr` (≥0), `blindRating?, requireSelfBeforeSupervisor?, hrReviewRequired?` | Create/update a cycle | Weights must be ≥0; `periodStart ≤ periodEnd`; the full schedule must run forward in time; changing `versionId` on a non-draft cycle is blocked |
| POST | `/appraisal-admin/cycles/:id/activate` \| `/lock` \| `/close` | — | Advance the cycle's status | Logs a cycle status event |
| POST | `/appraisal-admin/cycles/:id/generate` | `userIds?, departments?, versionId?` (override, must be published) | Generate appraisal records for employees in the cycle | With no `userIds`, generates for every active employee |
| POST | `/appraisal-admin/cycles/:id/release` | `appraisalIds?` (subset) | Release results to employees | — |
| GET | `/appraisal-admin/cycles/:id/progress` | — | Completion dashboard: status breakdown, missing-supervisor flag | — |
| GET | `/appraisal-admin/cycles/:id/eligible` | — | Active employees not yet in this cycle | Powers the assignment picker |

**Per-appraisal HR actions**

| Method | Path | Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| POST | `/appraisal-admin/appraisals/:id/assign-hr-rater` | `{ userId }` | Assign/replace the HR rater | Validated as sane; recomputes score |
| POST | `/appraisal-admin/appraisals/:id/override` | `{ finalScore, reason }` | Manually override a final score | — |
| DELETE | `/appraisal-admin/appraisals/:id/override` | — | Clear a score override | Recomputes score after clearing |
| POST | `/appraisal-admin/appraisals/:id/reopen` | `{ role, reason }` | Reopen a submitted rater's section | `role` must be a valid rater role |
| POST | `/appraisal-admin/appraisals/:id/recalculate` | — | Force-recompute the final score/band | — |
| GET | `/appraisal-admin/appraisals/:id/events` | — | Audit-event history (last 200) | — |
| POST | `/appraisal-admin/appraisals/:id/version/preview` | `versionId, onConflict?` (`keep_by_code`\|`clear`, default `keep_by_code`) | Dry-run: effect of moving this employee to another form | No writes |
| POST | `/appraisal-admin/appraisals/:id/version` | `versionId` (required), `onConflict?, reason?` | Move one employee's appraisal onto a different form version | — |
| DELETE | `/appraisal-admin/appraisals/:id` | `{ reason? }` | Remove one appraisal from its cycle | Refused if already `released` or `acknowledged`; cascades raters/responses/scores |

---

## Ashtrid (AI Assistant)

Base path: `/ashtrid`. All routes require auth; system-query routes also require
`module:ashtrid.use` (granted to everyone by default); the employee picker requires `module:admin.users`.

| Method | Path | Query / Body / Params | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/ashtrid/systems` | — | List connected/planned systems + the default system key | — |
| POST | `/ashtrid/ask` | `{ question (required), system? }` (defaults to the configured default system) | Ask a natural-language question, routed to the chosen system's adapter | Access is always scoped server-side, never by the model; an unwired ("planned") system returns an empty result with a warning; a caller with no linked identity gets an empty result with a "not linked" explanation rather than a 403 |
| GET | `/ashtrid/documents/:documentId/files` | `?system=` | List files attached to a document, scoped to caller's access | 403 if no access to that document; requires a linked identity or admin |
| GET | `/ashtrid/document/:fileId` | `?system=` | Stream a specific file inline | 403/404 forwarded from the adapter's own access check |
| GET | `/ashtrid/employees` | `?q=` (search text) | Search the e-Forward/HR employee directory (used by the "link account" picker) | Admin-only; returns up to 50 rows, matching employee id/first/last name/email |

---

## Admin

Base path: `/admin` (user/module management). All routes require `module:admin.users`.

| Method | Path | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/admin/modules` | — | Module registry + access roles + role defaults | Powers the admin UI's own permission list |
| GET | `/admin/email-status` | — | Whether SMTP is configured/reachable | Never throws — reports `{ configured, reachable, message }` |
| GET | `/admin/users` | `?search=` | List/search users (admin view — includes email, employeeId, supervisor) | — |
| POST | `/admin/users` | `name` (required), `email` (required, unique), `accessRole?` (valid role), `role?, department?, employeeId?` | Create a user account and email an invite link | Password is set to an unusable placeholder — the account can't log in until the invitee sets a real password via the emailed link |
| PATCH | `/admin/users/:id` | `accessRole?, modules?` (array of valid keys, or `null`), `isActive?, employeeId?` (≤15 chars, empty to unlink), `supervisorId?` | Update a user's access/role/status | Can't deactivate your own account or change your own `accessRole` away from `admin`; `supervisorId` can't be self or create a mutual-supervision cycle |
| POST | `/admin/users/:id/resend-invite` | — | Re-send the invite/reset-password email | Refused if the account is deactivated |
| GET | `/admin/audit` | `?action=, ?actorId=, ?entityId=, ?limit=` (default 100, max 300) | List administrative-action audit events, newest first | See [System Log](#system-log-audit--errors) |
| GET | `/admin/errors` | `?includeResolved=` (`true`/`false`, default `false`), `?source=, ?limit=` (default 100, max 300) | List server-error events (deduplicated by fingerprint) + a summary | See [System Log](#system-log-audit--errors) |
| POST | `/admin/errors/:id/resolve` | — | Mark an error as handled | Logs an `error.resolved` audit event |
| GET | `/admin/jobs` | — | Status of every registered background job | Returns `{ jobs: [{name, enabled, everyMs, lastRunAt, lastStatus, lastError, lastSummary, runCount, nextDueAt}] }` — see [Background Jobs](#background-jobs) |
| POST | `/admin/jobs/:name/run` | — | Run one job immediately, ignoring its schedule | 404 for an unknown job name; logs a `job.run` audit event; returns the refreshed job-status list |

---

## System Log (Audit & Errors)

New in this update: an internal system log that records deliberate admin actions and captures server
faults, both surfaced under `/admin` (`module:admin.users` required — see the routes above).

**Audit trail** — every sensitive admin action writes a row (currently: creating a user, and any
change to a user's `accessRole`/`isActive`/`employeeId`/`supervisorId`/effective modules; resolving an
error). Each row looks like:

```json
{
  "id": "123",
  "action": "user.access_changed",
  "actorName": "Alex Rivera",
  "actor": { "id": "...", "name": "Alex Rivera", "initials": "AR", "color": "..." },
  "entityType": "user",
  "entityId": "...",
  "entityLabel": "Jordan Cruz",
  "summary": "Jordan Cruz: role employee → hr; granted appraisal.manage, ethics.manage",
  "changes": { "accessRole": { "from": "employee", "to": "hr" }, "modules": { "gained": [...], "lost": [...] } },
  "ip": "203.0.113.4",
  "createdAt": "..."
}
```

Module changes are diffed on **effective** modules (what the person can actually do), not the raw
override column — so a role change that silently grants/revokes keys still shows up.

**Error log** — every unhandled 5xx response is recorded (client 4xx errors are not — those are the
API correctly saying "no"). Repeats of the same fault (same source + route shape + normalized
message) bump a counter on one row instead of creating duplicates, so a fault that fired 400 times
reads as one problem, not 400. Each row:

```json
{
  "id": "45",
  "source": "http",
  "message": "...",
  "stack": "... (never leaves this admin route)",
  "method": "POST",
  "path": "/api/bookings",
  "statusCode": 500,
  "context": { "...": "..." },
  "count": 7,
  "firstSeenAt": "...",
  "lastSeenAt": "...",
  "resolvedAt": null,
  "resolvedBy": null
}
```

`GET /admin/errors` also returns a `summary` alongside the `errors` array (open-error counts, etc. —
see `systemLog.errorSummary()`). Errors are also recorded for failures inside the notification
pipeline specifically (`source: 'notify'`), since a silently-broken notification path was the original
motivation for this feature — it used to fail with no visible symptom beyond notifications not
arriving.

---

## Background Jobs

New in this update: a small in-process scheduler (`src/services/scheduler.service.js`,
`src/jobs/index.js`) runs recurring maintenance work, and `GET /admin/jobs` / `POST /admin/jobs/:name/run`
(documented under [Admin](#admin) above) let the System page answer "did the backup run last night?"
without reading server logs.

**Registered jobs:**

| Name | What it does |
| --- | --- |
| `booking-reminders` | Sends reminder notifications ahead of upcoming van/room bookings |
| `call-reconcile` | Closes calls whose LiveKit room has already ended but whose webhook never arrived — the only thing that ever closes an abandoned group call. Only enabled when LiveKit is configured; see [Voice Calls](#voice-calls) |
| `nightly-backup` | Runs the database backup (`src/db/backup.js`) |
| `missed-notification-email` | Emails a digest of missed in-app notifications |

Each job-status entry: `{ name, enabled, everyMs, lastRunAt, lastStatus, lastError, lastSummary, runCount, nextDueAt }`.
A job can be disabled entirely via `SCHEDULER_ENABLED=false`, and failures are recorded into the same
error log described above (`source: 'scheduler'`).


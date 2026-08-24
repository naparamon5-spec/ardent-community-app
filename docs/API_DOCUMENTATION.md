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
| `appraisal.view` | View own appraisals / rate where assigned |
| `appraisal.manage` | Run the appraisal programme (HR/admin) |
| `ethics.report` | Report an ethics concern (everyone) |
| `ethics.manage` | Review ethics complaints (HR/admin) |
| `bookings.view` | View vans & rooms / schedule |
| `bookings.book` | Book a van or room |
| `bookings.manage` | Manage the fleet/room list (HR/admin) |
| `admin.users` | Manage users, roles, categories |

Default role → module mapping and full details: `src/config/modules.js`.

## Common error responses

| Status | Meaning |
| --- | --- |
| 400 | Bad request — missing/invalid fields (message explains which) |
| 401 | Missing, invalid, or expired token |
| 403 | Authenticated but not permitted (missing module, not the resource owner, recused, etc.) |
| 404 | Resource not found |
| 409 | Conflict — e.g. duplicate email/unique constraint |
| 500 | Unexpected server error |

## File uploads

Uploads use `multipart/form-data` and are handled in-memory (Multer) then pushed to MinIO; the API
never touches local disk. Limits and accepted types by preset (`src/middleware/upload.middleware.js`):

| Preset | Field name(s) | Accepted types | Max size | Used by |
| --- | --- | --- | --- | --- |
| `imageUpload(field)` | variable (`avatar`, `cover`, `photo`, `cover`) | JPEG, PNG, WEBP, GIF | 10 MB | avatars, covers, listing/event/group/booking-resource photos |
| `postUpload` | `photo` (1), `file` (1) | images + documents (PDF/Office/text/zip) | 10 MB | post composer |
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
11. [Categories](#categories)
12. [Celebrations](#celebrations)
13. [Notifications](#notifications)
14. [Search](#search)
15. [Bookings](#bookings)
16. [Booking Admin](#booking-admin)
17. [Ethics](#ethics)
18. [Ethics Admin](#ethics-admin)
19. [Appraisals](#appraisals)
20. [Appraisal Admin](#appraisal-admin)
21. [Ashtrid (AI Assistant)](#ashtrid-ai-assistant)
22. [Admin](#admin)

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
| POST | `/auth/login` | None | `{ email, password }` | Password login. Returns `{ token, user }`. 401 on bad credentials, 403 if deactivated |
| POST | `/auth/register` | None | `{ name, email, password, role?, department? }` (password ≥ 6 chars) | Self-registration. Returns `{ token, user }`, 201. 409 if email exists |
| GET | `/auth/me` | Required | — | Current user profile (`present.user` shape) |
| POST | `/auth/change-password` | Required | `{ currentPassword?, newPassword }` (newPassword ≥ 6 chars) | Change own password; emails a "password changed" notice |
| POST | `/auth/forgot-password` | None | `{ email }` | Always responds the same way regardless of whether the account exists (anti-enumeration). Emails a reset link if the account exists and is active |
| GET | `/auth/reset-token` | None | Query: `?token=` | Validates a reset/invite token before showing the reset form. Returns `{ valid, reason? }` or `{ valid: true, purpose, name, email }` |
| POST | `/auth/reset-password` | None | `{ token, password }` (password ≥ 8 chars) | Consumes a single-use reset/invite token, sets the new password, and signs the user in — returns `{ token, user }` |

**Notes:**
- Passwords are bcrypt-hashed (never stored/returned in plaintext).
- Reset/invite tokens are single-use and time-limited (`RESET_TOKEN_TTL_MINUTES` / `INVITE_TOKEN_TTL_HOURS`).
- `forgot-password` never reveals whether an email is registered.

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
| GET | `/posts` | Optional | Query: `?type=&limit=(≤100,default 20)&offset=` | Feed, pinned first then newest |
| GET | `/posts/:id` | Optional | — | One post, with its full comment list attached |
| GET | `/posts/:id/comments` | None | — | Comments for a post |
| POST | `/posts` | Required + `module:feed.post` | multipart (`postUpload`): `photo?` (image), `file?` (doc) + JSON fields: `type` (`text\|photo\|file\|poll\|kudos\|announcement\|share`), `text?, title?, note?, signoff?, lines?, details?, pinned?, kudosTo?` (slug/id/name), `pollOptions?` (≥2, distinct), `pollMultiple?`, `sharedPostId?`, `mentions?` (array of user ids, or JSON string when sent via multipart) | Create a post. 201. Notifies kudos recipient + mentioned users |
| PATCH | `/posts/:id` | Required | JSON: any post field | Edit — owner or `admin.users` only |
| DELETE | `/posts/:id` | Required | — | Delete — owner or `admin.users` only |
| POST | `/posts/:id/comments` | Required | `{ text (required), parentId?, mentions? }` | Add a comment/reply. Notifies post owner (+ parent comment author on a reply, + mentioned users) |
| PUT | `/posts/:id/reaction` | Required | `{ type: like\|celebrate\|support\|insightful }` | Set/replace your reaction |
| DELETE | `/posts/:id/reaction` | Required | — | Remove your reaction |
| PUT | `/posts/:id/save` | Required | — | Save the post |
| DELETE | `/posts/:id/save` | Required | — | Unsave |
| POST | `/posts/:id/share` | Required | — | Share the post (creates a `share`-type record) |
| GET | `/posts/:id/poll/voters` | Required | — | `{ [optionId]: [author, ...] }` — who voted for each option |
| POST | `/posts/:id/vote` | Required | `{ optionId (required) }` | Vote (or add a choice, if `pollMultiple`) |
| DELETE | `/posts/:id/vote` | Required | — | Withdraw your vote(s) |

**Post type payload notes:**
- `announcement`: use `title, lines, details, note, signoff`.
- `kudos`: set `kudosTo` (accepts slug, id, or display name).
- `poll`: `pollOptions` must have ≥2 distinct (case/whitespace-insensitive) options.

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

---

## Groups

Base path: `/groups`. All routes require `module:groups.view`.

| Method | Path | Body / Query | Description | Business rules |
| --- | --- | --- | --- | --- |
| GET | `/groups` | — | List groups visible to the viewer | — |
| GET | `/groups/direct` | — | List the caller's direct-message threads | — |
| POST | `/groups/direct` | `{ userId }` (required) | Open or find an existing 1:1 DM thread | Can't DM yourself; target must exist |
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
| GET | `/appraisals/:id/form` | — | The template form + the viewer's saved answers | HR/admin see everything; the subject sees everything only once `released`; otherwise each viewer sees only questions their own rater role answers |
| PATCH | `/appraisals/:id/responses` | `{ role, responses: [{itemId, numericValue, optionId, textValue, comment, isNa}] }` | Autosave answers (bulk upsert) | Only items belonging to this form and this rater's role are accepted; first save flips status to `in_progress` |
| POST | `/appraisals/:id/submit` | `{ role, overallComment? }` | Submit/lock this rater's responses | Requires an active rater row matching the role; runs required-field validation |
| GET | `/appraisals/:id/result` | — | View the final score/result | 403 until the cycle has released results |
| POST | `/appraisals/:id/acknowledge` | `{ comment? }` | Employee acknowledges their released result | — |
| GET | `/appraisals/:id/attachments` | — | List evidence attachments | — |
| POST | `/appraisals/:id/attachments` | multipart (`appraisalUpload`): `file` (required) | Attach supporting evidence | Only an active rater on this appraisal, or `appraisal.manage`, may attach |
| GET | `/appraisals/:id/attachments/:attachmentId` | — | Stream one evidence file | Access re-checked every read; never a public URL |

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
| PUT | `/appraisal-admin/versions/:versionId/structure` | `sections` (nested items), `bands`, `force?` | Bulk-save the section/item tree | A breaking edit to a published version with real saved answers is refused (400) unless `force: true`; orphaned answers are archived, not lost; logs a change-log entry |
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


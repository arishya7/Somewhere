# Somewhere — "Let it find you"

Godot 4.7 project (GL Compatibility renderer, so it can export to web). The world bible is
`~/Downloads/Somewhere_Storyline.docx`; read it before designing new beats.

## Godot MCP
A user-level MCP server named `godot` (`@coding-solo/godot-mcp`) points at `~/Downloads/Godot.app`.
Use it to `run_project`, read `get_debug_output`, `launch_editor`, and `create_scene` / `add_node`.

## Flow
landing → onboarding (name, phone + code, email + code, birthday, gender, who to meet, intent,
interests, prompt, photos) → avatar studio → arrival (alone on the sea wall; the Breeze; intro film)
→ Singapore map → a place's street (district) → venues (bar/café/thrift/…; malls open an indoor street)
→ tap someone → profile → match → chat. Bars run trivia night with a teammate.

Jump to any screen while developing (a demo profile is filled in if none exists); `_` becomes a space:
`Godot --path . -- --screen=district --place=Clarke_Quay`
(`landing`, `onboarding --step=N`, `avatar`, `arrival`, `map`, `district --place=X [--mall=Y]`,
`venue --place=X --type=bar --venue=Name`, `chat`).

## Layout
- `scenes/app.tscn` + `scripts/app.gd`: root Control, theme, screen switching with fades.
- `scripts/profile.gd` (autoload `Profile`): answers, photos, avatar, matches + messages, what you learned about people.
- `scripts/ui.gd`: design system. New York serif headlines, Avenir body; ivory primary buttons, soft chips, tabs, cards.
- `scripts/avatar.gd`: procedural avatar, grown-up doll-like proportions (`HEAD_SCALE`, `NECK_Y`) with 3D-style
  layered shading (`_shaded`, `_shaded_limb3`). `draw()`, `draw_portrait()`, `draw_back_sitting()`. Options include
  body shape (Straight / Curvy / V-shape) and a separate brow colour.
- `scripts/places.gd`: map coastline, hotspots, street style and venues per place, mall shops.
- `scripts/people.gd`: seeded simulated people (look, background, interests, traits, prompts, voice).
- `scripts/screens/`: `landing`, `onboarding`, `avatar_room`, `arrival`, `map`, `district`, `venue`, `chat`.
- `scripts/ui/`: `montage` (intro film), `trivia`, `profile_view`, `photo_card`, `option_tile`, `swatch`.

## Multiplayer (scripts/net.gd, autoload `Net`)
One player hosts a WebSocket relay on port 9080 inside the game; everyone (host included) joins as a client.
Sends only `Profile.public_profile()` plus up to 3 downscaled photos. The relay re-validates handles, names,
message length and photo size, rate-limits, only creates a match when both follow, and only relays chat between matches.
Run a second local player with `-- --profile=name` (separate save file and photos).

## Navigation & guide
`scripts/ui/dock.gd` (Map, Shore, Breeze, Messages) on map/street/venue. `scripts/ui/breeze_guide.gd` explains and
suggests places; it never suggests people. Following is mutual-only (`Profile.follow`); declines are never shown.

## Activities
`scripts/ui/trivia.gd` (bars) and `scripts/ui/activities.gd` (café, supper club, gallery, bookshop, studio,
thrift try-on, record listening via `scripts/synth.gd`, Star Catcher arcade, dance floor). Game logic runs in
`_process`, not in draw callbacks (draw doesn't run headless).

## Quests, calls, ghosting
- `scripts/quests.gd` catalogue; `Profile.propose_quest/accept_quest/quest_event`. Steps complete from world events:
  district `visit`, venue `enter`, activity/trivia `completed` signal → `activity`.
- Voice calls in `net.gd` (16 kHz mono PCM over the relay, only between matches, only after accept). Needs mic permission.
- Ghosting: `Profile.check_ghosting()` (app checks on a timer). Reminder at 3 days, then daily; 3 reminders = strike;
  3 strikes = banned screen. `close_kindly` never counts. Test with `-- --ghost-day=60` (a day = 60 s).
- The Breeze only answers app questions (`_on_topic` in `breeze_guide.gd`).
- Shore quotes rotate in `arrival.gd` (attributions checked). At the Shore, `Net.set_resting(true)` keeps you visible
  where you were, greyed out as resting.
- Quests name an exact venue (`Quests.venue_of(q)` → [name, door]). Chat has "Go there now", which drops you at the door;
  the street draws a gold star above it. The quest partner stays with you in any venue on that street.
- Close kindly asks to confirm, then waits `Profile.UNDO_SECONDS` (Undo toast) before anything is sent.
- First visit to the map runs `scripts/ui/tour.gd` (replay with the "? Tour" button; flag `seen_map_tour`).
- People who share your interests stand in a gold glow (`People.kindred`, `People.draw_spotlight`); hover tags show
  name, age, pronouns and interests in common (`People.tag`).
- Chat has an Icebreaker button (this or that, would you rather, never have I ever). In a venue, tapping someone offers
  "Invite to play" (no match needed).
- The Breeze: distress words get a kind reply with Samaritans of Singapore (1767) and 995 before anything else;
  "where can I find a good burger/coffee/..." lists in-game venues with Go buttons.

## Orientation, flags, live trivia
- Onboarding has an optional orientation step (`UI.ORIENTATIONS`) with a "show my pride flag" toggle. Name tags above
  heads use `UI.draw_tag` (flag + name + pronouns). `Profile.wants_to_meet_me(person)` checks their `show_me`;
  the profile's Follow button is disabled when they aren't looking to meet someone like you.
- Real players in the same venue can invite each other to trivia (no match needed). The relay only passes
  `invite` / `invite_reply` / `play` between two people whose presence is the same venue (`_same_room`).
  Trivia uses a shared seed and exchanges real answers per round; it never invents a real person's replies.

## Playing together (real people)
- `Net.set_presence(..., extra)` carries venue `type`, `door`, `mall` and table `seat`; presence is re-sent after every
  (re)connect and a `ping` goes out every 20 s. `Net.where_text(h)` / `Net.go_to(h)` power the dock's **Who's on**
  panel (`scripts/ui/whos_on.gd`): everyone online, where they are, "Go to them".
- Venues with `TABLES` (café, restaurant, bar, bookstore, records, gallery): tap a table to sit; friends' seats come
  from presence. Sitting with someone makes them the play target (`_play_target`: tablemate → quest partner here →
  the only friend here). Invites work in every venue type: bars play live trivia, others play live "moments"
  (`activities.gd` with a shared seed; `LIVE_MOMENTS` for hands-on venues). Picks are exchanged with `Net.send_play`;
  a real person's answers are never invented.
- Quests with a real match: `Profile.quest_partner` skips real people (they move on their own);
  `Profile.real_quest_partner(place)` drives the gold ★ tags and "Tell @x you're here" (sends a chat message).

## Data boundaries
`scripts/validate.gd`: name, handle, per-country phone length, email, real-date birthday 18–99, text limits, photo limits.

## Real people only
By default there are no simulated people: the map, streets and venues show only real players connected through
Play with friends. Activities aren't synced between players yet, so when you start one, the venue's host
(`People.host`, flagged `host: true`, no profile or follow) plays with you. `-- --demo-people` brings the
simulated crowd back for solo demos and interviews.

## Simulated for now
- Verification codes: generated locally and shown in a fake notification banner (tap to fill).
  Replace `_send_code()` in onboarding with a real SMS/email service via a backend.
- Other players (map, streets, venues) are generated by `people.gd`. Replace with a server feed for multiplayer.
- Their "photos" are illustrated (`photo_card.gd`); real members would show uploaded photos.
- Chat replies come from a small rule-based engine in `chat.gd`. Quests are not built yet (button shows "Coming next").

## Gotchas
- Full-screen Controls must use `set_anchors_and_offsets_preset`, not `set_anchors_preset`.
- Labels inside HBoxes need `UI.nowrap()` or they collapse into vertical text.
- Controls under a CanvasLayer don't inherit the root theme; set `theme = UI.theme()` on them.

## Vocabulary and principles (use in copy and code)
Pulse, Resonance, the Red String, Threads, the Breeze, Hotspots, the Shore, the Loop.
Felt, not shown. Suggest, never command. Consent-first. Fate is patient (no streaks, timers, scores or "% match").

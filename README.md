# EatUp!

Flutter + Flame game for iOS and Android (`completed.realfunrealgames.eatup`). You are a little
monster in a busy town: eat the people and things smaller than you to grow, then eat bigger things
(trees, cars, buses, houses, towers) and the rival monsters. Biggest when the timer runs out wins.

5 maps unlocked by level, 14 monster skins (coins, level or rewarded videos), 5 upgrade tracks,
daily missions, a 7-day daily gift, a lucky wheel, power-ups, revives, and 6 languages
(en, es, fr, de, pt, ja). No image or audio assets from third parties: all art is painted from
code and all sound is synthesized.

## Layout

- `lib/game/arena.dart` - the round, as plain Dart: eating, growth, rivals' AI, people, traffic,
  power-ups, respawns, results. Unit tested in `test/arena_test.dart` (every map, with timing).
- `lib/game/growth.dart` - every balance number for size, speed, camera and eating in one place.
- `lib/game/map_gen.dart` - deterministic town generator (road grid, blocks, props) per map + seed.
- `lib/game/maps.dart`, `skins.dart`, `upgrades.dart`, `props.dart`, `rewards.dart` - content and
  economy. Adding a map, skin or upgrade is one entry in a list (plus its strings).
- `lib/game/eat_game.dart` - the Flame game: camera, input (floating joystick), drawing, particles.
- `lib/game/art/` - the sprite atlas (people, props, pickups), monsters and ground, all vector code.
- `lib/ui/` - menus and HUD. Everything is a panel over the always-running town (`main_screen.dart`).
- `lib/core/` - save data, missions, strings, sound, ads, consent, purchases, remote config, analytics,
  review prompt.
- `tool/gen_sounds.dart` - synthesizes every sound + the music loop into `assets/audio/`
  (`dart run tool/gen_sounds.dart`).
- `tool/render_icon_test.dart` - renders the app icon (`flutter test tool/render_icon_test.dart`,
  then `dart run flutter_launcher_icons`).

## Scaling

- **Frame time**: every prop, person, shadow and pickup on screen goes out in a few batched
  `drawRawAtlas` calls from one texture painted at startup; the ground is a recorded picture.
  Eating and AI use a spatial grid, so a full round costs ~0.1 ms per update on a desktop CPU
  (checked in `test/arena_test.dart`). Towns grow with `MapDef.size`; population follows the area.
- **Screens**: every UI size goes through `context.u` (1.0 at 390 pt, clamped for small phones and
  tablets). `test/layout_test.dart` renders every panel at 5 screen sizes (iPhone SE to 12.9" iPad)
  in all 6 languages and fails on any overflow (330 cases).
- **Live tuning**: `lib/core/live_config.dart` wraps Firebase Remote Config: round length, ad pacing,
  free-coin amounts, wheel timers and revives can change without an app update. Shipped defaults
  apply offline or when Firebase isn't configured.
- **Content**: data-driven lists; save data has a `schema` version for migrations.

## Retention loop

- Player level + XP every round; levels pay coins and unlock maps (lv 3, 6, 10, 15) and skins.
- 3 daily missions sized to the player's level (+ bonus chest for all 3, one swap per day via video).
- 7-day daily gift streak (x2 with a video), lucky wheel (free every 6 h, +3 video spins a day).
- Map coin multipliers (x1 to x2.2) pull players to harder maps; "new best" and win counts per map.
- In-round: combos, tier hints ("now eat the buildings!"), power-ups (speed, magnet, x2 growth),
  edge arrows for nearby threats/prey, one revive per round.

## Monetization

- **Ads** (same setup as Stone Skipping): adaptive banner pinned to the top; interstitial only when
  leaving a results card - never in a player's first 2 rounds, never in the first 60 s of a session,
  at most once per 90 s (`InterstitialPacer`, tunable remotely). Rewarded: revive, x2 round coins,
  x2 daily gift, free coins (5 min cooldown), wheel spins, mission swap, video skins.
  UMP consent + iOS ATT before any ad request.
- **In-app purchases** (`lib/core/purchases.dart`): `eatup_remove_ads` (non-consumable: no banners or
  interstitials; rewarded stays optional) and coin packs `eatup_coins_small|medium|large`
  (2 000 / 6 000 / 20 000). Re-delivered purchases are never paid twice. Restore purchases in settings on iOS.

## Tests

```
flutter test                                      # everything (unit, simulation, layouts, app flows)
flutter test test/app_flow_test.dart --dart-define=CAPTURE=true   # + PNG of each screen in build/captures/
```

`test/app_flow_test.dart` drives the real app: menu, a full round with an autopilot, being eaten and
the revive offer, results, store tabs, missions, wheel, gift, settings and the first-launch tutorial.
Raw 1170x2532 store captures from it are in `store/raw/`.

## Before release

1. **AdMob**: create the EatUp app + 3 units per platform. Put the unit ids in
   `lib/core/ads/ad_ids.dart` and the app ids in `android/app/src/main/AndroidManifest.xml` and
   `ios/Runner/Info.plist` (both currently Google's TEST app ids). Publish a GDPR message in
   AdMob Privacy & messaging.
2. **Firebase**: create a project, run `flutterfire configure` (replaces `lib/firebase_options.dart`),
   enable Analytics and Remote Config. Without it the game runs with analytics off and default config.
3. **Purchases**: create the 4 product ids above in Play Console and App Store Connect.
4. **Android signing**: add `android/key.properties` (release falls back to the debug key without it).
5. **iOS**: set the App Store id in `lib/core/review.dart` once the app exists; run `pod install` on a
   Mac (Podfile targets iOS 15). Fill in the App Privacy labels (ads, analytics, IDFA).
6. Consider the full SKAdNetwork list from Google's docs in `Info.plist` if you add mediation.
7. Store listing copy is in `store/listing.md`.

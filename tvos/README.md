# Solitaire tvOS

A native SwiftUI port of the web solitaire collection in this repo, built for
the Apple TV and playable entirely with the Siri Remote's directional buttons
plus OK. All ten modes are here — Baker's Dozen, Eagle Wing, Emperor,
Freecell, Golf, Klondike, Scorpion, Spider, Spiderette, and Yukon — with the
same rules, dealing, hard modes, and win/loss logic as the web version
(`src/modes/*.js` was ported function-for-function to `Sources/Game/Modes/`).

## Controls

| Button | Action |
| --- | --- |
| Left/Right/Up/Down | Move the cursor between piles. Up/down also walks cards within a column wherever the grabbed card matters: the start of a movable run (Klondike, Eagle Wing, Spider, Spiderette), any face-up card (Yukon, Scorpion, Emperor), or the movable tail run (Freecell). |
| OK (click) | Select the cursored card/stack, or drop a held selection onto the cursored pile. Clicking the draw pile draws. Same select/move semantics as clicking in the web version. |
| OK (hold ~0.6s) | Send the cursored card to its foundation (the web version's right-click). |
| Play/Pause | Open the menu: Undo, Auto-Finish (when available), Rule Help, Hard Mode toggle, Play Again, and New Game for every mode. |
| Back/Menu | Cancel the current selection or close an overlay. With nothing to cancel, exits to the home screen (per the tvOS HIG). |

Holding a direction auto-repeats, which helps with Baker's Dozen's 13 columns.

Game state saves automatically after every move (the tvOS equivalent of the
web build's localStorage save), so quitting and relaunching resumes the game.

## Installing to a device

```
make clean && make install \
    DEVELOPMENT_TEAM=<TEAM_ID> \
    DEVICE_ID=<DEVICE_UUID>
```

`DEVELOPMENT_TEAM` is optional — when omitted, the Makefile auto-detects it
from your `Apple Development` certificate. `DEVICE_ID` is required if you have
more than one Apple TV paired (otherwise the first one is used).

### Finding `DEVICE_ID`

```
make list
```

## Other targets

- `make generate` — regenerate `Solitaire.xcodeproj` from `project.yml` via xcodegen
- `make build` — build for device (no install)
- `make run` — same as `make install`, but stays attached to the app's
  stdout/stderr (via `devicectl --console`). Ctrl-C detaches.
- `make simulator` — build for the tvOS simulator
- `make list` — list paired Apple TVs
- `make clean` — remove generated project, build dir, and DerivedData

## Notes

- Card art is the same Vector Playing Cards 3.2 deck as the web `basic` deck
  (`src/deck_basic/`), pre-rendered to 1024px PNGs in
  `Sources/Assets.xcassets`. The card back was rendered with qlmanage because
  its SVG uses pattern fills that ImageMagick drops; J♠, Q♣, K♣, and J♥
  (cards 10, 24, 25, 49) were rendered with headless Chrome because
  ImageMagick mangles their face art; everything else was rendered with
  ImageMagick.
- The layered app icon (parallax: felt → fanned card backs → ace of spades)
  and the top-shelf images are composited from those same card renders.
- Directional input listens for UIPress arrow events, i.e. the clickpad
  ring on the 2nd-gen (and later) Siri Remote. Touch-surface swipes from the
  1st-gen remote are not wired up.
- The app intentionally has no focusable SwiftUI controls; a transparent
  UIKit view (`RemoteInput.swift`) captures every remote press and drives the
  custom cursor, mirroring the duplex tvOS app's press-capture approach.

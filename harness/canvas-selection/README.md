# Canvas selection regression harness

Runs the actual lock-screen style model, artwork source walker, motion follower and player-state
publisher in the iOS simulator. The network is replaced with an NSURLProtocol fixture; no real
Spotify requests or account credentials are used.

    THEOS=/path/to/theos sh harness/canvas-selection/build.sh

The first executable checks Canvas-only preferences, every single-view choice, fallback ordering,
explicit star cycling, disabled views and independent manual/lyrics modes. The second checks late
request headers, request sharing, timeout recovery, same-track source changes, background defaults
writes, Canvas metadata arriving after a skip, updated Canvas URLs and stale results after rapid skips.
Position-only state updates must still avoid notifying observers.

`PLAYER_STATE_SOURCE=/path/to/PlayerState.x` runs the same scenarios with a different publisher.
The pre-fix publisher fails when Canvas metadata arrives after a skip. Two earlier reproductions also
showed the old star-view migration adding disabled styles and a missed lookup persisting Off.

This tests selection and callback ordering. Real lock-screen video presentation still needs an iOS 26+
phone with tracks that have Canvas available.

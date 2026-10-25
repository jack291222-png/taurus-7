// Saved choices stay separate from a track's temporary fallback artwork.
#import "Core/SGCore.h"
#import "AnimatedArtwork.h"
#import "Shared/LockScreenArtwork/LockScreenArtwork.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

static NSString *const kStarCanvas = @"canvas";
static NSString *const kStarCanvasLyrics = @"canvasLyrics";
static NSString *const kStarFill = @"fill";
static NSString *const kStarDefault = @"default";
static NSString *const kStarColorful = @"colorful";
static NSString *const kArtistLyricsWasEnabled = @"spotifyglass.lockscreen.artistLyricsWasEnabled";
static NSArray<NSString *> *defaultStarViewOrder(void) {
    return @[kStarCanvas, kStarCanvasLyrics, kStarFill, kStarColorful, kStarDefault];
}

SGLockArtwork SGLockScreenArtwork(void) {
    if (@available(iOS 26.0, *)) {
        // The old switch's YES and NO read as Moving artwork and Off, the enum's first two.
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
            SGMigrateKey(SGKeyLockScreenMotion, SGKeyFullScreenArtwork);
            SGMigrateKey(SGKeyLegacyLockScreenArtwork, SGKeyFullScreenArtwork);
            if (![store objectForKey:SGKeyFullScreenArtwork]) {
                SGSetInt(SGKeyFullScreenArtwork, SGFlag(SGKeyLegacyLockScreenArtwork, YES)
                         ? SGLockArtworkMotion : SGLockArtworkOff);
            }
            if (![store objectForKey:SGKeyMotionSources] && [store objectForKey:SGKeyLockScreenArtworkSources]) {
                NSArray<NSString *> *legacy = SGArtworkOrder();
                if (legacy.count) [store setObject:legacy forKey:SGKeyMotionSources];
            }
        });
        return (SGLockArtwork)SGInt(SGKeyFullScreenArtwork, SGLockArtworkOff);
    }
    return SGLockArtworkOff;
}

NSArray<NSString *> *SGLockScreenStarViewOrder(void) {
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:SGKeyLockScreenStarViews];
    if (![stored isKindOfClass:NSArray.class]) return defaultStarViewOrder();
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id key in (NSArray *)stored) {
        if (([key isEqual:kStarCanvas] || [key isEqual:kStarCanvasLyrics] || [key isEqual:kStarFill]
             || [key isEqual:kStarDefault] || [key isEqual:kStarColorful])
            && ![order containsObject:key]) {
            [order addObject:key];
        }
    }
    return order;
}

NSString *SGLockScreenStarCurrentView(void) {
    SGLockArtwork artwork = SGLockScreenArtwork();
    if (artwork == SGLockArtworkOff) return kStarDefault;
    if (artwork == SGLockArtworkEverySong) return kStarColorful;
    if (artwork == SGLockArtworkFill) return kStarFill;
    return artwork == SGLockArtworkMotion
        ? (SGLockScreenCanvasLyricsEnabled() ? kStarCanvasLyrics : kStarCanvas) : nil;
}

static void selectView(NSString *next) {
    if ([next isEqualToString:kStarDefault]) {
        SGSetInt(SGKeyFullScreenArtwork, SGLockArtworkOff);
        SGLockScreenCanvasLyricsSetEnabled(NO);
    } else if ([next isEqualToString:kStarColorful]) {
        SGSetInt(SGKeyFullScreenArtwork, SGLockArtworkEverySong);
        SGLockScreenCanvasLyricsSetEnabled(NO);
    } else if ([next isEqualToString:kStarFill]) {
        SGSetInt(SGKeyFullScreenArtwork, SGLockArtworkFill);
        SGLockScreenCanvasLyricsSetEnabled(NO);
    } else {
        SGSetInt(SGKeyFullScreenArtwork, SGLockArtworkMotion);
        SGLockScreenCanvasLyricsSetEnabled([next isEqualToString:kStarCanvasLyrics]);
    }
    SGLog(@"lock star: selected %@", next);
}

void SGLockScreenStarEnsureView(void) {
    if (!SGHidden(SGKeyLockScreenStar)) return;
    NSArray<NSString *> *order = SGLockScreenStarViewOrder();
    NSString *current = SGLockScreenStarCurrentView();
    if (current && order.count && ![order containsObject:current])
        selectView(order.firstObject);
}

void SGLockScreenStarAdvanceView(void) {
    NSArray<NSString *> *order = SGLockScreenStarViewOrder();
    if (!order.count) return;
    NSUInteger index = [order indexOfObject:SGLockScreenStarCurrentView() ?: @""];
    selectView(order[index == NSNotFound ? 0 : (index + 1) % order.count]);
}

NSString *SGLockScreenMotionFallbackView(void) {
    return SGLockScreenArtwork() == SGLockArtworkMotion && !SGLockScreenCanvasLyricsEnabled()
        ? kStarFill : nil;
}

BOOL SGLockScreenCanvasLyricsEnabled(void) {
    BOOL canvas = SGHidden(SGKeyLockScreenCanvasLyrics);
    if (canvas && SGFlag(SGKeyLockScreenLyrics, NO) && SGEnabled(SGKeyLockScreenExclusiveLyrics)) {
        SGSetEnabled(kArtistLyricsWasEnabled, YES);
        SGSetEnabled(SGKeyLockScreenLyrics, NO);
    }
    return canvas;
}

CGFloat SGLockScreenCoverArtworkScale(void) {
    return (CGFloat)SGInt(SGKeyLockScreenCoverArtworkScale, 50) / 100.0;
}

void SGLockScreenCanvasLyricsSetEnabled(BOOL enabled) {
    SGSetEnabled(SGKeyLockScreenCanvasLyrics, enabled);
    if (enabled && SGEnabled(SGKeyLockScreenExclusiveLyrics) && SGFlag(SGKeyLockScreenLyrics, NO)) {
        SGSetEnabled(kArtistLyricsWasEnabled, YES);
        SGSetEnabled(SGKeyLockScreenLyrics, NO);
    } else if (!enabled && SGFlag(kArtistLyricsWasEnabled, NO)) {
        SGSetEnabled(SGKeyLockScreenLyrics, YES);
        SGSetEnabled(kArtistLyricsWasEnabled, NO);
    }
}

void SGLockScreenLyricsExclusivityChanged(BOOL enabled) {
    if (enabled) {
        (void)SGLockScreenCanvasLyricsEnabled();
    } else if (SGFlag(kArtistLyricsWasEnabled, NO)) {
        SGSetEnabled(SGKeyLockScreenLyrics, YES);
        SGSetEnabled(kArtistLyricsWasEnabled, NO);
    }
}

void SGLockScreenArtistLyricsChanged(BOOL enabled) {
    if (enabled && SGEnabled(SGKeyLockScreenExclusiveLyrics)) {
        SGLockScreenCanvasLyricsSetEnabled(NO);
    } else if (!enabled) {
        SGSetEnabled(kArtistLyricsWasEnabled, NO);
    }
}

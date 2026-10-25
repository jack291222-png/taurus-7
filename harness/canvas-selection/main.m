#import "Core/SGCore.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

NSArray *SGArtworkOrder(void) { return @[@"canvas", @"applemusic"]; }
void SGLogMessage(NSString *message) {}

static void require(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

static void setViews(NSArray *order, SGLockArtwork style, BOOL lyrics) {
    [NSUserDefaults.standardUserDefaults setObject:order forKey:SGKeyLockScreenStarViews];
    SGSetInt(SGKeyFullScreenArtwork, style);
    SGLockScreenCanvasLyricsSetEnabled(lyrics);
}

int main(void) {
    @autoreleasepool {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        SGSetEnabled(SGKeyLockScreenStar, YES);
        SGSetEnabled(SGKeyLockScreenLyrics, NO);
        [store removeObjectForKey:@"spotifyglass.lockscreen.starViews.migrated"];

        setViews(@[@"canvas", @"fill", @"colorful", @"default"], SGLockArtworkMotion, NO);
        SGLockScreenStarEnsureView();
        require([SGLockScreenCurrentStarView() isEqual:@"canvas"], @"Canvas is the configured first style");
        require(SGLockScreenSkipUnavailableMotion() == SGLockArtworkFill, @"Missing Canvas must use the next enabled style");
        require(SGLockScreenEffectiveArtwork() == SGLockArtworkFill, @"Fallback style must be applied to this track");
        require(SGLockScreenArtwork() == SGLockArtworkMotion, @"Fallback must not overwrite the configured style");
        require([SGLockScreenCurrentStarView() isEqual:@"canvas"], @"Fallback must not move the selected style");
        require([SGLockScreenStarViewOrder() isEqualToArray:@[@"canvas", @"fill", @"colorful", @"default"]],
                @"Fallback must not change the hierarchy");

        SGLockScreenSetEffectiveArtwork(SGLockScreenArtwork());
        require(SGLockScreenEffectiveArtwork() == SGLockArtworkMotion, @"A new track must retry the configured Canvas style");
        require(SGLockScreenSkipUnavailableMotion() == SGLockArtworkFill, @"Canvas fallback must follow the configured order again");

        setViews(@[@"fill", @"canvas", @"default"], SGLockArtworkMotion, NO);
        SGSetEnabled(SGKeyLockScreenStar, NO);
        SGLockScreenStarEnsureView();
        require(SGLockScreenArtwork() == SGLockArtworkFill, @"When Canvas is not first, use the first configured style");
        require(SGLockScreenEffectiveArtwork() == SGLockArtworkFill, @"Non-Canvas first style must bypass Canvas lookup");

        SGSetEnabled(SGKeyLockScreenStar, YES);
        setViews(@[@"canvas", @"lyrics", @"fill", @"colorful", @"default"], SGLockArtworkMotion, NO);
        SGLockScreenStarEnsureView();
        require(SGLockScreenSkipUnavailableMotion() == SGLockArtworkLyrics, @"Lyrics must be the next fallback when ordered after Canvas");
        require(SGLockScreenEffectiveArtwork() == SGLockArtworkLyrics, @"Lyrics fallback must activate the track-local lyrics style");
        SGLockScreenSetEffectiveArtwork(SGLockScreenArtwork());
        require(SGLockScreenEffectiveArtwork() == SGLockArtworkMotion, @"Canvas must be retried after a lyrics fallback on the previous track");

        NSArray *keys = @[@"canvas", @"lyrics", @"fill", @"colorful", @"default"];
        NSArray *styles = @[@(SGLockArtworkMotion), @(SGLockArtworkLyrics), @(SGLockArtworkFill),
                            @(SGLockArtworkEverySong), @(SGLockArtworkOff)];
        for (NSUInteger i = 0; i < keys.count; i++) {
            setViews(@[keys[i]], SGLockArtworkFill, NO);
            SGLockScreenStarEnsureView();
            require(SGLockScreenArtwork() == [styles[i] integerValue], @"Each single enabled view must select its style");
            require([SGLockScreenCurrentStarView() isEqual:keys[i]], @"Single-choice mode must report its selected style");
        }

        setViews(@[@"canvas", @"canvasLyrics", @"fill"], SGLockArtworkMotion, NO);
        require([SGLockScreenStarViewOrder() isEqualToArray:@[@"canvas", @"lyrics", @"fill"]],
                @"Legacy Canvas-lyrics style keys must migrate to Lyrics");
        setViews(@[@"canvas", @"bad", @"canvas", @"fill"], SGLockArtworkMotion, NO);
        require([SGLockScreenStarViewOrder() isEqualToArray:@[@"canvas", @"fill"]], @"Unknown and repeated views must be removed");

        setViews(@[], SGLockArtworkFill, NO);
        SGSetEnabled(SGKeyLockScreenStar, NO);
        require(SGLockScreenArtwork() == SGLockArtworkFill, @"An empty cycle must leave manual artwork selection intact");
        puts("PASS: ordered track-local fallback, Canvas retry, non-Canvas priority, Lyrics fallback and style migration");
    }
    return 0;
}

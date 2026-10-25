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
        setViews(@[@"canvas"], SGLockArtworkFill, NO);
        require([SGLockScreenStarViewOrder() isEqualToArray:@[@"canvas"]], @"Canvas-only order must not enable other styles");
        SGLockScreenStarEnsureView();
        require(SGLockScreenArtwork() == SGLockArtworkMotion && !SGLockScreenCanvasLyricsEnabled(), @"Canvas-only must replace a disabled Fill choice");
        for (NSUInteger track = 0; track < 5; track++) {
            require(SGLockScreenMotionFallbackView() == nil, @"Canvas-only must not fall back to disabled styles");
            require(SGLockScreenArtwork() == SGLockArtworkMotion, @"A missing Canvas must retain the saved choice for the next track");
        }
        SGLockScreenStarAdvanceView();
        require([SGLockScreenStarCurrentView() isEqual:@"canvas"], @"Single-choice cycling must stay on Canvas");
        NSArray *keys = @[@"canvas", @"canvasLyrics", @"fill", @"colorful", @"default"];
        NSArray *styles = @[@(SGLockArtworkMotion), @(SGLockArtworkMotion), @(SGLockArtworkFill), @(SGLockArtworkEverySong), @(SGLockArtworkOff)];
        for (NSUInteger i = 0; i < keys.count; i++) {
            setViews(@[keys[i]], SGLockArtworkFill, NO);
            SGLockScreenStarEnsureView();
            require(SGLockScreenArtwork() == [styles[i] integerValue], @"Each single enabled view must select its own style");
            require([SGLockScreenStarCurrentView() isEqual:keys[i]], @"Single-choice mode must retain its lyrics state");
        }
        setViews(@[@"canvas", @"fill", @"colorful", @"default"], SGLockArtworkMotion, NO);
        require([SGLockScreenMotionFallbackView() isEqual:@"fill"], @"Fallback must follow enabled order");
        require(SGLockScreenArtwork() == SGLockArtworkMotion, @"Fallback must not persist Fill");
        SGLockScreenStarAdvanceView();
        require([SGLockScreenStarCurrentView() isEqual:@"fill"], @"The explicit star action must still switch styles");
        SGLockScreenStarAdvanceView();
        require([SGLockScreenStarCurrentView() isEqual:@"colorful"], @"The explicit star action must follow configured order");
        setViews(@[@"canvas", @"default", @"fill"], SGLockArtworkMotion, NO);
        require([SGLockScreenMotionFallbackView() isEqual:@"default"], @"A preferred plain-cover fallback must remain first");
        setViews(@[@"canvas", @"canvasLyrics"], SGLockArtworkMotion, NO);
        require(SGLockScreenMotionFallbackView() == nil, @"A second motion view must not become a fallback without a clip");
        setViews(@[], SGLockArtworkFill, NO);
        SGLockScreenStarEnsureView();
        require(SGLockScreenArtwork() == SGLockArtworkFill, @"An empty cycle must leave manual artwork selection intact");
        SGSetEnabled(SGKeyLockScreenStar, NO);
        setViews(@[@"canvas"], SGLockArtworkFill, NO);
        SGLockScreenStarEnsureView();
        require(SGLockScreenArtwork() == SGLockArtworkFill, @"Disabling the star must keep manual mode selection");
        require(SGLockScreenMotionFallbackView() == nil, @"A disabled star cycle must not supply other styles");
        SGSetEnabled(SGKeyLockScreenStar, YES);
        setViews(@[@"canvas"], SGLockArtworkLyrics, NO);
        SGLockScreenStarEnsureView();
        require(SGLockScreenArtwork() == SGLockArtworkLyrics, @"Dedicated lyrics mode must remain independent");
        setViews(@[@"canvas", @"bad", @"canvas", @"fill"], SGLockArtworkMotion, NO);
        require([SGLockScreenStarViewOrder() isEqualToArray:@[@"canvas", @"fill"]], @"Unknown and repeated views must be removed");
        [store removeObjectForKey:SGKeyLockScreenStarViews];
        require(SGLockScreenStarViewOrder().count == 5, @"New users must retain the complete default view list");
        puts("PASS: Canvas-only persistence, five single-view choices, allowed fallbacks, explicit cycling and independent manual modes");
    }
    return 0;
}

// What the lock screen fills the screen with, the lyrics' style and whether the downloads run in Low Data
// Mode. iOS 26 and up only.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Settings/SGSourcesPage.h"
#import "AnimatedArtwork.h"
#import "Shared/LockScreenArtwork/LockScreenArtwork.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

static NSString *const kStarCanvas = @"canvas";
static NSString *const kStarCanvasLyrics = @"canvasLyrics";
static NSString *const kStarFill = @"fill";
static NSString *const kStarDefault = @"default";
static NSString *const kStarColorful = @"colorful";

NSArray *SGLockScreenMotionRows(void) {
    if (@available(iOS 26.0, *)) {
        SGLockScreenArtwork();   // moves the old switch over before the row reads the new key
        SGModRow *style = SGChoiceRow(@"Lyrics style", @"Still draws each line once; Animated breathes the cover behind it",
                                      SGKeyLockScreenLyricsStyle, @[@"Still", @"Animated"], 0);
        style.visible = ^BOOL { return SGLockScreenArtwork() == SGLockArtworkLyrics; };
        SGModRow *canvasLyrics = SGOptionRow(@"Canvas lyrics", @"Show synced lines over the moving artwork",
                                             SGKeyLockScreenCanvasLyrics);
        canvasLyrics.changed = ^(BOOL on) { SGLockScreenCanvasLyricsSetEnabled(on); };
        canvasLyrics.visible = ^BOOL { return SGLockScreenArtwork() == SGLockArtworkMotion; };
        SGModRow *exclusiveLyrics = SGSwitchRow(@"Automatically switch lyric styles",
            @"Turn off artist-name lyrics when Canvas lyrics turn on, and vice versa", SGKeyLockScreenExclusiveLyrics);
        exclusiveLyrics.changed = ^(BOOL on) { SGLockScreenLyricsExclusivityChanged(on); };
        SGModRow *star = SGOptionRow(@"Switch with the star", @"Cycle through the ordered lock-screen artwork views",
                                     SGKeyLockScreenStar);
        SGModRow *starViews = SGLockScreenStarViewsRow();
        starViews.visible = ^BOOL { return SGHidden(SGKeyLockScreenStar); };
        SGModRow *lowData = SGOptionRow(@"Download in Low Data Mode", @"Moving artwork, up to about 7 MB a song", SGKeyMotionLowData);
        lowData.visible = ^BOOL { return SGLockScreenArtwork() == SGLockArtworkMotion; };
        SGModRow *coverSize = SGSliderRow(@"Fallback album art size",
            @"Every song's colourful cover-and-blur treatment, even when Canvas or animated covers are available",
            0.25, 0.85, 0.05,
            ^double { return SGLockScreenCoverArtworkScale(); },
            ^(double value) { SGSetInt(SGKeyLockScreenCoverArtworkScale, (NSInteger)lround(value * 100)); },
            ^NSString *(double value) { return [NSString stringWithFormat:@"%.0f%%", value * 100]; });
        coverSize.visible = ^BOOL { return SGLockScreenArtwork() == SGLockArtworkEverySong; };
        SGModRow *sources = SGMotionSourcesRow();
        sources.visible = lowData.visible;
        return @[
            SGChoiceRow(@"Full-screen artwork", @"Moving artwork uses Canvas or Apple Music's animated cover; Lyrics shows synced lines. "
                                                 @"Every song always uses the colourful cover-and-blur look. "
                                                 @"Fill uses a sharp cover fading into progressively blurred artwork.",
                        SGKeyFullScreenArtwork, @[@"Off", @"Moving artwork", @"Lyrics", @"Every song", @"Fill"], SGLockArtworkOff),
            style,
            canvasLyrics,
            exclusiveLyrics,
            star,
            starViews,
            sources,
            lowData,
            coverSize,
        ];
    }
    return @[SGLockScreenArtworkNeedsRow()];
}

SGModRow *SGLockScreenStarViewsRow(void) {
    SGModRow *row = SGPageRow(@"Lock-screen star views", ^UIViewController *{
        NSArray<SGSource *> *views = @[
            [SGSource sourceWithKey:kStarCanvas name:@"Canvas" detail:@"The track's Canvas or its Apple Music animated cover"],
            [SGSource sourceWithKey:kStarCanvasLyrics name:@"Canvas with lyrics" detail:@"Synced lyrics over the moving artwork"],
            [SGSource sourceWithKey:kStarFill name:@"Fill" detail:@"The cover fading into progressively blurred artwork"],
            [SGSource sourceWithKey:kStarColorful name:@"Colourful" detail:@"Every Song: the custom moving-cover look, without source animations"],
            [SGSource sourceWithKey:kStarDefault name:@"Default" detail:@"iOS's full album artwork without an animated layer"],
        ];
        return SGSourcesPageMake(@"Lock-screen star views",
            @"Tap to enable or disable a view. Drag enabled views to choose the cycle order. "
             @"A fallback for a track without moving artwork does not change your selected view.",
            views, ^NSArray<NSString *> *{ return SGLockScreenStarViewOrder(); },
            ^(NSArray<NSString *> *keys) {
                [NSUserDefaults.standardUserDefaults setObject:keys forKey:SGKeyLockScreenStarViews];
                SGLockScreenStarEnsureView();
            });
    });
    row.value = ^NSString * {
        NSArray<NSString *> *current = SGLockScreenStarViewOrder();
        if (!current.count) return @"Off";
        NSString *first = [current.firstObject isEqualToString:kStarCanvas] ? @"Canvas"
            : [current.firstObject isEqualToString:kStarCanvasLyrics] ? @"Canvas with lyrics"
            : [current.firstObject isEqualToString:kStarFill] ? @"Fill"
            : [current.firstObject isEqualToString:kStarColorful] ? @"Colourful" : @"Default";
        return current.count == 1 ? first : [NSString stringWithFormat:@"%@ +%lu", first, (unsigned long)current.count - 1];
    };
    return SGWithSymbol(row, @"arrow.trianglehead.2.clockwise.rotate.90");
}

// Below iOS 26 the section stays, with one row that says why there is nothing to pick.
SGModRow *SGLockScreenArtworkNeedsRow(void) {
    return SGStatActionRow(@"Full-screen artwork", nil, ^NSString *{ return @"Needs iOS 26"; }, ^{
        NSString *message = [NSString stringWithFormat:@"This iPhone has iOS %@. The lock screen takes moving artwork "
                                                       @"from apps from iOS 26 on, so the Canvas and Apple Music's animated "
                                                       @"covers and Fill can show there once the iPhone is updated.", UIDevice.currentDevice.systemVersion];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Needs iOS 26" message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    });
}

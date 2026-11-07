// Remove the promotional tag only on Spotify's audio-quality page. Never hide
// an entire row: the option label, checkmark and touch handling remain native.
#import "Core/SGCore.h"
#import "AdBlock.h"

static char kQualityBadgeAlpha;
static NSString *qualityText(UIView *view) {
    NSString *text = nil;
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        text = label.text ?: label.attributedText.string;
    }
    if (!text.length) text = view.accessibilityLabel;
    text = [text stringByReplacingOccurrencesOfString:@"\uFFFC" withString:@""];
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
static BOOL qualitySays(UIView *view, NSString *word) {
    return [qualityText(view) caseInsensitiveCompare:word] == NSOrderedSame && qualityText(view).length > 0;
}
static void qualitySuppress(UIView *view) {
    if (!objc_getAssociatedObject(view, &kQualityBadgeAlpha))
        objc_setAssociatedObject(view, &kQualityBadgeAlpha, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.alpha = 0;
}
static void qualityRestore(UIView *view) {
    NSNumber *alpha = objc_getAssociatedObject(view, &kQualityBadgeAlpha);
    if (!alpha) return;
    view.alpha = alpha.doubleValue;
    objc_setAssociatedObject(view, &kQualityBadgeAlpha, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void qualityBadges(UIView *root) {
    NSMutableArray<UIView *> *options = [NSMutableArray array], *promos = [NSMutableArray array], *all = [NSMutableArray array];
    __block BOOL page = NO;
    SGForEachView(root, ^(UIView *view) {
        [all addObject:view];
        if (qualitySays(view, @"Media quality") || qualitySays(view, @"Audio download quality") ||
            qualitySays(view, @"Wi-Fi streaming quality") || qualitySays(view, @"Cellular streaming quality")) page = YES;
        if ([view isKindOfClass:UILabel.class] && qualitySays(view, @"Very high")) [options addObject:view];
        if ([view isKindOfClass:UILabel.class] && qualitySays(view, @"Premium")) [promos addObject:view];
    });
    // Restore reused views before identifying the current page's badges.
    for (UIView *view in all) qualityRestore(view);
    if (!page) return;
    for (UIView *promo in promos) {
        CGRect badge = [promo convertRect:promo.bounds toView:root];
        if (badge.size.width <= 0 || badge.size.height <= 0) continue;
        BOOL aligned = NO;
        for (UIView *option in options) {
            CGRect frame = [option convertRect:option.bounds toView:root];
            if (frame.size.width <= 0 || frame.size.height <= 0) continue;
            CGFloat tolerance = MAX(8, MIN(frame.size.height, badge.size.height) / 2);
            if (fabs(CGRectGetMidY(frame) - CGRectGetMidY(badge)) <= tolerance &&
                CGRectGetMinX(badge) >= CGRectGetMaxX(frame) - 2 &&
                CGRectGetMinX(badge) - CGRectGetMaxX(frame) < 200) { aligned = YES; break; }
        }
        if (!aligned) continue;
        qualitySuppress(promo);
        // Only a small image immediately before the word is its logo. In
        // particular, do not hide arbitrary siblings or trailing checkmarks.
        UIView *anchor = promo;
        for (int depth = 0; depth < 2 && anchor.superview; depth++, anchor = anchor.superview) {
            UIView *line = anchor.superview;
            CGRect word = [anchor convertRect:anchor.bounds toView:line];
            for (UIView *sibling in line.subviews) {
                if (![sibling isKindOfClass:UIImageView.class] || sibling == anchor) continue;
                CGRect image = [sibling convertRect:sibling.bounds toView:line];
                if (image.size.width <= 0 || image.size.height <= 0 || image.size.width > 28 || image.size.height > 24) continue;
                if (CGRectGetMaxX(image) > CGRectGetMinX(word) + 2 || CGRectGetMaxX(image) < CGRectGetMinX(word) - 28) continue;
                if (CGRectGetMidY(image) < CGRectGetMinY(word) - 4 || CGRectGetMidY(image) > CGRectGetMaxY(word) + 4) continue;
                qualitySuppress(sibling);
            }
        }
    }
}
%hook UIViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *root = ((UIViewController *)self).viewIfLoaded;
    if (root) qualityBadges(root);
}
%end
%ctor {
    if (!SGFlag(SGKeyHideUpsells, YES)) return;
    %init;
}

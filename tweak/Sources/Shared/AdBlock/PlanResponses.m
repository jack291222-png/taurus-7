#import "PlanResponses.h"
#import "Protobuf.h"

// Wire schema checked against jack291222-png/Spotifypremium, Master:
// Premium/Models/Protobuf/{SpotifyPlan,PremiumPlanRow,YourPremiumBadge}.pb.swift.
// Independently implemented using Taurus's existing protobuf reader/writer.
// Native Spotify owns the cards, layout, badge padding and Manage navigation.
static NSInteger planKind(NSURL *url) {
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"spotify.com"] && ![host hasSuffix:@".spotify.com"]) return 0;
    NSString *path = url.path.lowercaseString;
    if ([path hasSuffix:@"/getyourpremiumbadge"]) return 1;
    if ([path hasSuffix:@"/v1/getpremiumplanrow"]) return 2;
    if ([path hasSuffix:@"/getplanoverview"]) return 3;
    return 0;
}
BOOL SGIsPlanResponseURL(NSURL *url) { return planKind(url) != 0; }

static void replaceFields(NSMutableArray<SGPBField *> *fields, NSArray<NSNumber *> *numbers,
                          NSArray<SGPBField *> *replacement) {
    NSIndexSet *remove = [fields indexesOfObjectsPassingTest:^BOOL(SGPBField *field, NSUInteger index, BOOL *stop) {
        return [numbers containsObject:@(field.number)];
    }];
    [fields removeObjectsAtIndexes:remove];
    [fields addObjectsFromArray:replacement];
}

NSData *SGPatchPlanResponse(NSURL *url, NSData *body) {
    NSInteger kind = planKind(url);
    if (!kind || !body) return nil;
    NSMutableArray<SGPBField *> *fields = SGPBParse(body);
    if (!fields) return nil; // Unknown/malformed payload: pass through, never destroy it.
    NSString *green = @"#1ED760";
    if (kind == 1) {
        replaceFields(fields, @[@1, @2, @3], @[
            SGPBString(1, @"Individual"), SGPBVarint(2, 2), SGPBString(3, green)
        ]);
    } else if (kind == 2) {
        // Preserve action text, billing labels and fields this client does not know.
        replaceFields(fields, @[@3, @4, @18], @[
            SGPBString(3, @"Individual"), SGPBString(4, green), SGPBString(18, @"Individual")
        ]);
    } else {
        SGPBField *original = SGPBFirst(fields, 1);
        if (original && original.wire != 2) return nil;
        NSMutableArray<SGPBField *> *subscription = original ? SGPBParse(original.payload) : [NSMutableArray array];
        if (!subscription) return nil;
        NSMutableArray<SGPBField *> *display = [NSMutableArray arrayWithArray:@[
            SGPBVarint(2, 2), SGPBString(3, @"Individual"),
            SGPBString(4, @"Individual"), SGPBString(5, green)
        ]];
        NSArray<NSString *> *benefits = @[@"Ad-free music listening", @"Download to listen offline",
            @"Play songs in any order", @"High quality audio", @"Listen with friends in real time",
            @"Organise listening queue"];
        for (NSString *benefit in benefits) {
            NSData *feature = SGPBSerialize(@[SGPBVarint(1, 1), SGPBString(2, benefit), SGPBString(4, @"#1ED760")]);
            [display addObject:SGPBBytes(20, feature)];
        }
        replaceFields(subscription, @[@2, @3, @4, @5, @20], display);
        // The fork supplies a notice even for an empty/free overview. Seed only
        // a generic local-preview notice when absent; never replace real billing.
        if (!SGPBFirst(fields, 2)) {
            NSData *notice = SGPBSerialize(@[
                SGPBString(1, @"Local plan preview. Manage your actual plan on Spotify’s website."),
                SGPBVarint(7, 2)
            ]);
            [fields addObject:SGPBBytes(2, notice)];
        }
        // Keep existing actions (including Manage) and unknown root fields intact.
        // Do not invent renewal dates, payment cards, or prices.
        replaceFields(fields, @[@1], @[SGPBBytes(1, SGPBSerialize(subscription))]);
    }
    return SGPBSerialize(fields);
}

NSData *SGImmediatePlanBadge(NSURL *url) {
    if (planKind(url) != 1) return nil;
    return SGPatchPlanResponse(url, [NSData data]);
}

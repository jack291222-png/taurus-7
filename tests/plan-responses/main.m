#import <Foundation/Foundation.h>
#import "PlanResponses.h"
#import "Protobuf.h"

static NSURL *endpoint(NSString *name) {
    return [NSURL URLWithString:[@"https://spclient.wg.spotify.com/pam-view-service/v1/" stringByAppendingString:name]];
}
static NSArray<SGPBField *> *parse(NSData *data) {
    NSCAssert(data != nil, @"expected a rewritten message");
    NSArray *fields = SGPBParse(data);
    NSCAssert(fields != nil, @"invalid rewritten protobuf");
    return fields;
}
int main(void) {
    @autoreleasepool {
        NSURL *overview = endpoint(@"GetPlanOverview");
        NSData *immediateBadge = SGImmediatePlanBadge(endpoint(@"GetYourPremiumBadge"));
        NSCAssert(immediateBadge != nil, @"badge does not need server data");
        NSCAssert([SGPBText(SGPBFirst(parse(immediateBadge), 1)) isEqualToString:@"Individual"], @"immediate badge name");
        NSCAssert([SGPBText(SGPBFirst(parse(immediateBadge), 3)) isEqualToString:@"#1ED760"], @"immediate badge color");
        NSCAssert(SGImmediatePlanBadge(overview) == nil, @"do not short circuit overview or native Manage actions");
        NSCAssert(SGImmediatePlanBadge(endpoint(@"GetPremiumPlanRow")) == nil, @"do not short circuit row actions");
        NSCAssert(SGImmediatePlanBadge([NSURL URLWithString:@"https://evilspotify.com/v1/GetYourPremiumBadge"]) == nil, @"immediate badge host boundary");
        NSCAssert(SGIsPlanResponseURL(overview), @"overview route");
        NSCAssert(!SGIsPlanResponseURL([NSURL URLWithString:@"https://evilspotify.com/v1/GetPlanOverview"]), @"host boundary");
        NSCAssert(!SGIsPlanResponseURL(endpoint(@"GetBilling")), @"billing must pass through");
        NSCAssert(!SGIsPlanResponseURL(endpoint(@"GetPlanOverviewExtra")), @"route boundary");
        NSCAssert(SGPatchPlanResponse(overview, nil) == nil, @"missing body");
        uint8_t truncated[] = {0x0a, 0xff};
        NSCAssert(SGPatchPlanResponse(overview, [NSData dataWithBytes:truncated length:sizeof(truncated)]) == nil, @"malformed body");
        NSArray *emptyOverview = parse(SGPatchPlanResponse(overview, [NSData data]));
        NSCAssert(SGPBFirst(emptyOverview, 1) != nil, @"empty overview gains native subscription");
        NSCAssert(SGPBFirst(emptyOverview, 2) != nil, @"empty overview gains generic notice");
        NSData *unknown = SGPBSerialize(@[SGPBVarint(99, 123)]);
        NSArray *badge = parse(SGPatchPlanResponse(endpoint(@"GetYourPremiumBadge"), unknown));
        NSCAssert([SGPBText(SGPBFirst(badge, 1)) isEqualToString:@"Individual"], @"badge words");
        NSCAssert([SGPBText(SGPBFirst(badge, 3)) isEqualToString:@"#1ED760"], @"badge color");
        NSCAssert(SGPBFirst(badge, 2).varint == 2, @"badge version");
        NSCAssert(SGPBFirst(badge, 99).varint == 123, @"badge unknown fields");
        NSData *rowInput = SGPBSerialize(@[SGPBString(3, @"Free"), SGPBString(9, @"Manage"), SGPBVarint(99, 456)]);
        NSArray *row = parse(SGPatchPlanResponse(endpoint(@"GetPremiumPlanRow"), rowInput));
        NSCAssert([SGPBText(SGPBFirst(row, 3)) isEqualToString:@"Individual"], @"row name");
        NSCAssert([SGPBText(SGPBFirst(row, 9)) isEqualToString:@"Manage"], @"row action survives");
        NSCAssert(SGPBFirst(row, 99).varint == 456, @"row unknown fields");
        NSData *sub = SGPBSerialize(@[SGPBString(3, @"Free"), SGPBString(4, @"Premium"), SGPBString(19, @"original-background"), SGPBVarint(99, 789)]);
        NSData *actions = SGPBSerialize(@[SGPBString(1, @"manage-action")]);
        NSData *notice = SGPBSerialize(@[SGPBString(1, @"original billing notice")]);
        NSData *input = SGPBSerialize(@[SGPBBytes(1, sub), SGPBBytes(2, notice), SGPBBytes(3, actions), SGPBVarint(99, 42)]);
        NSData *output = SGPatchPlanResponse(overview, input);
        NSArray *root = parse(output);
        NSCAssert([SGPBFirst(root, 3).payload isEqual:actions], @"native Manage actions survive");
        NSCAssert([SGPBFirst(root, 2).payload isEqual:notice], @"real notice survives");
        NSCAssert(SGPBFirst(root, 99).varint == 42, @"root unknown field");
        NSArray *subscription = parse(SGPBFirst(root, 1).payload);
        NSCAssert([SGPBText(SGPBFirst(subscription, 3)) isEqualToString:@"Individual"], @"plan name");
        NSCAssert([SGPBText(SGPBFirst(subscription, 4)) isEqualToString:@"Individual"], @"native category heading must also be Individual");
        NSCAssert([SGPBText(SGPBFirst(subscription, 5)) isEqualToString:@"#1ED760"], @"plan color");
        NSCAssert(SGPBFirst(subscription, 99).varint == 789, @"nested unknown field");
        NSUInteger count = 0;
        NSMutableArray *titles = [NSMutableArray array];
        for (SGPBField *field in subscription) {
            if (field.number != 20) continue;
            NSArray *feature = parse(field.payload);
            NSCAssert(SGPBFirst(feature, 1).varint == 1, @"native checkmark icon");
            [titles addObject:SGPBText(SGPBFirst(feature, 2)) ?: @"" ];
            NSCAssert([SGPBText(SGPBFirst(feature, 4)) isEqualToString:@"#1ED760"], @"benefit accent");
            count++;
        }
        NSArray *expected = @[@"Ad-free music listening", @"Download to listen offline", @"Play songs in any order", @"High quality audio", @"Listen with friends in real time", @"Organise listening queue"];
        NSCAssert(count == 6 && [titles isEqualToArray:expected], @"exact benefit titles");
        NSCAssert([SGPatchPlanResponse(overview, output) isEqual:output], @"patch is idempotent");
        puts("Plan response tests passed");
    }
    return 0;
}

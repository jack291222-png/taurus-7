#import "Core/SGCore.h"
#import "AdBlock.h"
#import "PlanResponses.h"

// The fork constructs YourPremiumBadge entirely locally. Serve that same small
// display model before waiting on account/network data, not after a fetch ends.
// No UILabel overlay, background recoloring, or private loading-view selectors.
@interface SGPlanBadgeProtocol : NSURLProtocol
@end
@implementation SGPlanBadgeProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [request.HTTPMethod isEqualToString:@"GET"] && SGImmediatePlanBadge(request.URL) != nil;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSData *data = SGImmediatePlanBadge(self.request.URL);
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
        statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{
            @"Content-Type": @"application/x-protobuf",
            @"Content-Length": [NSString stringWithFormat:@"%lu", (unsigned long)data.length],
            @"Cache-Control": @"no-store"
        }];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading { /* No network task or asynchronous work to cancel. */ }
@end

static NSURLSessionConfiguration *badgeConfiguration(NSURLSessionConfiguration *configuration) {
    // Background sessions do not support custom URL protocols.
    if (configuration.identifier.length || [configuration.protocolClasses containsObject:SGPlanBadgeProtocol.class]) return configuration;
    NSURLSessionConfiguration *copy = [configuration copy];
    NSMutableArray *protocols = [NSMutableArray arrayWithObject:SGPlanBadgeProtocol.class];
    [protocols addObjectsFromArray:copy.protocolClasses ?: @[]];
    copy.protocolClasses = protocols;
    return copy;
}

%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration { return badgeConfiguration(%orig); }
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration { return badgeConfiguration(%orig); }
%end

%hook NSURLSession
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    return %orig(badgeConfiguration(configuration), delegate, queue);
}
%end

%ctor {
    %init;
}

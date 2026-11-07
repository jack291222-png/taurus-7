#import <Foundation/Foundation.h>

// Local display payloads only. Never modify billing endpoints or account entitlements.
BOOL SGIsPlanResponseURL(NSURL *url);
NSData *SGPatchPlanResponse(NSURL *url, NSData *body);

// Small deterministic display reply, available before any account/network fetch.
NSData *SGImmediatePlanBadge(NSURL *url);

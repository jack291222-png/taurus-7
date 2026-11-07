#import "Core/SGCore.h"
#import "AdBlock.h"
#import "PlanResponses.h"

// Same model-first approach as the reference fork: Spotify sees only the
// completed, rewritten response. Completion-handler tasks need their own path;
// they need not deliver body data to the delegates hooked in AdNetwork.x.
static void (^planCompletion(NSURL *url, void (^completion)(NSData *, NSURLResponse *, NSError *)))
    (NSData *, NSURLResponse *, NSError *) {
    if (!completion || !SGIsPlanResponseURL(url)) return completion;
    return [^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { completion(data, response, error); return; }
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        NSData *patched = nil;
        if (http.statusCode == 304) {
            // A deterministic badge does not need an HTTP cache body. Do not
            // invent row/actions when an overview or plan row has no payload.
            patched = SGImmediatePlanBadge(url);
            if (patched) response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200
                HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/x-protobuf"}];
        } else if (!http || (http.statusCode >= 200 && http.statusCode < 300)) {
            if (data.length) patched = SGPatchPlanResponse(url, data);
            else patched = SGImmediatePlanBadge(url);
        }
        completion(patched ?: data, response, nil);
    } copy];
}

%group PlanCompletionBase
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    return %orig(request, planCompletion(request.URL, completion));
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    return %orig(url, planCompletion(url, completion));
}
%end
%end

// Only hook subclass-owned implementations. Inherited methods already reach
// the base hook; installing them twice would wrap/rewrite a response twice.
%group PlanCompletionLocalRequest
%hook __NSURLSessionLocal
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    return %orig(request, planCompletion(request.URL, completion));
}
%end
%end
%group PlanCompletionLocalURL
%hook __NSURLSessionLocal
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    return %orig(url, planCompletion(url, completion));
}
%end
%end

%ctor {
    %init(PlanCompletionBase);
    Class local = objc_getClass("__NSURLSessionLocal");
    if (!local) return;
    SEL request = @selector(dataTaskWithRequest:completionHandler:);
    if (class_getInstanceMethod(local, request) != class_getInstanceMethod(NSURLSession.class, request)) {
        %init(PlanCompletionLocalRequest);
    }
    SEL url = @selector(dataTaskWithURL:completionHandler:);
    if (class_getInstanceMethod(local, url) != class_getInstanceMethod(NSURLSession.class, url)) {
        %init(PlanCompletionLocalURL);
    }
}

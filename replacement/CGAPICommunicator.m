//
// CGAPICommunicator.m — modern OpenAI Responses transport for iOS 16
//
#import "CGAPICommunicator.h"

@implementation CGAPICommunicator

+ (void)cg_finishWithError:(NSString *)message {
    CGMessage *visual = [CGAPIHelper loopErrorBack:(message.length ? message : @"The request failed.")];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"CANCEL LOAD" object:nil];
        [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:visual];
    });
}

+ (void)cg_sendJSONRequest:(NSMutableURLRequest *)request completion:(void (^)(NSDictionary *, NSHTTPURLResponse *, NSError *))completion {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 90.0;
    config.timeoutIntervalForResource = 180.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = nil;
        NSError *jsonError = nil;
        if (data.length) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if ([object isKindOfClass:[NSDictionary class]]) json = object;
        }
        completion(json, (NSHTTPURLResponse *)response, error ?: jsonError);
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

+ (NSString *)cg_errorMessageFromJSON:(NSDictionary *)json status:(NSInteger)status error:(NSError *)error {
    if (error) return error.localizedDescription ?: @"Network request failed.";
    id errorObject = [json objectForKey:@"error"];
    if ([errorObject isKindOfClass:[NSDictionary class]]) {
        id message = [errorObject objectForKey:@"message"];
        if ([message isKindOfClass:[NSString class]] && [message length]) return message;
    }
    if (status < 200 || status >= 300) return [NSString stringWithFormat:@"OpenAI returned HTTP %ld.", (long)status];
    return nil;
}

+ (NSString *)cg_outputTextFromResponse:(NSDictionary *)json {
    id direct = [json objectForKey:@"output_text"];
    if ([direct isKindOfClass:[NSString class]] && [direct length]) return direct;
    id output = [json objectForKey:@"output"];
    if (![output isKindOfClass:[NSArray class]]) return nil;
    NSMutableString *combined = [NSMutableString string];
    for (id item in (NSArray *)output) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        id contents = [item objectForKey:@"content"];
        if (![contents isKindOfClass:[NSArray class]]) continue;
        for (id part in (NSArray *)contents) {
            if (![part isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = [part objectForKey:@"type"];
            NSString *text = [part objectForKey:@"text"];
            if (([type isEqualToString:@"output_text"] || [type isEqualToString:@"text"]) && [text isKindOfClass:[NSString class]]) {
                if (combined.length) [combined appendString:@"\n"];
                [combined appendString:text];
            }
        }
    }
    return combined.length ? combined : nil;
}

+ (void)createChatCompletionwithContent:(NSMutableArray *)content {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"THINK STATUS" object:nil];
    });

    id storedAPIKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"apiKey"];
    NSString *openAIAPIKey = [storedAPIKey isKindOfClass:[NSString class]] ? (NSString *)storedAPIKey : nil;
    if (openAIAPIKey.length == 0) {
        [self cg_finishWithError:@"No OpenAI API key is configured."];
        return;
    }

    NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/responses", domain]];
    if (!endpoint) { [self cg_finishWithError:@"Invalid API endpoint."]; return; }

    NSMutableArray *input = [NSMutableArray array];
    BOOL useWeb = [[NSUserDefaults standardUserDefaults] boolForKey:@"c-webSearch"];
    CGMessage *lastMessage = content.lastObject;
    if ([lastMessage.content hasPrefix:@"/web "]) useWeb = YES;
    for (CGMessage *message in content) {
        if (![message isKindOfClass:[CGMessage class]]) continue;
        if (message.type == 2 && message.imageHash.length) continue; // generated image display row
        NSString *role = [message.role isEqualToString:@"assistant"] ? @"assistant" : @"user";
        NSMutableArray *parts = [NSMutableArray array];
        NSString *text = message.content;
        if (message == lastMessage && [text hasPrefix:@"/web "]) text = [text substringFromIndex:5];
        if (text.length) [parts addObject:@{ @"type": @"input_text", @"text": text }];
        if (message.imageHash.length && [role isEqualToString:@"user"]) {
            [parts addObject:@{ @"type": @"input_image", @"image_url": [NSString stringWithFormat:@"data:image/png;base64,%@", message.imageHash] }];
        }
        if (parts.count) [input addObject:@{ @"role": role, @"content": parts }];
    }

    NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"c-aiModel"];
    if (!model.length) model = @"gpt-6-luna";
    NSMutableDictionary *body = [@{ @"model": model, @"input": input } mutableCopy];
    if (useWeb) {
        body[@"tools"] = @[ @{ @"type": @"web_search" } ];
    }

    NSError *encodeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encodeError];
    if (!jsonData) { [self cg_finishWithError:encodeError.localizedDescription]; return; }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", openAIAPIKey] forHTTPHeaderField:@"Authorization"];

    [self cg_sendJSONRequest:request completion:^(NSDictionary *json, NSHTTPURLResponse *response, NSError *error) {
        NSString *problem = [self cg_errorMessageFromJSON:json status:response.statusCode error:error];
        if (problem) { [self cg_finishWithError:problem]; return; }
        NSString *text = [self cg_outputTextFromResponse:json];
        if (!text.length) { [self cg_finishWithError:@"OpenAI returned no displayable text."]; return; }
        CGMessage *message = [CGAPIHelper assistantMessageWithText:text];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:message];
        });
    }];
}

+ (void)createImageGenerationWithContent:(NSString *)content {
    id storedAPIKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"apiKey"];
    NSString *openAIAPIKey = [storedAPIKey isKindOfClass:[NSString class]] ? (NSString *)storedAPIKey : nil;
    if (openAIAPIKey.length == 0) { [self cg_finishWithError:@"No OpenAI API key is configured."]; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"THINK STATUS" object:nil];
    });
    NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/images/generations", domain]];
    NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"i-aiModel"];
    if (!model.length) model = @"gpt-image-2";
    NSDictionary *body = @{ @"model": model, @"prompt": content ?: @"", @"n": @1, @"size": @"1024x1024" };
    NSError *encodeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encodeError];
    if (!jsonData) { [self cg_finishWithError:encodeError.localizedDescription]; return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", openAIAPIKey] forHTTPHeaderField:@"Authorization"];
    [self cg_sendJSONRequest:request completion:^(NSDictionary *json, NSHTTPURLResponse *response, NSError *error) {
        NSString *problem = [self cg_errorMessageFromJSON:json status:response.statusCode error:error];
        if (problem) { [self cg_finishWithError:problem]; return; }
        CGMessage *message = [CGAPIHelper convertImageGenerationResponse:json];
        if (!message) { [self cg_finishWithError:@"Image generation returned an unexpected response."]; return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:message];
        });
    }];
}
@end

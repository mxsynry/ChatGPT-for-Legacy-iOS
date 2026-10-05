//
// CGAPICommunicator.m — modern arm64 transport patch
//
#import "CGAPICommunicator.h"

@implementation CGAPICommunicator

+ (NSData *)cg_sendRequest:(NSURLRequest *)request response:(NSURLResponse **)outResponse error:(NSError **)outError {
    __block NSData *resultData = nil;
    __block NSURLResponse *resultResponse = nil;
    __block NSError *resultError = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 90.0;
    config.timeoutIntervalForResource = 120.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        resultData = data;
        resultResponse = response;
        resultError = error;
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    [session finishTasksAndInvalidate];

    if (outResponse) *outResponse = resultResponse;
    if (outError) *outError = resultError;
    return resultData;
}

+ (void)createChatCompletionwithContent:(NSMutableArray *)content {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"THINK STATUS" object:nil];
        });

        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/chat/completions", domain]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
        NSMutableArray *messagesArray = [NSMutableArray array];

        for (CGMessage *message in content) {
            if (message.type == 2 && message.imageHash != nil) continue;

            NSMutableDictionary *messageDict = [NSMutableDictionary dictionary];
            messageDict[@"role"] = message.role ?: @"user";

            NSMutableArray *contentArray = [NSMutableArray array];
            if (message.content.length > 0) {
                [contentArray addObject:@{@"type": @"text", @"text": message.content}];
            }
            if (message.imageHash) {
                [contentArray addObject:@{
                    @"type": @"image_url",
                    @"image_url": @{@"url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", message.imageHash]}
                }];
            }
            messageDict[@"content"] = contentArray;
            [messagesArray addObject:messageDict];
        }

        NSString *model = [[NSUserDefaults standardUserDefaults] objectForKey:@"c-aiModel"];
        if (model.length == 0) model = @"gpt-4o-mini";

        NSError *jsonError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{
            @"model": model,
            @"messages": messagesArray
        } options:0 error:&jsonError];

        if (!jsonData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"CANCEL LOAD" object:nil];
                [CGAPIHelper alert:@"Request Error" withMessage:jsonError.localizedDescription ?: @"Unable to encode request."];
            });
            return;
        }

        request.HTTPMethod = @"POST";
        request.HTTPBody = jsonData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey ?: @""] forHTTPHeaderField:@"Authorization"];

        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [self cg_sendRequest:request response:&response error:&error];

        if (!data) {
            CGMessage *visualEM = [CGAPIHelper loopErrorBack:
                @"The request could not reach the API. Check your connection and API settings, then try again."];
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"CANCEL LOAD" object:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:visualEM];
            });
            return;
        }

        NSError *parseError = nil;
        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        NSDictionary *errorDict = [parsedResponse objectForKey:@"error"];

        if (errorDict) {
            NSString *message = [errorDict objectForKey:@"message"] ?: @"Unknown API error.";
            CGMessage *visualEM = [CGAPIHelper loopErrorBack:message];
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:visualEM];
                [CGAPIHelper alert:@"Warning" withMessage:message];
            });
            return;
        }

        if (!parsedResponse || parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"CANCEL LOAD" object:nil];
                [CGAPIHelper alert:@"Response Error" withMessage:parseError.localizedDescription ?: @"Invalid API response."];
            });
            return;
        }

        CGMessage *convertedMessage = [CGAPIHelper convertTextCompletionResponse:parsedResponse];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:convertedMessage];
        });
    });
}

+ (void)createImageGenerationWithContent:(NSString *)content {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"THINK STATUS" object:nil];
        });

        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/images/generations", domain]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];

        NSString *model = [[NSUserDefaults standardUserDefaults] objectForKey:@"i-aiModel"];
        if (model.length == 0) model = @"dall-e-3";

        NSError *jsonError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{
            @"model": model,
            @"prompt": content ?: @"",
            @"n": @1,
            @"size": @"1024x1024",
            @"response_format": @"b64_json"
        } options:0 error:&jsonError];

        if (!jsonData) return;

        request.HTTPMethod = @"POST";
        request.HTTPBody = jsonData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey ?: @""] forHTTPHeaderField:@"Authorization"];

        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [self cg_sendRequest:request response:&response error:&error];

        if (!data) {
            CGMessage *visualEM = [CGAPIHelper loopErrorBack:@"Image generation request failed to connect."];
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"CANCEL LOAD" object:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:visualEM];
            });
            return;
        }

        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSDictionary *errorDict = [parsedResponse objectForKey:@"error"];
        if (errorDict) {
            NSString *message = [errorDict objectForKey:@"message"] ?: @"Unknown API error.";
            CGMessage *visualEM = [CGAPIHelper loopErrorBack:message];
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:visualEM];
                [CGAPIHelper alert:@"Warning" withMessage:message];
            });
            return;
        }

        CGMessage *convertedMessage = [CGAPIHelper convertImageGenerationResponse:parsedResponse];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"AI RESPONSE" object:convertedMessage];
        });
    });
}
@end

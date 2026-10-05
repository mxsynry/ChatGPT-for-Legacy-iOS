//
//  CGAPIHelper.m
//  ChatGPT
//
//  Created by XML on 1/13/25.
//  Copyright (c) 2025 XML. All rights reserved.
//

#import "CGAPIHelper.h"

@implementation CGAPIHelper

+ (NSString *)conversationDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *dir = [base stringByAppendingPathComponent:@"Conversations"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (void)checkForAppUpdate {
    //this is just via the "XML Update Server"
    //disable this if you'd like (check the header)
    if(updateChecks == YES) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *randomEndpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/update?v=%@", UDCheckServer, appVersion]];
            NSURLResponse *response;
            NSError *error;
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            [request setURL:randomEndpoint];
            [request setHTTPMethod:@"GET"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            if(data) {
                NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                
                NSNumber *update = response[@"outdated"];
                NSString *message = response[@"message"];
                
                if ([update intValue] == 1) {
                    [CGAPIHelper alert:@"Good news!" withMessage:message];
                } else {
                    return;
                }
            } else {
                return;
            }

        });
    }
    return;
}

+ (void)checkForAPIKeyValidity {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *randomEndpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/models", domain]];
        NSURLResponse *response;
        NSError *error;

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:randomEndpoint];
        [request setHTTPMethod:@"GET"];
        [request setHTTPBody:nil];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if(data) {
            NSDictionary* parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSDictionary *errorDict = [parsedResponse objectForKey:@"error"];
            if(errorDict) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [CGAPIHelper alert:@"Warning" withMessage:[NSString stringWithFormat:@"%@", [errorDict objectForKey:@"message"]]];
                });
                
                return;
            } else if(!errorDict) {
                //[NSNotificationCenter.defaultCenter postNotificationName:@"KEY IS VALID" object:nil];
            }
        } else if(!data) {
            if(error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [CGAPIHelper alert:@"Fatal Error" withMessage:@"Please check your internet connection."];
                });
                return;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [CGAPIHelper alert:@"Fatal Error" withMessage:[NSString stringWithFormat:@"An unknown error has occured."]];
                });
                return;
            }
        }
    });
}

+ (void)logInUserwithKey:(NSString*)key {
    if (key.length == 0) {
        [NSNotificationCenter.defaultCenter postNotificationName:@"LOG-IN FAILURE" object:nil];
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/models", domain]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
        request.HTTPMethod = @"GET";
        [request setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block NSInteger status = 0; __block NSError *requestError = nil; __block NSData *responseData = nil;
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            responseData = data; requestError = error; status = [(NSHTTPURLResponse *)response statusCode]; dispatch_semaphore_signal(sem);
        }];
        [task resume]; dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
        if (requestError || status < 200 || status >= 300) {
            NSString *message = requestError.localizedDescription ?: @"The API key was rejected.";
            if (responseData.length) {
                NSDictionary *j = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
                NSString *server = [j[@"error"] isKindOfClass:[NSDictionary class]] ? j[@"error"][@"message"] : nil;
                if ([server isKindOfClass:[NSString class]]) message = server;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ [self alert:@"Login failed" withMessage:message]; [NSNotificationCenter.defaultCenter postNotificationName:@"LOG-IN FAILURE" object:nil]; });
            return;
        }
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasLoggedInUser"];
        [[NSUserDefaults standardUserDefaults] setObject:@"You" forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"apiKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:@"LOG-IN VALID" object:nil]; });
    });
}

+ (void)saveConversationWithArray:(NSMutableArray *)conversationArray withID:(NSString *)uuid withTitle:(NSString *)title{
    NSMutableArray *messagesArray = [NSMutableArray array];
    for (CGMessage *message in conversationArray) {
        NSMutableDictionary *messageDict = [@{
                                              @"name": message.author ?: @"You",
                                              @"role": message.role ?: @"user",
                                              @"type": @(message.type),
                                              @"message": message.content ?: @""
                                              } mutableCopy];
        
        if (message.imageHash) {
            messageDict[@"image"] = @{@"url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", message.imageHash]};
        }
        
        [messagesArray addObject:messageDict];
    }

    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MM-yyyy"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString *ConvTitle = title;
    if([title isEqualToString:@"Chat"]) {
        ConvTitle = [NSString stringWithFormat:@"Chat, at %@", dateString];
    }
    NSDictionary *conversationDict = @{
                                       @"conversationID": uuid,
                                       @"title": ConvTitle,
                                       @"createdAt": dateString,
                                       @"messages": messagesArray
                                       }; //add exact time measurements to edits
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:conversationDict options:NSJSONWritingPrettyPrinted error:nil];

    NSURL *fileURL = [NSURL fileURLWithPath:[[self conversationDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", uuid]]];
    // Write data using writeToURL]
    BOOL success = [jsonData writeToURL:fileURL options:NSDataWritingAtomic error:nil];
    if (success)
        return;
}

+ (NSMutableArray*)loadConversations {
    NSMutableArray *conversations = [NSMutableArray array];
    
    NSString *directoryPath = [self conversationDirectory];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:nil];
    
    for (NSString *fileName in files) {
        if (![fileName hasSuffix:@".json"]) continue;
        NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        id decoded = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![decoded isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *conversationDict = decoded;
        
        CGConversation *conversation = CGConversation.new;
        conversation.uuid = conversationDict[@"conversationID"];
        conversation.title = conversationDict[@"title"];
        conversation.creationDate = conversationDict[@"createdAt"];
        conversation.messages = [NSMutableArray array];
        
        NSArray *messagesArray = [conversationDict[@"messages"] isKindOfClass:[NSArray class]] ? conversationDict[@"messages"] : @[];
        conversation.messageCount = (int)messagesArray.count;
        
        for (NSDictionary *messageDict in messagesArray) {
            if (![messageDict isKindOfClass:[NSDictionary class]]) continue;
            CGMessage *message = CGMessage.new;
            message.role = messageDict[@"role"];
            message.type = [messageDict[@"type"] intValue];
            message.content = [messageDict[@"message"] isKindOfClass:[NSString class]] ? messageDict[@"message"] : @"";
            
            float contentWidth = UIScreen.mainScreen.bounds.size.width - 63;
            CGSize textSize = [message.content sizeWithFont:[UIFont systemFontOfSize:15]
                                             constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT)
                                                 lineBreakMode:NSLineBreakByWordWrapping];
            message.contentHeight = textSize.height + 50;
            
            message.author = messageDict[@"name"];
            if(message.type == 1) {
                //hmm
                NSString *filePath = [directoryPath stringByAppendingPathComponent:@"avatar.png"];
                UIImage *image = [UIImage imageWithContentsOfFile:filePath];
                
                if (image) {
                    message.avatar = image;
                } else {
                    message.avatar = [UIImage imageNamed:@"defaultUserAvatar"];
                }
            } else if(message.type == 2) {
                message.avatar = [UIImage imageNamed:@"defaultAssistantAvatar"];
            }
            
            
            
            if (messageDict[@"image"] && [messageDict[@"image"] isKindOfClass:[NSDictionary class]]) {
                NSString *imageURL = messageDict[@"image"][@"url"];
                if ([imageURL hasPrefix:@"data:image/jpeg;base64,"]) {
                    NSString *base64String = [imageURL stringByReplacingOccurrencesOfString:@"data:image/jpeg;base64," withString:@""];
                    
                    NSData *imageData = [NSData dataWithBase64EncodedString:base64String];
                    message.imageAttachment = [UIImage imageWithData:imageData];
                }
            

            }
            [conversation.messages addObject:message];
        }
        [conversations addObject:conversation];
    }
    return conversations;
}

+ (BOOL)deleteConversationWithUUID:(NSString *)uuid {
    NSString *filePath = [[self conversationDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", uuid]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:filePath]) {
        BOOL success = [fileManager removeItemAtPath:filePath error:nil];
        if (success) {
            return YES;
        } else {
            [CGAPIHelper alert:@"Error" withMessage:@"An error occured when trying to delete this conversation."];
            return NO;
        }
        
    } else {
        [CGAPIHelper alert:@"Error" withMessage:@"An error occured when trying to delete this conversation."];
        return NO;
    }
}

+ (BOOL)deleteAllConversations {
    NSString *tempDirectory = [self conversationDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:tempDirectory error:&error];
    BOOL allDeleted = YES;
    
    for(NSString *file in files) {
        if([file.pathExtension isEqualToString:@"json"]) {
            NSString *filePath = [tempDirectory stringByAppendingPathComponent:file];
            BOOL success = [fileManager  removeItemAtPath:filePath error:&error];
            
            if(!success) {
                allDeleted = NO;
            }
        }
    }
    
    if(!allDeleted) {
        [CGAPIHelper alert:@"Error" withMessage:@"An error occured while trying to delete conversations."];
    }
    return allDeleted;
}
+ (CGMessage*)assistantMessageWithText:(NSString*)text {
    if (![text isKindOfClass:[NSString class]]) text = @"";
    CGMessage *message = CGMessage.new;
    message.author = @"ChatGPT"; message.content = text; message.role = @"assistant"; message.type = 2; message.indestructible = YES;
    message.avatar = [UIImage imageNamed:(VERSION_MIN(@"7.0") ? @"iOS7AssistantAvatar" : @"defaultAssistantAvatar")];
    float contentWidth = UIScreen.mainScreen.bounds.size.width - 63;
    CGSize textSize = [text sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
    message.contentHeight = textSize.height + 50;
    return message;
}

+ (CGMessage*)convertTextCompletionResponse:(NSDictionary*)jsonMessage {
    id choices = jsonMessage[@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || [choices count] == 0) return [self loopErrorBack:@"The API returned an unexpected response."];
    id first = [choices firstObject];
    id dict = [first isKindOfClass:[NSDictionary class]] ? first[@"message"] : nil;
    NSString *text = [dict isKindOfClass:[NSDictionary class]] && [dict[@"content"] isKindOfClass:[NSString class]] ? dict[@"content"] : @"";
    return [self assistantMessageWithText:text];
}

+ (CGMessage*)convertImageGenerationResponse:(NSDictionary*)jsonMessage {
    NSArray *dataArray = [jsonMessage[@"data"] isKindOfClass:[NSArray class]] ? jsonMessage[@"data"] : nil;
    if (dataArray.count == 0 || ![dataArray.firstObject isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *firstData = dataArray.firstObject;
    
    
    CGMessage *newAssistantResponseMessage = CGMessage.new;
    
    newAssistantResponseMessage.author = @"ChatGPT";
    newAssistantResponseMessage.content = [firstData[@"revised_prompt"] isKindOfClass:[NSString class]] ? firstData[@"revised_prompt"] : @"Generated image";
    newAssistantResponseMessage.imageHash = [firstData[@"b64_json"] isKindOfClass:[NSString class]] ? firstData[@"b64_json"] : nil;
    if (!newAssistantResponseMessage.imageHash.length) return nil;
    NSData *imageData = [NSData dataWithBase64EncodedString:newAssistantResponseMessage.imageHash];
    newAssistantResponseMessage.imageAttachment = [UIImage imageWithData:imageData];
    
    newAssistantResponseMessage.role = @"assistant";
    if(VERSION_MIN(@"7.0")) {
        newAssistantResponseMessage.avatar = [UIImage imageNamed:@"iOS7AssistantAvatar"];
    } else {
        newAssistantResponseMessage.avatar = [UIImage imageNamed:@"defaultAssistantAvatar"];
    }
    newAssistantResponseMessage.type = 2; //AI Message is 2, user 1, errors 3
    newAssistantResponseMessage.indestructible = YES;
    
    float contentWidth = UIScreen.mainScreen.bounds.size.width - 63;
    CGSize textSize = [newAssistantResponseMessage.content sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
    newAssistantResponseMessage.contentHeight = textSize.height + 50;
    
    return newAssistantResponseMessage;
    
}
+ (CGMessage*)loopErrorBack:(NSString*)errorMessage {
    CGMessage *newError = CGMessage.new;
    
    newError.author = @"ChatGPT";
    newError.content = errorMessage;
    newError.type = 2; //AI Message is 2, user 1, errors 3 //temporary at 2
    newError.indestructible = YES;
    
    if(VERSION_MIN(@"7.0")) {
        newError.avatar = [UIImage imageNamed:@"iOS7AssistantAvatar"];
    } else {
        newError.avatar = [UIImage imageNamed:@"defaultAssistantAvatar"];
    }
    
    float contentWidth = UIScreen.mainScreen.bounds.size.width - 63;
    CGSize textSize = [newError.content sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
    newError.contentHeight = textSize.height + 50;
    return newError;
}


+ (void)alert:(NSString*)title withMessage:(NSString*)message{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [UIAlertView.alloc
                              initWithTitle: title
                              message: message
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
		[alert show];
	});
}




@end

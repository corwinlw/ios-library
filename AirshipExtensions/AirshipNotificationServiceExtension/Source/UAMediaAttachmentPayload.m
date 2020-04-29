/* Copyright Airship and Contributors */

#define kUAAccengageNotificationAttachmentServiceURLKey @"att-url"
#define kUAAccengageNotificationAttachmentServiceURLIdKey @"att-id"
#define kUAAccengageNotificationAttachmentServiceURLSKey @"acc-atts"
#define kUAAccengageNotificationIDKey @"a4sid"

#define kUANotificationAttachmentServiceURLKey @"url"
#define kUANotificationAttachmentServiceURLIdKey @"url_id"
#define kUANotificationAttachmentServiceURLSKey @"urls"
#define kUANotificationAttachmentServiceThumbnailKey @"thumbnail_id"
#define kUANotificationAttachmentServiceOptionsKey @"options"
#define kUANotificationAttachmentServiceCropKey @"crop"
#define kUANotificationAttachmentServiceTimeKey @"time"
#define kUANotificationAttachmentServiceHiddenKey @"hidden"
#define kUANotificationAttachmentServiceContentKey @"content"
#define kUANotificationAttachmentServiceBodyKey @"body"
#define kUANotificationAttachmentServiceTitleKey @"title"
#define kUANotificationAttachmentServiceSubtitleKey @"subtitle"

#import <UserNotifications/UserNotifications.h>
#import "UAMediaAttachmentPayload.h"

@interface UAMediaAttachmentContent ()

+ (UAMediaAttachmentContent *)contentWithDictionary:(NSDictionary *)dictionary;

@property(nonatomic, copy) NSString *body;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;

@end

@interface UAMediaAttachmentURL ()

@property(nonatomic, copy) NSURL *url;
@property(nonatomic, copy) NSString *urlID;

@end

@interface UAMediaAttachmentPayload ()

@property(nonatomic, strong) NSMutableArray *urls;
@property(nonatomic, copy) NSDictionary *options;
@property(nonatomic, strong) UAMediaAttachmentContent *content;
@property(nonatomic, copy) NSString *thumbnailID;

@end

@implementation UAMediaAttachmentContent

- (instancetype)initWithDictionary:(id)dictionary {
    self = [super init];

    if (self) {
        self.body = dictionary[kUANotificationAttachmentServiceBodyKey];
        self.title = dictionary[kUANotificationAttachmentServiceTitleKey];
        self.subtitle = dictionary[kUANotificationAttachmentServiceSubtitleKey];
    }

    return self;
}

+ (instancetype)contentWithDictionary:(id)object {
    return [[self alloc] initWithDictionary:object];
}

@end

@implementation UAMediaAttachmentURL

- (instancetype)initWithDictionary:(id)object isAccengagePayload:(BOOL)isAccengagePayload {
    self = [super init];

    if (self) {
        if ([self validateURLPayload:object isAccengagePayload:isAccengagePayload]) {
            NSDictionary *payload = object;
            NSString *urlString = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLKey] : payload[kUANotificationAttachmentServiceURLKey];
            self.url = [NSURL URLWithString:urlString];
            self.urlID = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLIdKey] : payload[kUANotificationAttachmentServiceURLIdKey];
        } else {
            return nil;
        }
    }

    return self;
}

+ (instancetype)URLWithDictionary:(id)object {
    return [[self alloc] initWithDictionary:object isAccengagePayload:NO];
}
             
+ (instancetype)URLWithDictionary:(id)object isAccengagePayload:(BOOL)isAccengagePayload {
    return [[self alloc] initWithDictionary:object isAccengagePayload:isAccengagePayload];
}

- (BOOL)validateURLPayload:(id)payload isAccengagePayload:(BOOL)isAccengagePayload {
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id urlId = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLIdKey] : payload[kUANotificationAttachmentServiceURLIdKey];
    id url = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLKey] : payload[kUANotificationAttachmentServiceURLKey];
    
    // URL is required
    if (![self validateURL:url]) {
        NSLog(@"Unable to parse url: %@", url);
        return NO;
    }
    
    // URL ID is optional
    if (urlId) {
        if (![self validateURLId:urlId]) {
            NSLog(@"Unable to parse url id: %@", urlId);
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)validateURL:(id)url {
    return [url isKindOfClass:[NSString class]];
}

- (BOOL)validateURLId:(id)urlID {
    return [urlID isKindOfClass:[NSString class]];
}

@end

@implementation UAMediaAttachmentPayload

- (instancetype)initWithJSONObject:(id)object {
    self = [super init];

    if (self) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        NSDictionary *payload = object;
        
        BOOL isAccengagePayload = NO;
        if (payload[kUAAccengageNotificationIDKey]) {
            isAccengagePayload = YES;
        }
        
        if ([self validatePayload:object isAccengagePayload:isAccengagePayload]) {
            self.urls = [NSMutableArray array];
            id payloadURLs = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLSKey] : payload[kUANotificationAttachmentServiceURLSKey];
            
            if (payloadURLs) {
                for (NSDictionary *urlDictionary in payloadURLs) {
                    UAMediaAttachmentURL *url = [UAMediaAttachmentURL URLWithDictionary:urlDictionary isAccengagePayload:isAccengagePayload];
                    if (url) {
                        [self.urls addObject:url];
                    }
                }
            } else {
                // Only Airship media attachment payloads have the kUANotificationAttachmentServiceURLKey at the root level
                id payloadURL = payload[kUANotificationAttachmentServiceURLKey];
                if ([payloadURL isKindOfClass:[NSArray class]]) {
                    for (NSString *urlString in payloadURL) {
                        UAMediaAttachmentURL *url = [UAMediaAttachmentURL URLWithDictionary:@{kUANotificationAttachmentServiceURLKey:urlString}];
                        if (url) {
                            [self.urls addObject:url];
                        }
                    }
                } else {
                    if ([payloadURL isKindOfClass:[NSString class]]) {
                        UAMediaAttachmentURL *url = [UAMediaAttachmentURL URLWithDictionary:@{kUANotificationAttachmentServiceURLKey:payloadURL}];
                        if (url) {
                            [self.urls addObject:url];
                        }
                    }
                }
            }

            self.options = [self optionsWithPayload:payload];
            self.content = [self contentWithPayload:payload];
            self.thumbnailID = payload[kUANotificationAttachmentServiceThumbnailKey];
        } else {
            return nil;
        }
    }

    return self;
}

+ (instancetype)payloadWithJSONObject:(id)object {
    return [[self alloc] initWithJSONObject:object];
}

- (UAMediaAttachmentContent *)contentWithPayload:(NSDictionary *)payload {
    NSDictionary *content = payload[kUANotificationAttachmentServiceContentKey];
    return [UAMediaAttachmentContent contentWithDictionary:content];
}

- (NSDictionary *)optionsWithPayload:(NSDictionary *)payload {
    NSDictionary *payloadOptions = payload[kUANotificationAttachmentServiceOptionsKey];
    NSMutableDictionary *attachmentOptions = [NSMutableDictionary dictionary];

    if (payloadOptions) {
        NSDictionary *crop = payloadOptions[kUANotificationAttachmentServiceCropKey];
        NSNumber *time = payloadOptions[kUANotificationAttachmentServiceTimeKey];
        NSNumber *hidden = payloadOptions[kUANotificationAttachmentServiceHiddenKey];

        if (crop) {
            // normalize crop dictionary to use capitalized keys, as expected
            NSMutableDictionary *normalizedCrop = [NSMutableDictionary dictionary];
            for (NSString *key in crop) {
                [normalizedCrop setValue:crop[key] forKey:key.capitalizedString];
            }

            [attachmentOptions setValue:normalizedCrop forKey:UNNotificationAttachmentOptionsThumbnailClippingRectKey];
        }

        if (time) {
            [attachmentOptions setValue:time forKey:UNNotificationAttachmentOptionsThumbnailTimeKey];
        }

        if (hidden) {
            [attachmentOptions setValue:hidden forKey:UNNotificationAttachmentOptionsThumbnailHiddenKey];
        }
    }

    return attachmentOptions;
}

- (BOOL)validateURL:(id)url {
    return [url isKindOfClass:[NSArray class]] || [url isKindOfClass:[NSString class]];
}

- (BOOL)validateURLS:(id)urls {
    return [urls isKindOfClass:[NSArray class]];
}

- (BOOL)validateCrop:(id)crop {
    if (![crop isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    NSArray *keys = @[@"x", @"y", @"width", @"height"];
    for (NSString *key in keys) {
        id value = [crop valueForKey:key];
        if (![value isKindOfClass:[NSNumber class]]) {
            return NO;
        }
        float normalizedValue = [value floatValue];
        if (normalizedValue < 0.0 || normalizedValue > 1.0) {
            return NO;
        }
    }

    return YES;

}

- (BOOL)validateTime:(id)time {
    return [time isKindOfClass:[NSNumber class]];
}

- (BOOL)validateHidden:(id)hidden {
    return [hidden isKindOfClass:[NSNumber class]];
}

- (BOOL)validateThumbnailID:(id)thumbnailID {
    return [thumbnailID isKindOfClass:[NSString class]];
}

- (BOOL)validateOptions:(id)options {
    if (![options isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id crop = options[kUANotificationAttachmentServiceCropKey];
    id time = options[kUANotificationAttachmentServiceTimeKey];
    id hidden = options[kUANotificationAttachmentServiceHiddenKey];

    if (crop) {
        if (![self validateCrop:crop]) {
            NSLog(@"Unable to parse crop: %@", crop);
            return NO;
        }
    }

    if (time) {
        if (![self validateTime:time]) {
            NSLog(@"Unable to parse time: %@", time);
            return NO;
        }
    }

    if (hidden) {
        if (![self validateHidden:hidden]) {
            NSLog(@"Unable to parse hidden: %@", hidden);
            return NO;
        }
    }

    return YES;
}

- (BOOL)validateContent:(id)content {
    if (![content isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id body = content[kUANotificationAttachmentServiceBodyKey];
    id title = content[kUANotificationAttachmentServiceTitleKey];
    id subtitle = content[kUANotificationAttachmentServiceSubtitleKey];

    if (body) {
        if (![body isKindOfClass:[NSString class]]) {
            NSLog(@"Unable to parse body: %@", body);
            return NO;
        }
    }

    if (title) {
        if (![title isKindOfClass:[NSString class]]) {
            NSLog(@"Unable to parse title: %@", title);
            return NO;
        }
    }

    if (subtitle) {
        if (![subtitle isKindOfClass:[NSString class]]) {
            NSLog(@"Unable to parse subtitle: %@", subtitle);
            return NO;
        }
    }

    return YES;
}

- (BOOL)validatePayload:(id)payload isAccengagePayload:(BOOL)isAccengagePayload {
    id url = payload[kUANotificationAttachmentServiceURLKey];
    id options = payload[kUANotificationAttachmentServiceOptionsKey];
    id content = payload[kUANotificationAttachmentServiceContentKey];
    id thumbnailID = payload[kUANotificationAttachmentServiceThumbnailKey];
    id urls = isAccengagePayload ? payload[kUAAccengageNotificationAttachmentServiceURLSKey] : payload [kUANotificationAttachmentServiceURLSKey];

    // The URL is required if no URLs specified
    
    if (urls) {
        if (![self validateURL:urls]) {
            NSLog(@"Unable to parse urls: %@", urls);
            return NO;
        }
    } else {
        if (![self validateURL:url]) {
            NSLog(@"Unable to parse url: %@", url);
            return NO;
        }
    }
    
    // Options, content and thumbnail id are optional
    if (options) {
        if (![self validateOptions:options]) {
            NSLog(@"Unable to parse options");
            return NO;
        }
    }

    if (content) {
        if (![self validateContent:content]) {
            NSLog(@"Unable to parse content");
            return NO;
        }
    }
    
    if (thumbnailID) {
        if (![self validateThumbnailID:thumbnailID]) {
            NSLog(@"Unable to parse thumbnail id");
            return NO;
        }
    }

    return YES;
}

@end

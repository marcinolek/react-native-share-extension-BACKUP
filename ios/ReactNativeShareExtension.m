#import "ReactNativeShareExtension.h"
#import "DataItem.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define VCARD_IDENTIFIER @"public.vcard"
#define MAP_IDENTIFIER @"com.apple.mapkit.map-item"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;
    
    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }
    
    self.view = rootView;
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}

RCT_EXPORT_METHOD(openURL:(NSString *)url) {
    UIApplication *application = [UIApplication sharedApplication];
    NSURL *urlToOpen = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
    [application openURL:urlToOpen options:@{} completionHandler: nil];
}


RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (NSString *)findGoogleAddressIn:(NSString *)url {
    NSRange searchedRange = NSMakeRange(0, [url length]);
    NSString *pattern = @"/?q=(([^&]+))&";
    NSError  *error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:url options:0 range: searchedRange];
    for (NSTextCheckingResult* match in matches) {
        NSString* matchText = [url substringWithRange:[match range]];
        NSString *address = [matchText substringWithRange:NSMakeRange(2, matchText.length - 3)]; // ommit q= and final &
        return address;
    }
    return nil;
}

- (NSString *)findAppleAddressIn:(NSString *)url {
    NSRange searchedRange = NSMakeRange(0, [url length]);
    NSString *pattern = @"/?address=(([^&]+))&";
    NSError  *error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:url options:0 range: searchedRange];
    for (NSTextCheckingResult* match in matches) {
        NSString* matchText = [url substringWithRange:[match range]];
        NSString *address = [matchText substringWithRange:NSMakeRange(8, matchText.length - 9)]; // ommit q= and final &
        return address;
    }
    return nil;
}

- (NSString *)findAppleCoordinates:(NSString *)url {
    NSRange searchedRange = NSMakeRange(0, [url length]);
    NSString *pattern = @"/?ll=(([^&]+))&";
    NSError  *error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:url options:0 range: searchedRange];
    for (NSTextCheckingResult* match in matches) {
        NSString* matchText = [url substringWithRange:[match range]];
        NSString *address = [matchText substringWithRange:NSMakeRange(3, matchText.length - 4)]; // ommit q= and final &
        return address;
    }
    return nil;
}
    
- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *value, NSString* contentType, NSException *exception))callback {
    
    
    void (^processResults)(NSArray *) = ^void(NSArray *results) {
        for (DataItem *result in results) {
            NSLog(@"Share Extension Provider Result %@ Value: %@", result.contentType, result.value);
            if(!result.exception) {
                // Google
                if([result.value containsString:@"goo.gl"]) {
                    NSURL *redirectURL = [NSURL URLWithString:result.value];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:redirectURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15.0];
                    [request setHTTPMethod:@"HEAD"];
                    NSURLSession *session = [NSURLSession sharedSession];
                    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                        if(!error) {
                            NSString *address = [self findGoogleAddressIn:response.URL.absoluteString];
                            NSString *response = [NSString stringWithFormat:@"address=%@", address];
                            callback(response, @"text/plain", nil);
                        }
                    }] resume];
                // Apple
                } else if([result.value containsString:@"maps.apple.com"]) {
                    NSString *url = result.value;
                    NSString *address = [self findAppleAddressIn:url];
                    NSString *coordinates = [self findAppleCoordinates:url];
                    NSString *response = [NSString stringWithFormat:@"address=%@&coords=%@", address, coordinates];
                    callback(response, @"text/plain", nil);
                }
            }
        }

    };
    
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;
        
        NSInteger itemsCount = [attachments count];
        __block NSMutableArray *results = [NSMutableArray array];
        
        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            
            if ([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]){
                [provider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    NSURL *url = (NSURL *)item;
                    DataItem *dataItem = [DataItem itemWithContentType:@"text/plain" value:[url absoluteString] exception:nil];
                    [results addObject:dataItem];
                    if(results.count == itemsCount) {
                        processResults(results);
                    }
                }];
                
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                
                [provider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    NSString *text = (NSString *)item;
                    DataItem *dataItem = [DataItem itemWithContentType:@"text/plain" value:text exception:nil];
                    [results addObject:dataItem];
                    if(results.count == itemsCount) {
                        processResults(results);
                    }
                }];
                
            } else  /* if ([provider hasItemConformingToTypeIdentifier:MAP_IDENTIFIER]){
                
                [provider loadItemForTypeIdentifier:MAP_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    NSLog(@"GOT");
                }];
                
            } else if ([provider hasItemConformingToTypeIdentifier:VCARD_IDENTIFIER]){
                
                [provider loadItemForTypeIdentifier:VCARD_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    NSLog(@"GOT");
                }];
                
            }
            
            else  if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                
                [provider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    UIImage *sharedImage;
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"RNSE_TEMP_IMG"];
                    NSString *fullPath = [filePath stringByAppendingPathExtension:@"png"];
                    
                    if ([(NSObject *)item isKindOfClass:[UIImage class]]){
                        sharedImage = (UIImage *)item;
                    }else if ([(NSObject *)item isKindOfClass:[NSURL class]]){
                        NSURL* url = (NSURL *)item;
                        NSData *data = [NSData dataWithContentsOfURL:url];
                        sharedImage = [UIImage imageWithData:data];
                    }
                    
                    [UIImagePNGRepresentation(sharedImage) writeToFile:fullPath atomically:YES];
                    
                    DataItem *dataItem = [DataItem itemWithContentType:[fullPath pathExtension] value:fullPath exception:nil];
                    [results addObject:dataItem];
                    if(results.count == itemsCount) {
                        processResults(results);
                    }
                    
                }];
            } else */ {
                DataItem *dataItem = [DataItem itemWithContentType:nil value:nil exception: [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]];
                [results addObject:dataItem];
                if(results.count == itemsCount) {
                    processResults(results);
                }
            }
        }];
        
        
    }
    @catch (NSException *exception) {
        DataItem *dataItem = [DataItem itemWithContentType:nil value:nil exception: exception];
        NSArray *results = @[dataItem];
        processResults(results);
    }
}



@end

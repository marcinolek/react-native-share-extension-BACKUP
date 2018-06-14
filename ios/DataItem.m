//
//  DataItem.m
//  ReactNativeShareExtension
//
//  Created by Marcin Olek on 14/06/2018 09:56.
//  Copyright © 2018 Ali Najafizadeh. All rights reserved.
//

#import "DataItem.h"

@implementation DataItem

- (instancetype)initWithContentType:(NSString *)contentType value:(NSString *)value exception:(NSException *)exception {
    if (self = [super init]) {
        _contentType = contentType;
        _value = value;
        _exception = exception;
    }
    return self;
}

+ (instancetype)itemWithContentType:(NSString *)contentType value:(NSString *)value exception:(NSException *)exception {
    return [[self alloc] initWithContentType:contentType value:value exception:exception];
}

@end

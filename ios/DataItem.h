//
//  DataItem.h
//  ReactNativeShareExtension
//
//  Created by Marcin Olek on 14/06/2018 09:56.
//  Copyright © 2018 Ali Najafizadeh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataItem : NSObject
@property (nonatomic, strong) NSString *contentType;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) NSException *exception;

+ (instancetype)itemWithContentType:(NSString *)contentType value:(NSString *)value exception:(NSException *)exception;

@end

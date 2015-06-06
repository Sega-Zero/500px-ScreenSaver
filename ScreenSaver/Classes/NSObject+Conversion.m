//
//  NSObject+Conversion.m
//  ScreenSaver
//
//  Created by dstd on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "NSObject+Conversion.h"

NSString* toSafeString(NSString* s)
{
    if (!s)
        return @"";
    return [s isKindOfClass:NSString.class] ? s : [s description];
}

@implementation NSObject (Conversion)

- (UInt64) asUInt64
{
    id me = self;
    if ([me respondsToSelector:@selector(unsignedLongLongValue)])
        return [me unsignedLongLongValue];
    if ([me isKindOfClass:NSString.class])
        return strtoull([me UTF8String], NULL, 10);
    return 0;
}

- (NSInteger) asInteger
{
    id me = self;
    if ([me respondsToSelector:@selector(integerValue)])
        return [me integerValue];
    if ([me isKindOfClass:NSString.class])
        return (NSInteger)strtoull([me UTF8String], NULL, 10);
    if ([me respondsToSelector:@selector(boolValue)])
        return [me boolValue];
    return 0;
}

- (id) objectIfKindOfClass:(Class)cls
{
    return [self isKindOfClass:cls] ? self : nil;
}

@end

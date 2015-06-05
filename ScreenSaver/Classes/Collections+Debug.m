//
//  Collections+Debug.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "Collections+Debug.h"

static NSString* debugDescriptionCompact(id obj)
{
    if ([obj respondsToSelector:@selector(debugDescriptionCompact)])
        return [obj debugDescriptionCompact];
    else
        return [obj debugDescription];
}

@implementation NSDictionary (Debug)
- (NSString *)debugDescriptionCompact
{
    NSMutableString* r = [NSMutableString new];
    [r appendString:@"{"];
    __block NSInteger i = 0;
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (i++ > 0)
            [r appendString:@","];
        [r appendString:debugDescriptionCompact(key)];
        [r appendString:@":"];
        [r appendString:debugDescriptionCompact(obj)];
    }];
    [r appendString:@"}"];
    return r;
}
@end

@implementation NSArray (Debug)
- (NSString *)debugDescriptionCompact
{
    NSMutableString* r = [NSMutableString new];
    [r appendString:@"["];
    __block NSInteger i = 0;
    for (id obj in self)
    {
        if (i++ > 0)
            [r appendString:@","];
        [r appendString:debugDescriptionCompact(obj)];
    }
    [r appendString:@"]"];
    return r;
}
@end

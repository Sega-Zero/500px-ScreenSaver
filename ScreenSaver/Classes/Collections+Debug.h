//
//  Collections+Debug.h
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface NSDictionary (Debug)
- (NSString*) debugDescriptionCompact;
@end

@interface NSArray (Debug)
- (NSString*) debugDescriptionCompact;
@end

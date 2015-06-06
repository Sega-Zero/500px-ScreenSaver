//
//  NSObject+Conversion.h
//  ScreenSaver
//
//  Created by dstd on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* toSafeString(NSString* s);

@interface NSObject (Conversion)

- (UInt64) asUInt64;
- (NSInteger) asInteger;
- (id) objectIfKindOfClass:(Class)cls;

@end

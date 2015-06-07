//
//  Common.h
//  ScreenSaver
//
//  Created by dstd on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* kCachePath;

extern NSString* kPrefsCategory;

NSInteger prefsIntValue(NSString* key);
#define PREFS_FORCE_SYNC YES
void setPrefsIntValue(NSString* key, NSInteger value, BOOL forceSync);
void registerPrefsDefaults(NSDictionary* values);
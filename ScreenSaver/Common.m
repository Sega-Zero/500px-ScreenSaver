//
//  Common.m
//  ScreenSaver
//
//  Created by dstd on 06/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "Common.h"

NSString* kCachePath = nil;
__attribute__((constructor))
static void initCachePath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    kCachePath = [paths[0] stringByAppendingPathComponent:@"500px screensaver/"];
    
    if (kCachePath.length > 0) {
        NSFileManager* m = [NSFileManager defaultManager];
        if (![m fileExistsAtPath:kCachePath]) {
            NSError *error = nil;
            [m createDirectoryAtPath:kCachePath withIntermediateDirectories:YES attributes:nil error:&error];
            NSLog(@"[media preview] created %@ with %@", kCachePath, error);
        }
    }
}

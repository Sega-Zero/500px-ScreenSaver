//
//  PhotoSource.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "PhotoSource.h"

static NSString* s_cachePath = nil;
__attribute__((constructor))
static void initCachePath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    s_cachePath = [paths[0] stringByAppendingPathComponent:@"500px screensaver/"];
    
    if (s_cachePath.length > 0) {
        NSFileManager* m = [NSFileManager defaultManager];
        if (![m fileExistsAtPath:s_cachePath]) {
            NSError *error = nil;
            [m createDirectoryAtPath:s_cachePath withIntermediateDirectories:YES attributes:nil error:&error];
            NSLog(@"[media preview] created %@ with %@", s_cachePath, error);
        }
    }
}

@implementation PhotoItem

+ (PhotoItem*)photoItemWithId:(NSString*)photoId title:(NSString*)title description:(NSString*)description author:(NSString*)author rating:(NSString*)rating photoUrl:(NSString *)photoUrl
{
    PhotoItem* item = [PhotoItem new];
    item->_photoId = photoId;
    item->_title = title;
    item->_descriptionText = description;
    item->_author = author;
    item->_photoUrl = photoUrl;
    return item;
}

- (NSString *)debugDescriptionCompact
{
    return _photoId;
}

@end

@implementation PhotoItem (Cache)

- (NSString *)cachedFilepath
{
    return [s_cachePath stringByAppendingPathComponent:_photoId];
}

@end
//
//  PhotoSource.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "PhotoSource.h"
#import "Common.h"
#import "NSObject+Conversion.h"

@implementation PhotoItem

- (NSString *)debugDescriptionCompact
{
    return _photoId;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (!self)
        return self;
    
    _title = [aDecoder decodeObjectForKey:@"t"];
    _descriptionText = [aDecoder decodeObjectForKey:@"d"];
    _author = [aDecoder decodeObjectForKey:@"a"];
    _authorId = [aDecoder decodeObjectForKey:@"ai"];
    _authorPicUrl = [aDecoder decodeObjectForKey:@"p"];
    _rating = [aDecoder decodeObjectForKey:@"r"];
    _photoId = [aDecoder decodeObjectForKey:@"i"];
    _photoHashId = [[aDecoder decodeObjectForKey:@"h"] asUInt64];
    _photoUrl = [aDecoder decodeObjectForKey:@"u"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_title forKey:@"t"];
    [aCoder encodeObject:_descriptionText forKey:@"d"];
    [aCoder encodeObject:_author forKey:@"a"];
    [aCoder encodeObject:_authorId forKey:@"ai"];
    [aCoder encodeObject:_authorPicUrl forKey:@"p"];
    [aCoder encodeObject:_rating forKey:@"r"];
    [aCoder encodeObject:_photoId forKey:@"i"];
    [aCoder encodeObject:@(_photoHashId) forKey:@"h"];
    [aCoder encodeObject:_photoUrl forKey:@"u"];
}

@end

@implementation PhotoItem (Cache)

- (NSString *)cachedFilepath
{
    return [kCachePath stringByAppendingPathComponent:_photoId];
}

- (NSString *)cachedAuthorPicFilepath
{
    return [[kCachePath stringByAppendingPathComponent:_authorId] stringByAppendingString:@".author"];
}

- (BOOL)cached
{
    NSFileManager* m = [NSFileManager defaultManager];
    BOOL completed = [m fileExistsAtPath:self.cachedFilepath isDirectory:NULL] &&
                     [m fileExistsAtPath:self.cachedAuthorPicFilepath isDirectory:NULL];
    return completed;
}

@end

@implementation PhotoItem (px500)

NSString* bestPhotoUrl(NSDictionary* item)
{
    NSArray* images = item[@"images"];
    if (![images isKindOfClass:NSArray.class])
        return nil;
    
    for (NSDictionary* image in images) {
        if (![image isKindOfClass:NSDictionary.class])
            continue;
        
        NSString* url = image[@"url"];
        if (![url isKindOfClass:NSString.class])
            continue;
        
        return url;
    }
    
    return nil;
}

+ (PhotoItem*)photoItemFor500px:(NSDictionary*)photoObject
{
    PhotoItem* item = [PhotoItem new];
    item->_photoHashId = [photoObject[@"id"] asUInt64];
    item->_photoId = [NSString stringWithFormat:@"%llu", item->_photoHashId];
    item->_title = toSafeString(photoObject[@"name"]);;
    item->_descriptionText = toSafeString(photoObject[@"description"]);
    
    NSDictionary* user = photoObject[@"user"];
    if (user) {
        item->_author = toSafeString(user[@"fullname"]);
        item->_authorId = toSafeString(user[@"id"]);
        item->_authorPicUrl = toSafeString(user[@"userpic_url"]);
    }
    item->_photoUrl = toSafeString(bestPhotoUrl(photoObject));
    item->_rating = toSafeString(photoObject[@"rating"]);
    
    return item;
}

@end

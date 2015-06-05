//
//  PhotoSource.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "PhotoSource.h"
#import "Common.h"

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

+ (PhotoItem*)photoItemWithHashId:(UInt64)photoHashId title:(NSString*)title description:(NSString*)description author:(NSString*)author rating:(NSString*)rating photoUrl:(NSString*)photoUrl
{
    PhotoItem* item = [PhotoItem new];
    item->_photoHashId = photoHashId;
    item->_photoId = [NSString stringWithFormat:@"%llu", item->_photoHashId];
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

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (!self)
        return self;
    
    _title = [aDecoder decodeObjectForKey:@"t"];
    _descriptionText = [aDecoder decodeObjectForKey:@"d"];
    _author = [aDecoder decodeObjectForKey:@"a"];
    _rating = [aDecoder decodeObjectForKey:@"r"];
    _photoId = [aDecoder decodeObjectForKey:@"i"];
    _photoHashId = [[aDecoder decodeObjectForKey:@"h"] unsignedLongLongValue];
    _photoUrl = [aDecoder decodeObjectForKey:@"u"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_title forKey:@"t"];
    [aCoder encodeObject:_descriptionText forKey:@"d"];
    [aCoder encodeObject:_author forKey:@"a"];
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

@end
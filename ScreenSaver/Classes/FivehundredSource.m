//
//  FivehundredSource.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "FivehundredSource.h"
#import "AFNetworking.h"
#import "Collections+Debug.h"
#import "Common.h"

#define PAGE_COUNT 20
#define FEED_COUNT 300

@implementation FivehundredSource
{
    BOOL _fetchingFeed;
    BOOL _fetchedFeed;
    NSInteger _currentPage;
    NSInteger _totalPages;
    
    NSMutableArray *_randomizedPhotos;
    NSMutableArray *_readyPhotos;
    NSMutableArray *_loadingPhotos;
    NSMutableArray *_parsedPhotos;
    
    dispatch_queue_t _queue;
    void*            _queueTag;
    
    PhotoSourceCompletion _nextPhotoHandler;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return self;
    
    [self commonInit];
    
    return self;
}

- (void)retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler
{
    if (!completionHandler)
        return;
    
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self retrieveNextPhotoWithCompletion:completionHandler]; });
        return;
    }
    
    if (_randomizedPhotos.count == 0 && _readyPhotos.count > 0) {
        _randomizedPhotos = [_readyPhotos mutableCopy];
        NSUInteger count = _randomizedPhotos.count;
        for (NSUInteger x = 0; x < count; x++) {
            NSUInteger n = arc4random() % count;
            [_randomizedPhotos exchangeObjectAtIndex:x withObjectAtIndex:n];
        }
        NSLog(@"[500px] new not randomized photos: %@", [_readyPhotos debugDescriptionCompact]);
        NSLog(@"[500px] new     randomized photos: %@", [_randomizedPhotos debugDescriptionCompact]);
    }
    
    if (_randomizedPhotos.count > 0) {
        PhotoItem* nextPhoto = _randomizedPhotos.firstObject;
        [_randomizedPhotos removeObjectAtIndex:0];
        NSLog(@"[500px] next photo choosen: %llu.%@", nextPhoto.photoHashId, nextPhoto.title);
        
        _nextPhotoHandler = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nextPhoto, nil);
        });
    }
    else
        _nextPhotoHandler = completionHandler;
}

- (void)cancelPhotoRequest
{
    
}

- (void)commonInit
{
    _fetchingFeed = NO;
    _currentPage = 1;
    _totalPages = 500;
    
    NSArray* saved = [NSKeyedUnarchiver unarchiveObjectWithFile:[kCachePath stringByAppendingPathComponent:@"savedFeed.plist"]];
    if (![saved isKindOfClass:NSArray.class])
        saved = nil;
    
    _randomizedPhotos = [NSMutableArray new];
    _readyPhotos = [saved mutableCopy] ?: [NSMutableArray new];
    _loadingPhotos = [NSMutableArray new];
    _parsedPhotos = [NSMutableArray new];
    
    _queue = dispatch_queue_create("500px-source-queue", DISPATCH_QUEUE_SERIAL);
    _queueTag = &_queueTag;
    dispatch_queue_set_specific(_queue, _queueTag, _queueTag, nil);
    
    _nextPhotoHandler = nil;

    [self fetchFeed];
}

- (void)saveFeed
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self saveFeed]; });
        return;
    }

    [NSKeyedArchiver archiveRootObject:_readyPhotos toFile:[kCachePath stringByAppendingPathComponent:@"savedFeed.plist"]];
}

NSString* userName(NSDictionary* item)
{
    NSDictionary* user = item[@"user"];
    if (![user isKindOfClass:NSDictionary.class])
        return nil;
    
    return user[@"fullname"];
}

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

PhotoItem* photoById(NSArray* items, UInt64 n)
{
    for (PhotoItem* item in items)
        if (item.photoHashId == n)
            return item;

    return nil;
}

- (void)parseFeed:(NSDictionary*)feed
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self parseFeed:feed]; });
        return;
    }
    
    if (!_fetchedFeed) {
        _fetchedFeed = YES;
        
        _readyPhotos = [NSMutableArray new];
        _randomizedPhotos = [NSMutableArray new];
    }
    
    _totalPages = [feed[@"total_pages"] integerValue];
    
    NSArray* items = feed[@"photos"];
    
    NSLog(@"[500px] parse feed:");
    for (NSDictionary* item in items) {
        UInt64 photoId = [item[@"id"] longLongValue];
        if (photoById(_parsedPhotos, photoId) || photoById(_readyPhotos, photoId) || photoById(_loadingPhotos, photoId))
            continue;
        
        NSString* title = item[@"name"] ?: @"";
        NSString* text = item[@"description"] ?: @"";
        NSString* author = userName(item) ?: @"";
        NSString* photoUrl = bestPhotoUrl(item) ?: @"";

        /* filter out vertical photos
        NSInteger width = [item[@"width"] integerValue];
        NSInteger height = [item[@"height"] integerValue];
        if (width < height)
            continue;
        */

        id ratingValue = item[@"rating"];
        NSString* rating = ratingValue ? [NSString stringWithFormat:@"%@", ratingValue] : @"";
        
        PhotoItem* photoItem = [PhotoItem photoItemWithHashId:photoId title:title description:text author:author rating:rating photoUrl:photoUrl];
        [_parsedPhotos addObject:photoItem];
        NSLog(@"[500px] feed item: %llu. %@", photoId, title);
    }
    
    NSInteger feedLength = _parsedPhotos.count + _loadingPhotos.count + _readyPhotos.count;
    
    if (feedLength < FEED_COUNT) {
        _currentPage++;
        NSLog(@"[500px] feed length - %d, too small, get the next page", (int)feedLength);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self fetchFeed];
        });
    }
    
    [self fetchNextPhoto];
}

- (void)fetchFeed
{
    if (_fetchingFeed)
        return;
    _fetchingFeed = YES;
    _currentPage = arc4random() % _totalPages;
    
    NSURL *baseUrl = [NSURL URLWithString:@"https://api.500px.com"];
    NSString *methodPhotos = @"/v1/photos";
    NSDictionary *params = @{@"feature": @"editors",
                             @"image_size[]": @"2048",
                             @"rpp": @(PAGE_COUNT),
                             @"page": @(_currentPage),
                             @"consumer_key": @"DI7ANAHTalF5WUsa7vdaHiY4tM8kwduHT08vDaJm"
                             };
    
    NSLog(@"[500px] fetching feed");
    AFHTTPSessionManager* manager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseUrl];
    [manager GET:methodPhotos parameters:params
         success:^(NSURLSessionDataTask *task, id responseObject) {
             _fetchingFeed = NO;

             NSLog(@"[500px] feed received");
             [self parseFeed:responseObject];
         }
         failure:^(NSURLSessionDataTask *task, NSError *error) {
             _fetchingFeed = NO;

             NSLog(@"[500px] feed fetching failed");
         }];
}

- (void)fetchNextPhoto
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self fetchNextPhoto]; });
        return;
    }

    if (_parsedPhotos.count == 0) {
        NSLog(@"[500px] no more photos to fetch");
        return;
    }

    PhotoItem* nextPhoto = _parsedPhotos.firstObject;
    [_parsedPhotos removeObjectAtIndex:0];
    [_loadingPhotos addObject:nextPhoto];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:nextPhoto.cachedFilepath]) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:nextPhoto]; });
        return;
    }

    NSLog(@"[500px] fetch next photo: %llu.%@ - %@, to %@", nextPhoto.photoHashId, nextPhoto.title, nextPhoto.photoUrl, nextPhoto.cachedFilepath);

    NSURL* url = [NSURL URLWithString:nextPhoto.photoUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    __weak id w_self = self;
    
    AFURLSessionManager* manager = [[AFURLSessionManager alloc] init];
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil
                                destination:^NSURL *(NSURL *targetPath, NSURLResponse *response)
                                {
                                    NSFileManager* m = [NSFileManager defaultManager];
                                    
                                    NSString* cachedFilepath = nextPhoto.cachedFilepath;
                                    NSString* folder = [cachedFilepath stringByDeletingLastPathComponent];
                                    if (![m fileExistsAtPath:folder])
                                        [m createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
                                    
                                    if ([m fileExistsAtPath:cachedFilepath])
                                        [m removeItemAtPath:cachedFilepath error:nil];
                                    
                                    return [NSURL fileURLWithPath:cachedFilepath];
                                }
                                completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error)
                                {
                                    FivehundredSource* s_self = w_self;
                                    if (!s_self)
                                        return;
                                    
                                    NSLog(@"[500px] fetch next photo: %llu. %@", nextPhoto.photoHashId, error ? @"failed" : @"completed");
                                    [s_self didFetchedPhoto:nextPhoto];
                                }];
    
    [downloadTask resume];
}

- (void)didFetchedPhoto:(PhotoItem*)photoItem
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:photoItem]; });
        return;
    }

    [_loadingPhotos removeObject:photoItem];
    [_readyPhotos addObject:photoItem];
    [self saveFeed];
    
    NSLog(@"[500px] readyPhotos: %@", [_readyPhotos debugDescriptionCompact]);
    
    [self checkAwaiters];
    [self fetchNextPhoto];
}

- (void)checkAwaiters
{
    if (_nextPhotoHandler) {
        NSLog(@"[500px] call the awaiting completion handler");
        [self retrieveNextPhotoWithCompletion:_nextPhotoHandler];
    }
}

@end

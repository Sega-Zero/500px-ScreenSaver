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

@implementation FivehundredSource
{
    BOOL _fetchingFeed;
    
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
    
    if (!dispatch_queue_get_specific(_queue, _queueTag)) {
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
        NSLog(@"[500px] next photo choosen: %@.%@", nextPhoto.photoId, nextPhoto.title);
        
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
    
    _randomizedPhotos = [NSMutableArray new];
    _readyPhotos = [NSMutableArray new];
    _loadingPhotos = [NSMutableArray new];
    _parsedPhotos = [NSMutableArray new];
    
    _queue = dispatch_queue_create("500px-source-queue", DISPATCH_QUEUE_SERIAL);
    _queueTag = &_queueTag;
    dispatch_queue_set_specific(_queue, _queueTag, _queueTag, nil);
    
    _nextPhotoHandler = nil;

    [self fetchFeed];
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

- (void)parseFeed:(NSDictionary*)feed
{
    if (!dispatch_queue_get_specific(_queue, _queueTag)) {
        dispatch_async(_queue, ^{ [self parseFeed:feed]; });
        return;
    }
    
    NSArray* items = feed[@"photos"];
    
    NSLog(@"[500px] parse feed:");
    for (NSDictionary* item in items) {
        NSString* title = item[@"name"] ?: @"";
        NSString* text = item[@"description"] ?: @"";
        NSString* author = userName(item) ?: @"";
        NSString* photoUrl = bestPhotoUrl(item) ?: @"";
        NSString* photoId = [item[@"id"] description] ?: @"";

        id ratingValue = item[@"rating"];
        NSString* rating = ratingValue ? [NSString stringWithFormat:@"%@", ratingValue] : @"";
        
        PhotoItem* photoItem = [PhotoItem photoItemWithId:photoId title:title description:text author:author rating:rating photoUrl:photoUrl];
        [_parsedPhotos addObject:photoItem];
        NSLog(@"[500px] feed item: %@. %@", photoId, title);
    }
    
    [self fetchNextPhoto];
}

- (void)fetchFeed
{
    if (_fetchingFeed)
        return;
    _fetchingFeed = YES;
    
    NSURL *baseUrl = [NSURL URLWithString:@"https://api.500px.com"];
    NSString *methodPhotos = @"/v1/photos";
    NSDictionary *params = @{@"feature": @"editors",
                             @"image_size[]": @"2048",
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
    if (!dispatch_queue_get_specific(_queue, _queueTag)) {
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

    NSLog(@"[500px] fetch next photo: %@.%@ - %@, to %@", nextPhoto.photoId, nextPhoto.title, nextPhoto.photoUrl, nextPhoto.cachedFilepath);

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
                                    
                                    NSLog(@"[500px] fetch next photo: %@. %@", nextPhoto.photoId, error ? @"failed" : @"completed");
                                    [s_self didFetchedPhoto:nextPhoto];
                                }];
    
    [downloadTask resume];
}

- (void)didFetchedPhoto:(PhotoItem*)photoItem
{
    if (!dispatch_queue_get_specific(_queue, _queueTag)) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:photoItem]; });
        return;
    }

    [_loadingPhotos removeObject:photoItem];
    [_readyPhotos addObject:photoItem];
    
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

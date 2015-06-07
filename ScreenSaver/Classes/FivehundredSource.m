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
#import "NSObject+Conversion.h"

#define PAGE_COUNT 30
#define FEED_COUNT 20

#if DEBUG
#define LOG NSLog
#else
#define LOG(...) {}
#endif

@implementation FivehundredSource
{
    BOOL _cancelRequested;
    NSMutableSet *_networkTasks;
    BOOL _fetchingFeed;
    NSInteger _currentPage;
    NSInteger _totalPages;
    NSInteger _currentCategory;
    
    NSTimeInterval _lastSaveFeed;

    NSMutableArray *_photosFeed;
    NSInteger _nextPhotoIndex;
    NSInteger _indexToContinue; // if no downloaded photos available, save the position and spin for the start

    dispatch_queue_t _queue;
    void*            _queueTag;
    
    PhotoSourceCompletion _nextPhotoHandler;
}

#pragma mark - public methods

- (instancetype)init
{
    self = [super init];
    if (!self)
        return self;
    
    [self commonInit];
    
    return self;
}

- (void)randomizeFeed:(NSMutableArray*)photosFeed
{
    [self randomizeFeed:photosFeed inRange:NSMakeRange(0, photosFeed.count)];
}

- (void)randomizeFeed:(NSMutableArray*)photosFeed inRange:(NSRange)range
{
    if (_photosFeed.count == 0 || range.length == 0 || range.location + range.length >= _photosFeed.count)
        return;
    NSUInteger base = range.location;
    NSUInteger count = range.length;
    for (NSUInteger cycles = 0; cycles < 3; ++cycles) {
        for (NSUInteger i = 0; i < count; ++i) {
            NSUInteger j = arc4random() % count;
            if (i != j)
                [photosFeed exchangeObjectAtIndex:i + base withObjectAtIndex:j + base];
        }
    }
}

- (void)retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler
{
    _cancelRequested = NO;

    if (!completionHandler)
        return;
    
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self retrieveNextPhotoWithCompletion:completionHandler]; });
        return;
    }
    
    NSInteger currentCategory = prefsIntValue(kPrefsCategory);
    if (_currentCategory != currentCategory) {
        _currentCategory = currentCategory;
        [self fetchFeed];
    }

    if (_photosFeed.count - _nextPhotoIndex < 3)
        [self fetchFeed];
    
    if (_photosFeed.count > 0) {
        if (_nextPhotoIndex >= _photosFeed.count) {
            [self randomizeFeed:_photosFeed];
            _nextPhotoIndex %= _photosFeed.count;
        }
        
        PhotoItem* nextPhoto = _photosFeed[_nextPhotoIndex];
        BOOL cached = nextPhoto.cached;
        if (!cached) {
            if (_nextPhotoIndex > 1) {
                // if the user has some network issues and forthcoming photo still not cached, we'll spin available photos once again
                // but remember the position we interrupted on to resume from that point
                if (_indexToContinue == -1)
                    _indexToContinue = _nextPhotoIndex;
                
                [self randomizeFeed:_photosFeed inRange:NSMakeRange(0, _nextPhotoIndex)];
                
                _nextPhotoIndex = 0;
                nextPhoto = _photosFeed[_nextPhotoIndex];
                cached = nextPhoto.cached;
            }
        }
        
        if (nextPhoto.cached) {
            LOG(@"[500px] next photo choosen: %llu.(%d)%@", nextPhoto.photoHashId, (int)_nextPhotoIndex, nextPhoto.title);
            
            ++_nextPhotoIndex;
            _nextPhotoHandler = nil;

            [self saveFeedThrottled];
            [self fetchNextPhoto];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nextPhoto, nil);
            });
            
            return;
        }
    }

    [self fetchNextPhoto];
    _nextPhotoHandler = completionHandler;
}

- (void)cancelPhotoRequest
{
    _cancelRequested = YES;
    NSSet* tasks = [_networkTasks copy];
    _networkTasks = [NSMutableSet new];
    [tasks enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        NSURLSessionDownloadTask* dl = [obj objectIfKindOfClass:NSURLSessionDownloadTask.class];
        if (dl) {
            [dl cancel];
            return;
        }
        
        NSURLSessionDataTask* dt = [obj objectIfKindOfClass:NSURLSessionDataTask.class];
        if (dt) {
            [dt cancel];
            return;
        }
    }];
}

#pragma - initialization and state

- (void)commonInit
{
    _cancelRequested = NO;
    _networkTasks = [NSMutableSet new];

    _fetchingFeed = NO;
    _currentPage = 1;
    _totalPages = 100;
    _currentCategory = prefsIntValue(kPrefsCategory);

    _queue = dispatch_queue_create("500px-source-queue", DISPATCH_QUEUE_SERIAL);
    _queueTag = &_queueTag;
    dispatch_queue_set_specific(_queue, _queueTag, _queueTag, nil);

    NSDictionary* saved = [NSKeyedUnarchiver unarchiveObjectWithFile:[kCachePath stringByAppendingPathComponent:@"state.plist"]];
    if ([saved isKindOfClass:NSDictionary.class]) {
        _photosFeed = [[saved[@"feed"] objectIfKindOfClass:NSArray.class] mutableCopy];
        _nextPhotoIndex = [saved[@"next"] asInteger];
        if (_nextPhotoIndex > 2)
            [self randomizeFeed:_photosFeed inRange:NSMakeRange(0, _nextPhotoIndex)];

        [self cleanupCache];
    }
    
    if (_photosFeed == nil) {
        _photosFeed = [NSMutableArray new];
        _nextPhotoIndex = 0;
    }
    
    _indexToContinue = -1;
    
    _nextPhotoHandler = nil;

    if (_photosFeed == nil)
        [self fetchFeed];
}

- (void)saveFeedThrottled
{
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _lastSaveFeed;
    if (elapsed < 20)
        return;
    
    _lastSaveFeed = [NSDate timeIntervalSinceReferenceDate];
    [self saveFeed];
}

- (void)saveFeed
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self saveFeed]; });
        return;
    }

    [NSKeyedArchiver archiveRootObject:@{@"feed": _photosFeed, @"next": @(_nextPhotoIndex)} toFile:[kCachePath stringByAppendingPathComponent:@"state.plist"]];
}

- (void)cleanupCache
{
    if (_photosFeed.count == 0)
        return;
    
    NSMutableSet* activeNames = [NSMutableSet setWithCapacity:_photosFeed.count];
    for (PhotoItem* item in _photosFeed) {
        [activeNames addObject:item.cachedFilepath];
        [activeNames addObject:item.cachedAuthorPicFilepath];
    }
    [activeNames addObject:[kCachePath stringByAppendingPathComponent:@"state.plist"]];
    
    dispatch_async(_queue, ^{
        NSFileManager* m = [NSFileManager defaultManager];
        NSArray* files = [m contentsOfDirectoryAtPath:kCachePath error:nil];
        for (NSString* filename in files) {
            NSString* pathname = [kCachePath stringByAppendingPathComponent:filename];
            if (![activeNames containsObject:pathname])
                [m removeItemAtPath:pathname error:nil];
        }
    });
}

#pragma mark - photos meta processing

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

    _totalPages = [feed[@"total_pages"] integerValue];
    
    NSArray* items = feed[@"photos"];
    NSMutableArray* parsedFeed = [NSMutableArray new];
    
    LOG(@"[500px] parse feed:");
    for (NSDictionary* item in items) {
        /* filter out vertical photos */
        NSInteger width = [item[@"width"] asInteger];
        NSInteger height = [item[@"height"] asInteger];
        if (width < height)
            continue;
        //*/
        
        PhotoItem* photoItem = [PhotoItem photoItemFor500px:item];
        if (photoItem == nil)
            continue;
        
        if (photoById(_photosFeed, photoItem.photoHashId))
            continue;

        [parsedFeed addObject:photoItem];
        LOG(@"[500px] feed item: %llu. %@", photoItem.photoHashId, photoItem.title);
    }
    
    if (parsedFeed.count < FEED_COUNT) {
        _currentPage = arc4random() % _totalPages;
        LOG(@"[500px] feed length - %d, too small, get the next page", (int)parsedFeed.count);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self fetchFeed];
        });
    }
    
    [self randomizeFeed:parsedFeed];
    _photosFeed = parsedFeed;
    _nextPhotoIndex = 0;
    _fetchingFeed = NO;
    
    [self saveFeed];
    
    [self fetchNextPhoto];
    [self checkAwaiters];
}

static NSDictionary* s_categoryName = nil;
static NSString* categoryNameById(NSInteger n)
{
    if (s_categoryName == nil) {
        s_categoryName = @{
                         @(0):	@"Uncategorized",
                         @(10):	@"Abstract",
                         @(11):	@"Animals",
                         @(5):	@"Black and White",
                         @(1):	@"Celebrities",
                         @(9):	@"City and Architecture",
                         @(15):	@"Commercial",
                         @(16):	@"Concert",
                         @(20):	@"Family",
                         @(14):	@"Fashion",
                         @(2):	@"Film",
                         @(24):	@"Fine Art",
                         @(23):	@"Food",
                         @(3):	@"Journalism",
                         @(8):	@"Landscapes",
                         @(12):	@"Macro",
                         @(18):	@"Nature",
                         @(4):	@"Nude",
                         @(7):	@"People",
                         @(19):	@"Performing Arts",
                         @(17):	@"Sport",
                         @(6):	@"Still Life",
                         @(21):	@"Street",
                         @(26):	@"Transportation",
                         @(13):	@"Travel",
                         @(22):	@"Underwater",
                         @(27):	@"Urban Exploration",
                         @(25):	@"Wedding",
                         };
    }
    
    return toSafeString(s_categoryName[@(n)]);
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
                             @"only": categoryNameById(_currentCategory),
                             @"consumer_key": @"DI7ANAHTalF5WUsa7vdaHiY4tM8kwduHT08vDaJm"
                             };
    
    LOG(@"[500px] fetching feed");
    AFHTTPSessionManager* manager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseUrl];
    NSURLSessionDataTask* task = [manager GET:methodPhotos parameters:params
         success:^(NSURLSessionDataTask *task, id responseObject) {
             LOG(@"[500px] feed received");
             [_networkTasks removeObject:task];
             [self parseFeed:responseObject];
         }
         failure:^(NSURLSessionDataTask *task, NSError *error) {
             LOG(@"[500px] feed fetching failed");
             [_networkTasks removeObject:task];
             _fetchingFeed = NO;
         }];
    [_networkTasks addObject:task];
}

#pragma mark - photos payload handling

- (void)fetchNextPhoto
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self fetchNextPhoto]; });
        return;
    }

    if (_photosFeed.count == 0) {
        LOG(@"[500px] no more photos to fetch");
        return;
    }

    PhotoItem* nextPhoto = nil;
    
    for (NSInteger n = 0; n < 3; ++n) {
        PhotoItem* photo = _photosFeed[(_nextPhotoIndex + n) % _photosFeed.count];
        if (!photo.cached) {
            nextPhoto = photo;
            break;
        }
    }
    
    if (!nextPhoto)
        return;
    
    [self fetchAuthorPic:nextPhoto];
    [self fetchPhoto:nextPhoto];
}

- (void)fetchPhoto:(PhotoItem*)nextPhoto
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self fetchNextPhoto]; });
        return;
    }
    
    if (_cancelRequested)
        return;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:nextPhoto.cachedFilepath]) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:nextPhoto]; });
        return;
    }

    LOG(@"[500px] fetch next photo: %llu.%@ - %@, to %@", nextPhoto.photoHashId, nextPhoto.title, nextPhoto.photoUrl, nextPhoto.cachedFilepath);

    NSURL* url = [NSURL URLWithString:nextPhoto.photoUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    __weak id w_self = self;
    
    AFURLSessionManager* manager = [[AFURLSessionManager alloc] init];
    __block NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil
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
                                    
                                    LOG(@"[500px] fetch next photo: %llu. %@", nextPhoto.photoHashId, error ? @"failed" : @"completed");
                                    [s_self->_networkTasks removeObject:downloadTask];
                                    
                                    [s_self didFetchedPhoto:nextPhoto];
                                }];
    
    [_networkTasks addObject:downloadTask];
    [downloadTask resume];
}

- (void)fetchAuthorPic:(PhotoItem*)photoItem
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self fetchNextPhoto]; });
        return;
    }
    
    if (_cancelRequested)
        return;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:photoItem.cachedAuthorPicFilepath]) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:photoItem]; });
        return;
    }
    
    LOG(@"[500px] fetch authorpic: %llu. - %@, to %@", photoItem.photoHashId, photoItem.authorPicUrl, photoItem.cachedAuthorPicFilepath);

    NSURL* url = [NSURL URLWithString:photoItem.authorPicUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    __weak id w_self = self;
    
    AFURLSessionManager* manager = [[AFURLSessionManager alloc] init];
    __block NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil
                                destination:^NSURL *(NSURL *targetPath, NSURLResponse *response)
                                {
                                    NSFileManager* m = [NSFileManager defaultManager];
                                    
                                    NSString* cachedFilepath = photoItem.cachedAuthorPicFilepath;
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
                                    
                                    LOG(@"[500px] fetch authorpic: %llu. %@", photoItem.photoHashId, error ? @"failed" : @"completed");
                                    [s_self->_networkTasks removeObject:downloadTask];
                                    
                                    NSString* cachedFilepath = photoItem.cachedAuthorPicFilepath;
                                    NSFileManager* m = [NSFileManager defaultManager];
                                    if (![m fileExistsAtPath:cachedFilepath])
                                        [m createFileAtPath:cachedFilepath contents:[NSData data] attributes:nil];

                                    [s_self didFetchedPhoto:photoItem];
                                }];
    [_networkTasks addObject:downloadTask];
    [downloadTask resume];
}

- (void)didFetchedPhoto:(PhotoItem*)photoItem
{
    if (!dispatch_get_specific(_queueTag)) {
        dispatch_async(_queue, ^{ [self didFetchedPhoto:photoItem]; });
        return;
    }
    
    if (!photoItem.cached)
        return;

    if (_indexToContinue != -1) {
        _nextPhotoIndex = _indexToContinue;
        _indexToContinue = -1;
    }

    [self checkAwaiters];
    [self fetchNextPhoto];
}

- (void)checkAwaiters
{
    // check if photo was requested by consumer and feed'em
    if (_nextPhotoHandler) {
        LOG(@"[500px] call the awaiting completion handler");
        [self retrieveNextPhotoWithCompletion:_nextPhotoHandler];
    }
}

@end

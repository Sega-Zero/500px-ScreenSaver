//
//  PhotoSource.h
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PhotoItem: NSObject <NSCoding>
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *descriptionText;
@property (nonatomic, readonly) NSString *author;
@property (nonatomic, readonly) NSString *authorPicUrl;
@property (nonatomic, readonly) NSString *rating;
@property (nonatomic, readonly) NSString *photoId;
@property (nonatomic, readonly) UInt64    photoHashId;

@property (nonatomic, readonly) NSString *photoUrl;

+ (PhotoItem*)photoItemWithId:(NSString*)photoId title:(NSString*)title description:(NSString*)description author:(NSString*)author authorPic:(NSString*)authorPic rating:(NSString*)rating photoUrl:(NSString*)photoUrl;
+ (PhotoItem*)photoItemWithHashId:(UInt64)photoHashId title:(NSString*)title description:(NSString*)description author:(NSString*)author authorPic:(NSString*)authorPic rating:(NSString*)rating photoUrl:(NSString*)photoUrl;
@end

typedef void (^PhotoSourceCompletion)(PhotoItem* photo, NSError* error);

@interface PhotoItem (Cache)
@property (nonatomic, readonly) NSString *cachedFilepath;
@property (nonatomic, readonly) NSString *cachedAuthorPicFilepath;
@property (nonatomic, readonly) BOOL cached;
@end

@protocol PhotoSource <NSObject>

- (void) retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler;
- (void) cancelPhotoRequest;

@end

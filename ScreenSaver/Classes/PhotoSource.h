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
@property (nonatomic, readonly) NSString *authorId;
@property (nonatomic, readonly) NSString *authorPicUrl;
@property (nonatomic, readonly) NSString *rating;
@property (nonatomic, readonly) NSString *photoId;
@property (nonatomic, readonly) UInt64    photoHashId;

@property (nonatomic, readonly) NSString *photoUrl;
@end

typedef void (^PhotoSourceCompletion)(PhotoItem* photo, NSError* error);

@interface PhotoItem (Cache)
@property (nonatomic, readonly) NSString *cachedFilepath;
@property (nonatomic, readonly) NSString *cachedAuthorPicFilepath;
@property (nonatomic, readonly) BOOL cached;
@end

@interface PhotoItem (px500)
+ (PhotoItem*)photoItemFor500px:(NSDictionary*)jsonObject;
@end

@protocol PhotoSource <NSObject>

- (void) retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler;
- (void) cancelPhotoRequest;

@end

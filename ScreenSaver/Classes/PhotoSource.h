//
//  PhotoSource.h
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PhotoItem: NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *descriptionText;
@property (nonatomic, readonly) NSString *author;
@property (nonatomic, readonly) NSString *rating;
@property (nonatomic, readonly) NSString *photoId;

@property (nonatomic, readonly) NSString *photoUrl;

+ (PhotoItem*)photoItemWithId:(NSString*)photoId title:(NSString*)title description:(NSString*)description author:(NSString*)author rating:(NSString*)rating photoUrl:(NSString*)photoUrl;
@end

typedef void (^PhotoSourceCompletion)(PhotoItem* photo, NSError* error);

@interface PhotoItem (Cache)
@property (nonatomic, readonly) NSString *cachedFilepath;
@end

@protocol PhotoSource <NSObject>

- (void) retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler;
- (void) cancelPhotoRequest;

@end

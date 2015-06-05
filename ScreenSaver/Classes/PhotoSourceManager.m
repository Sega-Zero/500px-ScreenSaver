//
//  PhotoSourceManager.m
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "PhotoSourceManager.h"
#import "FivehundredSource.h"

@implementation PhotoSourceManager
{
    FivehundredSource* _source;
}

+ (PhotoSourceManager *)shared
{
    static PhotoSourceManager* instance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PhotoSourceManager new];
    });
    
    return instance;
}

- (instancetype) init
{
    self = [super init];
    if (!self)
        return self;
    
    _source = [FivehundredSource new];
    return self;
}


- (void)retrieveNextPhotoWithCompletion:(PhotoSourceCompletion)completionHandler
{
    [_source retrieveNextPhotoWithCompletion:completionHandler];
}

- (void)cancelPhotoRequest
{
    [_source cancelPhotoRequest];
}

@end

//
//  PhotoSourceManager.h
//  ScreenSaver
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PhotoSource.h"

@interface PhotoSourceManager : NSObject <PhotoSource>
+ (PhotoSourceManager*) shared;
@end

//
//  ScreenSaver500pxView.m
//  ScreenSaver
//
//  Created by Сергей Галездинов on 05.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "ScreenSaver500pxView.h"

@implementation ScreenSaver500pxView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
}

- (void)animateOneFrame
{
    return;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end

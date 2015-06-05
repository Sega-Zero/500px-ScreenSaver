//
//  ScreenSaver500pxView.m
//  ScreenSaver
//
//  Created by Сергей Галездинов on 05.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "ScreenSaver500pxView.h"
#import "PhotoSourceManager.h"

#define PHOTO_SHOW_INTERVAL 3.

@implementation ScreenSaver500pxView
{
    BOOL _fetchingImage;
    NSImage* _activeImage;
    NSTimeInterval _activeImageShownAt;
    NSImage* _nextImage;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];
        [self retrieveNextPhoto];
    }
    return self;
}

- (void)retrieveNextPhoto
{
    if (_fetchingImage)
        return;
    _fetchingImage = YES;
    
    [[PhotoSourceManager shared] retrieveNextPhotoWithCompletion:^(PhotoItem *photo, NSError *error) {
        if (error)
            return;
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            NSImage* image = [[NSImage alloc] initWithContentsOfFile:photo.cachedFilepath];
            dispatch_async(dispatch_get_main_queue(), ^{
                _fetchingImage = NO;
                if (!image) {
                    [self retrieveNextPhoto];
                }
                
                if (!_activeImage) {
                    [self updateActiveImage:image];
                    [self retrieveNextPhoto];
                } else
                    _nextImage = image;
            });
        });
    }];
}

- (void)updateActiveImage:(NSImage*)image
{
    _activeImage = image;
    _activeImageShownAt = [NSDate timeIntervalSinceReferenceDate];
    [self setNeedsDisplay:YES];
}

- (void)checkToNextImage
{
    if (!_nextImage) {
        [self retrieveNextPhoto];
        return;
    }
    
    NSTimeInterval shownInterval = [NSDate timeIntervalSinceReferenceDate] - _activeImageShownAt;
    if (shownInterval < PHOTO_SHOW_INTERVAL)
        return;
    
    [self updateActiveImage:_nextImage];
    _nextImage = nil;
    
    [self retrieveNextPhoto];
}

- (NSTimeInterval)animationTimeInterval
{
    return 0.5;
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
    NSColor* color = [NSColor colorWithCalibratedWhite:(arc4random()%1024) / 1024. alpha:1.0];
    [color setFill];
    [NSBezierPath fillRect:rect];
    
    if (_activeImage) {
        CGSize imageSize = _activeImage.size;
        CGRect targetRect = self.bounds;

        CGFloat targetWidth = imageSize.width / imageSize.height * CGRectGetHeight(targetRect);
        targetRect.origin.x = CGRectGetMidX(targetRect) - targetWidth / 2;
        targetRect.size.width = targetWidth;
        
        if (targetRect.origin.x > 0) {
            targetRect = self.bounds;
            CGFloat targetHeight = imageSize.height / imageSize.width * CGRectGetWidth(targetRect);
            targetRect.origin.y = CGRectGetMidY(targetRect) - targetHeight / 2;
            targetRect.size.height = targetHeight;
        }

        [_activeImage drawInRect:targetRect];
    }
}

- (void)animateOneFrame
{
//    [self setNeedsDisplay:YES];
    [self checkToNextImage];
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

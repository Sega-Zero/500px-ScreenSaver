//
//  ScreenSaver500pxView.m
//  ScreenSaver
//
//  Created by Сергей Галездинов on 05.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "ScreenSaver500pxView.h"
#import "PhotoSourceManager.h"
#import <QuartzCore/QuartzCore.h>

#define PHOTO_SHOW_INTERVAL 3.

@implementation ScreenSaver500pxView
{
    BOOL _fetchingImage;
    NSImage* _activeImage;
    NSTimeInterval _activeImageShownAt;
    NSImage* _nextImage;
}

#pragma mark view & layer methods

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/60.0];

        self.wantsLayer = YES;
        self.layerUsesCoreImageFilters = YES;
        self.layer.backgroundColor = [NSColor blackColor].CGColor;

        [self retrieveNextPhoto];
    }
    return self;
}

-(void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    [self adoptLayerGravity];
}

-(id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    if ([event isEqualToString:@"contents"]) {

        NSRect		rect = [self bounds];
        CIFilter	*transitionFilter = nil;

        static NSArray *animationTransitions = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            animationTransitions = @[kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal,
                                     @"CIBarsSwipeTransition", @"CIModTransition", @"CIPageCurlWithShadowTransition",
                                     @"CIRippleTransition", @"CISwipeTransition"];
        });

        NSString *transition = animationTransitions[arc4random_uniform((u_int32_t)animationTransitions.count)];

        if ([transition isEqualToString:@"CIModTransition"])
        {
            transitionFilter = [CIFilter filterWithName:transition];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
        }
        else if ([transition isEqualToString:@"CIRippleTransition"])
        {
            transitionFilter = [CIFilter filterWithName:transition];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
            [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
            [transitionFilter setValue:[CIImage imageWithColor:[CIColor colorWithRed:1. green:0 blue:0]] forKey:@"inputShadingImage"];
        }

        CATransition *newTransition = [CATransition animation];
        if (transitionFilter)
            [newTransition setFilter:transitionFilter];
        else
        {
            [newTransition setType:transition];
            [newTransition setSubtype:kCATransitionFromLeft];
        }

        [newTransition setDuration:1.];

        return newTransition;
    }
    
    return [super actionForLayer:layer forKey:event];
}

-(void) adoptLayerGravity
{
    NSSize imageSize = _activeImage.size;
    NSRect viewFrame = self.frame;

    if (imageSize.width < viewFrame.size.width || imageSize.height < viewFrame.size.height) {
        self.layer.contentsGravity = kCAGravityResizeAspect;
        self.layer.frame = viewFrame;
        return;
    }

    CGFloat targetWidth = imageSize.width / imageSize.height * viewFrame.size.height;
    CGRect targetRect = CGRectMake(self.bounds.size.width / 2 - targetWidth / 2,
                                   0,
                                   targetWidth,
                                   viewFrame.size.height);

    self.layer.contentsGravity = kCAGravityResize;

    if (targetRect.origin.x > 0) {
        self.layer.contentsGravity = kCAGravityResizeAspect;
        CGFloat targetHeight = imageSize.height / imageSize.width * viewFrame.size.width;
        targetRect = CGRectMake(NSMinX(viewFrame),
                                NSMidY(viewFrame) - targetHeight / 2,
                                viewFrame.size.width,
                                targetHeight);
    }

    self.animator.layer.frame = targetRect;
}

#pragma mark internal methods

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

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self adoptLayerGravity];
        self.animator.layer.contents = [_activeImage layerContentsForContentsScale:[_activeImage recommendedLayerContentsScale:0]];
    } completionHandler:nil];
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

#pragma mark screensaver override methods

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

- (void)animateOneFrame
{
    [self checkToNextImage];
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

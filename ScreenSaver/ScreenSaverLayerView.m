//
//  ScreenSaverLayerView.m
//  ScreenSaver
//
//  Created by Сергей Галездинов on 06.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "ScreenSaverLayerView.h"
#import <QuartzCore/QuartzCore.h>

@implementation ScreenSaverLayerView

-(instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        self.wantsLayer = YES;
        self.layerUsesCoreImageFilters = YES;
        self.layer.backgroundColor = [NSColor blackColor].CGColor;
    }
    return self;
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

-(void) adoptLayerGravity:(NSSize)withImageSize
{
    NSRect viewFrame = self.frame;

    if (withImageSize.width < viewFrame.size.width || withImageSize.height < viewFrame.size.height) {
        self.layer.contentsGravity = kCAGravityResizeAspect;
        self.layer.frame = viewFrame;
        return;
    }

    CGFloat targetWidth = withImageSize.width / withImageSize.height * viewFrame.size.height;
    CGRect targetRect = CGRectMake(self.bounds.size.width / 2 - targetWidth / 2,
                                   0,
                                   targetWidth,
                                   viewFrame.size.height);

    self.layer.contentsGravity = kCAGravityResize;

    if (targetRect.origin.x > 0) {
        CGFloat targetHeight = withImageSize.height / withImageSize.width * viewFrame.size.width;
        targetRect = CGRectMake(NSMinX(viewFrame),
                                NSMidY(viewFrame) - targetHeight / 2,
                                viewFrame.size.width,
                                targetHeight);
    }
    
    self.animator.layer.frame = targetRect;
}

@end

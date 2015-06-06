//
//  ScreenSaver500pxView.m
//  ScreenSaver
//
//  Created by Сергей Галездинов on 05.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "ScreenSaver500pxView.h"
#import "PhotoSourceManager.h"
#import "ScreenSaverLayerView.h"
#import <QuartzCore/QuartzCore.h>

#define PHOTO_SHOW_INTERVAL 3.

@implementation ScreenSaver500pxView
{
    BOOL _fetchingImage;
    NSImage* _activeImage;
    NSTimeInterval _activeImageShownAt;
    NSImage* _nextImage;
    PhotoItem *_nextPhotoItem;

    ScreenSaverLayerView *_imageLayerView;
    NSImageView *_authorAvatar;
    NSTextField *_authorName, *_photoDescription;
}

#pragma mark view & layer methods

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/60.0];
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor blackColor].CGColor;

        _imageLayerView = [[ScreenSaverLayerView alloc] initWithFrame:frame];
        [self addSubview:_imageLayerView];
        _imageLayerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_imageLayerView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_imageLayerView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_imageLayerView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_imageLayerView)]];

        _authorAvatar = [[NSImageView alloc] initWithFrame:NSZeroRect];
        _authorAvatar.imageScaling = NSImageScaleAxesIndependently;
        _authorAvatar.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_authorAvatar];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_authorAvatar(<=64)]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_authorAvatar(<=64)]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar)]];

        NSShadow* shadow = [[NSShadow alloc] init];
        shadow.shadowBlurRadius = 2;
        shadow.shadowOffset = NSMakeSize(2, 2);
        shadow.shadowColor = [NSColor blackColor];

        _photoDescription = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _photoDescription.translatesAutoresizingMaskIntoConstraints = NO;
        _photoDescription.font = [NSFont systemFontOfSize:21];
        _photoDescription.textColor = [NSColor whiteColor];
        _photoDescription.bordered = NO;
        _photoDescription.alignment = NSRightTextAlignment;
        _photoDescription.drawsBackground = NO;
        _photoDescription.editable = NO;
        _photoDescription.shadow = shadow;
        [_photoDescription setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

        [self addSubview:_photoDescription];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=0)-[_photoDescription]-10-[_authorAvatar]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar, _photoDescription)]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoDescription
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:_authorAvatar
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1.
                                                          constant:0]];


        _authorName = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _authorName.translatesAutoresizingMaskIntoConstraints = NO;
        _authorName.font = [NSFont systemFontOfSize:18];
        _authorName.textColor = [NSColor whiteColor];
        _authorName.bordered = NO;
        _authorName.alignment = NSRightTextAlignment;
        _authorName.drawsBackground = NO;
        _authorName.editable = NO;
        _authorName.shadow = shadow;
        [_authorName setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

        [self addSubview:_authorName];

        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=0)-[_authorName]-10-[_authorAvatar]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar, _authorName)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_photoDescription]-5-[_authorName]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_photoDescription, _authorName)]];

        [self retrieveNextPhoto];
    }
    return self;
}

-(void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    [_imageLayerView adoptLayerGravity:_activeImage.size];
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
                    _nextPhotoItem = photo;
                    [self updateActiveImage:image photoItem:photo];
                    [self retrieveNextPhoto];
                }
                else
                {
                    _nextImage = image;
                    _nextPhotoItem = photo;
                }
            });
        });
    }];
}

- (void)updateActiveImage:(NSImage*)image photoItem:(PhotoItem*)item
{
    _activeImage = image;
    _activeImageShownAt = [NSDate timeIntervalSinceReferenceDate];
    _authorAvatar.alphaValue = 0;
    _authorName.alphaValue = 0;
    _photoDescription.alphaValue = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [_imageLayerView adoptLayerGravity:_activeImage.size];
        _imageLayerView.animator.layer.contents = [_activeImage layerContentsForContentsScale:[_activeImage recommendedLayerContentsScale:0]];
    } completionHandler:^{
        _authorAvatar.image = _activeImage;
        _authorName.stringValue = item.author;
        _photoDescription.stringValue = item.title;

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            _authorAvatar.animator.alphaValue = 1;
            _authorName.animator.alphaValue = 1;
            _photoDescription.animator.alphaValue = 1;
        } completionHandler:nil];
    }];
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
    
    [self updateActiveImage:_nextImage photoItem:_nextPhotoItem];
    _nextImage = nil;
    _nextPhotoItem = nil;

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

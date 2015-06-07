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
#import "Common.h"

#import "CocoaLumberjack.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"

#define PHOTO_SHOW_INTERVAL 3.

@implementation ScreenSaver500pxView
{
    BOOL _fetchingImage;
    NSImage* _activeImage;
    NSTimeInterval _activeImageShownAt;
    NSImage* _nextImage;
    NSImage* _nextAuthorImage;
    PhotoItem *_nextPhotoItem;

    ScreenSaverLayerView *_imageLayerView;
    NSImageView *_authorAvatar;
    NSTextField *_authorName, *_photoDescription;
    NSImageView *_loadingImageView;
}

#pragma mark view & layer methods

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        registerPrefsDefaults(@{kPrefsCategory: @(-1)});
        
#if DEBUG
        [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelDebug];
        DDFileLogger* ff = [[DDFileLogger alloc] init];
        ff.doNotReuseLogFiles = YES;
        ff.maximumFileSize = 0;
        [ff.logFileManager setMaximumNumberOfLogFiles:100];
        [DDLog addLogger:ff withLevel:DDLogLevelAll];
#endif
        
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
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_authorAvatar(50)]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_authorAvatar(50)]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_authorAvatar)]];

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
        _authorName.font = [NSFont systemFontOfSize:14];
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

        _loadingImageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        _loadingImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _loadingImageView.image = [NSImage imageNamed:@"Logo"];
        _loadingImageView.alphaValue = 0;
        [self addSubview:_loadingImageView];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_loadingImageView
                                                         attribute:NSLayoutAttributeCenterX
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeCenterX
                                                        multiplier:1.
                                                          constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_loadingImageView
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1.
                                                          constant:0]];


        [self retrieveNextPhoto];
        [self animateLoading];
    }
    return self;
}

- (void)cleanState
{
    _fetchingImage = NO;
    _activeImage = nil;
    _activeImageShownAt = 0;
    _nextImage = nil;
    _nextAuthorImage = nil;
    _nextPhotoItem = nil;
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
            NSImage* authorImage = [[NSImage alloc] initWithContentsOfFile:photo.cachedAuthorPicFilepath];

            //this is a very rare to happen, but sometimes after loading from file we may have an image with weird size (like {72, 150994944})
            //couldn't find out the reason for this, drawInRect will fix an image and there won't be a layout ambiguity in avatar which may lead to main thread freezing
            if (authorImage.size.width > authorImage.size.height || authorImage.size.height > authorImage.size.width)
                authorImage = [NSImage imageWithSize:NSMakeSize(50, 50) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
                    [authorImage drawInRect:dstRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1. respectFlipped:YES hints:nil];
                    return YES;
                }];

            dispatch_async(dispatch_get_main_queue(), ^{
                _loadingImageView.alphaValue = 0;

                _fetchingImage = NO;
                if (!image) {
                    [self retrieveNextPhoto];
                }

                if (!_activeImage) {
                    _nextPhotoItem = photo;
                    [self updateActiveImage:image authorImage:authorImage photoItem:photo];
                    [self retrieveNextPhoto];
                }
                else
                {
                    _nextImage = image;
                    _nextAuthorImage = authorImage;
                    _nextPhotoItem = photo;
                }
            });
        });
    }];
}

- (void)updateActiveImage:(NSImage*)image authorImage:(NSImage*)authorImage photoItem:(PhotoItem*)item
{
    _activeImage = image;
    _activeImageShownAt = [NSDate timeIntervalSinceReferenceDate];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        _authorAvatar.animator.alphaValue = 0;
        _authorName.animator.alphaValue = 0;
        _photoDescription.animator.alphaValue = 0;
        [_imageLayerView adoptLayerGravity:_activeImage.size];
        _imageLayerView.animator.layer.contents = [_activeImage layerContentsForContentsScale:[_activeImage recommendedLayerContentsScale:0]];
    } completionHandler:^{
        _authorAvatar.image = authorImage;
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
    
    [self updateActiveImage:_nextImage authorImage:_nextAuthorImage photoItem:_nextPhotoItem];
    _nextImage = nil;
    _nextAuthorImage = nil;
    _nextPhotoItem = nil;

    [self retrieveNextPhoto];
}

- (void)animateLoading
{
    if (!_activeImage) {
        _authorAvatar.image = nil;
        _authorName.stringValue = @"";
        _photoDescription.stringValue = @"";

        _authorAvatar.animator.alphaValue = 1;
        _authorName.animator.alphaValue = 1;
        _photoDescription.animator.alphaValue = 1;

        _imageLayerView.layer.contents = nil;

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 1.2;
            _loadingImageView.animator.alphaValue = _loadingImageView.alphaValue > 0.2 ? 0.2 : 1;
        } completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self animateLoading];
            });
        }];
    }
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
    [[PhotoSourceManager shared] cancelPhotoRequest];
}

- (void)animateOneFrame
{
    [self checkToNextImage];
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    if (!_prefsSheet)
    {
        NSArray *topLevels = nil;
        NSNib *prefsNib = [[NSNib alloc] initWithNibNamed:@"PrefsSheet" bundle:[NSBundle bundleForClass:[self class]]];
        if (![prefsNib instantiateWithOwner:self topLevelObjects:&topLevels])
        {
            NSLog( @"Failed to load configure sheet." );
            NSBeep();
        }
    }

    //see https://github.com/500px/api-documentation/blob/master/basics/formats_and_terms.md#categories
    NSDictionary *categories = @{                                //this strings are for genstrings utility
                                   @"Uncategorized"        : @0, //NSLocalizedString(@"Uncategorized", "title for Uncategorized category in preferences")
                                   @"Abstract"             : @10,//NSLocalizedString(@"Abstract", "title for Abstract category in preferences")
                                   @"Animals"              : @11,//NSLocalizedString(@"Animals", "title for Animals category in preferences")
                                   @"Black and White"      : @5, //NSLocalizedString(@"Black and White", "title for Black and White category in preferences")
                                   @"Celebrities"          : @1, //NSLocalizedString(@"Celebrities", "title for Celebrities category in preferences")
                                   @"City and Architecture": @9, //NSLocalizedString(@"City and Architecture", "title for City and Architecture category in preferences")
                                   @"Commercial"           : @15,//NSLocalizedString(@"Commercial", "title for Commercial category in preferences")
                                   @"Concert"              : @16,//NSLocalizedString(@"Concert", "title for Concert category in preferences")
                                   @"Family"               : @20,//NSLocalizedString(@"Family", "title for Family category in preferences")
                                   @"Fashion"              : @14,//NSLocalizedString(@"Fashion", "title for Fashion category in preferences")
                                   @"Film"                 : @2, //NSLocalizedString(@"Film", "title for Film category in preferences")
                                   @"Fine Art"             : @24,//NSLocalizedString(@"Fine Art", "title for Fine Art category in preferences")
                                   @"Food"                 : @23,//NSLocalizedString(@"Food", "title for Food category in preferences")
                                   @"Journalism"           : @3, //NSLocalizedString(@"Journalism", "title for Journalism category in preferences")
                                   @"Landscapes"           : @8, //NSLocalizedString(@"Landscapes", "title for Landscapes category in preferences")
                                   @"Macro"                : @12,//NSLocalizedString(@"Macro", "title for Macro category in preferences")
                                   @"Nature"               : @18,//NSLocalizedString(@"Nature", "title for Nature category in preferences")
                                   @"Nude"                 : @4, //NSLocalizedString(@"Nude", "title for Nude category in preferences")
                                   @"People"               : @7, //NSLocalizedString(@"People", "title for People category in preferences")
                                   @"Performing Arts"      : @19,//NSLocalizedString(@"Performing Arts", "title for Performing Arts category in preferences")
                                   @"Sport"                : @17,//NSLocalizedString(@"Sport", "title for Sport category in preferences")
                                   @"Still Life"           : @6, //NSLocalizedString(@"Still Life", "title for Still Life category in preferences")
                                   @"Street"               : @21,//NSLocalizedString(@"Street", "title for Street category in preferences")
                                   @"Transportation"       : @26,//NSLocalizedString(@"Transportation", "title for Transportation category in preferences")
                                   @"Travel"               : @13,//NSLocalizedString(@"Travel", "title for Travel category in preferences")
                                   @"Underwater"           : @22,//NSLocalizedString(@"Underwater", "title for Underwater category in preferences")
                                   @"Urban Exploration"    : @27,//NSLocalizedString(@"Urban Exploration", "title for Urban Exploration category in preferences")
                                   @"Wedding"              : @25 //NSLocalizedString(@"Wedding", "title for Wedding category in preferences")
                               };

    NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:categories.count];

    [categories enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [menuItems addObject:@{@"localized" : NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:[self class]], ""), @"key" : key}];
    }];

    [menuItems sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj1[@"localized"] localizedStandardCompare:obj2[@"localized"]];
    }];

    NSInteger selectedIndex = prefsIntValue(kPrefsCategory);
    [_browseCategory removeAllItems];
    [menuItems enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        [_browseCategory addItemWithTitle:obj[@"localized"]];
        NSMenuItem *item = [_browseCategory lastItem];
        item.tag = [categories[obj[@"key"]] integerValue];
        if (item.tag == selectedIndex)
            [_browseCategory selectItem:item];
    }];
    
    NSMenuItem* allItem = [NSMenuItem new];
    allItem.title = NSLocalizedStringFromTableInBundle(@"All Categories", nil, [NSBundle bundleForClass:[self class]], ""); //NSLocalizedString(@"All Categories", "title for 'all categories' item in preferences")
    allItem.tag = -1;
    [_browseCategory.menu insertItem:allItem atIndex:0];
    if (allItem.tag == selectedIndex)
        [_browseCategory selectItemAtIndex:0];
    
    [_browseCategory.menu insertItem:[NSMenuItem separatorItem] atIndex:1];

    return _prefsSheet;
}

#pragma mark preferences ui handlers

- (IBAction)cancelClick:(id)sender {
    [[NSApp mainWindow] endSheet:_prefsSheet];
}

- (IBAction)okClick:(id)sender {
    NSInteger prevCategory = prefsIntValue(kPrefsCategory);
    NSInteger newCategory = _browseCategory.selectedItem.tag;
    if (prevCategory != newCategory) {
        setPrefsIntValue(kPrefsCategory, _browseCategory.selectedItem.tag, PREFS_FORCE_SYNC);

        [[PhotoSourceManager shared] cancelPhotoRequest];
        [self cleanState];
        [self retrieveNextPhoto];
        [self animateLoading];
    }
    [[NSApp mainWindow] endSheet:_prefsSheet];
}

@end

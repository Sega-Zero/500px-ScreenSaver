//
//  AppDelegate.m
//  ScreenSaverLoader
//
//  Created by Denis Stanishevsky on 05/06/15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import "AppDelegate.h"
#import "ScreenSaver500pxView.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
{
    ScreenSaver500pxView *_screenSaver;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _screenSaver = [ScreenSaver500pxView new];
    _screenSaver.translatesAutoresizingMaskIntoConstraints = NO;
    [_window.contentView addSubview:_screenSaver];
    [_window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_screenSaver]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_screenSaver)]];
    [_window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_screenSaver]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_screenSaver)]];
    
    [_screenSaver startAnimation];
    [NSTimer scheduledTimerWithTimeInterval:[_screenSaver animationTimeInterval] target:_screenSaver selector:@selector(animateOneFrame) userInfo:nil repeats:YES];
    
    __block BOOL inOptions = NO;
    [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^NSEvent *(NSEvent *ev) {
        if (inOptions)
            return ev;
        inOptions = YES;
        [_window beginSheet:[_screenSaver configureSheet] completionHandler:^(NSModalResponse returnCode) {
            inOptions = NO;
        }];
        return ev;
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end

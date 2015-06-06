//
//  ScreenSaverLayerView.h
//  ScreenSaver
//
//  Created by Сергей Галездинов on 06.06.15.
//  Copyright (c) 2015 Сергей Галездинов. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ScreenSaverLayerView : NSView

-(void) adoptLayerGravity:(NSSize)withImageSize;
@end

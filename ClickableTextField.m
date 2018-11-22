//
//  ClickableTextField.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "ClickableTextField.h"

@implementation ClickableTextField

//show mouse as 'hand cursor'
- (void)resetCursorRects
{
    //skip if no plist
    if(YES == [self.stringValue hasPrefix:@"no plist"])
    {
        //bail
        goto bail;
    }
    
    //set as 'hand cursor'
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
    
bail:
    
    return;
}

@end

//
//  PrefsWindowController.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AboutWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak) IBOutlet NSTextField *versionLabel;

/* METHODS */

//invoked when user clicks 'more info' button
// ->open KK's webpage
- (IBAction)moreInfo:(id)sender;

@end

//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "Utilities.h"
#import "AppDelegate.h"

#import "AboutWindowController.h"


@implementation AboutWindowController

@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //set version sting
    [self.versionLabel setStringValue:[NSString stringWithFormat:@"version: %@", getAppVersion()]];

    return;
}

//automatically invoked when user clicks 'more info'
// ->load knockknock's html page
- (IBAction)moreInfo:(id)sender
{
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://objective-see.com/products/knockknock.html"]];
        
    return;
}
@end

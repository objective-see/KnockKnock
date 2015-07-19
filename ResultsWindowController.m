//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "Utilities.h"
#import "AppDelegate.h"

#import "ResultsWindowController.h"


@implementation ResultsWindowController

@synthesize details;
@synthesize detailsLabel;

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
    
    //set details
    self.detailsLabel.stringValue = self.details;
    
    return;
}

//automatically invoked when user clicks 'OK'
// ->close window
-(IBAction)close:(id)sender
{
    //close
    [[self window] close];
        
    return;
}

//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    //when user wants to save results
    // ->show popup once (this) window closes
    if(YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.saveOutput)
    {
        //save after delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //save
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) saveResults];
        });
    }

    return;
}


@end

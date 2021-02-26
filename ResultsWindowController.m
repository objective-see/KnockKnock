//
//  ResultsWindowController.m
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
@synthesize okButton;
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
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set details
    self.detailsLabel.stringValue = self.details;
    
    //make 'ok' button active
    [self.window makeFirstResponder:okButton];
    
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
    
    return;
}

@end

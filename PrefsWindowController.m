//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "AppDelegate.h"
#import "PrefsWindowController.h"


@implementation PrefsWindowController

@synthesize saveOutput;
@synthesize shouldSaveNow;
@synthesize disableVTQueries;
@synthesize showTrustedItems;


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
    
    return;
}

//save existing prefs
-(void)captureExistingPrefs
{
    //save current state of 'show os/trusted' components
    self.showTrustedItems = self.showTrustedItemsBtn.state;
    
    //save current state of 'disable VT'
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    //save current state of 'save' button
    self.saveOutput = self.saveOutputBtn.state;
    
    return;
}

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender
{
    //first, any prefs changed, a 'save' set
    // ->set 'save now' flag
    if( ((self.showTrustedItems != self.showTrustedItemsBtn.state) ||
         (self.disableVTQueries != self.disableVTQueriesBtn.state) ||
         (self.saveOutput != self.saveOutputBtn.state) ) &&
       (YES == self.saveOutputBtn.state) )
    {
        //set
        self.shouldSaveNow = YES;
    }
    //don't save
    else
    {
        //unset
        self.shouldSaveNow = NO;
    }
    
    //save hiding OS components flag
    self.showTrustedItems = self.showTrustedItemsBtn.state;
    
    //save disabling VT flag
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    
    
    //save save output flag
    self.saveOutput = self.saveOutputBtn.state;
    
    //close
    [self.window close];
    
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    //call back up into app delegate for filtering/hiding OS components
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) applyPreferences];

    return;
}
@end

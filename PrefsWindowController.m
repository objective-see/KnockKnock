//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "Utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"


@implementation PrefsWindowController

@synthesize okButton;
@synthesize saveOutput;
@synthesize shouldSaveNow;
@synthesize disableVTQueries;
@synthesize showTrustedItems;
@synthesize disableUpdateCheck;


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
    
    //make button selected
    [self.window makeFirstResponder:self.okButton];
    
    //check if 'show trusted items' button should be selected
    if(YES == self.showTrustedItems)
    {
        //set
        self.showTrustedItemsBtn.state = STATE_ENABLED;
    }
    
    //check if 'disable update check' button should be selected
    if(YES == self.disableUpdateCheck)
    {
        //set
        self.disableUpdateCheckBtn.state = STATE_ENABLED;
    }

    //check if 'disable vt queries' button should be selected
    if(YES == self.disableVTQueries)
    {
        //set
        self.disableVTQueriesBtn.state = STATE_ENABLED;
    }
    
    //check if 'save output' button should be selected
    if(YES == self.saveOutput)
    {
        //set
        self.saveOutputBtn.state = STATE_ENABLED;
    }
    
    //capture existing prefs
    // ->needed to trigger re-saves
    [self captureExistingPrefs];
    
    return;
}

//register default prefs
// only used if user hasn't set any
-(void)registerDefaults
{
    //set defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PREF_SHOW_TRUSTED_ITEMS:@NO, PREF_DISABLE_UPDATE_CHECK:@NO, PREF_DISABLE_VT_QUERIRES:@NO, PREF_SAVE_OUTPUT:@NO}];
    
    return;
}

//load (persistence) preferences from file system
-(void)loadPreferences
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];

    //load prefs
    // ->won't be any until user set some...
    if(nil != defaults)
    {
        //load 'show trusted items'
        if(nil != [defaults objectForKey:PREF_SHOW_TRUSTED_ITEMS])
        {
            //save
            self.showTrustedItems = [defaults boolForKey:PREF_SHOW_TRUSTED_ITEMS];
        }
        
        //load 'disable update check'
        if(nil != [defaults objectForKey:PREF_DISABLE_UPDATE_CHECK])
        {
            //save
            self.disableUpdateCheck = [defaults boolForKey:PREF_DISABLE_UPDATE_CHECK];
        }
        
        //load 'disable vt queries'
        if(nil != [defaults objectForKey:PREF_DISABLE_VT_QUERIRES])
        {
            //save
            self.disableVTQueries = [defaults boolForKey:PREF_DISABLE_VT_QUERIRES];
        }
        
        //load 'save output'
        if(nil != [defaults objectForKey:PREF_SAVE_OUTPUT])
        {
            //save
            self.saveOutput = [defaults boolForKey:PREF_SAVE_OUTPUT];
        }
    }
    
    return;
}

//save existing prefs
-(void)captureExistingPrefs
{
    //save current state of 'include os/trusted' components
    self.showTrustedItems = self.showTrustedItemsBtn.state;
    
    //save current state of 'disable update checks'
    self.disableUpdateCheck = self.disableUpdateCheckBtn.state;
    
    //save current state of 'disable VT'
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    //save current state of 'save' button
    self.saveOutput = self.saveOutputBtn.state;
    
    return;
}

//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //save prefs
    [self savePrefs];
    
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

//save prefs
-(void)savePrefs
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];
    
    //first, any prefs changed, a 'save' set
    // ->set 'save now' flag
    if( ((self.showTrustedItems != self.showTrustedItemsBtn.state) ||
         (self.disableUpdateCheck != self.disableUpdateCheckBtn.state) ||
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
    
    //save current state of 'disable update checks'
    self.disableUpdateCheck = self.disableUpdateCheckBtn.state;
    
    //save disabling VT flag
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    //save save output flag
    self.saveOutput = self.saveOutputBtn.state;
    
    //save 'show trusted items'
    [defaults setBool:self.showTrustedItems forKey:PREF_SHOW_TRUSTED_ITEMS];
    
    //save 'disable update checks'
    [defaults setBool:self.disableUpdateCheck forKey:PREF_DISABLE_UPDATE_CHECK];
    
    //save 'disable vt queries'
    [defaults setBool:self.disableVTQueries forKey:PREF_DISABLE_VT_QUERIRES];
    
    //save 'save output'
    [defaults setBool:self.saveOutput forKey:PREF_SAVE_OUTPUT];
    
    //flush/save
    [defaults synchronize];
    
    //call back up into app delegate for filtering/hiding OS components
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) applyPreferences];

    return;
}


//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender
{
    //close
    [self.window close];
    
    return;
}
@end

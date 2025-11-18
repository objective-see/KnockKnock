//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"

@implementation PrefsWindowController

@synthesize okButton;
@synthesize saveOutput;
@synthesize disableVTQueries;
@synthesize showTrustedItems;
@synthesize disableUpdateCheck;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    [self.window makeFirstResponder:self.okButton];
}

//automatically invoked when window is loaded
// initialize prefs UI
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
    
    //VT API key
    if(0 != self.vtAPIKey.length) {
        
        self.apiTextField.stringValue = self.vtAPIKey;
    }
    
    
    
    return;
}

-(void)windowDidBecomeKey:(NSNotification *)notification {
    [self.window makeFirstResponder:self.okButton];
}


//register default prefs
// only used if user hasn't set any
-(void)registerDefaults
{
    //set defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PREF_SHOW_TRUSTED_ITEMS:@NO, PREF_DISABLE_UPDATE_CHECK:@NO, PREF_DISABLE_VT_QUERIRES:@NO}];
    
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
        
    }
    
    //load API key
    self.vtAPIKey = loadAPIKeyFromKeychain();
    
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
        
    //save hiding OS components flag
    self.showTrustedItems = self.showTrustedItemsBtn.state;
    
    //save current state of 'disable update checks'
    self.disableUpdateCheck = self.disableUpdateCheckBtn.state;
    
    //save disabling VT flag
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    //save save output flag
    self.saveOutput = self.saveOutputBtn.state;
    
    //grab API key
    self.vtAPIKey = self.apiTextField.stringValue;
    
    //save 'show trusted items'
    [defaults setBool:self.showTrustedItems forKey:PREF_SHOW_TRUSTED_ITEMS];
    
    //save 'disable update checks'
    [defaults setBool:self.disableUpdateCheck forKey:PREF_DISABLE_UPDATE_CHECK];
    
    //save 'disable vt queries'
    [defaults setBool:self.disableVTQueries forKey:PREF_DISABLE_VT_QUERIRES];
    
    //save vt API key
    saveAPIKeyToKeychain(self.apiTextField.stringValue);
    
    //flush/save
    [defaults synchronize];
    
    //call back up into app delegate for filtering/hiding OS components
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) applyPreferences];

    return;
}

//show info about API
- (IBAction)showAPIHelp:(id)sender {
    
    //popover
    NSPopover *popover = [[NSPopover alloc] init];
        
    //view controller
    NSViewController *viewController = [[NSViewController alloc] init];
    
    //set view
    viewController.view = self.getAPIHelp;
    
    //make url a hyperlink
    makeTextViewHyperlink(self.getAPILink, [NSURL URLWithString:@"https://docs.virustotal.com/docs/please-give-me-an-api-key"]);
    
    //init
    popover.contentViewController = viewController;
    popover.behavior = NSPopoverBehaviorTransient; // Closes when you click outside
        
    //show relative to the button
    [popover showRelativeToRect:[sender bounds]
                         ofView:sender
                  preferredEdge:NSRectEdgeMaxY];    
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

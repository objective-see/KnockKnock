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
        self.showTrustedItemsBtn.state = NSControlStateValueOn;
    }
    
    //check if 'show trusted items' button should be selected
    if(YES == self.startAtLogin)
    {
        //set
        self.startAtLoginBtn.state = NSControlStateValueOn;
    }
    
    //check if 'disable update check' button should be selected
    if(YES == self.disableUpdateCheck)
    {
        //set
        self.disableUpdateCheckBtn.state = NSControlStateValueOn;
    }

    //check if 'disable vt queries' button should be selected
    if(YES == self.disableVTQueries)
    {
        //set
        self.disableVTQueriesBtn.state = NSControlStateValueOn;
    }
    
    //check if 'always run as root' button should be selected
    if(YES == self.alwaysRoot)
    {
        //set
        self.alwaysRootBtn.state = NSControlStateValueOn;
    }
    
    //VT API key
    if(0 != self.vtAPIKey.length) {

        //set
        self.apiTextField.stringValue = self.vtAPIKey;
    }
    
    //make url a hyperlink
    makeTextViewHyperlink(self.getAPILink, [NSURL URLWithString:@"https://docs.virustotal.com/docs/please-give-me-an-api-key"]);
    

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
    // note: 'getPreference' also applies these (needed when root, as it reads the console user's prefs directly)
    [[NSUserDefaults standardUserDefaults] registerDefaults:preferenceDefaults()];
    
    return;
}

//load (persistence) preferences from file system
// note: via 'getPreference', so when root, these are the console user's (not root's)
-(void)loadPreferences
{
    //load 'show trusted items'
    self.showTrustedItems = getPreferenceBool(PREF_SHOW_TRUSTED_ITEMS);
    
    //load 'start at login'
    self.startAtLogin = getPreferenceBool(PREF_START_AT_LOGIN);
    
    //load 'disable update check'
    self.disableUpdateCheck = getPreferenceBool(PREF_DISABLE_UPDATE_CHECK);
    
    //load 'disable vt queries'
    self.disableVTQueries = getPreferenceBool(PREF_DISABLE_VT_QUERIRES);
    
    //load 'always run as root'
    self.alwaysRoot = getPreferenceBool(PREF_ALWAYS_RUN_AS_ROOT);
    
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
// note: via 'setPreference', so when root, these are the console user's (not root's)
-(void)savePrefs
{
    //grab 'include macOS/known items'
    self.showTrustedItems = self.showTrustedItemsBtn.state;
    
    //grab 'start at login' state
    self.startAtLogin = self.startAtLoginBtn.state;
    
    //grab 'disable update checks' state
    self.disableUpdateCheck = self.disableUpdateCheckBtn.state;
    
    //grab: disable VT state
    self.disableVTQueries = self.disableVTQueriesBtn.state;
    
    //grab: always run as root
    self.alwaysRoot = self.alwaysRootBtn.state;
    
    //grab API key
    self.vtAPIKey = self.apiTextField.stringValue;
    
    //save 'show trusted items'
    setPreference(PREF_SHOW_TRUSTED_ITEMS, @(self.showTrustedItems));
    
    //log item state change?
    // toggle login item (enable/disable)
    if(self.startAtLogin != getPreferenceBool(PREF_START_AT_LOGIN)) {
        
        //toggle
        // on failure (e.g. couldn't drop to console user when root), keep the old pref, so it matches reality
        if(YES != toggleLoginItem(NSBundle.mainBundle.bundleURL, self.startAtLogin)) {
            self.startAtLogin = getPreferenceBool(PREF_START_AT_LOGIN);
            self.startAtLoginBtn.state = self.startAtLogin;
        }
    }
    
    //now save 'start at login'
    setPreference(PREF_START_AT_LOGIN, @(self.startAtLogin));
    
    //save 'disable update checks'
    setPreference(PREF_DISABLE_UPDATE_CHECK, @(self.disableUpdateCheck));
    
    //save 'disable vt queries'
    setPreference(PREF_DISABLE_VT_QUERIRES, @(self.disableVTQueries));
    
    //save 'always run as root'
    setPreference(PREF_ALWAYS_RUN_AS_ROOT, @(self.alwaysRoot));
    
    //save vt API key
    saveAPIKeyToKeychain(self.apiTextField.stringValue);
    
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
    makeTextViewHyperlink(self.getAPILinkPopover, [NSURL URLWithString:@"https://docs.virustotal.com/docs/please-give-me-an-api-key"]);
    
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

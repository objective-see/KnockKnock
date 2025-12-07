//
//  file: WelcomeWindowController.m
//  project: KnockKnock
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "Extension.h"
#import "AppDelegate.h"

#import "WelcomeWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//buttons
#define REQUEST_FDA 1
#define SHOW_CONFIGURE 2
#define SHOW_VT_INTEGRATION 3
#define SHOW_SUPPORT 4
#define SUPPORT_NO 5
#define SUPPORT_YES 6

@implementation WelcomeWindowController

@synthesize welcomeViewController;

//welcome!
-(void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //when supported
    // indicate title bar is transparent (too)
    if(YES == [self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"KnockKnock v%@", getAppVersion()];
    
    //no FDA?
    // next view should be 'request FDA'
    if(!hasFDA()) {
        self.nextButton.tag = REQUEST_FDA;
    }
    //otherwise
    // next view should be 'configure'
    else {
        self.nextButton.tag = SHOW_CONFIGURE;
    }
    
    //show view
    [self showView:self.welcomeView firstResponder:self.nextButton];

    //center (before showing)
    [self.window center];
    
    //make key and front
    [self.window makeKeyAndOrderFront:self];
    
    //activate
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender {
    
    //leaving configure view?
    // capture the user's selections
    if( (SHOW_CONFIGURE+1) == ((NSToolbarItem*)sender).tag) {
        
        //user defaults
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            
        //save 'show trusted items'
        [defaults setBool:self.showAppleItems.state forKey:PREF_SHOW_TRUSTED_ITEMS];
        
        //save 'show trusted items'
        [defaults setBool:self.disableUpdateCheck.state forKey:PREF_DISABLE_UPDATE_CHECK];
        
    }
    
    //leaving vt integration view?
    // capture the user's selections
    if( (SHOW_VT_INTEGRATION+1) == ((NSToolbarItem*)sender).tag) {
        
        //user defaults
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            
        //save 'disable VT queries'
        [defaults setBool:self.disableVTQueries.state forKey:PREF_DISABLE_VT_QUERIRES];
        
        //save API key to keychain
        if(0 != self.vtAPIKey.stringValue.length) {
            saveAPIKeyToKeychain(self.vtAPIKey.stringValue);
        }
    }
    
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //request FDA view
        case REQUEST_FDA:
        {
            //hide title
            self.window.title = @"";
            
            //rounded corners
            self.fdaNote.wantsLayer = true;
            self.fdaNote.layer.cornerRadius = 5;
            
            //show
            [self showView:self.enableFDAView firstResponder:self.diskAccessButton];
            
            //start spinner
            [self.FDAActivityIndicator startAnimation:self];
            
            //in background
            // wait unitl user grants us FDA
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{

                //wait for FDA
                do {
                    //nap
                    [NSThread sleepForTimeInterval:0.25];
                } while(YES != hasFDA());
                
                //update UI
                dispatch_sync(dispatch_get_main_queue(),
                              ^{
                    //hide spinner
                    self.FDAActivityIndicator.hidden = YES;
                    
                    //change fda message
                    self.FDAMessage.stringValue = @"☑️ Full Disk Access granted!";
                    
                    //enable 'next' button
                    ((NSButton*)[self.enableFDAView viewWithTag:SHOW_CONFIGURE]).enabled = YES;
                    
                    //make it first responder
                    [self.window makeFirstResponder:[self.enableFDAView viewWithTag:SHOW_CONFIGURE]];
                });
            });
            
            break;
        }
        
        //show configure view
        case SHOW_CONFIGURE:
            
            //hide title
            self.window.title = @"";
            
            //show
            [self showView:self.configureView firstResponder:[self.configureView viewWithTag:SHOW_VT_INTEGRATION]];
            
            break;
            
        //show VT integration view
        case SHOW_VT_INTEGRATION:
            
            //hide title
            self.window.title = @"";
            
            //show
            [self showView:self.vtIntegrationView firstResponder:self.vtAPIKey];
            
            //make url a hyperlink
            makeTextViewHyperlink(self.getAPILink, [NSURL URLWithString:@"https://docs.virustotal.com/docs/please-give-me-an-api-key"]);
            
            break;
            
        //show "support us" view
        case SHOW_SUPPORT:
            
            //show support view
            [self showView:self.supportView firstResponder:[self.supportView viewWithTag:SUPPORT_YES]];
            
            break;
            
            
        //support, yes!
        case SUPPORT_YES:
            
            //open patreon URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to close/set app state
        
        //support, no :(
        case SUPPORT_NO:
            
            //close window
            [self.window close];
            
            //done, so show main UI scan window
            [((AppDelegate*)NSApplication.sharedApplication.delegate) initializeForScan];
        
            break;
            
        default:
            break;
    }

    return;
}

//show a view
// note: replaces old view and highlights specified responder
-(void)showView:(NSView*)view firstResponder:(NSView*)firstResponder
{
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //set white
        view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    }
    
    //set content view size
    self.window.contentSize = view.frame.size;
    
    //update config view
    self.window.contentView = view;
    
    //make 'next' button first responder
    // calling this without a timeout, sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        if(firstResponder)
        {
            //first responder
            [self.window makeFirstResponder:firstResponder];
        }
        
    });

    return;
}


//open system settings to FDA
-(IBAction)openSystemSettings:(id)sender {
    
    //show FDA view
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
    
    return;
}

@end

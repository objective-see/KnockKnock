//
//  PrefsWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rdParty/HyperlinkTextField.h"

@interface PrefsWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* METHODS */

//register default prefs
// ->only used if user hasn't set any
-(void)registerDefaults;

//load (persistence) preferences from file system
-(void)loadPreferences;

//buttons

//button: filtering out OS componets
@property (weak) IBOutlet NSButton* showTrustedItemsBtn;

//button: start at login
@property (weak) IBOutlet NSButton* startAtLoginBtn;

//button: disable update check
@property (weak) IBOutlet NSButton* disableUpdateCheckBtn;

//button: disable VT checks (hash)
@property (weak) IBOutlet NSButton* disableVTQueriesBtn;

//button for ok/close
@property (weak) IBOutlet NSButton *okButton;

//filter out OS/known items
@property BOOL showTrustedItems;

//start at login
@property BOOL startAtLogin;

//no update checks
@property BOOL disableUpdateCheck;

//VT api key
@property(nonatomic, retain)NSString* vtAPIKey;

//disable talking to VT
@property BOOL disableVTQueries;

//VT API key
@property (weak) IBOutlet NSTextField* apiTextField;

//how to get a VT key
@property (strong) IBOutlet NSView* getAPIHelp;

//link (how to get a VT key)
@property (weak) IBOutlet HyperlinkTextField* getAPILink;

/* METHODS */

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender;


/* METHODS */


@end

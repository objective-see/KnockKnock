//
//  PrefsWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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

//button for filtering out OS componets
@property (weak) IBOutlet NSButton* showTrustedItemsBtn;

//button disabling update check
@property (weak) IBOutlet NSButton *disableUpdateCheckBtn;

//button for disabling talking to VT
@property (weak) IBOutlet NSButton* disableVTQueriesBtn;

//button for saving output
@property (weak) IBOutlet NSButton* saveOutputBtn;

//button for ok/close
@property (weak) IBOutlet NSButton *okButton;

//filter out OS/known items
@property BOOL showTrustedItems;

//no update checks
@property BOOL disableUpdateCheck;

//disable talking to VT
@property BOOL disableVTQueries;

//save results (at end of scan)
@property BOOL saveOutput;

//save results now
@property BOOL shouldSaveNow;

/* METHODS */

//save existing prefs
-(void)captureExistingPrefs;

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender;


/* METHODS */


@end

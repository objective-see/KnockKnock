//
//  LinkWindowController.h
//  LuLu
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

@interface WelcomeWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//main view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

//welcome view
@property (strong) IBOutlet NSView *welcomeView;

//next
@property (weak) IBOutlet NSButton* nextButton;

//allow FDA view
@property (strong) IBOutlet NSView *enableFDAView;

@property (weak) IBOutlet NSTextField *fdaNote;

@property (weak) IBOutlet NSButton *diskAccessButton;

@property (weak) IBOutlet NSProgressIndicator *FDAActivityIndicator;


@property (weak) IBOutlet NSTextField *FDAMessage;

//allow extension view
@property (strong) IBOutlet NSView *allowExtensionView;

//allow extension spinner
@property (weak) IBOutlet NSProgressIndicator *allowExtActivityIndicator;

//allow extension message
@property (weak) IBOutlet NSTextField *allowExtMessage;

//approve extension image
@property (weak) IBOutlet NSImageView *approveExt;

//approve extension message
@property (weak) IBOutlet NSTextField *approveExtMessage;

//config view
@property (strong) IBOutlet NSView *configureView;

@property (strong) IBOutlet NSView *vtIntegrationView;

@property (weak) IBOutlet NSTextField *vtAPIKey;

//show apple items
@property (weak) IBOutlet NSButton *showAppleItems;

//start at login
@property (weak) IBOutlet NSButton *startAtLogin;

//disable update check
@property (weak) IBOutlet NSButton *disableUpdateCheck;

@property (weak) IBOutlet NSButton *disableVTQueries;
@property (weak) IBOutlet HyperlinkTextField *getAPILink;

//support view
@property (strong) IBOutlet NSView *supportView;

/* METHODS */

//show a view
// note: replaces old view and highlights specified responder
-(void)showView:(NSView*)view firstResponder:(NSView*)firstResponder;

@end

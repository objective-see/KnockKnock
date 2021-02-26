//
//  AppDelegate.h
//  KnockKnock
//
//  Created by Patrick Wardle
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Results/ItemBase.h"

#import "Filter.h"
#import "PluginBase.h"
#import "VirusTotal.h"
#import "ItemEnumerator.h"
#import "ItemTableController.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"
#import "CategoryTableController.h"
#import "ResultsWindowController.h"

#import <Cocoa/Cocoa.h>

/* GLOBALS */

//shared enumerator
extern ItemEnumerator* sharedItemEnumerator;

//filter object
extern Filter* itemFilter;


@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
{
   

}

/* PROPERTIES */

//friends
@property (weak) IBOutlet NSWindow* friends;

//close button
@property (weak) IBOutlet NSButton* closeButton;

//flag for secondary scan
// ->need to restart shared enumerator 
@property BOOL secondaryScan;

//plugin objects
@property(nonatomic, retain)NSMutableArray* plugins;

//version string
@property (weak) IBOutlet NSTextField *versionString;

//category table controller object
@property (weak) IBOutlet CategoryTableController *categoryTableController;

//item table controller object
@property (weak) IBOutlet ItemTableController *itemTableController;

//currently selected (in table) plugin
@property(nonatomic, retain)PluginBase* selectedPlugin;

//array to hold binary objects that are in array
@property (nonatomic, retain)NSMutableArray *tableContents;

//main window
@property (assign) IBOutlet NSWindow *window;

//logo button
@property (weak) IBOutlet NSButton *logoButton;

//scan button
@property (weak) IBOutlet NSButton *scanButton;

//scan button label
@property (weak) IBOutlet NSTextField *scanButtonLabel;

//show preferences button
@property (weak) IBOutlet NSButton *showPreferencesButton;

//save button
@property (weak) IBOutlet NSButton *saveButton;

//spinner
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

//status msg
@property (weak) IBOutlet NSTextField *statusText;

//non-UI thread that performs actual scan
@property(nonatomic, strong)NSThread *scannerThread;

//virus total object
@property(nonatomic, retain)VirusTotal* virusTotalObj;

//array for all virus total threads
@property(nonatomic, retain)NSMutableArray* vtThreads;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//results window controller
@property(nonatomic, retain)ResultsWindowController* resultsWindowController;

//connection flag
@property BOOL isConnected;

//constraint for status text
@property (weak) IBOutlet NSLayoutConstraint *statusTextConstraint;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;


/* METHODS */

//init tracking areas for buttons
// ->provide mouse over effects
-(void)initTrackingAreas;

//create instances of all registered plugins
-(NSMutableArray*)instantiatePlugins;

//callback method, invoked by plugin(s) when item is found
// ->update the 'total' count and the item table (if active plugin is selected in UI)
-(void)itemFound:(ItemBase*)item;

//callback method, invoked by virus total when plugin's items have been processed
// ->reload table if plugin matches active plugin
-(void)itemsProcessed:(PluginBase*)plugin;

//callback method, invoked by category table controller when user selects category
// ->save the selected plugin & reload the item table
-(void)categorySelected:(NSUInteger)rowIndex;

//callback when user has updated prefs
// ->reload table, etc
-(void)applyPreferences;

//update a single row
-(void)itemProcessed:(File*)fileObj;

//action
// ->invoked when user clicks 'About/Info' or Objective-See logo in main UI
-(void)displayScanStats;

//action
// ->invoked when user click main scan button
-(IBAction)scanButtonHandler:(id)sender;

//button handler for when settings icon (gear) is clicked
-(IBAction)showPreferences:(id)sender;

//kickoff a thread to query VT
-(void)queryVT:(PluginBase*)plugin;

//button handler for logo
-(IBAction)logoButtonHandler:(id)sender;

//action for 'about' in menu/logo in UI
-(IBAction)about:(id)sender;

//execute logic to complete scan
// ->ensures various threads are terminated, etc
-(void)completeScan;

@end

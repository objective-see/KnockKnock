//
//  AppDelegate.h
//  KnockKnock
//
//  Created by Patrick Wardle
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Binary.h"
#import "Results/ItemBase.h"

#import "Filter.h"
#import "PluginBase.h"
#import "VirusTotal.h"
#import "ItemTableController.h"
#import "CategoryTableController.h"
#import "PrefsWindowController.h"

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
   

}

//plugin objects
@property(nonatomic, retain)NSMutableArray* plugins;

//category table controller object
@property (weak) IBOutlet CategoryTableController *categoryTableController;

//item table controller object
@property (weak) IBOutlet ItemTableController *itemTableController;

//currently active (scanner) plugin
@property NSUInteger activePluginIndex;

//currently selected (in table) plugin
@property(nonatomic, retain)PluginBase* selectedPlugin;

//array to hold binary objects that are in array
@property (nonatomic, retain)NSMutableArray *tableContents;

//index of 'Vulnerable Applications' header row
@property NSUInteger vulnerableAppHeaderIndex;

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *logoButton;

@property(weak) IBOutlet NSButton *scanButton;
@property(weak) IBOutlet NSTextField *scanButtonLabel;

@property (weak) IBOutlet NSButton *showPreferencesButton;

//spinner
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *statusText;

//non-UI thread that performs actual scan
@property(nonatomic, strong)NSThread *scannerThread;

//filter object
@property(nonatomic, retain)Filter* filterObj;

//virus total object
@property(nonatomic, retain)VirusTotal* virusTotalObj;

//array for all virus total threads
@property(nonatomic, retain)NSMutableArray* vtThreads;

//preferences window controller
@property (nonatomic, retain)PrefsWindowController* prefsWindowController;



/* METHODS */

//init tracking areas for buttons
// ->provide mouse over effects
-(void)initTrackingAreas;

//create instances of all registered plugins
-(NSMutableArray*)instantiatePlugins;

//callback method, invoked by plugin(s) when item is found
// ->update the 'total' count and the item table (if active plugin is selected in UI)
-(void)itemFound;

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
-(void)itemProcessed:(File*)fileObj rowIndex:(NSUInteger)rowIndex;

//action
// ->invoked when user clicks 'About/Info' or Objective-See logo in main UI
-(void)displayScanStats;

-(IBAction)scanButtonHandler:(id)sender;

//button handler for when settings icon (gear) is clicked
-(IBAction)showPreferences:(id)sender;

//kickoff a thread to query VT
-(void)queryVT:(PluginBase*)plugin;


//action for 'about' in menu/logo in UI
-(IBAction)about:(id)sender;

//version string
@property (weak) IBOutlet NSTextField *versionString;


@end

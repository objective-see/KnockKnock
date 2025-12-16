//
//  AppDelegate.m
//  KnockKnock
//

#import "diff.h"
#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "PluginBase.h"
#import "AppDelegate.h"

//TODO: scan other volumes
//TODO: support delete items
//TODO: search in UI


/* GLOBALS */

//scan ID
NSString* scanID = nil;

//query VT
extern BOOL queryVT;

@implementation AppDelegate

@synthesize plugins;
@synthesize scanButton;
@synthesize isConnected;
@synthesize scannerThread;
@synthesize tableContents;
@synthesize versionString;
@synthesize virusTotalObj;
@synthesize selectedPlugin;
@synthesize scanButtonLabel;
@synthesize progressIndicator;
@synthesize itemTableController;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize showSettingsButton;
@synthesize updateWindowController;
@synthesize categoryTableController;
@synthesize resultsWindowController;
@synthesize welcomeWindowController;

//exception handler
// show alert and log error
void uncaughtExceptionHandler(NSException* exception) {
    
    //alert
    NSAlert* alert = nil;
    
    //alloc/init alert
    alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR:\nKnockKnock Encountered a Fatal Error", @"KnockKnock Encountered a Fatal Error") defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"Exception: %@",@"Exception: %@"), exception];
    
    //show it
    [alert runModal];
    
    //log
    os_log_error(OS_LOG_DEFAULT, "KnockKnock crash: %{public}@", exception);
    os_log_error(OS_LOG_DEFAULT, "KnockKnock crash (stack trace): %{public}@", [exception callStackSymbols]);
    
    //bye
    exit(EXIT_FAILURE);
    
    return;
}

//automatically invoked by OS
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //flag
    BOOL startScan = NO;
    
    //defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    //first time run?
    // show welcome/configuration screens
    if(![defaults boolForKey:NOT_FIRST_TIME])
    {
        //set key
        [defaults setBool:YES forKey:NOT_FIRST_TIME];
        
        //alloc window controller
        welcomeWindowController = [[WelcomeWindowController alloc] initWithWindowNibName:@"Welcome"];
    
        //show window
        [self.welcomeWindowController showWindow:self];
        
        //make front
        [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    }
    //otherwise just kick off scan initializations
    // though check if we're started via the login item, which in that case, start scan too
    else
    {
        //started via login item?
        NSAppleEventDescriptor *event =
                NSAppleEventManager.sharedAppleEventManager.currentAppleEvent;
            
            if (event && event.eventID == kAEOpenApplication) {
                NSAppleEventDescriptor *prop =
                    [event paramDescriptorForKeyword:keyAEPropData];
                
                if (prop && prop.enumCodeValue == keyAELaunchedAsLogInItem) {
                    startScan = YES;
                }
            }
        
        //init
        [self initializeForScan:startScan];
    }
    
    return;
}

//init all the thingz for a scan
-(void)initializeForScan:(BOOL)startScan
{
    //defaults
    NSUserDefaults* defaults = nil;
    
    //init filter object
    itemFilter = [[Filter alloc] init];
    
    //init virus total object
    virusTotalObj = [[VirusTotal alloc] init];
    
    //alloc shared item enumerator
    sharedItemEnumerator = [[ItemEnumerator alloc] init];
    
    //check/request for FDA
    // delay, so UI completes rendering
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        //request access
        [self requestFDA];
    });
        
    //check for update
    // unless user has turn off via prefs
    if(YES != [defaults boolForKey:PREF_DISABLE_UPDATE_CHECK])
    {
        //check
        [self check4Update:nil];
    }

    //kick off thread to begin enumerating shared objects
    // ->this takes awhile, so do it now/first!
    [sharedItemEnumerator start];
    
    //instantiate all plugins objects
    self.plugins = [self instantiatePlugins];
    
    //set selected plugin to first
    self.selectedPlugin = [self.plugins firstObject];

    //pre-populate category table w/ each plugin title
    [self.categoryTableController initTable:self.plugins];
    
    //make category table active/selected
    [[self.categoryTableController.categoryTableView window] makeFirstResponder:self.categoryTableController.categoryTableView];
    
    //hide status msg
    // ->when user clicks scan, will show up..
    [self.statusText setStringValue:@""];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //set label text to 'Start Scan'
    self.scanButtonLabel.stringValue = NSLocalizedString(@"Start Scan", @"Start Scan");

    //set version info
    [self.versionString setStringValue:[NSString stringWithFormat:NSLocalizedString(@"version: %@", @"version: %@"), getAppVersion()]];
    
    //init tracking areas
    [self initTrackingAreas];
    
    //set delegate
    // ->ensures our 'windowWillClose' method, which has logic to fully exit app
    self.window.delegate = self;
    
    //alloc/init prefs
    prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    
    //register defaults
    [self.prefsWindowController registerDefaults];
    
    //load prefs
    [self.prefsWindowController loadPreferences];
    
    //center
    [self.window center];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];

    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //started cuz of login item?
    // then let's start the scan automatically
    if(YES == startScan) {
        [self scanButtonHandler:nil];
    }
    
    return;
    
}

//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//request full disk access
-(void)requestFDA
{
    //alert
    __block NSAlert* infoAlert = nil;

    if(!hasFDA()) {
    
        //alloc alert
        infoAlert = [[NSAlert alloc] init];
        
        NSString *settingsName = nil;
        if (@available(macOS 13.0, *))
            settingsName = @"System Settings";
        else
            settingsName = @"System Preferences";

        //set msg
        infoAlert.informativeText = [NSString stringWithFormat:
            NSLocalizedString(@"KnockKnock needs Full Disk Access to perform a complete system scan.\n\nClick 'Open' to open %@ and grant access.", nil),
            settingsName];
        
        //ok button
        [infoAlert addButtonWithTitle:NSLocalizedString(@"Open", @"Open")];
        
        //alert button
        [infoAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
        
        //show 'alert' and capture user response
        // user clicked 'OK'? -> open System Preferences
        if(NSAlertFirstButtonReturn == [infoAlert runModal])
        {
            //open System Preferences
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
        }
        //close
        else
        {
            //close
            [NSApp terminate:nil];
        }
    }
    
    return;
}

//init tracking areas for buttons
// provides mouse over effects (i.e. image swaps)
-(void)initTrackingAreas
{
    //tracking area for buttons
    NSTrackingArea* trackingArea = nil;
    
    //init tracking area
    // ->for scan button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.scanButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.scanButton.tag]}];
    
    //add tracking area to scan button
    [self.scanButton addTrackingArea:trackingArea];

    //init tracking area
    // ->for preference button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.showSettingsButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.showSettingsButton.tag]}];
    
    //add tracking area to pref button
    [self.showSettingsButton addTrackingArea:trackingArea];
    
    //init tracking area
    // ->for save results button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.saveButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.saveButton.tag]}];
    
    //add tracking area to save button
    [self.saveButton addTrackingArea:trackingArea];
    
    //init tracking area
    // ->for save results button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.compareButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.compareButton.tag]}];
    
    //add tracking area to save button
    [self.compareButton addTrackingArea:trackingArea];

    //init tracking area
    // ->for logo button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.logoButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.logoButton.tag]}];
    
    //add tracking area to logo button
    [self.logoButton addTrackingArea:trackingArea];
    
    return;
}


//automatically invoked when window is un-minimized
// since the progress indicator is stopped (bug?), restart it
-(void)windowDidDeminiaturize:(NSNotification *)notification
{
    //make sure scan is going on
    // ->and then restart spinner
    if(YES == [self.scannerThread isExecuting])
    {
        //show
        [self.progressIndicator setHidden:NO];
        
        //start spinner
        [self.progressIndicator startAnimation:nil];
    }
    
    return;
}

//create instances of all registered plugins
-(NSMutableArray*)instantiatePlugins
{
    //plugin objects
    NSMutableArray* pluginObjects = nil;
    
    //number of plugins
    NSUInteger pluginCount = 0;
    
    //plugin object
    PluginBase* pluginObj = nil;
    
    //init array
    pluginObjects = [NSMutableArray array];
    
    //get number of plugins
    pluginCount = sizeof(SUPPORTED_PLUGINS)/sizeof(SUPPORTED_PLUGINS[0]);
    
    //iterate over all supported plugin names
    // ->init and save each
    for(NSUInteger i=0; i < pluginCount; i++)
    {
        //init plugin
        pluginObj = [[NSClassFromString(SUPPORTED_PLUGINS[i]) alloc] init];
        
        //save it
        [pluginObjects addObject:pluginObj];
    }
    
    return pluginObjects;
}

//automatically invoked when the user clicks 'start'/'stop' scan
-(IBAction)scanButtonHandler:(id)sender
{
    //check state
    // START scan
    if(YES == [self.scanButtonLabel.stringValue isEqualToString:NSLocalizedString(@"Start Scan", @"Start Scan")])
    {
        //clear out all plugin results
        for(PluginBase* plugin in self.plugins)
        {
            //remove all results
            [plugin reset];
        }
        
        //update the UI
        // reset tables/reflect the started state
        [self startScanUI];
        
        //start scan
        // kicks off background scanner thread
        [self startScan];
    }

    //check state
    // ->STOP scan, by cancelling threads, etc.
    else
    {
        //complete scan
        [self completeScan];
        
        //update the UI
        // ->reflect the stopped state & and display stats
        [self stopScanUI:SCAN_MSG_STOPPED];
    }
    
    return;
}

//kickoff background thread to scan
// ->also shared enumerator thread (if needed)
-(void)startScan
{
    //scan ID
    scanID = [[NSUUID UUID] UUIDString];
    
    //alloc scanner thread
    scannerThread = [[NSThread alloc] initWithTarget:self selector:@selector(scan) object:nil];
    
    //on secondary runs
    // ->always restart shared enumerator
    if(YES == self.secondaryScan)
    {
        //start it
        [sharedItemEnumerator start];
    }
    
    //start scanner thread
    [self.scannerThread start];
    
    //set flag
    // ->indicates that this isn't first scan
    self.secondaryScan = YES;
    
    return;
}

//thread function
// runs in the background to execute each plugin
-(void)scan
{
    //set scan flag
    self.isConnected = isNetworkConnected();
    
    //load VT API key
    NSString* vtAPIKey = loadAPIKeyFromKeychain();
    
    //skip VT scanning if
    // not connected, user disabled queries, or no API key
    queryVT = (vtAPIKey.length) && self.isConnected && (!self.prefsWindowController.disableVTQueries);
    
    //create dispatch group for VT queries
    dispatch_group_t vtGroup = dispatch_group_create();
    
    //iterate over all plugins
    // ->invoke's each scan message
    for(PluginBase* plugin in self.plugins)
    {
        //pool
        @autoreleasepool
        {
        
        //exit if scanner (self) thread was cancelled
        if(YES == [[NSThread currentThread] isCancelled])
        {
            //exit
            [NSThread exit];
        }
        
        //update scanner msg
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //show
            self.statusText.hidden = NO;
            
            //update
            [self.statusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Scanning: %@", @"Scanning: %@"), plugin.name]];
            
        });
        
        //set callback
        plugin.callback = ^(ItemBase* item)
        {
            [self itemFound:item];
        };
            
        //scan
        // will invoke callback as items are found
        [plugin scan];
            
        //should query VT?
        // if so, do it in background
        if(queryVT)
        {
            //enter group
            dispatch_group_enter(vtGroup);
            
            //VT query in BG
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //check all plugin's files
                [self->virusTotalObj checkFiles:plugin apiKey:vtAPIKey uiMode:YES completion:^{
                    //done
                    dispatch_group_leave(vtGroup);
                }];
                
                
            });
        }
            
        }//pool
    }
    
    //wait till all VT threads are done
    if(queryVT)
    {
        //update scanner msg
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //update
            [self.statusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Awaiting VirusTotal results", @"Awaiting VirusTotal results")]];
            
        });
        
        //nap
        // ->VT threads take some time to spawn/process
        [NSThread sleepForTimeInterval:1.0f];
        
        //wait for all VT queries to complete
        dispatch_group_wait(vtGroup, DISPATCH_TIME_FOREVER);
        
    }//VT scanning enabled
    
    //complete scan logic and show result
    // ->but *only* if scan wasn't stopped
    if(YES != [[NSThread currentThread] isCancelled])
    {
        //execute final scan logic
        [self completeScan];

        //stop ui & show informational alert
        // ->executed on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //update the UI
            // ->reflect the stopped state
            [self stopScanUI:SCAN_MSG_COMPLETE];
            
        });
        
    }
    
    return;
}


//automatically invoked when user clicks logo
// ...load objective-see's html page
-(IBAction)logoButtonHandler:(id)sender
{
    //open URL
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://objective-see.org"]];
    
    return;
}

//callback method, invoked by plugin(s) when item is found
// ->update the 'total' count and the item table (if it's selected)
-(void)itemFound:(ItemBase*)item
{
    //item backing item table
    // ->depending on flilter status, either all items, or just known ones
    NSArray* tableItems = nil;
    
    //only show refresh table if
    // a) filter is not enabled (e.g. show all)
    // b) filtering is enable, but item is unknown
    if( (YES == self.prefsWindowController.showTrustedItems) ||
        ((YES != self.prefsWindowController.showTrustedItems) && (YES != item.isTrusted)) )
    {
        //set table item array
        // ->case: all
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //set to all items
            tableItems = item.plugin.allItems;
        }
        //set table item array
        // ->case: unknown items
        else
        {
            //set to unknown items
            tableItems = item.plugin.untrustedItems;
        }
        //reload category table (on main thread)
        // ->this will result in the 'total' being updated
        dispatch_async(dispatch_get_main_queue(), ^{
            
            @synchronized (self) {
                
                //begin updates
                [self.itemTableController.itemTableView beginUpdates];
                
                //update category table row
                // ->this will result in the 'total' being updated
                [self.categoryTableController.categoryTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:[self.plugins indexOfObject:item.plugin]] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                
                //if this plugin is currently the selected one (in the category table)
                // ->update the item row
                if(self.selectedPlugin == item.plugin)
                {
                    //first tell item table the # of items have changed
                    [self.itemTableController.itemTableView noteNumberOfRowsChanged];
                    
                    //reload just the new row
                    [self.itemTableController.itemTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(tableItems.count-1)] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                }
                
                //end updates
                [self.itemTableController.itemTableView endUpdates];
                
            }//sync
        });
    }
    
    return;
}

//callback method, invoked by virus total when plugin's items have been processed
// ->reload table if plugin matches active plugin
-(void)itemsProcessed:(PluginBase*)plugin
{
    //if there are any flagged items
    // reload category table (to trigger title turning red)
    if(0 != plugin.flaggedItems.count)
    {
        //reload category table
        [self.categoryTableController customReload];
    }

    //check if active plugin matches
    if(plugin == self.selectedPlugin)
    {
        //scroll to top of item table
        [self.itemTableController scrollToTop];
            
        //reload item table
        [self.itemTableController.itemTableView reloadData];
    }
    
    return;
}

//update a single row
-(void)itemProcessed:(File*)fileObj
{
    //row index
    __block NSUInteger rowIndex = NSNotFound;
    
    //current items
    __block NSArray* tableItems = nil;
    
    //reload category table
    [self.categoryTableController customReload];
    
    //check if active plugin matches
    if(fileObj.plugin == self.selectedPlugin)
    {
        //get current items
        tableItems = [self.itemTableController getTableItems];
            
        //sync
        @synchronized (tableItems) {
            
            //find index of item
            rowIndex = [tableItems indexOfObject:fileObj];
            
        } //sync
        
        //reload row
        if(NSNotFound != rowIndex)
        {
            //start table updates
            [self.itemTableController.itemTableView beginUpdates];
        
            //update
            [self.itemTableController.itemTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        
            //end table updates
            [self.itemTableController.itemTableView endUpdates];
        }
    }
    
    return;
}

//callback method, invoked by category table controller when OS/user clicks a row
// ->lookup/save the selected plugin & reload the item table
-(void)categorySelected:(NSUInteger)rowIndex
{
    //save selected plugin
    self.selectedPlugin = self.plugins[rowIndex];
    
    //scroll to top of item table
    [self.itemTableController scrollToTop];
    
    //reload item table
    [self.itemTableController.itemTableView reloadData];
    
    return;
}

//callback when user has updated prefs
-(void)applyPreferences
{
    //currently selected category
    NSUInteger selectedCategory = 0;
    
    //get currently selected category
    selectedCategory = self.categoryTableController.categoryTableView.selectedRow;
    
    //reload category table
    [self.categoryTableController customReload];
    
    //reloading the category table resets the selected plugin
    // ->so manually (re)set it here
    self.selectedPlugin = self.plugins[selectedCategory];
    
    //reload item table
    [self.itemTableController.itemTableView reloadData];
    
    return;
}

//update the UI to reflect that the fact the scan was started
// ->disable settings, set text 'stop scan', etc...
-(void)startScanUI
{
    //if scan was previous run
    // ->will need to shift status msg back over
    if(YES != [[self.statusText stringValue] isEqualToString:@""])
    {
        //reset
        self.statusTextConstraint.constant = 56;
    }
    
    //reset category table
    [self.categoryTableController.categoryTableView reloadData];
    
    //reset item table
    [self.itemTableController.itemTableView reloadData];
    
    //close results window
    if(YES == [self.resultsWindowController.window isVisible])
    {
        //close
        [self.resultsWindowController.window close];
    }
    
    //show progress indicator
    self.progressIndicator.hidden = NO;
    
    //start spinner
    [self.progressIndicator startAnimation:nil];
    
    //set status msg
    // ->scanning started
    [self.statusText setStringValue:SCAN_MSG_STARTED];
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"stopScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"stopScanBG"];
    
    //set label text to 'Stop Scan'
    self.scanButtonLabel.stringValue = NSLocalizedString(@"Stop Scan", @"Stop Scan");
    
    //disable gear (show prefs) button
    self.showSettingsButton.enabled = NO;
    
    //disable save button
    self.saveButton.enabled = NO;
    
    //disable compare button
    self.compareButton.enabled = NO;
    
    return;
}

//execute logic to complete scan
// ->ensures various threads are terminated, etc
-(void)completeScan
{
    //reset scan ID
    scanID = nil;
    
    //tell enumerator to stop
    [sharedItemEnumerator stop];
    
    //cancel enumerator thread
    if(YES == [sharedItemEnumerator.enumeratorThread isExecuting])
    {
        //cancel
        [sharedItemEnumerator.enumeratorThread cancel];
    }
    
    //when invoked from the UI (e.g. 'Stop Scan' was clicked)
    // ->cancel scanner thread
    if([NSThread currentThread] != self.scannerThread)
    {
        //cancel scanner thread
        if(YES == [self.scannerThread isExecuting])
        {
            //cancel
            [self.scannerThread cancel];
        }
    }
    
    return;
}

//update the UI to reflect that the fact the scan was stopped
// ->set text back to 'start scan', etc...
-(void)stopScanUI:(NSString*)statusMsg
{
    //stop spinner
    [self.progressIndicator stopAnimation:nil];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //shift over status msg
    self.statusTextConstraint.constant = 10;
    
    //set status msg
    [self.statusText setStringValue:statusMsg];
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"startScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"startScanBG"];
    
    //set label text to 'Start Scan'
    self.scanButtonLabel.stringValue = NSLocalizedString(@"Start Scan", @"Start Scan");
    
    //(re)enable gear (show prefs) button
    self.showSettingsButton.enabled = YES;
    
    //(re)enable save button
    self.saveButton.enabled = YES;
    
    //enable compare button
    self.compareButton.enabled = YES;
    
    //only show scan stats for completed scan
    if(YES == [statusMsg isEqualToString:SCAN_MSG_COMPLETE])
    {
        //display scan stats in UI (popup)
        [self displayScanStats];
    }

    return;
}

//shows alert stating that that scan is complete (w/ stats)
-(void)displayScanStats
{
    //detailed results msg
    NSMutableString* details = nil;
    
    //unknown items message
    NSString* vtDetails = nil;
    
    //item count
    NSUInteger items = 0;
    
    //flagged item count
    NSUInteger flaggedItems =  0;
    
    //unknown items
    NSMutableArray* unknownItems = nil;
    
    //init
    unknownItems = [NSMutableArray array];
    
    //iterate over all plugins
    // sum up their item counts and flag items count
    for(PluginBase* plugin in self.plugins)
    {
        //when showing all (including OS) findings
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //add up
            items += plugin.allItems.count;
            
            //add plugin's flagged items
            flaggedItems += plugin.flaggedItems.count;
            
            //add unknown file items
            // plugins will only have one type, so can just check first
            if(YES == [[plugin.unknownItems firstObject] isKindOfClass:[File class]])
            {
                //add
                [unknownItems addObjectsFromArray:plugin.unknownItems];
            }
        
            //init detailed msg
            details = [NSMutableString stringWithFormat:NSLocalizedString(@"Found %lu persistent items", @"Found %lu persistent items"), (unsigned long)items];
        }
        //not showing OS files
        else
        {
            //add up
            items += plugin.untrustedItems.count;
            
            //sync
            @synchronized (plugin.untrustedItems) {
                
                //manually check if each untrusted item is flagged/unknown
                for(ItemBase* item in plugin.untrustedItems)
                {
                    //check if item is flagged
                    if(YES == [plugin.flaggedItems containsObject:item])
                    {
                        //inc
                        flaggedItems++;
                    }
                    
                    //check if item is unknown
                    // but has to be a File* object
                    if(YES == [item isKindOfClass:[File class]])
                    {
                        //is unknown?
                        if(YES == [plugin.unknownItems containsObject:item])
                        {
                            //add
                            [unknownItems addObject:item];
                        }
                    }
                }
                
            } //sync
            
            //init detailed msg
            details = [NSMutableString stringWithFormat:NSLocalizedString(@"Found %lu persistent (non-OS) items", @"Found %lu persistent (non-OS) items"), (unsigned long)items];
        }
    }
    
    //remove any dups from unknown items
    [self removeDuplicates:unknownItems];

    //when VT integration is enabled
    // add flagged and unknown items
    if( !self.prefsWindowController.disableVTQueries &&
        self.prefsWindowController.vtAPIKey.length)
    {
        //when network is down
        // ->add msg about not being able to query VT
        if(YES != self.isConnected)
        {
            //VT issues
            vtDetails = NSLocalizedString(@"VirusTotal: Unable to query VirusTotal (network)", @"VirusTotal: Unable to query VirusTotal (network)");
        }
        //otherwise
        // ->add details about # of flagged and untrusted items
        else
        {
            //add flagged items
            vtDetails = [NSString stringWithFormat:NSLocalizedString(@"VirusTotal:\r\n %lu flagged item(s)\r\n %lu unknown item(s)", @"VirusTotal:\r\n %lu flagged item(s)\r\n %lu unknown item(s)"), flaggedItems, unknownItems.count];
        }
    }
    
    //alloc/init
    resultsWindowController = [[ResultsWindowController alloc] initWithWindowNibName:@"ResultsWindow"];
        
    //set details
    self.resultsWindowController.details = details;
        
    //set vt details
    self.resultsWindowController.vtDetails = vtDetails;
    
    //set unknown items
    self.resultsWindowController.unknownItems = unknownItems;
    
    //show it
    [self.resultsWindowController showWindow:self];
    
    //make front/visible
    [self.resultsWindowController.window setLevel:NSPopUpMenuWindowLevel];
    
    return;
}

//remove duplicate file objects
// note: key is "path"
-(void)removeDuplicates:(NSMutableArray<File *>*)files
{
    NSMutableSet *uniquePaths = [NSMutableSet set];
    
    //interate backwards to remove in place
    for (NSInteger i = files.count - 1; i >= 0; i--)
    {
        File *file = files[i];
        if ([uniquePaths containsObject:file.path]) {
            [files removeObjectAtIndex:i];
        }
        else
        {
            [uniquePaths addObject:file.path];
        }
    }
    return;
}

//automatically invoked when mouse entered
-(void)mouseEntered:(NSEvent*)theEvent
{
    //mouse entered
    // ->highlight (visual) state
    [self buttonAppearance:theEvent shouldReset:NO];
    
    return;
}

//automatically invoked when mouse exits
-(void)mouseExited:(NSEvent*)theEvent
{
    //mouse exited
    // ->so reset button to original (visual) state
    [self buttonAppearance:theEvent shouldReset:YES];
    
    return;
}

//set or unset button's highlight
-(void)buttonAppearance:(NSEvent*)theEvent shouldReset:(BOOL)shouldReset
{
    //tag
    NSUInteger tag = 0;
    
    //image name
    NSString* imageName =  nil;
    
    //button
    NSButton* button = nil;
    
    //extract tag
    tag = [((NSDictionary*)theEvent.userData)[@"tag"] unsignedIntegerValue];
    
    //restore button back to default (visual) state
    if(YES == shouldReset)
    {
        //set original scan image
        if(SCAN_BUTTON_TAG == tag)
        {
            //scan running?
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:NSLocalizedString(@"Stop Scan", @"Stop Scan")])
            {
                //set
                imageName = @"stopScan";

            }
            //scan not running
            else
            {
                //set
                imageName = @"startScan";
            }
            
        }
        //set original preferences image
        else if(PREF_BUTTON_TAG == tag)
        {
            //set
            imageName = @"Preferences";
        }
        
        //set original save image
        else if(SAVE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"Save";
        }
        
        //set orginal compare image
        else if(COMPARE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"Compare";
        }
        
        //set original logo image
        else if(LOGO_BUTTON_TAG == tag)
        {
            //set
            imageName = @"logoApple";
        }
    }
    //highlight button
    else
    {
        //set original scan image
        if(SCAN_BUTTON_TAG == tag)
        {
            //scan running
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:NSLocalizedString(@"Stop Scan", @"Stop Scan")])
            {
                //set
                imageName = @"stopScanOver";
                
            }
            //scan not running
            else
            {
                //set
                imageName = @"startScanOver";
            }
        }
        //set mouse over preferences image
        else if(PREF_BUTTON_TAG == tag)
        {
            //set
            imageName = @"PreferencesAlternate";
        }
        //set mouse over save image
        else if(SAVE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"SaveAlternate";
        }
        
        //set mouse over compare image
        else if(COMPARE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"CompareAlternate";
        }
        
        //set mouse over logo image
        else if(LOGO_BUTTON_TAG == tag)
        {
            //set
            imageName = @"logoAppleOver";
        }
    }
    
    //set image
    
    //grab button
    button = [[[self window] contentView] viewWithTag:tag];
    
    if(YES == [button isEnabled])
    {
        //set
        [button setImage:[NSImage imageNamed:imageName]];
    }
    
    return;    
}


//show 'save file' popup
// ->user clicks ok, save results (JSON) to disk
-(IBAction)saveResults:(id)sender
{
    //save panel
    NSSavePanel* panel = nil;
    
    //save results popup
    __block NSAlert* alert = nil;
    
    //output
    __block NSMutableString* output = nil;
    
    //error
    __block NSError* error = nil;
    
    //create panel
    panel = [NSSavePanel savePanel];
    
    //default to desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //formatter for file name
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];

    //suggest file name
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"KnockKnock_Results_%@.json", [dateFormatter stringFromDate:[NSDate date]]]];

    //show panel
    // ->completion handler will invoked when user clicks 'ok'
    [panel beginWithCompletionHandler:^(NSInteger result)
     {
         //only need to handle 'ok'
         if(NSFileHandlingPanelOKButton == result)
         {
             //convert scan to JSON
             output = [self scanToJSON];
            
             //save JSON to disk
             if(YES == [output writeToURL:[panel URL] atomically:YES encoding:NSUTF8StringEncoding error:&error])
             {
                //activate Finder & select file
                [NSWorkspace.sharedWorkspace selectFile:panel.URL.path inFileViewerRootedAtPath:@""];
             }
             //error saving file
             else
             {
                //err msg
                //NSLog(@"ERROR: saving output to %@ failed with %@", panel.URL, error);
                
                //init alert
                alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Ok"];
                
                //error msg
                alert.messageText = NSLocalizedString(@"ERROR: failed to save output", @"ERROR: failed to save output");
                
                //error details
                alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Details: %@", @"Details: %@"), error];
                
                //show popup
                [alert runModal];
             }
            
         }//clicked 'ok' (to save)
    
     }]; //panel callback
    
    return;
}

//convert scan results to json
-(NSMutableString*)scanToJSON
{
    //json
    NSMutableString* json = nil;
    
    //plugin's items
    NSArray* items = nil;
    
    //init
    json = [NSMutableString string];
    
    //start json
    [json appendString:@"{"];
    
    //iterate over all plugins
    // ->format/add items to output
    for(PluginBase* plugin in self.plugins)
    {
        //set items
        // ->all?
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //set
            items = plugin.allItems;
        }
        //set items
        // ->just unknown items
        else
        {
            //set
            items = plugin.untrustedItems;
        }
        
        //add plugin name
        [json appendString:[NSString stringWithFormat:@"\"%@\":[", plugin.name]];
    
        //sync
        // ->since array will be reset if user clicks 'stop' scan
        @synchronized(items)
        {
        
        //iterate over all items
        // convert to JSON/append to output
        for(ItemBase* item in items)
        {
            //add item
            [json appendFormat:@"%@,", [item toJSON]];
            
        }//all plugin items
            
        }//sync
        
        //remove last ','
        if(YES == [json hasSuffix:@","])
        {
            //remove
            [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
        }
        
        //terminate list
        [json appendString:@"],"];

    }//all plugins
    
    //remove last ','
    if(YES == [json hasSuffix:@","])
    {
        //remove
        [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
    }
    
    //terminate list/output
    [json appendString:@"}"];
    
    return json;
}

#pragma mark Menu Handler(s) #pragma mark -

//automatically invoked when user clicks 'About/Info'
// ->show about window
-(IBAction)about:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];

    return;
}

//automatically invoked when user clicks gear icon
// ->show preferences
-(IBAction)showPreferences:(id)sender
{
    //show it
    [self.prefsWindowController showWindow:self];
    
    //make modal
    [[NSApplication sharedApplication] runModalForWindow:self.prefsWindowController.window];

    return;
}

//compare a past to a current scan
-(IBAction)compareScans:(id)sender
{
    //previous scan
    NSString* prevScan = nil;
    NSDictionary* prevScanContents = nil;
    NSDictionary* currentScanContents = nil;
    
    //diff results
    NSString* differences = nil;
    
    //init panel
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    //configure panel
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"json"];
    panel.treatsFilePackagesAsDirectories = YES;
    
    //default to desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //show panel, bail on cancel
    if([panel runModal] == NSModalResponseOK) {
        
        //load previous scan
        prevScan = [NSString stringWithContentsOfURL:panel.URL encoding:NSUTF8StringEncoding error:nil];
        
        //parse previous scan JSON
        prevScanContents = [NSJSONSerialization JSONObjectWithData:[prevScan dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        
        //parse current scan JSON
        currentScanContents = [NSJSONSerialization JSONObjectWithData:[[self scanToJSON] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        
        //diff scans
        differences = diffScans(prevScanContents, currentScanContents);
        if(differences) {
            
            //show diff window
            self.diffWindowController = [[DiffWindowController alloc] initWithWindowNibName:@"DiffWindow"];
            self.diffWindowController.differences = differences;
            [self.diffWindowController showWindow:self];
            
        }
        //error
        else {
            
            //show error alert
            NSAlert* alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"Ok"];
            alert.messageText = NSLocalizedString(@"ERROR: Failed to compare scans", @"ERROR: Failed to compare scans");
            [alert runModal];
        }
    }
    
    return;
}

//automatically invoked when menu is clicked
// tell menu to disable 'Preferences' when scan is running
-(BOOL)validateMenuItem:(NSMenuItem *)item
{
    //enable
    BOOL bEnabled = YES;
    
    //check if item is 'Preferences'
    if(PREF_MENU_ITEM_TAG == item.tag)
    {
        //unset enabled flag if scan is running
        if(YES != [self.scanButtonLabel.stringValue isEqualToString:NSLocalizedString(@"Start Scan", @"Start Scan")])
        {
            //disable
            bEnabled = NO;
        }
    }

    return bEnabled;
}

//call into Update obj
// check to see if there an update?
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion alwaysShow:(nil != sender)];
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion alwaysShow:(BOOL)alwaysShow
{
    //details
    NSString* details = nil;
    
    //action
    NSString* action = nil;
    
    //handle response
    // new version, show popup
    switch(result)
    {
        //error
        case UPDATE_ERROR:
            
            //set details
            details = NSLocalizedString(@"error, failed to check for an update.", @"error, failed to check for an update.");
            
            //set action
            action = NSLocalizedString(@"Close", @"Close");
            
            break;
            
        //no updates
        case UPDATE_NOTHING_NEW:
            
            //set details
            details = [NSString stringWithFormat:NSLocalizedString(@"You're all up to date! (v%@)", @"You're all up to date! (v%@)"), getAppVersion()];
            
            //set action
            action = NSLocalizedString(@"Close", @"Close");
            
            break;
            
        //new version
        case UPDATE_NEW_VERSION:
            
            //set details
            details = [NSString stringWithFormat:NSLocalizedString(@"a new version (%@) is available!", @"a new version (%@) is available!"), newVersion];
            
            //set action
            action = NSLocalizedString(@"Update", @"Update");
            
            break;
    }

    //new version?
    //...or always show results?
    if( (YES == alwaysShow) ||
        (UPDATE_NEW_VERSION == result) )
    {
        //alloc update window
        updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
        
        //configure
        [self.updateWindowController configure:details buttonTitle:action];
        
        //center window
        [[self.updateWindowController window] center];
        
        //show it
        [self.updateWindowController showWindow:self];
        
        //make front/visible
        [self.updateWindowController.window setLevel:NSPopUpMenuWindowLevel];
    }
    
    return;
}

@end

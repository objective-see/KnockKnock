//
//  AppDelegate.m
//  KnockKnock
//

#import "Consts.h"
#import "Update.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "AppDelegate.h"

//TODO: scan other volumes
//TODO: support delete items
//TODO: search in UI

@implementation AppDelegate

@synthesize friends;
@synthesize plugins;
@synthesize vtThreads;
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
@synthesize showPreferencesButton;
@synthesize updateWindowController;
@synthesize categoryTableController;
@synthesize resultsWindowController;

//center window
// also make front
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];

    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked by OS
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //defaults
    NSUserDefaults* defaults = nil;
    
    //app's (self) signing status
    OSStatus signingStatus = -1;
    
    //init filter object
    itemFilter = [[Filter alloc] init];
    
    //init virus total object
    virusTotalObj = [[VirusTotal alloc] init];
    
    //init array for virus total threads
    vtThreads = [NSMutableArray array];
    
    //alloc shared item enumerator
    sharedItemEnumerator = [[ItemEnumerator alloc] init];
    
    //toggle away
    [[[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.loginwindow"] firstObject] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    
    //toggle back
    // work-around for menu not showing since we set Application is agent(UIElement): YES
    [[[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.objective-see.KnockKnock"] firstObject] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    
    //verify self
    signingStatus = verifySelf();
   
    //show error if app (self) cannot be verified
    if(noErr != signingStatus)
    {
        //show alert
        [self showUnverifiedAlert:signingStatus];
        
        //exit
        exit(0);
    }
    
    //load defaults
    defaults = [NSUserDefaults standardUserDefaults];

    //first time run?
    // show thanks to friends window!
    if(YES != [defaults boolForKey:NOT_FIRST_TIME])
    {
        //set key
        [defaults setBool:YES forKey:NOT_FIRST_TIME];
        
        //set delegate
        self.friends.delegate = self;
        
        //show friends window
        [self.friends makeKeyAndOrderFront:self];
        
        //then make action button first responder
        [self.friends makeFirstResponder:self.closeButton];
        
        //close after a few seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //close to hide
            [self.friends close];
            
        });
    }
    //asked for full disk access yet?
    else if(YES != [defaults boolForKey:REQUESTED_FULL_DISK_ACCESS])
    {
        //set key
        [defaults setBool:YES forKey:REQUESTED_FULL_DISK_ACCESS];
        
        //request access
        // delay, so UI completes rendering
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            
            //request access
            [self requestFullDiskAcces];
            
        });
    }
    
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
    
    //init button label
    // ->start scan
    [self.scanButtonLabel setStringValue:START_SCAN];
    
    //set version info
    [self.versionString setStringValue:[NSString stringWithFormat:@"version: %@", getAppVersion()]];
    
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

    return;
}

//close 'friends' window
-(IBAction)closeFriendsWindow:(id)sender
{
    //close to hide
    [self.friends close];

    return;
}

//window close handler
-(void)windowWillClose:(NSNotification *)notification {
    
    //closing friends window?
    // request full disk access
    if(self.friends == notification.object)
    {
        //request access
        // delay ensures (friends) window will close
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //request access
            [self requestFullDiskAcces];
            
        });
    }
    
    return;
}

//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//request full disk access
-(void)requestFullDiskAcces
{
    //request
    __block NSAlert* infoAlert = nil;
    
    //once
    static dispatch_once_t once;
    
    //show request once
    dispatch_once(&once, ^
    {
        //on request on 10.14+
        if(@available(macOS 10.14, *))
        {
            //alloc alert
            infoAlert = [[NSAlert alloc] init];
            
            //main text
            infoAlert.messageText = @"Open 'System Preferences' to give KnockKnock Full Disk Access?";
            
            //detailed test
            infoAlert.informativeText = @"This allows the app to perform a comprehensive scan.\n\nIn System Preferences:\r ▪ Click the 🔒 to authenticate\r ▪ Click the ➕ to add KnockKnock.app\n";
            
            //ok button
            [infoAlert addButtonWithTitle:@"OK"];
            
            //alert button
            [infoAlert addButtonWithTitle:@"Cancel"];
            
            //show 'alert' and capture user response
            // user clicked 'OK'? -> open System Preferences
            if(NSAlertFirstButtonReturn == [infoAlert runModal])
            {
                //open System Preferences
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
            }
        }
    });
    
    return;
}

//display alert about OS not being supported
-(void)showUnsupportedAlert
{
    //alert box
    NSAlert* unsupportedAlert = nil;
    
    //alloc/init alert
    unsupportedAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"OS X %@ is not supported", [[NSProcessInfo processInfo] operatingSystemVersionString]] defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"sorry for the inconvenience!"];
    
    //show it
    [unsupportedAlert runModal];
    
    return;
}

//display alert about app being unverifable
-(void)showUnverifiedAlert:(OSStatus)signingError
{
    //alert box
    NSAlert* modifiedAlert = nil;
    
    //alloc/init alert
    modifiedAlert = [NSAlert alertWithMessageText:@"ERROR: application could not be verified" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"code: %d\nplease re-download, and run again", signingError];
    
    //show it
    [modifiedAlert runModal];
    
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
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.showPreferencesButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.showPreferencesButton.tag]}];
    
    //add tracking area to pref button
    [self.showPreferencesButton addTrackingArea:trackingArea];
    
    //init tracking area
    // ->for save results button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.saveButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.saveButton.tag]}];
    
    //add tracking area to save button
    [self.saveButton addTrackingArea:trackingArea];

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
        pluginObj = [(PluginBase*)([NSClassFromString(SUPPORTED_PLUGINS[i]) alloc]) init];
        
        //save it
        [pluginObjects addObject:pluginObj];
    }
    
    return pluginObjects;
}

//automatically invoked when the user clicks 'start'/'stop' scan
-(IBAction)scanButtonHandler:(id)sender
{
    //check state
    // ->START scan
    if(YES == [[self.scanButtonLabel stringValue] isEqualToString:START_SCAN])
    {
        //clear out all plugin results
        for(PluginBase* plugin in self.plugins)
        {
            //remove all results
            [plugin reset];
        }
        
        //update the UI
        // ->reset tables/reflect the started state
        [self startScanUI];
        
        //start scan
        // ->kicks off background scanner thread
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
// ->runs in the background to execute each plugin
-(void)scan
{
    //flag indicating an active VT thread
    BOOL activeThread = NO;
    
    //set scan flag
    self.isConnected = isNetworkConnected();
    
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
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show
            self.statusText.hidden = NO;
            
            //update
            [self.statusText setStringValue:[NSString stringWithFormat:@"Scanning: %@", plugin.name]];
            
        });
        
        //set callback
        plugin.callback = ^(ItemBase* item)
        {
            [self itemFound:item];
        };
            
        //scan
        // will invoke callback as items are found
        [plugin scan];

        //when 'disable VT' prefs not selected and network is reachable
        // ->kick of thread to perform VT query in background
        if( (YES != self.prefsWindowController.disableVTQueries) &&
            (YES == self.isConnected) )
        {
            //do query
            [self queryVT:plugin];
        }
            
        }//pool
    }
    
    //if VT querying is enabled (default) and network is available
    // ->wait till all VT threads are done
    if( (YES != self.prefsWindowController.disableVTQueries) &&
        (YES == self.isConnected) )
    {
        //update scanner msg
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //update
            [self.statusText setStringValue:[NSString stringWithFormat:@"Awaiting VirusTotal results"]];
            
        });
        
        //nap
        // ->VT threads take some time to spawn/process
        [NSThread sleepForTimeInterval:5.0f];
        
        //wait for all VT threads to exit
        while(YES)
        {
            //reset flag
            activeThread = NO;
            
            //sync
            @synchronized(self.vtThreads)
            {
                //check all threads
                for(NSThread* vtThread in self.vtThreads)
                {
                    //check if still running
                    // ->set flag & break out of loop
                    if(YES == [vtThread isExecuting])
                    {
                        //set flag
                        activeThread = YES;
                        
                        //bail
                        break;
                    }
                }
                
            }//sync
            
            //check flag
            if(YES != activeThread)
            {
                //finally no active threads
                // ->bail
                break;
            }
            
            //exit if scanner (self) thread was cancelled
            if(YES == [[NSThread currentThread] isCancelled])
            {
                //exit
                [NSThread exit];
            }
            
            //nap
            [NSThread sleepForTimeInterval:0.5];
            
        }//active thread
        
    }//VT scanning enabled
    
    //complete scan logic and show result
    // ->but *only* if scan wasn't stopped
    if(YES != [[NSThread currentThread] isCancelled])
    {
        //execute final scan logic
        [self completeScan];

        //stop ui & show informational alert
        // ->executed on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //update the UI
            // ->reflect the stopped state
            [self stopScanUI:SCAN_MSG_COMPLETE];
            
        });
        
    }//scan not stopped by user
    
    return;
}

//kickoff a thread to query VT
-(void)queryVT:(PluginBase*)plugin
{
    //virus total thread
    NSThread* virusTotalThread = nil;
    
    //alloc thread
    // ->will query virus total to get info about all detected items
    virusTotalThread = [[NSThread alloc] initWithTarget:virusTotalObj selector:@selector(getInfo:) object:plugin];
    
    //start thread
    [virusTotalThread start];
    
    //sync
    @synchronized(self.vtThreads)
    {
        //save it into array
        [self.vtThreads addObject:virusTotalThread];
    }
    
    return;
}

//automatically invoked when user clicks logo
// ->load objective-see's html page
-(IBAction)logoButtonHandler:(id)sender
{
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://objective-see.com"]];
    
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
            tableItems = item.plugin.unknownItems;
        }
        //reload category table (on main thread)
        // ->this will result in the 'total' being updated
        dispatch_sync(dispatch_get_main_queue(), ^{
            
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
        });
    }
    
    return;
}

//callback method, invoked by virus total when plugin's items have been processed
// ->reload table if plugin matches active plugin
-(void)itemsProcessed:(PluginBase*)plugin
{
    //if there are any flagged items
    // ->reload category table (to trigger title turning red)
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
    
    //reload category table (on main thread)
    // ->ensures correct title color (red, or reset)
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        //reload category table
        [self.categoryTableController customReload];
        
    });

    //check if active plugin matches
    if(fileObj.plugin == self.selectedPlugin)
    {
        //execute on main (UI) thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //get current items
            tableItems = [self.itemTableController getTableItems];
            
            //find index of item
            rowIndex = [tableItems indexOfObject:fileObj];
            
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
            
        });
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
// ->reload table, etc
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
    
    //(re)check network connectivity
    // ->set iVar
    self.isConnected = isNetworkConnected();
    
    //if VT query was never done (e.g. scan was started w/ pref disabled) and network is available
    // ->kick off VT queries now
    if( (0 == self.vtThreads.count) &&
        (YES != self.prefsWindowController.disableVTQueries) &&
        (YES == self.isConnected) )
    {
        //iterate over all plugins
        // ->do VT query for each
        for(PluginBase* plugin in self.plugins)
        {
            //do query
            [self queryVT:plugin];
        }
    }
    
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
    
    //set label text
    // ->'Stop Scan'
    [self.scanButtonLabel setStringValue:STOP_SCAN];

    //disable gear (show prefs) button
    self.showPreferencesButton.enabled = NO;
    
    //disable save button
    self.saveButton.enabled = NO;
    
    return;
}

//execute logic to complete scan
// ->ensures various threads are terminated, etc
-(void)completeScan
{
    //tell enumerator to stop
    [sharedItemEnumerator stop];
    
    //cancel enumerator thread
    if(YES == [sharedItemEnumerator.enumeratorThread isExecuting])
    {
        //cancel
        [sharedItemEnumerator.enumeratorThread cancel];
    }
    
    //sync to cancel all VT threads
    @synchronized(self.vtThreads)
    {
        //tell all VT threads to bail
        for(NSThread* vtThread in self.vtThreads)
        {
            //cancel running threads
            if(YES == [vtThread isExecuting])
            {
                //cancel
                [vtThread cancel];
            }
        }
    }
    
    //remove all VT threads
    [self.vtThreads removeAllObjects];
    
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
    //self.progressIndicator.hidden = YES;
    
    //shift over status msg
    self.statusTextConstraint.constant = 10;
    
    //set status msg
    [self.statusText setStringValue:statusMsg];
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"startScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"startScanBG"];
    
    //set label text
    // ->'Start Scan'
    [self.scanButtonLabel setStringValue:START_SCAN];
    
    //(re)enable gear (show prefs) button
    self.showPreferencesButton.enabled = YES;
    
    //(re)enable save button
    self.saveButton.enabled = YES;
    
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
    //detailed scan msg
    NSMutableString* details = nil;
    
    //item count
    NSUInteger itemCount = 0;
    
    //flagged item count
    NSUInteger flaggedItemCount =  0;
    
    //iterate over all plugins
    // ->sum up their item counts and flag items count
    for(PluginBase* plugin in self.plugins)
    {
        //when showing all findings
        // ->sum em all up!
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //add up
            itemCount += plugin.allItems.count;
            
            //add plugin's flagged items
            flaggedItemCount += plugin.flaggedItems.count;
            
            //init detailed msg
            details = [NSMutableString stringWithFormat:@"■ Found %lu items", (unsigned long)itemCount];
        }
        //otherwise just unknown items
        else
        {
            //add up
            itemCount += plugin.unknownItems.count;
            
            //manually check if each unknown item is flagged
            // ->gotta do this since flaggedItems includes all items
            for(ItemBase* item in plugin.unknownItems)
            {
                //check if item it flagged
                if(YES == [plugin.flaggedItems containsObject:item])
                {
                    //inc
                    flaggedItemCount++;
                }
            }
            
            //init detailed msg
            details = [NSMutableString stringWithFormat:@"■ Found %lu non-OS items", (unsigned long)itemCount];
        }
    }

    //when VT integration is enabled
    // ->add flagged items
    if(YES != self.prefsWindowController.disableVTQueries)
    {
        //when network is down
        // ->add msg about not being able to query VT
        if(YES != self.isConnected)
        {
            //add disconnected msg
            [details appendFormat:@" \r\n■ Unable to query VirusTotal (network)"];
        }
        //otherwise
        // ->add details about # of flagged items
        else
        {
            //add flagged items
            [details appendFormat:@" \r\n■ %lu item(s) flagged by VirusTotal", flaggedItemCount];
        }
    }
    
    //alloc/init results window
    if(nil == self.resultsWindowController)
    {
        //alloc/init
        resultsWindowController = [[ResultsWindowController alloc] initWithWindowNibName:@"ResultsWindow"];
        
        //set details
        self.resultsWindowController.details = details;
    }
    
    //subsequent times
    // ->set details directly
    if(nil != self.resultsWindowController.detailsLabel)
    {
        //set
        self.resultsWindowController.detailsLabel.stringValue = details;
    }
    
    //show it
    [self.resultsWindowController showWindow:self];
    
    //invoke function in background that will make window modal
    // ->waits until window is non-nil
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.resultsWindowController);
        
    });
    
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
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:@"Stop Scan"])
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
            imageName = @"settings";
        }
        
        //set original preferences image
        else if(SAVE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"save";
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
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:@"Stop Scan"])
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
            imageName = @"settingsOver";
        }
        //set mouse over save image
        else if(SAVE_BUTTON_TAG == tag)
        {
            //set
            imageName = @"saveOver";
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
    NSSavePanel *panel = nil;
    
    //save results popup
    __block NSAlert* saveResultPopup = nil;
    
    //output
    __block NSMutableString* output = nil;
    
    //plugin items
    __block NSArray* items = nil;
    
    //error
    __block NSError* error = nil;
    
    //create panel
    panel = [NSSavePanel savePanel];
    
    //default to desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //suggest file name
    [panel setNameFieldStringValue:OUTPUT_FILE];
    
    //show panel
    // ->completion handler will invoked when user clicks 'ok'
    [panel beginWithCompletionHandler:^(NSInteger result)
     {
         //only need to handle 'ok'
         if(NSFileHandlingPanelOKButton == result)
         {
            //init output string
            output = [NSMutableString string];
            
            //start JSON
            [output appendString:@"{"];
            
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
                    items = plugin.unknownItems;
                }
                
                //add plugin name
                [output appendString:[NSString stringWithFormat:@"\"%@\":[", plugin.name]];
            
                //sync
                // ->since array will be reset if user clicks 'stop' scan
                @synchronized(items)
                {
                
                //iterate over all items
                // ->convert to JSON/append to output
                for(ItemBase* item in items)
                {
                    //add item
                    [output appendFormat:@"{%@},", [item toJSON]];
                    
                }//all plugin items
                    
                }//sync
                
                //remove last ','
                if(YES == [output hasSuffix:@","])
                {
                    //remove
                    [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
                }
                
                //terminate list
                [output appendString:@"],"];

            }//all plugins
            
            //remove last ','
            if(YES == [output hasSuffix:@","])
            {
                //remove
                [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
            }
            
            //terminate list/output
            [output appendString:@"}"];
            
            //save JSON to disk
            // ->on error will show err msg in popup
            if(YES != [output writeToURL:[panel URL] atomically:YES encoding:NSUTF8StringEncoding error:&error])
            {
                //err msg
                NSLog(@"OBJECTIVE-SEE ERROR: saving output to %@ failed with %@", [panel URL], error);
                
                //init popup w/ error msg
                saveResultPopup = [NSAlert alertWithMessageText:@"ERROR: failed to save output" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"details: %@", error];

            }
            //happy
            // ->set result msg
            else
            {
                //init popup w/ msg
                saveResultPopup = [NSAlert alertWithMessageText:@"Succesfully saved output" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"file: %s", [[panel URL] fileSystemRepresentation]];
            }
                 
            //show popup
            [saveResultPopup runModal];
             
         }//clicked 'ok' (to save)
    
     }]; //panel callback
    
    return;
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
    
    //invoke function in background that will make window modal
    // ->waits until window is non-nil
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        //make modal
        makeModal(self.prefsWindowController);
        
    });

    return;
}


//automatically invoked when menu is clicked
// ->tell menu to disable 'Preferences' when scan is running
-(BOOL)validateMenuItem:(NSMenuItem *)item
{
    //enable
    BOOL bEnabled = YES;
    
    //check if item is 'Preferences'
    if(PREF_MENU_ITEM_TAG == item.tag)
    {
        //unset enabled flag if scan is running
        if(YES != [[self.scanButtonLabel stringValue] isEqualToString:START_SCAN])
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
            details = @"error, failed to check for an update.";
            
            //set action
            action = @"Close";
            
            break;
            
        //no updates
        case UPDATE_NOTHING_NEW:
            
            //set details
            details = [NSString stringWithFormat:@"you're all up to date! (v. %@)", getAppVersion()];
            
            //set action
            action = @"Close";
            
            break;
            
        //new version
        case UPDATE_NEW_VERSION:
            
            //set details
            details = [NSString stringWithFormat:@"a new version (%@) is available!", newVersion];
            
            //set action
            action = @"Update";
            
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
        
        //invoke function in background that will make window modal
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //make modal
            makeModal(self.updateWindowController);
            
        });
    }
    
    return;
}

@end

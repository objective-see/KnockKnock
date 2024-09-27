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
@synthesize showSettingsButton;
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
            infoAlert.messageText = NSLocalizedString(@"Open 'System Preferences' to give KnockKnock Full Disk Access?", @"Open 'System Preferences' to give KnockKnock Full Disk Access?");
            
            //detailed test
            infoAlert.informativeText = NSLocalizedString(@"This allows the app to perform a comprehensive scan.\n\nIn System Preferences:\r ▪ Click the 🔒 to authenticate\r ▪ Click the ➕ to add KnockKnock.app\n", @"This allows the app to perform a comprehensive scan.\n\nIn System Preferences:\r ▪ Click the 🔒 to authenticate\r ▪ Click the ➕ to add KnockKnock.app\n");
            
            //ok button
            [infoAlert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
            
            //alert button
            [infoAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
            
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
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //update
            [self.statusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Awaiting VirusTotal results", @"Awaiting VirusTotal results")]];
            
        });
        
        //nap
        // ->VT threads take some time to spawn/process
        [NSThread sleepForTimeInterval:3.0f];
        
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
        dispatch_async(dispatch_get_main_queue(), ^{
            
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://objective-see.org"]];
    
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
    
    //reload category table
    [self.categoryTableController customReload];
    
    //check if active plugin matches
    if(fileObj.plugin == self.selectedPlugin)
    {
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
            
            //init detailed msg
            details = [NSMutableString stringWithFormat:NSLocalizedString(@"Found %lu persistent (non-OS) items", @"Found %lu persistent (non-OS) items"), (unsigned long)items];
        }
    }

    //when VT integration is enabled
    // add flagged and unknown items
    if(YES != self.prefsWindowController.disableVTQueries)
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
    
    //remove any dups from unknown items
    [self removeDuplicates:unknownItems];

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
    __block NSAlert* alert = nil;
    
    //output
    __block NSMutableString* output = nil;
    
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
                NSLog(@"OBJECTIVE-SEE ERROR: saving output to %@ failed with %@", [panel URL], error);
                
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
        // ->convert to JSON/append to output
        for(ItemBase* item in items)
        {
            //add item
            [json appendFormat:@"{%@},", [item toJSON]];
            
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
    //error
    NSError* error = nil;
    
    //previous scan
    NSString* prevScan = nil;
    NSDictionary* prevScanContents = nil;
    
    //added items
    NSMutableArray* addedItems = nil;
    
    //removed items
    NSMutableArray* removedItems = nil;
    
    //diff results
    NSMutableString* differences = nil;
    
    //'browse' panel
    NSOpenPanel *panel = nil;
    
    //init
    differences = [NSMutableString string];
    
    //init panel
    panel = [NSOpenPanel openPanel];
    
    //allow files
    panel.canChooseFiles = YES;
    
    //disallow directories
    panel.canChooseDirectories = NO;
    
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
    
    //can open app bundles
    panel.treatsFilePackagesAsDirectories = YES;
    
    //default to desktop
    // as this where scans are suggested to be saved
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
    
    //show panel
    // but bail on cancel
    if(NSModalResponseCancel == [panel runModal])
    {
        //bail
        goto bail;
    }
    
    //load previous scan
    prevScan = [NSString stringWithContentsOfURL:panel.URL encoding:NSUTF8StringEncoding error:&error];
    if(nil == prevScan)
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: failed to load %@", panel.URL);
        goto bail;
    }
    
    //serialize json
    prevScanContents = [NSJSONSerialization JSONObjectWithData:[prevScan dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if(YES != [prevScanContents isKindOfClass:[NSDictionary class]])
    {
        goto bail;
    }
    
    //init
    addedItems = [NSMutableArray array];
    removedItems = [NSMutableArray array];
    
    //compare
    // for now, only adds / removes
    for(PluginBase* plugin in self.plugins)
    {
        //init
        NSArray* prevItems = nil;
        NSArray* currentItems = nil;
        
        NSSet *prevPaths = nil;
        NSSet *currentPaths = nil;
        
        NSMutableSet *addedPaths = nil;
        NSMutableSet *removedPaths = nil;
        
        NSMutableDictionary* addedItem = nil;
        NSMutableDictionary* removedItem = nil;
        
        NSString* key = plugin.name;
        
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //set
            currentItems = plugin.allItems;
        }
        //set items
        // just unknown items
        else
        {
            //set
            currentItems = plugin.untrustedItems;
        }
        
        prevItems = prevScanContents[key];
        
        prevPaths = [NSSet setWithArray:[prevItems valueForKey:@"path"]];
        currentPaths = [NSSet setWithArray:[currentItems valueForKey:@"path"]];

        addedPaths = [currentPaths mutableCopy];
        [addedPaths minusSet:prevPaths];
        
        removedPaths = [prevPaths mutableCopy];
        [removedPaths minusSet:currentPaths];

        //save added items
        for(ItemBase* currentItem in currentItems) {
            if(YES == [addedPaths containsObject:currentItem.path])
            {
                //convert to dictionary
                addedItem = [[NSJSONSerialization JSONObjectWithData:[[NSString stringWithFormat:@"{%@}", [currentItem toJSON]] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] mutableCopy];
                if(nil == addedItem)
                {
                    continue;
                }
                
                //add key
                addedItem[@"key"] = key;
                
                //add
                [addedItems addObject:addedItem];
            }
        }
        
        //save removed items
        for(NSDictionary* prevItem in prevItems) {
            if(YES == [removedPaths containsObject:prevItem[@"path"]])
            {
                removedItem = [prevItem mutableCopy];
                removedItem[@"key"] = key;
                
                //add
                [removedItems addObject:removedItem];
            }
        }
    }
    
    //any changes
    if( (0 == addedItems.count) &&
        (0 == removedItems.count) )
    {
        //no changes
        differences = [@"No Changes Detected\r\n...scans are identical" mutableCopy];
    }
    
    //any added items?
    if(0 != addedItems.count)
    {
        //msg
        [differences appendString:@"NEW ITEMS:\r\n"];
        
        //add each item
        for(NSDictionary* item in addedItems)
        {
            //add
            [differences appendString:[NSString stringWithFormat:@"(%@): %@\r\n", [item[@"key"] substringToIndex:[item[@"key"] length]-1], item.description]];
        }
    }
    
    //any removed items
    if(0 != removedItems.count)
    {
        //msg
        [differences appendString:@"REMOVED ITEMS:\r\n"];
        
        //add each item
        for(NSDictionary* item in removedItems)
        {
            //add
            [differences appendString:[NSString stringWithFormat:@"(%@): %@\r\n", [item[@"key"] substringToIndex:[item[@"key"] length]-1], item.description]];
        }
    }

    //alloc window controller
    self.diffWindowController = [[DiffWindowController alloc] initWithWindowNibName:@"DiffWindow"];
    
    //set text (differences)
    self.diffWindowController.differences = differences;
    
    //show window
    [self.diffWindowController showWindow:self];
    
bail:
    
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
            details = [NSString stringWithFormat:NSLocalizedString(@"you're all up to date! (v. %@)", @"you're all up to date! (v. %@)"), getAppVersion()];
            
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
        
        //invoke function in background that will make window modal
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //make modal
            makeModal(self.updateWindowController);
            
        });
    }
    
    return;
}

@end

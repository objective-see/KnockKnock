//
//  AppDelegate.m
//  KnockKnock
//

#import "Consts.h"
#import "Binary.h"
#import "Scanner.h"
#import "Exception.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "AppDelegate.h"

//supported plugins
NSString * const SUPPORTED_PLUGINS[] = {@"BrowserExtensions", @"Kexts", @"LaunchItems", @"LoginItems", @"SpotlightImporters"};


@implementation AppDelegate

@synthesize plugins;
@synthesize filterObj;
@synthesize vtThreads;
@synthesize virusTotalObj;
@synthesize selectedPlugin;
@synthesize activePluginIndex;
@synthesize itemTableController;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize showPreferencesButton;
@synthesize categoryTableController;
@synthesize resultsWindowController;

@synthesize scanButton;
@synthesize scannerThread;
@synthesize tableContents;
@synthesize versionString;
@synthesize scanButtonLabel;
@synthesize progressIndicator;
@synthesize vulnerableAppHeaderIndex;

//TODO: testing (older OS, w/ malware!! (and take screen shots))
//TODO: kext plugin - check for ones that won't be loaded? parse plist or something?
//TODO: white buttons!! (copy from BB)


//TODO: tools, snapshot between runs? 'what changed app' rootkit revealer? driver view?

//center window
// ->also make front
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
// ->main entry point
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //first thing...
    // ->install exception handlers!
    installExceptionHandlers();
    
    //init filter object
    filterObj = [[Filter alloc] init];
    
    //init virus total object
    virusTotalObj = [[VirusTotal alloc] init];
    
    //init array for virus total threads
    vtThreads = [NSMutableArray array];
    
    //check that OS is supported
    if(YES != isSupportedOS())
    {
        //show alert
        [self showUnsupportedAlert];
        
        //exit
        exit(0);
    }

    //instantiate all plugins objects
    self.plugins = [self instantiatePlugins];
    
    //set selected plugin to first
    self.selectedPlugin = [self.plugins firstObject];
    
    //dbg msg
    //NSLog(@"KNOCKKNOCK: registered plugins: %@", self.plugins);
    
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

    return;
}

//display alert about OS not being supported
-(void)showUnsupportedAlert
{
    //response
    // ->index of button click
    NSModalResponse response = 0;
    
    //alert box
    NSAlert* fullScanAlert = nil;
    
    //alloc/init alert
    fullScanAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"OS X %@ is not supported", [[NSProcessInfo processInfo] operatingSystemVersionString]] defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"sorry for the inconvenience!"];
    
    //and show it
    response = [fullScanAlert runModal];
    
    return;
}

//init tracking areas for buttons
// ->provide mouse over effects
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
// ->returns list
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
    // ->STOP scan
    else
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
        
        //cancel scanner thread
        if(YES == [self.scannerThread isExecuting])
        {
            //cancel
            [self.scannerThread cancel];
        }
        
        //update the UI
        // ->reflect the stopped state & and display stats
        [self stopScanUI:SCAN_MSG_STOPPED];
    }
    
    return;
}

//kickoff background thread to scan
-(void)startScan
{
    //alloc thread
    scannerThread = [[NSThread alloc] initWithTarget:self selector:@selector(scan) object:nil];
    
    //start thread
    [self.scannerThread start];
    
    return;
}

//thread function
// ->runs in the background to execute each plugin
-(void)scan
{
    //reset active plugin index
    self.activePluginIndex = 0;
    
    //iterate over all plugins
    // ->invoke's each scan message
    for(PluginBase* plugin in self.plugins)
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
            [self.statusText setStringValue:[NSString stringWithFormat:@"scanning %@", plugin.name]];
            
        });
        
        //scan
        // ->will call back up into UI as items are found
        [plugin scan];
        
        //when 'disable VT' prefs not selected
        // ->kick of thread to perform VT query in background
        if(YES != self.prefsWindowController.disableVTQueries)
        {
            //do query
            [self queryVT:plugin];
        }
        
        //go to next active plugin
        self.activePluginIndex++;
    }
    
    //reset active plugin index
    // ->just to be safe...
    self.activePluginIndex = 0;
    
    //if VT querying is enabled (default)
    // ->wait a bit to let the VT results come in
    if(YES != self.prefsWindowController.disableVTQueries)
    {
        //nap
        [NSThread sleepForTimeInterval:3.0];
    }
    
    //stop ui & show informational alert
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        //save results?
        if(YES == self.prefsWindowController.saveOutput)
        {
            //save
            [self saveResults];
        }
        
        //update the UI
        // ->reflect the stopped state
        [self stopScanUI:SCAN_MSG_COMPLETE];
        
    });
    
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
    
    //save it into array
    [self.vtThreads addObject:virusTotalThread];
    
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
-(void)itemFound
{
    //active plugin object
    PluginBase* activePlugin = nil;
    
    //item
    ItemBase* uncoveredItem = nil;
    
    //item backing item table
    // ->depending on flilter status, either all items, or just known ones
    NSArray* tableItems = nil;
    
    //grab active plugin object
    activePlugin = self.plugins[self.activePluginIndex];
    
    //extract uncovered item
    // ->either File obj, Command obj, or Extension obj
    uncoveredItem = [activePlugin.allItems lastObject];
    
    //only show refresh table if
    // a) filter is not enabled (e.g. show all)
    // b) filtering is enable, but item is unknown
    if( (YES == self.prefsWindowController.showTrustedItems) ||
        ((YES != self.prefsWindowController.showTrustedItems) && (YES != uncoveredItem.isTrusted)) )
    {
        //set table item array
        // ->case: all
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //set to all items
            tableItems = activePlugin.allItems;
        }
        //set table item array
        // ->case: unknown items
        else
        {
            //set to unknown items
            tableItems = activePlugin.unknownItems;
        }
        //reload category table (on main thread)
        // ->this will result in the 'total' being updated
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //begin updates
            [self.itemTableController.itemTableView beginUpdates];
            
            //update category table row
            // ->this will result in the 'total' being updated
            [self.categoryTableController.categoryTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:self.activePluginIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            
            //if this plugin is currently the selected one (in the category table)
            // ->update the item row
            if(self.selectedPlugin == activePlugin)
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
        //execute on main (UI) thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //reload category table
            [self.categoryTableController customReload];
            
        });
    }

    //check if active plugin matches
    if(plugin == self.selectedPlugin)
    {
        //execute on main (UI) thread
        dispatch_sync(dispatch_get_main_queue(), ^{
        
            //scroll to top of item table
            [self.itemTableController scrollToTop];
            
            //reload item table
            [self.itemTableController.itemTableView reloadData];

        });
    }
    
    return;
}

//update a single row
-(void)itemProcessed:(File*)fileObj rowIndex:(NSUInteger)rowIndex
{
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
            
            //start table updates
            [self.itemTableController.itemTableView beginUpdates];
            
            //update
            [self.itemTableController.itemTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            
            //end table updates
            [self.itemTableController.itemTableView endUpdates];
            
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
    
    //save alert
    NSAlert* saveAlert = nil;
    
    //get currently selected category
    selectedCategory = self.categoryTableController.categoryTableView.selectedRow;
    
    //reload category table
    [self.categoryTableController customReload];
    
    //reloading the category table resets the selected plugin
    // ->so manually (re)set it here
    self.selectedPlugin = self.plugins[selectedCategory];
    
    //reload item table
    [self.itemTableController.itemTableView reloadData];
    
    //if VT query was never done (e.g. scan was started w/ pref disabled)
    // ->kick off VT queries now
    if( (0 == self.vtThreads.count) &&
        (YES != self.prefsWindowController.disableVTQueries) )
    {
        //iterate over all plugins
        // ->do VT query for each
        for(PluginBase* plugin in self.plugins)
        {
            //do query
            [self queryVT:plugin];
        }
    }
    
    //save results?
    // ->if there was a previous scan
    if( (nil != self.scannerThread) &&
        (YES == self.prefsWindowController.shouldSaveNow))
    {
        //save
        [self saveResults];
        
        //alloc/init alert
        saveAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"current results saved to %@", OUTPUT_FILE] defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"subsequent scans will overwrite this file"];
        
        //show it
        [saveAlert runModal];
    }
   
    return;
}

//update the UI to reflect that the fact the scan was started
// ->disable settings, set text 'stop scan', etc...
-(void)startScanUI
{
    //status msg's frame
    CGRect newFrame = {};
    
    //if scan was previous run
    // ->will need to shift status msg back over
    if(YES != [[self.statusText stringValue] isEqualToString:@""])
    {
        //grab status msg's frame
        newFrame = self.statusText.frame;
        
        //shift it over (since activity spinner is about to be shown)
        newFrame.origin.x -= 50;
        
        //update status msg w/ new frame
        self.statusText.frame = newFrame;
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
    
    return;
}

//update the UI to reflect that the fact the scan was stopped
// ->set text back to 'start scan', etc...
-(void)stopScanUI:(NSString*)statusMsg
{
    //status msg's frame
    CGRect newFrame = {};

    //stop spinner
    [self.progressIndicator stopAnimation:nil];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //grab status msg's frame
    newFrame = self.statusText.frame;
    
    //shift it over (since activity spinner is gone)
    newFrame.origin.x += 50;
    
    //update status msg w/ new frame
    self.statusText.frame = newFrame;
    
    //set status msg
    [self.statusText setStringValue:statusMsg];
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"startScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"startScanBG"];
    
    //set label text
    // ->'Start Scan'
    [self.scanButtonLabel setStringValue:START_SCAN];
    
    //re-enable gear (show prefs) button
    self.showPreferencesButton.enabled = YES;
    
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
    //NSUInteger flaggedItemCount =  0;
    
    //iterate over all plugins
    // ->sum up their item counts
    for(PluginBase* plugin in self.plugins)
    {
        //when showing all findings
        // ->sum em all up!
        if(YES == self.prefsWindowController.showTrustedItems)
        {
            //add up
            itemCount += plugin.allItems.count;
        }
        //otherwise just unknown items
        else
        {
            //add up
            itemCount += plugin.unknownItems.count;
        }
        
        //add plugin's flagged items
        //flaggedItemCount += plugin.flaggedItems.count;
    }
    
    //init detailed msg
    details = [NSMutableString stringWithFormat:@"■ found %lu items", (unsigned long)itemCount];
    
    /*
    //when VT integration is enabled
    // ->add flagged items
    if(YES != self.prefsWindowController.disableVTQueries)
    {
        //add flagged items
        [details appendFormat:@" \r\n■ %lu flagged by virus total", flaggedItemCount];
    }
    */
    
    //display 'saved' msg
    if(YES == self.prefsWindowController.saveOutput)
    {
        //add save msg
        [details appendFormat:@" \r\n■ saved findings to '%@'", OUTPUT_FILE];
    }
    
    //alloc/init settings window
    if(nil == self.resultsWindowController)
    {
        //alloc/init
        resultsWindowController = [[ResultsWindowController alloc] initWithWindowNibName:@"ResultsWindow"];
    }
    
    //center window
    [[self.resultsWindowController window] center];
    
    //show it
    [self.resultsWindowController showWindow:self];
    
    //set details
    [self.resultsWindowController.detailsLabel setStringValue:details];
    
    //make it modal
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        //modal!
        [[NSApplication sharedApplication] runModalForWindow:resultsWindowController.window];
        
    });
    
    return;
} 
 
//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //exit
    [NSApp terminate:self];
    
    return;
}

//button handler
// ->invoked when user checks/unchecks 'weak hijack detection' checkbox
-(IBAction)hijackDetectionOptions:(id)sender
{
    //alert
    NSAlert* detectionAlert = nil;
    
    //check if user clicked (on)
    if(NSOnState == ((NSButton*)sender).state)
    {
        //alloc/init alert
        detectionAlert = [NSAlert alertWithMessageText:@"This might produce false positives" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"please consult an expert if any results are found!"];
        
        //show it
        [detectionAlert runModal];
        
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

//save results to disk
// ->JSON dumped to current directory
-(void)saveResults
{
    //output
    NSMutableString* output = nil;
    
    //plugin items
    NSArray* items = nil;

    //output directory
    NSString* outputDirectory = nil;
    
    //output file
    NSString* outputFile = nil;
    
    //error
    NSError* error = nil;
    
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
    
    //init output directory
    // ->app's directory
    outputDirectory = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    //init full path to output file
    outputFile = [NSString stringWithFormat:@"%@/%@", outputDirectory, OUTPUT_FILE];
    
    //save JSON to disk
    if(YES != [output writeToFile:outputFile atomically:YES encoding:NSUTF8StringEncoding error:nil])
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: saving output to %@ failed with %@", outputFile, error);
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
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
    //alloc/init settings window
    if(nil == self.prefsWindowController)
    {
        //alloc/init
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    }
    
    //center window
    [[self.prefsWindowController window] center];
    
    //show it
    [self.prefsWindowController showWindow:self];
    
    //make it modal
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        //capture existing prefs
        // ->needed to trigger re-saves
        [self.prefsWindowController captureExistingPrefs];
        
        //modal!
        [[NSApplication sharedApplication] runModalForWindow:prefsWindowController.window];
        
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

@end

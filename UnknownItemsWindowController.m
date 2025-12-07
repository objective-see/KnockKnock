//
//  UnknownItemsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 1/1/25
//

#define COL_ENABLED 0x0
#define COL_RESULT 0x1
#define COL_PATH 0x2

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "UnknownItemsWindowController.h"

@implementation UnknownItemsWindowController

@synthesize items;
@synthesize submit;
@synthesize results;
@synthesize tableView;
@synthesize selections;

-(void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //grab last column
    NSTableColumn *lastColumn = self.tableView.tableColumns.lastObject;

    //set its resizing mask
    // expand as table does too
    lastColumn.resizingMask = NSTableColumnAutoresizingMask;
    
    //init
    results = [NSMutableDictionary dictionary];
    selections = [NSMutableDictionary dictionary];
    
    //make first responder
    [self.window makeFirstResponder:self.submit];
    
    return;
}

//table delegate
// ->return number of commands
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.items.count;
}

//table delegate method
// ->return cell for row
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //command
    File* file = nil;
    
    //column index
    NSUInteger index = 0;

    //table cell
    NSTableCellView* cell = nil;
    
    //check box
    NSButton* button = nil;
    
    //get existing cell
    cell = [self.tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    //grab index
    index = [[self.tableView tableColumns] indexOfObject:tableColumn];
    
    //get item for row
    file = self.items[row];
    
    //handle column specific logic
    switch(index)
    {
        //logic for 'enabled' column
        case COL_ENABLED:
            
            //grab checkbox
            button = (NSButton*)[cell viewWithTag:1001];
            if(button) {
                
                //set the state
                NSNumber* savedState = self.selections[@(row)];
                button.state = savedState ? savedState.integerValue : NSControlStateValueOn;

                //add target & action
                button.target = self;
                button.action = @selector(toggleTest:);
            }
            
            break;
            
        case COL_RESULT:
        {
            //result
            NSDictionary* result = self.results[@(row)];
            
            //erorr button
            NSButton* moreInfo =  (NSButton*)[cell viewWithTag:100];
            moreInfo.hidden = YES;
            
            //nothing
            if(!result.count) {
                
                //set
                cell.textField.toolTip = @"";
                cell.textField.stringValue = @"Not Submitted";
            }
            
            //error
            else if(result[VT_ERROR]) {
                
                //add
                cell.textField.stringValue = @"Failed to Submit";
                cell.textField.toolTip = [NSString stringWithFormat:@"ERROR: %@", result[VT_ERROR]];
                
                //show button
                moreInfo.hidden = NO;
               
            }
            //ok
            else
            {
                //set
                cell.textField.toolTip = @"";
                cell.textField.stringValue = @"Submitted";
                
                //already viewed?
                // no need to show again
                if(result[VT_REPORT_VIEWED]) {
                    break;
                }
                
                //got response?
                // launch browser to show user
                if(nil != result[VT_RESULTS_URL])
                {
                    //update result to note we've shown report
                    NSMutableDictionary* updatedResults = [result mutableCopy];
                    updatedResults[VT_REPORT_VIEWED] = @(YES);
                    
                    self.results[@(row)] = updatedResults;
                    
                    //launch browser to show new report
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //launch browser
                        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:result[VT_RESULTS_URL]]];
                
                    });
                }
            }
             
            break;
        }
           
        //logic for 'path' column
        case COL_PATH:
            
            //set path
            cell.textField.stringValue = file.path;
            break;
            
        default:
            break;
    }
    
    return cell;
}

- (IBAction)showErrorInfo:(id)sender
{
    
    //get the row for this button
    NSInteger row = [self.tableView rowForView:sender];
    if (row == -1)
    {
        return;
    }

    //get the result for this row
    NSDictionary* result = self.results[@(row)];
    if (!result)
    {
        return;
    }
    
    //popover
    NSPopover *popover = [[NSPopover alloc] init];
        
    //view controller
    NSViewController *viewController = [[NSViewController alloc] init];
    
    //set view
    viewController.view = self.errorPopover;
    
    //set text
    self.errorLabel.stringValue = [NSString stringWithFormat:@"ERROR: %@", result[VT_ERROR]];
    
    //init
    popover.contentViewController = viewController;
    popover.behavior = NSPopoverBehaviorTransient;
        
    //show relative to the button
    [popover showRelativeToRect:[sender bounds]
                         ofView:sender
                  preferredEdge:NSRectEdgeMaxY];
    return;
    
}

//automatically invoked when user checks/unchecks checkbox in row
// enable/disable command state, plus handle some other button logic
-(IBAction)toggleTest:(NSButton*)sender
{
    NSInteger row = [self.tableView rowForView:sender];
    if (row >= 0) {
        self.selections[@(row)] = @(sender.state);
    }
    
    //(re)enable submit button
    if(NSOnState == ((NSButton*)(sender)).state)
    {
        self.submit.enabled = YES;
    }
    //nothing selected?
    // disable submit button
    else
    {
        //disable
        self.submit.enabled = ![self allUnchecked];
    }
    
    return;
}

//checks if all items are unchecked
-(BOOL)allUnchecked {
    
    NSButton* button = nil;
    NSTableCellView* cell = nil;
    
    //check each/all
    for (NSInteger row = 0; row < self.tableView.numberOfRows; row++) {
        cell = [self.tableView viewAtColumn:0 row:row makeIfNecessary:NO];
        if(cell) {
            button = [cell viewWithTag:1001];
            if (button && (NSOnState == button.state)) {
                return NO;
            }
        }
    }
    
    return YES;
}

//submit items to VT
-(IBAction)submit:(id)sender
{
    //item
    File* item = nil;
    
    //submitted items
    __block NSUInteger submittedItems = 0;

    //VT object
    VirusTotal* vtObj = nil;
    
    //button
    NSButton* button = nil;
    
    //cell
    NSTableCellView* cell = nil;
    
    //alloc
    vtObj = [[VirusTotal alloc] init];
    
    //disable
    self.submit.enabled = NO;
   
    //show activity indicator
    self.activityIndicator.hidden = NO;
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    //submit all selected items
    for(NSInteger row = 0; row < self.tableView.numberOfRows; row++) {
        
        //grab cell
        cell = [self.tableView viewAtColumn:0 row:row makeIfNecessary:NO];
        if(!cell) {
            continue;
        }
        
        //get button
        button = [cell viewWithTag:1001];
        if (!button || (NSOnState != button.state)) {
            continue;
        }
        
        //extract item
        item = self.items[row];
        
        //skip non-file items
        if(YES != [item isKindOfClass:[File class]]) {
            //skip
            continue;
        }
        
        //skip item's without hashes
        // ...not sure how this could ever happen
        if(nil == ((File*)item).hashes[KEY_HASH_SHA1]) {
            //skip
            continue;
        }
        
        //set status
        self.statusLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Submitting '%@'...", @"Submitting '%@'..."), ((File*)item).name];
        
        //inc
        submittedItems++;
        
        //submit in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //nap
            sleep(0.5);
            
            //submit to VT
            [vtObj submitFile:((File*)item).path completion:^(NSDictionary *result) {
                
                
                //stop ui & show informational alert
                // ->executed on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //save results
                    self.results[@(row)] = result;
                    
                    //dec
                    submittedItems--;
                    
                    //reload
                    [self.tableView reloadData];
                    
                    //done?
                    if(0 == submittedItems) {
                        
                        //(re)enable
                        self.submit.enabled = YES;
                        
                        //stop spinner
                        [self.activityIndicator stopAnimation:nil];
                        
                        //set status
                        self.statusLabel.stringValue = NSLocalizedString(@"Submissions complete!", @"Submissions complete!");
                    }
                    
                });
                
            }];
            
        });

    }
    
    return;
}

@end

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
            
            //reset/hide text
            cell.textField.hidden = YES;
            cell.textField.stringValue = @"";
            
            //hide button
            button = (NSButton*)[cell viewWithTag:1001];
            if(button) {
                button.hidden = YES;
            }
            
            //display non-200 HTTP OK codes
            if( (nil != result) &&
                (200 != (long)[(NSHTTPURLResponse *)result[VT_HTTP_RESPONSE] statusCode]) )
            {
                
                //add
                cell.textField.stringValue = [NSString stringWithFormat:@"Error: %ld", (long)[(NSHTTPURLResponse *)result[VT_HTTP_RESPONSE] statusCode]];
                
                //show
                cell.textField.hidden = NO;
            }
            
            //otherwise
            // show button w/ link VT report
            else if(nil != result[@"sha256"])
            {
                //hide text
                cell.textField.hidden = YES;
                
                //get button
                button = (NSButton*)[cell viewWithTag:1001];
                if(button) {
                    
                    //configure
                    button.target = self;
                    button.action = @selector(viewReport:);
                    button.hidden = NO;
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

//invoked when user clicks 'View'
-(IBAction)viewReport:(NSButton*)sender {
    
    //get row
    NSInteger row = [self.tableView rowForView:sender];
    if (row != -1) {
         
        //get result
        NSDictionary* result = self.results[@(row)];
        
        //build report to URL
        NSURL* report = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", result[@"sha256"]]];
        
        //open (in browser)
        [[NSWorkspace sharedWorkspace] openURL:report];
    }
    
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
    
    //result (from VT)
    __block NSDictionary* result = nil;
    
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
        if(YES != [item isKindOfClass:[File class]])
        {
            //skip
            continue;
        }
        
        //skip item's without hashes
        // ...not sure how this could ever happen
        if(nil == ((File*)item).hashes[KEY_HASH_SHA1])
        {
            //skip
            continue;
        }
        
        //set status
        self.statusLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Submitting '%@'", @"Submitting '%@'"), ((File*)item).name];
        
        //inc
        submittedItems++;
        
        //submit in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //nap
            sleep(0.5);
            
            //submit file to VT
            result = [vtObj submit:(File*)item];
            
            //save results
            self.results[@(row)] = result;
            
            //reload table
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //dec
                submittedItems--;
                
                //reload
                [self.tableView reloadData];
                
                //done?
                if(0 == submittedItems)
                {
                    //(re)enable
                    self.submit.enabled = YES;
                    
                    //stop spinner
                    [self.activityIndicator stopAnimation:nil];
                    
                    //set status
                    self.statusLabel.stringValue = NSLocalizedString(@"Submissions complete!", @"Submissions complete!");
                }
            });
        });
    }
    
    return;
}

@end

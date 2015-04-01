//
//  CategoryTableController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/18/15.
//


#import "Consts.h"
#import "PluginBase.h"
#import "AppDelegate.h"
#import "CategoryTableController.h"

@implementation CategoryTableController

@synthesize selectedRow;
@synthesize tableContents;
@synthesize categoryTableView;

//invoked automatically while nib is loaded
// ->note: outlets are nil here :/
-(id)init
{
    self = [super init];
    if(nil != self)
    {
        //init
        self.selectedRow = -1;
    }
    
    return self;
}

//initialize table
// ->save plugins into array that backs table, then reload
-(void)initTable:(NSMutableArray*)plugins
{
    //save plugins
    self.tableContents = plugins;
    
    //reload table
    [self.categoryTableView reloadData];
    
    return;
}

//pragma stuff

//table delegate
// ->return number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.tableContents.count;
}

//table delegate method
// ->return cell for row
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //category items
    // ->depending on state, will either be all items, or only unknown ones
    NSUInteger itemsInCategory = 0;
    
    //category cell
    NSTableCellView *categoryCell = nil;
    
    //plugin
    PluginBase* plugin = nil;
    
    //extract plugin object
    plugin = self.tableContents[row];
    
    //set item number of category items
    // ->case: no filtering (i.e., all items)
    if(YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.showTrustedItems)
    {
        //set count
        itemsInCategory = plugin.allItems.count;
    }
    //set item number of category items
    // ->case: filtering (i.e., unknown items)
    else
    {
        //set count
        itemsInCategory = plugin.unknownItems.count;
    }

    //create cell
    categoryCell = [tableView makeViewWithIdentifier:@"categoryCell" owner:self];
    if(nil == categoryCell)
    {
        //bail
        goto bail;
    }

    //set icon
    categoryCell.imageView.image = [NSImage imageNamed:plugin.icon];
    
    //set (main) text
    [categoryCell.textField setStringValue:plugin.name];
    
    //set detailed text
    [[categoryCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:plugin.description];
    
    //set item count
    [[categoryCell viewWithTag:TABLE_ROW_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", itemsInCategory]];
    
//bail
bail:
    
    return categoryCell;
}

//table delegate method
// ->invoke when user clicks row (to select)
//   if its a content row, allow the selection (and handle text highlighting issues)
-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
    //ret flag
    BOOL shouldSelect = NO;
    
    //current row
    NSTableCellView* currentRow = nil;
    
    //previously selected row
    NSTableCellView* previousRow = nil;
    
    //detailed text
    NSTextField* detailedTextField = nil;
    
    //category count
    NSTextField* countTextField = nil;
    
    //sanity check
    if(-1 == rowIndex)
    {
        //bail
        goto bail;
    }
    
    //get row that's about to be selected
    currentRow = [self.categoryTableView viewAtColumn:0 row:rowIndex makeIfNecessary:YES];
    
    //for new row, set text to white
    // ->for previous row, reset text color
    if(nil != currentRow)
    {
        //for previously selected row
        // ->reset set
        if( (-1 != self.selectedRow) &&
            (rowIndex != self.selectedRow) )
        {
            //get previous row
            previousRow = [self.categoryTableView viewAtColumn:0 row:self.selectedRow makeIfNecessary:NO];
            
            //reset row
            [self resetRow:previousRow];
        }
        
        //save selected row index
        self.selectedRow = rowIndex;
        
        //get detailed text of current row
        detailedTextField = [currentRow viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
        
        //set text color to white
        detailedTextField.textColor = [NSColor whiteColor];
        
        //get category count
        countTextField = [currentRow viewWithTag:TABLE_ROW_TOTAL_TAG];
        
        //set text color to white
        countTextField.textColor = [NSColor whiteColor];
        
        //callback up into app delegate
        // ->lets it know that row selection changed
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) categorySelected:rowIndex];
    }
    
    //happy
    shouldSelect = YES;
    
//bail
bail:
    
    return YES;
}

//reload due to toggle of filter options
// ->extra logic needed to handle selections/highlighting, etc
-(void)customReload
{
    //currently selected category
    NSUInteger selectedCategory = 0;
    
    //get currently selected category
    selectedCategory = self.categoryTableView.selectedRow;
    
    //reload category table
    [self.categoryTableView reloadData];
    
    //re-select
    if(-1 != selectedCategory)
    {
        //make sure category is still selected
        [self.categoryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedCategory] byExtendingSelection:NO];
        
        //manually re-select row in category table
        // ->since 'shouldSelectRow' isn't triggered via 'selectRowIndexes'
        [self tableView:self.categoryTableView shouldSelectRow:selectedCategory];
    }
    
    return;
}

//reset a row that was modified (manually) when selected
-(void)resetRow:(NSTableCellView*)row
{
    //detailed text
    NSTextField* detailedTextField = nil;
    
    //total
    NSTextField* totalTextField = nil;
    
    //get detailed text of previous row
    detailedTextField = [row viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
    
    //reset its color to gray
    detailedTextField.textColor = [NSColor grayColor];
    
    //get detailed text of previous row
    totalTextField = [row viewWithTag:TABLE_ROW_TOTAL_TAG];
    
    //reset its color to gray
    totalTextField.textColor = [NSColor grayColor];
    
    return;
}


@end

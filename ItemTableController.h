//
//  ItemTableController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/18/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "InfoWindowController.h"
#import "VTInfoWindowController.h"

#import <Foundation/Foundation.h>

@interface ItemTableController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
    
}

//category table view
@property(weak) IBOutlet NSTableView *itemTableView;

//info window
@property(retain, nonatomic)InfoWindowController* infoWindowController;

//preferences window controller
@property (nonatomic, retain)VTInfoWindowController* vtWindowController;

//no items label
@property (nonatomic, retain) IBOutlet NSTextField *noItemsLabel;

/* METHODS */

//button handler
// ->show item in finder
- (IBAction)showInFinder:(id)sender;

//button handler
// ->show info window
- (IBAction)showInfo:(id)sender;

//button handler
// ->show virus total info window
-(void)showVTInfo:(NSView*)button;

//scroll back up to top of table
-(void)scrollToTop;

//helper function
// ->get items array (either all or just unknown)
-(NSArray*)getTableItems;




@end

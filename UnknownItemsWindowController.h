//
//  UnknownItemsWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 1/1/25
//

#import <Cocoa/Cocoa.h>

#define COL_ENABLED 0x0
#define COL_RESULT  0x1
#define COL_PATH    0x2

static const unsigned long long MAX_UPLOAD_SIZE = 32 * 1024 * 1024;

@interface UnknownItemsWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
{
    
}

/* PROPERTIES */

//unknown items
@property(nonatomic, retain)NSMutableArray* items;

@property(nonatomic, retain)NSMutableDictionary<NSNumber *, NSDictionary*>*results;
@property(nonatomic, retain)NSMutableDictionary<NSNumber *, NSNumber *>*selections;

//table view
@property(weak)IBOutlet NSTableView *tableView;

//'submit' button
@property(weak)IBOutlet NSButton *submit;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//status label
@property (weak) IBOutlet NSTextField *statusLabel;

//error
@property (strong) IBOutlet NSView *errorPopover;

//error label
@property (weak) IBOutlet NSTextField *errorLabel;


/* METHODS */

//checkbox button handler
-(IBAction)toggleTest:(id)sender;

//submit button handler
-(IBAction)submit:(id)sender;

@end

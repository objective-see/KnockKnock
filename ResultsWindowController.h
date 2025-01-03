//
//  ResultsWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UnknownItemsWindowController.h"

@interface ResultsWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//details
@property(nonatomic, retain)NSString* details;

//details of results label/string
@property(weak) IBOutlet NSTextField* detailsLabel;

//unknown items
@property(nonatomic, retain)NSMutableArray* unknownItems;

//unknown itmes details
@property(nonatomic, retain)NSString* vtDetails;

//unknown items
@property (weak) IBOutlet NSTextField *vtDetailsLabel;

//submit to VT button
@property (weak) IBOutlet NSButton *submitToVT;

//window controller for unknown items
@property(nonatomic, strong)UnknownItemsWindowController* unknownItemsWindowController;

/* METHODS */

@end

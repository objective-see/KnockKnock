//
//  InfoWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/21/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PlistWindowController.h"

@class ItemBase;

@interface InfoWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//properties in window
// ->attributes about the item
@property(weak)IBOutlet NSImageView *icon;
@property(weak)IBOutlet NSTextField *name;
@property(weak)IBOutlet NSTextField *path;
@property(weak)IBOutlet NSTextField *date;


//file window specific outlets
@property(weak)IBOutlet NSTextField *hashes;
@property(weak)IBOutlet NSTextField *size;
@property(weak)IBOutlet NSTextField *sign;

@property (weak) IBOutlet NSTextField *plistLabel;
@property (weak) IBOutlet NSTextField *plist;

//extension window specific outlets
@property (weak) IBOutlet NSTextField *details;
@property (weak) IBOutlet NSTextField *identifier;

//window controller
@property(nonatomic, strong)InfoWindowController *windowController;

//item
@property(nonatomic, retain)ItemBase* itemObj;

//entitlements popup controller
@property (strong) PlistWindowController* plistWindowController;

/* METHODS */

//init method
// ->save item and load nib
-(id)initWithItem:(ItemBase*)selectedItem;

//configure window
// ->add item's attributes (name, path, etc.)
-(void)configure;

//close button handler
-(IBAction)closeWindow:(id)sender;

@end

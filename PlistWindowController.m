//
//  EntitlementsWindowController.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "PlistWindowController.h"


@implementation PlistWindowController

@synthesize plist;

//window load
// init UI stuffz
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];

    //set path in ui
    self.path.stringValue = self.plist;
    
    //set inset
    self.contents.textContainerInset = NSMakeSize(0, 10);
    
    //set font
    self.contents.font = [NSFont fontWithName:@"Menlo" size:13];
    
    //add plist
    self.contents.string = [[NSDictionary dictionaryWithContentsOfFile:self.plist] description];
    if(0 == self.contents.string.length)
    {
        //display error
        self.contents.string = [NSString stringWithFormat:@"failed to load contents of %@", self.plist];
    }

    return;
}

//close
// end sheet
-(IBAction)close:(id)sender
{
    //end sheet
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end

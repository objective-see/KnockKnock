//
//  EntitlementsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "consts.h"
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
    
    //load plist
    // note: nil if unreadable, or not a dictionary at the top level (e.g. an array plist)
    NSString* plistContents = [[NSDictionary dictionaryWithContentsOfFile:self.plist] description];
    if(0 == plistContents.length)
    {
        //display error
        plistContents = [NSString stringWithFormat:NSLocalizedString(@"failed to load contents of %@", @"failed to load contents of %@"), self.plist];
    }
    
    //add plist
    self.contents.string = plistContents;

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

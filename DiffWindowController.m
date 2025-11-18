//
//  DiffWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 09/01/24.
//  Copyright (c) 2024 Objective-See. All rights reserved.
//

#import "consts.h"
#import "DiffWindowController.h"

@implementation DiffWindowController

-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//window load
// init UI stuffz
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];

    //set path in ui
    //self.path.stringValue = self.plist;
    
    //set inset
    self.contents.textContainerInset = NSMakeSize(0, 10);
    
    //set font
    self.contents.font = [NSFont fontWithName:@"Menlo" size:13];
    
    //add plist
    self.contents.string = self.differences;//[[NSDictionary dictionaryWithContentsOfFile:self.plist] description];
    /*
    if(0 == self.contents.string.length)
    {
        //display error
        self.contents.string = [NSString stringWithFormat:NSLocalizedString(@"failed to load contents of %@", @"failed to load contents of %@"), self.plist];
    }
    */

    return;
}

//close
// end sheet
-(IBAction)close:(id)sender
{
    [self.window close];
    
    return;
}

@end

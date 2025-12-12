//
//  ResultsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "utilities.h"
#import "AppDelegate.h"
#import "ResultsWindowController.h"

@implementation ResultsWindowController

@synthesize details;
@synthesize detailsLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//initialize window
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set details
    self.detailsLabel.stringValue = self.details;
    
    //set VT results
    if(nil != self.vtDetails)
    {
        //set
        self.vtDetailsLabel.stringValue = self.vtDetails;
        
        //line spacing
        setLineSpacing(self.vtDetailsLabel, 5.0);
        
        //show/hide 'unknown items' button
        self.submitToVT.hidden = !(self.unknownItems.count);
    }
    //no VT results
    // disabled? something else?
    else
    {
        //hide 'unknown items' button
        self.submitToVT.hidden = YES;
        
        //disabled
        if(((AppDelegate*)NSApplication.sharedApplication.delegate).prefsWindowController.disableVTQueries)
        {
            self.vtDetailsLabel.stringValue = NSLocalizedString(@"VirusTotal Results: N/A (Disabled)", @"VirusTotal Results: N/A (Disabled)");
        }
        
        //no API key
        else if(!((AppDelegate*)NSApplication.sharedApplication.delegate).prefsWindowController.vtAPIKey.length)
        {
            self.vtDetailsLabel.stringValue = NSLocalizedString(@"VirusTotal Results: N/A (No API Key)", @"VirusTotal Results: N/A (No API Key)");
        }
        
        //?
        else
        {
            self.vtDetailsLabel.stringValue = @"VirusTotal: Error(?)";
        }
    }
    
    return;
}

//show 'unknown items' window
-(IBAction)viewUnknownItems:(id)sender
{
    //make normal
    [self.window setLevel:NSNormalWindowLevel];
    
    //alloc/init unknown items
    self.unknownItemsWindowController = [[UnknownItemsWindowController alloc] initWithWindowNibName:@"UnknownItems"];
     
    //set unknown items
    self.unknownItemsWindowController.items = self.unknownItems;
    
    //show it
    [self.unknownItemsWindowController showWindow:self];
    
    //center
    [self.unknownItemsWindowController.window center];
    
    return;
}

@end

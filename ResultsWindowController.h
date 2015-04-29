//
//  PrefsWindowController.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ResultsWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//details
@property(nonatomic, retain)NSString* details;

//details of results label/string
@property(weak) IBOutlet NSTextField *detailsLabel;


/* METHODS */

//invoked when user clicks 'more info' button
// ->open KK's webpage
- (IBAction)close:(id)sender;

@end

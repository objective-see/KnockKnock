//
//  main.h
//  KnockKnock
//
//  Created by Patrick Wardle on 11/12/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "Consts.h"
#import "Filter.h"
#import "Utilities.h"
#import "VirusTotal.h"
#import "AppDelegate.h"
#import "ItemEnumerator.h"

#import <Cocoa/Cocoa.h>

/* GLOBALS */

//filter object
Filter* itemFilter = nil;

//shared item enumerator object
ItemEnumerator* sharedItemEnumerator = nil;

//cmdline flag
BOOL cmdlineMode = NO;

/* FUNCTIONS */

//print usage
void usage(void);

//perform a cmdline scan
void cmdlineScan(void);

//pretty print JSON
void prettyPrintJSON(NSString* output);

#endif /* main_h */

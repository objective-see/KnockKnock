//
//  main.h
//  KnockKnock
//
//  Created by Patrick Wardle on 11/12/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "consts.h"
#import "Filter.h"
#import "utilities.h"
#import "VirusTotal.h"
#import "AppDelegate.h"
#import "ItemEnumerator.h"

#import <Cocoa/Cocoa.h>

/* GLOBALS */

//filter object
Filter* itemFilter = nil;

//shared item enumerator object
ItemEnumerator* sharedItemEnumerator = nil;

//cmdline scan
BOOL cmdlineMode = NO;

//cmdline flag
BOOL isVerbose = NO;

//query VT?
BOOL queryVT = NO;

//(VT) API key for cmdline scan
NSString* vtAPIKey = nil;


/* FUNCTIONS */

//print usage
void usage(BOOL error);

//print version
void version(void);

//perform a cmdline scan
void cmdlineScan(NSArray* args);

//pretty print JSON
void prettyPrintJSON(NSString* output);

#endif /* main_h */

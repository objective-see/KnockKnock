//
//  VirusTotal.h
//  KnockKnock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

@interface VirusTotal : NSObject
{
    
}

/* METHODS */

//thread function
// ->runs in the background to get virus total info about a plugin's items
-(void)getInfo:(PluginBase*)plugin;

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url parameters:(id)params;

//submit a file to VT
-(NSDictionary*)submit:(File*)fileObj;

//submit a rescan request
-(NSDictionary*)reScan:(File*)fileObj;

//process results
// ->updates items (found, detection ratio, etc)
-(void)processResults:(NSArray*)items results:(NSDictionary*)results;

//get info for a single item
// ->will callback into AppDelegate to reload plugin
-(void)getInfoForItem:(File*)fileObj scanID:(NSString*)scanID;

@end

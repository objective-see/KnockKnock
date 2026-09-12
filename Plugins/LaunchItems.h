//
//  LaunchItems.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PluginBase.h"

/* GLOBALS */

//shared enumerator
extern ItemEnumerator* sharedItemEnumerator;


@interface LaunchItems : PluginBase
{
    
}

//PROPERTIES

//launchd overrides (i.e. 'launchctl enable/disable' state), per domain
// domain ("system" or uid) -> (label -> @YES (disabled) / @NO (explicitly enabled))
@property(nonatomic, retain)NSDictionary* overrides;

//users' home directories -> uid
// to map a (per-user) launch agent plist to its launchd domain
@property(nonatomic, retain)NSDictionary* userHomes;

/* (custom) METHODS */

//get all overridden enabled/disabled launch items
// ->from launchd's (live) override database
-(void)processOverrides;

//get the override for a launch item, in the domain(s) it loads into
// returns @YES (disabled), @NO (explicitly enabled), or nil (no override)
-(NSNumber*)overrideForLabel:(NSString*)label plist:(NSString*)plist;

//checks if an item will be automatically run by the OS
-(BOOL)isAutoRun:(NSDictionary*)plistContents plist:(NSString*)plist;

@end

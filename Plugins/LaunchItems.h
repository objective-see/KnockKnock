//
//  Kexts.h
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

//overridden disabled items
@property(nonatomic, retain)NSMutableArray* disabledItems;

//overridden enabled items
@property(nonatomic, retain)NSMutableArray* enabledItems;

/* (custom) METHODS */

//get all overridden enabled/disabled launch items
// ->specified in various overrides.plist files
-(void)processOverrides;

//checks if an item will be automatically run by the OS
-(BOOL)isAutoRun:(NSDictionary*)plistContents;

@end

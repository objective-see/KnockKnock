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

//items disabled via override (i.e. 'launchctl disable')
@property(nonatomic, retain)NSMutableArray* disabledItems;

//items explicitly enabled via override (i.e. 'launchctl enable')
// note: such items run even if their plist says 'Disabled'
@property(nonatomic, retain)NSMutableArray* enabledItems;

/* (custom) METHODS */

//get all overridden enabled/disabled launch items
// ->from launchd's (live) override database
-(void)processOverrides;

//checks if an item will be automatically run by the OS
-(BOOL)isAutoRun:(NSDictionary*)plistContents;

@end

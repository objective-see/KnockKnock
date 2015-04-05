//
//  Kexts.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PluginBase.h"

@interface LaunchItems : PluginBase
{
    
}

/* (custom) METHODS */

//get all disabled launch items
// ->specified in various overrides.plist files
-(NSArray*)getDisabledItems;


@end

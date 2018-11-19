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


@interface DylibInserts : PluginBase
{
    
}

/* (custom) METHODS */

//scan all launch items
// ->looks in their plists for DYLD_INSERT_LIBRARYs
-(void)scanLaunchItems;

//scan all installed applications
// ->looks in their plists for DYLD_INSERT_LIBRARYs
-(void)scanApplications;


@end

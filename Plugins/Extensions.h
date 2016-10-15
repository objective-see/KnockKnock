//
//  Extensions.h
//  KnockKnock
//
//  Created by Patrick Wardle on 7/19/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

/* DEFINES */

//file that contains some (more?) finder syncs
#define FINDER_SYNCS @"~/Library/Preferences/com.apple.preferences.extensions.FinderSync.plist"

@interface Extensions : PluginBase
{
    
}

/* (custom) METHODS */

//given output from plugin kit
// ->parse out all enabled extensions
-(NSMutableArray*)parseExtensions:(NSString*)output;

@end

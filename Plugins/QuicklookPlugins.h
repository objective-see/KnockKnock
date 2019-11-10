//
//  QuicklookPlugins.h
//  KnockKnock
//
//  Created by Patrick Wardle on 11/09/19.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <dlfcn.h>
#import "PluginBase.h"
#import <Foundation/Foundation.h>

//path to QL framework
#define QUICKLOOK_FRAMEWORK @"/System/Library/Frameworks/QuickLook.framework"

//function def for '_QLCopyServerStatistics'
typedef id (*QLCopyServerStatistics)(NSArray* stats);

//function pointer for
static QLCopyServerStatistics copyServerStats = NULL;

@interface QuicklookPlugins : PluginBase
{
    
}

/* (custom) METHODS */

@end

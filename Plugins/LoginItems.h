//
//  Kexts.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

@interface LoginItems : PluginBase
{
    
}

/* PROPERTIES */

/* (custom) METHODS */

//enumerate traditional login items
// ->basically just invoke LSSharedFileListCopySnapshot(), etc to get list of items
-(NSMutableArray*)enumTraditionalItems;

//enumerate sandboxed login items
// ->scan /Applications for 'Contents/Library/LoginItems/' and xref w/ launchd jobs
-(NSMutableArray*)enumSandboxItems;

@end

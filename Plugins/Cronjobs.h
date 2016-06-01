//
//  Cronjobs.h
//  KnockKnock
//
//  Created by Patrick Wardle on 7/10/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

@interface CronJobs : PluginBase
{
    
}

/* (custom) METHODS */

//determines if a line is really a cronjob
// ->ignores everything that doesn't start with a digit, '*', or '@'
-(BOOL)isJob:(NSString*)possibleJob;


@end

//
//  LoginOutHooks.m
//  KnockKnock
//
//  Created by Patrick Wardle on 7/18/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

@interface LogInOutHooks : PluginBase
{
    
}

/* (custom) METHODS */

//create a File obj
// ->then save & report to UI
-(void)processHook:(NSString*)file parentFile:(NSString*)parentFile;

@end

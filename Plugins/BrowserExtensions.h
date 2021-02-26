//
//  BrowserExtensions.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>



@interface BrowserExtensions : PluginBase
{
    
}

/* (custom) METHODS */

//get all disabled launch items
// ->specified in various overrides.plist files
-(NSArray*)getInstalledBrowsers;

//scan for Safari extensions
-(void)scanExtensionsSafari:(NSString*)browserPath;

//scan for Chrome extensions
-(void)scanExtensionsChrome:(NSString*)browserPath;

//scan for Firefox extensions
-(void)scanExtensionsFirefox:(NSString*)browserPath;

@end

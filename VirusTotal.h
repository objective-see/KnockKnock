//
//  VirusTotal.h
//  KnockKnock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "PluginBase.h"
#import <Foundation/Foundation.h>

@interface VirusTotal : NSObject
{
    
}

/* METHODS */

//check (all plugin's) files
-(void)checkFiles:(PluginBase*)plugin apiKey:(NSString*)apiKey uiMode:(BOOL)uiMode completion:(void(^)(void))completion;

//submit a file for scanning
-(void)submitFile:(NSString *)filePath completion:(void (^)(NSDictionary *result))completion;

@end

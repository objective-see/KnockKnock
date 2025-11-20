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

-(void)checkFiles:(PluginBase*)plugin;

- (void)submitFile:(NSString *)filePath completion:(void (^)(NSDictionary *result))completion;


@end

//
//  Extension.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Extension.h"
#import "utilities.h"
#import "AppDelegate.h"

@implementation Extension

//init method
-(id)initWithParams:(NSDictionary*)params
{
    //super
    self = [super initWithParams:params];
    if(nil != self)
    {
        //extract/save id
        // coerced, as (untrusted) JSON values can be any type
        self.identifier = stringValue(params[KEY_EXTENSION_ID]);
        
        //extract/save description
        self.details = stringValue(params[KEY_EXTENSION_DETAILS]);
        
        //extract/save browser
        self.browser = stringValue(params[KEY_EXTENSION_BROWSER]);
        
        //call into filter object to check if file is known
        // ->signed or whitelisted
        self.isTrusted = [itemFilter isTrustedExtension:self];
    }
    
    return self;
}

//convert obj to JSON
-(NSString*)toJSON
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    dict[@"name"] = self.name ?: @"unknown";
    dict[@"path"] = self.path ?: @"unknown";
    dict[@"identifier"] = self.identifier ?: @"unknown";
    dict[@"details"] = self.details ?: @"unknown";
    dict[@"browser"] = self.browser ?: @"unknown";
    
    //serialize
    // sanitizes, and never drops name/path
    return [self serializeToJSON:dict];
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"name: %@, path: %@, identifier: %@, details: %@, browser: %@", self.name, self.path, self.identifier, self.details, self.browser];
}

@end

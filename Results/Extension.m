//
//  Extension.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Extension.h"
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
        self.identifier = params[KEY_EXTENSION_ID];
        
        //extract/save description
        self.details = params[KEY_EXTENSION_DETAILS];
        
        //extract/save description
        self.browser = params[KEY_EXTENSION_BROWSER];
        
        //call into filter object to check if file is known
        // ->signed or whitelisted
        self.isTrusted = [itemFilter isTrustedExtension:self];
    }
    
    return self;
}

//convert obj to JSON
-(NSString*)toJSON
{
    NSString* json = nil;
    NSData* jsonData = nil;
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    dict[@"name"] = self.name ?: @"unknown";
    dict[@"path"] = self.path ?: @"unknown";
    dict[@"identifier"] = self.identifier ?: @"unknown";
    dict[@"details"] = self.details ?: @"unknown";
    dict[@"browser"] = self.browser ?: @"unknown";
    
    @try
    {
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:NULL];
        if(jsonData) {
            json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    @catch(NSException* exception)
    {
        json = @"{\"error\": \"serialization failed\"}";
    }
    
    return json ?: @"{\"error\": \"serialization failed\"}";
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"name: %@, path: %@, identifier: %@, details: %@, browser: %@", self.name, self.path, self.identifier, self.details, self.browser];
}

@end

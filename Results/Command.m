//
//  Command.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Command.h"
#import "utilities.h"

@implementation Command

@synthesize command;

//init method
-(id)initWithParams:(NSDictionary*)params
{
    //super
    self = [super initWithParams:params];
    if(nil != self)
    {
        //save command
        self.command = params[KEY_RESULT_COMMAND];
    }
    
    return self;
}

//convert obj to JSON
-(NSString*)toJSON
{
    NSString* json = nil;
    NSData* jsonData = nil;
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    dict[@"command"] = self.command ?: @"unknown";
    dict[@"file"] = self.path ?: @"unknown";
    
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
    return [NSString stringWithFormat:@"command: %@, file: %@", self.command, self.path];
}

@end

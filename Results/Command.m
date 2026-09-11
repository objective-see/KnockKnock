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
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    dict[@"command"] = self.command ?: @"unknown";
    dict[@"file"] = self.path ?: @"unknown";
    
    //serialize
    // sanitizes, and never drops name/path
    return [self serializeToJSON:dict];
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"command: %@, file: %@", self.command, self.path];
}

@end

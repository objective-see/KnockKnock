//
//  Command.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Command.h"
#import "Utilities.h"

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

//convert object to JSON string
-(NSString*)toJSON
{
    //json string
    NSString *json = nil;
    
    //init json
    // ->note: command is escaped to make sure its valid JSON
    json = [NSString stringWithFormat:@"\"command\": \"%@\", \"file\": \"%@\"", escapeString(self.command), self.path];
    
    return json;
}



@end

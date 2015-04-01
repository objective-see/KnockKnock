//
//  Binary.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import "Binary.h"
#import "MachO.h"

@implementation Binary

@synthesize path;


@synthesize parserInstance;

@synthesize lcRPATHS;


@synthesize issueType;
@synthesize issueItem;
@synthesize isHijacked;
@synthesize isVulnerable;


//init with a path
-(id)initWithPath:(NSString*)binaryPath
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        self.path = binaryPath;
        
        //alloc array for run-path search directories
        // ->needed since we resolve these manually
        lcRPATHS = [NSMutableArray array];
    }
    
    return self;
}

//get the machO type from the machO parser instance
// ->just grab from first header (should all by the same)
-(uint32_t)getType
{
    //type
    uint32_t type = 0;
    
    //extract type
    if(nil != self.parserInstance)
    {
        //extract
        type = [[[self.parserInstance.binaryInfo[KEY_MACHO_HEADERS] firstObject] objectForKey:KEY_HEADER_BINARY_TYPE] unsignedIntValue];
    }
    
    return type;
}


@end

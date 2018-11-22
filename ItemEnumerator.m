//
//  ItemEnumerator.m
//  KnockKnock
//
//  Created by Patrick Wardle on 4/24/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"
#import "ItemEnumerator.h"

@implementation ItemEnumerator

@synthesize launchItems;
@synthesize applications;
@synthesize launchItemsEnumerator;
@synthesize applicationsEnumerator;

//plugin search directories
NSString * const LAUNCHITEM_SEARCH_DIRECTORIES[] = {@"/System/Library/LaunchDaemons/", @"/Library/LaunchDaemons/", @"/System/Library/LaunchAgents/", @"/Library/LaunchAgents/", @"~/Library/LaunchAgents/"};

//enumerate all 'shared' items
// ->that is to say, items that multiple plugins scan/process
-(void)start
{
    //save self's thread
    self.enumeratorThread = [NSThread currentThread];
    
    //alloc/init thread to enumerate launch items
    launchItemsEnumerator = [[NSThread alloc] initWithTarget:self selector:@selector(enumerateLaunchItems) object:nil];

    //alloc/init thread to enumerate installed applications
    applicationsEnumerator = [[NSThread alloc] initWithTarget:self selector:@selector(enumerateApplications) object:nil];

    //start launch item enumerator thread
    [self.launchItemsEnumerator start];
    
    //start installed application enumerator thread
    [self.applicationsEnumerator start];
    
    return;
}

//cancel all enumerator threads
-(void)stop
{
    //cancel launch item enumerator thread
    if(YES == [self.launchItemsEnumerator isExecuting])
    {
        //cancel
        [self.launchItemsEnumerator cancel];
    }
    
    //cancel installed application enumerator thread
    if(YES == [self.applicationsEnumerator isExecuting])
    {
        //cancel
        [self.applicationsEnumerator cancel];
    }
    
    //set launch items array to nil
    self.launchItems = nil;
    
    //set installed app array to nil
    self.applications = nil;
    
    return;
}

//generate list of all launch items (daemons & agents)
-(void)enumerateLaunchItems
{
    //all launch items
    NSMutableArray* allLaunchItems = nil;
    
    //all launch item directories, expanded
    NSMutableArray* launchItemDirectories = nil;
    
    //alloc array for all launch items
    allLaunchItems = [NSMutableArray array];
    
    //expand list
    launchItemDirectories = expandPaths(LAUNCHITEM_SEARCH_DIRECTORIES, sizeof(LAUNCHITEM_SEARCH_DIRECTORIES)/sizeof(LAUNCHITEM_SEARCH_DIRECTORIES[0]));
    
    //iterate over all launch item direcoties
    // grab all .plists and add to cumulative array
    for(NSString* launchItemDirectory in launchItemDirectories)
    {
        //grab all plist
        for(NSString* plist in directoryContents(launchItemDirectory, @"self ENDSWITH '.plist'"))
        {
            //build full path to item/plist and save
            [allLaunchItems addObject:[launchItemDirectory stringByAppendingPathComponent:plist]];
        }
    }
    
    //save into iVar
    self.launchItems = allLaunchItems;
    
    return;
}


//generate list of all installed applications
// ->save into iVar, 'applications'
-(void)enumerateApplications
{
    //installed apps
    NSMutableArray* installedApplications = nil;
    
    //output from system profiler task
    NSData* taskOutput = nil;
    
    //serialized task output
    NSArray* serializedOutput = nil;
    
    //alloc array for installed apps
    installedApplications = [NSMutableArray array];
    
    //exec system profiler
    taskOutput = execTask(SYSTEM_PROFILER, @[@"SPApplicationsDataType", @"-xml",  @"-detailLevel", @"mini"]);
    if( (nil == taskOutput) ||
        (0 == taskOutput.length) )
    {
        //bail
        goto bail;
    }
    
    //serialize output to array
    serializedOutput = [NSPropertyListSerialization propertyListWithData:taskOutput options:kNilOptions format:NULL error:NULL];
    
    //grab list of installed apps from '_items' key
    // ->save into iVar 'applications'
    @try
    {
        //save
        self.applications = serializedOutput[0][@"_items"];
    }
    @catch (NSException *exception)
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: serialized output not formatted as expected");
        
        //bail
        goto bail;
    }
   
//bail
bail:
    
    return;
}


@end

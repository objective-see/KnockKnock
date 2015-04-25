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
    //applicationsEnumerator = [[NSThread alloc] initWithTarget:self selector:@selector(enumerateApplications) object:nil];

    //start launch item enumerator thread
    [self.launchItemsEnumerator start];
    
    //start installed application enumerator thread
    //[self.applicationsEnumerator start];
    
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
    
    /*
    //cancel installed application enumerator thread
    if(YES == [self.applicationsEnumerator isExecuting])
    {
        //cancel
        [self.applicationsEnumerator cancel];
    }
    */
    
    //set launch items array to nil
    self.launchItems = nil;
    
    //set installed app array to nil
    self.applications = nil;
    
    return;
}

//generate list of all launch items (daemons & agents)
// ->save into iVar, 'launchItem'
-(void)enumerateLaunchItems
{
    //all launch items
    NSMutableArray* allLaunchItems = nil;
    
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //current launch item directory
    NSString* launchItemDirectory = nil;
    
    //alloc array for all launch items
    allLaunchItems = [NSMutableArray array];
    
    //get number of search directories
    directoryCount = sizeof(LAUNCHITEM_SEARCH_DIRECTORIES)/sizeof(LAUNCHITEM_SEARCH_DIRECTORIES[0]);
    
    //iterate over all launch item directories
    // ->cumulativelly save all launch items
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //extract current directory
        launchItemDirectory = [LAUNCHITEM_SEARCH_DIRECTORIES[i] stringByExpandingTildeInPath];
        
        //iterate over all launch item (plists) in current launch item directory
        // ->build full path it launch item and save it into array
        for(NSString* plist in directoryContents(launchItemDirectory, @"self ENDSWITH '.plist'"))
        {
            //build full path to item/plist
            // ->save it into array
            [allLaunchItems addObject:[NSString stringWithFormat:@"%@/%@", launchItemDirectory, plist]];
        }
    }
    
    //save into iVar
    self.launchItems = allLaunchItems;
    
    return;
}


/*
//generate list of all installed applications
// ->save into iVar, 'applications'
-(void)enumerateApplications
{
    //installed apps
    NSMutableArray* installedApplications = nil;
    
    //
    NSArray* systemProfilerInfo = nil;
    
    //output from
    NSString* output = nil;
    
    //alloc array for installed apps
    installedApplications = [NSMutableArray array];
    
    //exec system profiler
    output = execTask(SYSTEM_PROFILER, @[@"SPApplicationsDataType", @"-xml",  @"-detailLevel", @"mini"]);
    
    //TODO convert directly to dictionary from output
    // ->no need for file
    [output writeToFile:@"del.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    systemProfilerInfo = [NSArray arrayWithContentsOfFile:@"del.txt"];
    
    //iterate over to save all install apps
    // ->list of apps in '_items' key of array
    for(NSDictionary* installedApp in systemProfilerInfo[0][@"_items"])
    {
        //save
        // ->'path' key contains full path
        [installedApplications addObject:installedApp[@"path"]];
    }
    
    //save into iVar
    self.applications = installedApplications;
    
//bail
bail:
    
    return;
}
*/


@end

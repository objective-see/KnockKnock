//
//  QuicklookPlugins.m
//  KnockKnock
//
//  Created by Patrick Wardle on 11/09/19.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "Utilities.h"
#import "QuicklookPlugins.h"

//plugin name
#define PLUGIN_NAME @"Quicklook Plugins"

//plugin description
#define PLUGIN_DESCRIPTION @"registered quicklook bundles"

//plugin icon
#define PLUGIN_ICON @"quicklookIcon"

@implementation QuicklookPlugins

//init
// ->set name, description, etc
-(id)init
{
    //super
    self = [super init];
    if(self)
    {
        //set name
        self.name = PLUGIN_NAME;
        
        //set description
        self.description = PLUGIN_DESCRIPTION;
        
        //set icon
        self.icon = PLUGIN_ICON;
    
        //load ql framework
        // and resolve '_QLCopyServerStatistics' function
        if(YES == [[NSBundle bundleWithPath:QUICKLOOK_FRAMEWORK] load])
        {
            //resolve '_QLCopyServerStatistics'
            copyServerStats = dlsym(RTLD_NEXT, "_QLCopyServerStatistics");
        }
    }
    
    return self;
}

//scan for quicklook plugins
-(void)scan
{
    //stats (from QL server)
    NSDictionary* stats = nil;
    
    //all ql plugins
    NSDictionary* plugins = nil;
    
    //unique plugins
    // same plugin can be registered multiple times
    NSMutableSet* uniquePlugins = nil;
    
    //plugin path
    NSString* pluginPath = nil;
    
    //range
    // needed for parsing plugin paths
    NSRange range = {0};
    
    //File obj
    File* fileObj = nil;
    
    //alloc
    uniquePlugins = [NSMutableSet set];

    //get stats (plugins)
    // should return a dictionary...
    stats = copyServerStats(@[@"plugins"]);
    if(YES != [stats isKindOfClass:[NSDictionary class]])
    {
        //bail
        goto bail;
    }
    
    //process all plugins
    for(NSString* key in stats)
    {
        //get list for key
        // should be another dictionary
        plugins = stats[key];
        if(YES != [plugins isKindOfClass:[NSDictionary class]])
        {
            //skip
            continue;
        }
        
        //process each plugin
        // have to parse path a bit...
        for(NSString* name in plugins)
        {
            //extract path
            // format is path (#)
            pluginPath = plugins[name];
            
            //find offset of last " (
            range = [pluginPath rangeOfString:@" (" options:NSBackwardsSearch];
            if(NSNotFound == range.location)
            {
                //skip
                continue;
            }
            
            //grab just path part
            pluginPath = [pluginPath substringWithRange:NSMakeRange(0, range.location)];
            
            //skipping already reported plugins
            if(YES == [uniquePlugins containsObject:pluginPath])
            {
                //skip
                continue;
            }
            
            //new
            // add plugin path
            [uniquePlugins addObject:pluginPath];
            
            //create File object for plugin
            fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:pluginPath}];
            
            //skip File objects that err'd out for any reason
            if(nil == fileObj)
            {
                //skip
                continue;
            }
            
            //process item
            // save & report to UI
            [super processItem:fileObj];
        }
    }
    
bail:
    
    return;
}

@end

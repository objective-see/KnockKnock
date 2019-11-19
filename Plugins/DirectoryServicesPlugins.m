//
//  QuicklookPlugins.m
//  KnockKnock
//
//  Created by Patrick Wardle on 11/09/19.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "Utilities.h"
#import "DirectoryServicesPlugins.h"

//plugin name
#define PLUGIN_NAME @"Dir. Services Plugins"

//plugin description
#define PLUGIN_DESCRIPTION @"registered directory services bundles"

//plugin icon
#define PLUGIN_ICON @"directoryServicesIcon"

@implementation DirectoryServicesPlugins

//plugin search directories
NSString* const DIRECTORY_SERVICES_SEARCH_DIRECTORIES[] = {@"/System/Library/Frameworks/DirectoryService.framework/Versions/A/Resources/Plugins",  @"/Library/DirectoryServices/PlugIns"};

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
    }
    
    return self;
}

//scan for dir services plugins
-(void)scan
{
    //all plugins
    NSArray* allPlugins = nil;
    
    //path to plugin
    NSString* pluginPath = nil;
    
    //File obj
    File* fileObj = nil;
    
    //iterate over all auth plugin search directories
    // get all authorization plugins and process each of them
    for(NSString* pluginDirectory in expandPaths(DIRECTORY_SERVICES_SEARCH_DIRECTORIES, sizeof(DIRECTORY_SERVICES_SEARCH_DIRECTORIES)/sizeof(DIRECTORY_SERVICES_SEARCH_DIRECTORIES[0])))
    {
        //get all items in current directory
        allPlugins = directoryContents(pluginDirectory, nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* plugin in allPlugins)
        {
            //build full path to plugin
            pluginPath = [NSString stringWithFormat:@"%@/%@", pluginDirectory, plugin];
            
            //make sure plugin is a '.dsplug' bundle
            if(YES != [pluginPath hasSuffix:@".dsplug"])
            {
                //skip
                continue;
            }
        
            //create File object for plugin
            fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:pluginPath}];
            
            //skip File objects that err'd out for any reason
            if(nil == fileObj)
            {
                //skip
                continue;
            }
            
            //process item
            // ->save and report to UI
            [super processItem:fileObj];
        }
        
    }//dir services plugin directories
    
    return;
}

@end

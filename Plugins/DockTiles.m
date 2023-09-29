//
//  DockTiles.m
//  KnockKnock
//
//  More info: https://theevilbit.github.io/beyond/beyond_0032/

#import "File.h"
#import "DockTiles.h"
#import "Utilities.h"
#import "AppDelegate.h"

//plugin name
#define PLUGIN_NAME @"Dock Tiles Plugins"

//plugin description
#define PLUGIN_DESCRIPTION @"bundles hosted by a Dock XPC service"

//plugin icon
#define PLUGIN_ICON @"dockTileIcon"

//dock key (in Info.plist)
#define INFO_PLIST_DOCK_TILE_KEY @"NSDockTilePlugIn"

@implementation DockTiles

//init
// set name, description, etc
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

//scan installed applications
// looking for app plists that contain 'NSDockTilePlugIn'
-(void)scan
{
    //installed apps
    NSArray* installedApps = nil;
        
    //app's bundle
    NSBundle* appBundle = nil;
    
    //(relative) dock plugin path
    NSString* relativePath = nil;
    
    //dock plugin path
    NSString* fullPath = nil;
    
    //dock plugin
    File* fileObj = nil;
    
    //wait for shared item enumerator to complete enumeration of installed apps
    for(NSUInteger i=0; i<(10*60)*5; i++)
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab installed apps
        // will only !nil, when enumeration is complete
        installedApps = sharedItemEnumerator.applications;
        
        //exit loop once we have apps
        if(nil != installedApps)
        {
            //break
            break;
        }
        
    }//try up to 5 minutes?
    
    //iterate over all install apps
    for(NSDictionary* installedApp in installedApps)
    {
        //skip apps that don't have paths
        if(nil == installedApp[@"path"])
        {
            //skip
            continue;
        }
        
        //grab app's bundle
        appBundle = [NSBundle bundleWithPath:installedApp[@"path"]];
        if( (nil == appBundle) ||
            (nil == appBundle.infoDictionary) )
        {
            //skip
            continue;
        }
        
        //grab dock tile plugin path from 'NSDockTilePlugIn'
        // note: this path is relative (within) application's bundle
        relativePath = appBundle.infoDictionary[INFO_PLIST_DOCK_TILE_KEY];
        if(nil == relativePath)
        {
            //skip
            continue;
        }
        
        //build full path
        fullPath = [NSString pathWithComponents:@[installedApp[@"path"], @"Contents", @"PlugIns", relativePath]];
        
        //create File object from bundle
        // skip those that err out for any reason
        if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:fullPath}]))
        {
            //skip
            continue;
        }
        
        //process item
        // save & report to UI
        [super processItem:fileObj];
    }
    
bail:

    return;
}

@end

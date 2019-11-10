//
//  AuthorizationPlugins.m
//  KnockKnock
//
//  Notes: Authorization, or Authentication plugins can be used to customize logins,
//         example app (for testing, etc): http://www.rohos.com/2015/10/installing-rohos-logon-in-mac-os-10-11-el-capitan/

#import "File.h"
#import "Utilities.h"
#import "AuthorizationPlugins.h"

//plugin name
#define PLUGIN_NAME @"Authorization Plugins"

//plugin description
#define PLUGIN_DESCRIPTION @"registered authorization bundles"

//plugin icon
#define PLUGIN_ICON @"authorizationIcon"

//plugin search directories
NSString* const AUTHORIZATION_SEARCH_DIRECTORIES[] = {@"/System/Library/CoreServices/SecurityAgentPlugins", @"/Library/Security/SecurityAgentPlugins/"};


@implementation AuthorizationPlugins

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

//scan for auth plugins
-(void)scan
{
    //all auth plugins
    NSArray* allAuthPlugins = nil;
    
    //path to auth plugin
    NSString* authPluginPath = nil;
    
    //File obj
    File* fileObj = nil;
    
    //iterate over all auth plugin search directories
    // get all authorization plugins and process each of them
    for(NSString* authPluginDirectory in expandPaths(AUTHORIZATION_SEARCH_DIRECTORIES, sizeof(AUTHORIZATION_SEARCH_DIRECTORIES)/sizeof(AUTHORIZATION_SEARCH_DIRECTORIES[0])))
    {
        //get all items in current directory
        allAuthPlugins = directoryContents(authPluginDirectory, nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* authPlugin in allAuthPlugins)
        {
            //build full path to plugin
            authPluginPath = [NSString stringWithFormat:@"%@/%@", authPluginDirectory, authPlugin];
            
            //make sure plugin is a bundle
            // ->i.e. not just a random directory
            if(YES != [[NSWorkspace sharedWorkspace] isFilePackageAtPath:authPluginPath])
            {
                //skip
                continue;
            }
        
            //create File object for plugin
            fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:authPluginPath}];
            
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
        
    }//auth plugin directories
    
    return;
}

@end

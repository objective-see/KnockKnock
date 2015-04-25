//
//  AuthorizationPlugins.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "AuthorizationPlugins.h"

//plugin name
#define PLUGIN_NAME @"Authorization Plugins"

//plugin description
#define PLUGIN_DESCRIPTION @"registered custom authorization bundles"

//plugin icon
#define PLUGIN_ICON @"authorizationIcon"

//plugin search directories
NSString * const AUTHORIZATION_SEARCH_DIRECTORIES[] = {@"/System/Library/CoreServices/SecurityAgentPlugins", @"/Library/Security/SecurityAgentPlugins/"};


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

//scan for login items
-(void)scan
{
    //spotlight importer directory
    NSString* authPluginDirectory = nil;
    
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //all auth plugins
    NSArray* allAuthPlugins = nil;
    
    //path to auth plugin
    NSString* authPluginPath = nil;
    
    //directory (bundle) flag
    BOOL isDirectory = NO;
    
    //File obj
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //get number of search directories
    directoryCount = sizeof(AUTHORIZATION_SEARCH_DIRECTORIES)/sizeof(AUTHORIZATION_SEARCH_DIRECTORIES[0]);
    
    //iterate over all login item search directories
    // ->get all login items plists and process 'em
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //extract current directory
        authPluginDirectory = [AUTHORIZATION_SEARCH_DIRECTORIES[i] stringByExpandingTildeInPath];
        
        //get all items in current directory
        allAuthPlugins = directoryContents(authPluginDirectory, nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* importer in allAuthPlugins)
        {
            //build full path to importer
            authPluginPath = [NSString stringWithFormat:@"%@/%@", authPluginDirectory, importer];
            
            //get directory flag
            if(YES != [[NSFileManager defaultManager] fileExistsAtPath:authPluginPath isDirectory:&isDirectory])
            {
                //ignore errors
                continue;
            }
            
            //skip non-directories
            if(YES != isDirectory)
            {
                //skip
                continue;
            }
            
            //TODO: write helper function: isBundle
            //TODO: also call in SpotLight importers
            
            //create File object for importer
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

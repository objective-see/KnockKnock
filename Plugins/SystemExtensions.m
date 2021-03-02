//
//  Extensions.m
//  KnockKnock
//
//  Notes: view via these via System Preferences->Extensions, or pluginkit -vmA
//         only for current user, since we utilized 'pluginkit' which is "for current user"

#import "File.h"
#import "Utilities.h"
#import "SystemExtensions.h"

//plugin name
#define PLUGIN_NAME @"System Extensions"

//plugin description
#define PLUGIN_DESCRIPTION @"plugins that extend OS functionality"

//plugin icon
#define PLUGIN_ICON @"systemExtensionIcon"

//path to 'database'
#define SYSTEM_EXTENSION_DATABASE @"/Library/SystemExtensions/db.plist"

@implementation SystemExtensions

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

//get list of installed extensions
// how? parses: /Library/SystemExtensions/db.plist
-(NSMutableArray*)enumExtensions
{
    //database
    NSDictionary* database = nil;
    
    //all extensions
    NSMutableArray* extensions = nil;
    
    //alloc array for extensions
    extensions = [NSMutableArray array];
    
    //load from database
    database = [NSDictionary dictionaryWithContentsOfFile:SYSTEM_EXTENSION_DATABASE];
    
    //parse extensions
    for(NSDictionary* extension in database[@"extensions"])
    {
        //not active
        if(YES != [extension[@"state"] isEqualToString:@"activated_enabled"]) continue;
        
        //save path
        [extensions addObject:extension[@"originPath"]];
    }

    return extensions;
}

//scan for extensions
-(void)scan
{
    //File obj
    File* fileObj = nil;
    
    //enumerate all extensions
    for(NSString* extension in [self enumExtensions])
    {
        //create File object
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:extension}];
        if(nil == fileObj)
        {
            //skip
            continue;
        }
        
        //process item
        // save and report to UI
        [super processItem:fileObj];
    }
    
    return;
}

@end

//
//  SystemExtensions.m
//  KnockKnock
//
//  Notes: system extensions (network, endpoint security, drivers) from the system extensions database
//         view via 'systemextensionsctl list'

#import "File.h"
#import "utilities.h"
#import "SystemExtensions.h"

//plugin name
#define PLUGIN_NAME @"System Extensions"

//plugin description
#define PLUGIN_DESCRIPTION NSLocalizedString(@"user-mode 'drivers' extending OS functionality", @"user-mode 'drivers' extending OS functionality")

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
    // (only dictionaries, from an array)
    if(YES == [database[@"extensions"] isKindOfClass:[NSArray class]])
    {
        for(NSDictionary* extension in database[@"extensions"])
        {
            //skip non-dictionaries
            if(YES != [extension isKindOfClass:[NSDictionary class]]) continue;
            
            //not active
            if( (YES != [extension[@"state"] isKindOfClass:[NSString class]]) ||
                (YES != [extension[@"state"] isEqualToString:@"activated_enabled"]) ) continue;
            
            //skip those w/o a (string) path
            if(YES != [extension[@"originPath"] isKindOfClass:[NSString class]]) continue;
            
            //save path
            [extensions addObject:extension[@"originPath"]];
        }
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

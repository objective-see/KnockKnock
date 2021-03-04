//
//  Extensions.m
//  KnockKnock
//
//  Notes: view via these via System Preferences->Extensions, or pluginkit -vmA
//         only for current user, since we utilized 'pluginkit' which is "for current user"

#import "File.h"
#import "Utilities.h"
#import "Extensions.h"

//plugin name
#define PLUGIN_NAME @"Extensions and Widgets"

//plugin description
#define PLUGIN_DESCRIPTION @"plugins that extend/customize the OS"

//plugin icon
#define PLUGIN_ICON @"extensionIcon"

@implementation Extensions

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

//get list of installed extensions
// for now, done via exec'ing pluginkit
-(NSMutableArray*)enumExtensions
{
    //console user
    NSString* currentUser = nil;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //all extensions
    NSMutableArray* extensions = nil;
    
    //task output
    NSData* taskOutput = nil;
    
    //finder syncs (from plist)
    NSDictionary* finderSyncs = nil;
    
    //alloc array for extensions
    extensions = [NSMutableArray array];
    
    //exec 'pluginkit -vmA'
    taskOutput = execTask(PLUGIN_KIT, @[@"-vmA"]);
    if( (nil == taskOutput) ||
        (0 == taskOutput.length) )
    {
        //bail
        goto bail;
    }
    
    //process output
    [extensions addObjectsFromArray:[self parseExtensions:[[[NSString alloc] initWithData:taskOutput encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
    
    //get current/console user
    currentUser = getConsoleUser();
    
    //get their home directory
    userDirectory = NSHomeDirectoryForUser(currentUser);
    
    //sanity check(s)
    if( (0 == currentUser.length) ||
        (0 == userDirectory.length) )
    {
        //bail
        goto bail;
    }
    
    //load finder syncs from plist
    finderSyncs = [NSDictionary dictionaryWithContentsOfFile:[userDirectory stringByAppendingPathComponent:[FINDER_SYNCS substringFromIndex:1]]];
    if( (nil == finderSyncs) ||
        (nil == finderSyncs[@"displayOrder"]) )
    {
        //bail
        goto bail;
    }
    
    //process each finder sync
    // exec 'pluginkit -mi <bundle> -v' to get info
    for(NSString* finderSync in finderSyncs[@"displayOrder"])
    {
        //exec pluginkit
        taskOutput = execTask(PLUGIN_KIT, @[@"-mi", finderSync, @"-v"]);
        if( (nil == taskOutput) ||
            (0 == taskOutput.length) )
        {
            //skip
            continue;
        }
        
        //process output
        [extensions addObjectsFromArray:[self parseExtensions:[[[NSString alloc] initWithData:taskOutput encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
    }
    
    //remove any duplicates
    extensions = [[[NSSet setWithArray:extensions] allObjects] mutableCopy];
    
//bail
bail:
    
    return extensions;
    
}

//given output from plugin kit
// ->parse out all enabled extensions
-(NSMutableArray*)parseExtensions:(NSString*)output
{
    //enabled extensions
    NSMutableArray* extensions = nil;
    
    //start of path
    NSRange pathOffset = {0};
    
    //extension path
    NSString* path = nil;
    
    //alloc array for extensions
    extensions = [NSMutableArray array];
    
    //process each line
    for(NSString* line in [output componentsSeparatedByString:@"\n"])
    {
        //ignore those that aren't enabled
        // ->enabled plugins start with '+'
        if(YES != [line hasPrefix:@"+"])
        {
            //skip
            continue;
        }
        
        //find start of path
        // ->first occurance of '/'
        pathOffset = [line rangeOfString:@"/"];
        if(NSNotFound == pathOffset.location)
        {
            //skip
            continue;
        }
        
        //grab path
        path = [line substringFromIndex:pathOffset.location];
        
        //add
        [extensions addObject:path];
    }
    
//bail
bail:

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
        // ->save and report to UI
        [super processItem:fileObj];
    }
    
    return;
}

@end

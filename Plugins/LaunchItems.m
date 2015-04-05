//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "LaunchItems.h"

//plugin name
#define PLUGIN_NAME @"Launch Items"

//plugin description
#define PLUGIN_DESCRIPTION @"daemons and agents loaded by launchd"

//plugin icon
#define PLUGIN_ICON @"launchIcon"

//plugin search directories
NSString * const LAUNCHITEM_SEARCH_DIRECTORIES[] = {@"/System/Library/LaunchDaemons/", @"/Library/LaunchDaemons/", @"/System/Library/LaunchAgents/", @"/Library/LaunchAgents/", @"~/Library/LaunchAgents/"};

//(base) directory that has overrides for launch* and apps
#define OVERRIDES_DIRECTORY @"/private/var/db/launchd.db/"

@implementation LaunchItems

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
    //all launch items
    NSArray* allLaunchItems = nil;
    
    //disable items
    NSArray* disabledItems = nil;
    
    //launch item directory
    NSString* launchItemDirectory = nil;
    
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //full path to login item
    NSString* plistPath = nil;
    
    //plist data
    NSDictionary* plistContents = nil;
    
    //launch item binary
    NSString* launchItemPath = nil;
    
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //get disabled items
    disabledItems = [self getDisabledItems];

    //get number of search directories
    directoryCount = sizeof(LAUNCHITEM_SEARCH_DIRECTORIES)/sizeof(LAUNCHITEM_SEARCH_DIRECTORIES[0]);
    
    //iterate over all login item search directories
    // ->get all login items plists and process 'em
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //extract current directory
        launchItemDirectory = [LAUNCHITEM_SEARCH_DIRECTORIES[i] stringByExpandingTildeInPath];
        
        //get all login items plists in current directory
        allLaunchItems = directoryContents(launchItemDirectory, @"self ENDSWITH '.plist'");
        
        //process a plist
        // ->check if its set to auto run
        for(NSString* plist in allLaunchItems)
        {
            //build full path to plist
            plistPath = [NSString stringWithFormat:@"%@/%@", launchItemDirectory, plist];
            
            //load plist
            plistContents = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            
            //skip disabled launch items
            if(YES == [disabledItems containsObject:plistContents[@"Label"]])
            {
                //skip
                continue;
            }
            
            //skip items that aren't auto launched
            // ->neither 'RunAtLoad' *and* 'KeepAlive' is set to YES
            if( (YES != [plistContents[@"RunAtLoad"] isKindOfClass:[NSNumber class]]) ||
                (YES != [plistContents[@"RunAtLoad"] boolValue]) )
            {
                //also check 'KeepAlive'
                if( (YES != [plistContents[@"KeepAlive"] isKindOfClass:[NSNumber class]]) ||
                    (YES != [plistContents[@"KeepAlive"] boolValue]) )
                {
                    //skip
                    continue;
                }
            }
            
            //attempt to extact path to launch item
            // ->first, via 'ProgramArguments'
            if(nil != plistContents[@"ProgramArguments"])
            {
                //extract path
                launchItemPath = [plistContents[@"ProgramArguments"] firstObject];
            }
            
            //attempt to extact path to launch item
            // ->second, via 'Program'
            else if(nil != plistContents[@"Program"])
            {
                //extract path
                launchItemPath = plistContents[@"Program"];
            }
            
            //skip paths that don't exist
            if( (nil == launchItemPath) ||
                (YES != [[NSFileManager defaultManager] fileExistsAtPath:launchItemPath]))
            {
                //skip
                continue;
            }
            
            //create File object for launch item
            // ->skip those that err out for any reason
            if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:launchItemPath, KEY_RESULT_PLIST:plistPath}]))
            {
                //skip
                continue;
            }
            
            //process item
            // ->save and report to UI
            [super processItem:fileObj];
        }
    }
    
    return;
}

//get all disabled launch items
// ->specified in various overrides.plist files
-(NSArray*)getDisabledItems
{
    //disable items
    NSMutableArray* disabledItems = nil;
    
    //override directories
    NSArray* overrideDirectories = nil;
    
    //override path
    NSString* overridePath = nil;
    
    //overrides user id
    uid_t overridesUserID = 0;
    
    //override contents
    NSDictionary* overrideContents = nil;
    
    //alloc array
    disabledItems = [NSMutableArray array];
    
    //get all override directories
    overrideDirectories = directoryContents(OVERRIDES_DIRECTORY, @"self BEGINSWITH 'com.apple.launchd'");
    
    //iterate over all directories
    // ->open/parse 'overrides.plist'
    for(NSString* overrideDirectory in overrideDirectories)
    {
        //init full path
        overridePath = [NSString stringWithFormat:@"%@%@%@", OVERRIDES_DIRECTORY, overrideDirectory, @"/overrides.plist"];
        
        //skip files that don't exist/aren't accessible
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:overridePath])
        {
            //skip
            continue;
        }
        
        //extract overrides UID from its directory name
        // ->e.g. 'com.apple.launchd.peruser.501' -> 501
        overridesUserID = [[overrideDirectory pathExtension] intValue];
        
        //for override UID's over 500
        // ->ignore unless it matches current users
        if( (overridesUserID > 500) &&
            (overridesUserID != getuid()) )
        {
            //skip
            continue;
        }
        
        //load override plist
        overrideContents = [NSDictionary dictionaryWithContentsOfFile:overridePath];
        
        //iterate over all items in override plist file
        // ->save any that are disabled
        for(NSString* overrideItem in overrideContents)
        {
            //skip enabled items
            if(YES != [overrideContents[overrideItem][@"Disabled"] boolValue])
            {
                //skip
                continue;
            }
            
            //save disabled item
            [disabledItems addObject:overrideItem];
        }
    }
    
    return disabledItems;
}

@end

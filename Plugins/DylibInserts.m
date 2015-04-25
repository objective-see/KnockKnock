//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "DylibInserts.h"

//plugin name
#define PLUGIN_NAME @"Dylib Inserts"

//plugin description
#define PLUGIN_DESCRIPTION @"dynamic libraries inserted via env. vars"

//plugin icon
#define PLUGIN_ICON @"launchIcon"

//(base) directory that has overrides for launch* and apps
#define OVERRIDES_DIRECTORY @"/private/var/db/launchd.db/"

@implementation DylibInserts

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
    NSArray* launchItems = nil;
    
    //disable items
    NSArray* disabledItems = nil;
    
    //all installed applications
    NSArray* applications = nil;
    
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
    
    //wait for shared item enumerator to complete enumeration of launch items
    do
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab launch items
        // ->will only !nil, when enumeration is complete
        launchItems = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).sharedItemEnumerator.launchItems;
        
    //keep trying until we get em!
    }while(nil == launchItems);
    
    //iterate over all launch items
    // ->scan/process each
    for(NSString* launchItemPlist in launchItems)
    {
        //load launch item's plist
        plistContents = [NSDictionary dictionaryWithContentsOfFile:launchItemPlist];
        
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
        
        //skip items that don't have env var dictionary w/ 'DYLD_INSERT_LIBRARY' in it
        if( (nil == plistContents[LAUNCH_ITEM_DYLD_KEY]) ||
            (nil == plistContents[LAUNCH_ITEM_DYLD_KEY][@"DYLD_INSERT_LIBRARY"]) )
        {
            //skip
            continue;
        }
        
        //create File object for dylib inject
        // ->skip those that err out for any reason
        if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:launchItemPath, KEY_RESULT_PLIST:launchItemPlist}]))
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

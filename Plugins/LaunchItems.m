//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "LaunchItems.h"

//plugin name
#define PLUGIN_NAME @"Launch Items"

//plugin description
#define PLUGIN_DESCRIPTION @"daemons and agents loaded by launchd"

//plugin icon
#define PLUGIN_ICON @"launchIcon"

//(base) directory that has overrides for launch* and apps
#define OVERRIDES_DIRECTORY @"/private/var/db/launchd.db/"

@implementation LaunchItems

@synthesize enabledItems;
@synthesize disabledItems;


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
    
    //plist data
    NSDictionary* plistContents = nil;
    
    //launch item binary
    NSString* launchItemPath = nil;
    
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //get overriden enabled & disabled items
    [self processOverrides];
    
    //wait for shared item enumerator to complete enumeration of launch items
    do
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab launch items
        // ->will only !nil, when enumeration is complete
        launchItems = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).sharedItemEnumerator.launchItems;
        
    //keep trying until we get em!
    } while(nil == launchItems);
    
    //iterate over all launch items
    // ->scan/process each
    for(NSString* launchItemPlist in launchItems)
    {
        //reset
        launchItemPath = nil;
        
        //load plist contents
        // ->skip any that error out
        plistContents = [NSDictionary dictionaryWithContentsOfFile:launchItemPlist];
        if(nil == plistContents)
        {
            //skip
            continue;
        }
        
        //skip non-auto run items
        if(YES != [self isAutoRun:plistContents])
        {
            //skip
            continue;
        }
        
        //extact path to launch item
        // ->first, check 'Program' key
        if(nil != plistContents[@"Program"])
        {
            //extract path
            launchItemPath = plistContents[@"Program"];
        }
        
        //extact path to launch item
        // ->second, via 'ProgramArguments' (sometimes just has args)
        else if(nil != plistContents[@"ProgramArguments"])
        {
            //should (usually) be an array
            // ->extract & grab first item
            if(YES == [plistContents[@"ProgramArguments"] isKindOfClass:[NSArray class]])
            {
                //extract path
                launchItemPath = [plistContents[@"ProgramArguments"] firstObject];
            }
            
            //sometime this is a string...
            // ->just save as path (assumes no args)
            else if(YES == [plistContents[@"ProgramArguments"] isKindOfClass:[NSString class]])
            {
                //extract path
                launchItemPath = plistContents[@"ProgramArguments"];
            }
        }
        
        //skip any that don't have a path
        if(nil == launchItemPath)
        {
            //skip
            continue;
        }
        
        //create File object for launch item
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

//get all overridden enabled/disabled launch items
// ->specified in various overrides.plist files
-(void)processOverrides
{
    //override directories
    NSArray* overrideDirectories = nil;
    
    //override path
    NSString* overridePath = nil;
    
    //overrides user id
    uid_t overridesUserID = 0;
    
    //override contents
    NSDictionary* overrideContents = nil;
    
    //alloc enabled items array
    enabledItems = [NSMutableArray array];
    
    //alloc disabled items array
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
        // ->but first try to resolve via 'which()' to get long path
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:overridePath])
        {
            //try resolve
            overridePath = which(overridePath);
            if( (nil == overridePath) ||
                (YES != [[NSFileManager defaultManager] fileExistsAtPath:overridePath]))
            {
                //skip
                continue;
            }
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
            //skip items that don't have 'Disabled' key
            if(nil == overrideContents[overrideItem][@"Disabled"])
            {
                //skip
                continue;
            }
            
            //add enabled item
            if(YES == [overrideContents[overrideItem][@"Disabled"] boolValue])
            {
                //add
                [self.enabledItems addObject:overrideItem];
            }
            
            //add disabled item
            else
            {
                //add
                [self.disabledItems addObject:overrideItem];
            }
        }
    }
    
    return;
}

//checks if an item will be automatically run by the OS
-(BOOL)isAutoRun:(NSDictionary*)plistContents
{
    //flag
    BOOL isAutoRun = NO;
    
    //flag for 'RunAtLoad'
    // ->default to -1 for not found
    NSInteger runAtLoad = -1;
    
    //flag for 'KeepAlive'
    // ->default to -1 for not found
    NSInteger keepAlive = -1;
    
    //flag for 'OnDemand'
    // ->default to -1 for not found
    NSInteger onDemand = -1;
    
    //flag for start interval
    BOOL startInterval = NO;
    
    //skip launch items overriden with 'Disable'
    if(YES == [self.disabledItems containsObject:plistContents[@"Label"]])
    {
        //bail
        goto bail;
    }

    //skip directly disabled items
    // ->unless its overridden w/ enabled
    if( (YES == [plistContents[@"Disabled"] isKindOfClass:[NSNumber class]]) &&
        (YES == [plistContents[@"Disabled"] boolValue]) )
    {
        //also make sure it's not enabled via an override
        if(YES != [self.disabledItems containsObject:plistContents[@"Label"]])
        {
            //bail
            goto bail;
        }
    }
    
    //set 'RunAtLoad' flag
    if(YES == [plistContents[@"RunAtLoad"] isKindOfClass:[NSNumber class]])
    {
        //set
        runAtLoad = [plistContents[@"RunAtLoad"] boolValue];
    }
    
    //set 'KeepAlive' flag
    if(YES == [plistContents[@"KeepAlive"] isKindOfClass:[NSNumber class]])
    {
        //set
        keepAlive = [plistContents[@"KeepAlive"] boolValue];
    }
    
    //set 'OnDemand' flag
    if(YES == [plistContents[@"OnDemand"] isKindOfClass:[NSNumber class]])
    {
        //set
        onDemand = [plistContents[@"OnDemand"] boolValue];
    }
    
    //set 'StartInterval' flag
    // ->check both and 'StartInterval' and 'StartCalendarInterval'
    if( (nil != plistContents[@"StartInterval"]) ||
        (nil != plistContents[@"StartCalendarInterval"]) )
                 
    {
        //set
        startInterval = YES;
    }

    //CHECK 0x1: 'RunAtLoad' / 'KeepAlive'
    // ->either of these set to ok, means auto run!
    if( (YES == runAtLoad) ||
        (YES == keepAlive) )
    {
        //auto
        isAutoRun = YES;
    }
    
    //CHECK 0x2: 'StartInterval' / 'StartCalendarInterval'
    // ->either set, means will auto run (at some point)
    else if(YES == startInterval)
    {
        //auto
        isAutoRun = YES;
    }
    
    //when neither 'RunAtLoad' and 'KeepAlive' not found
    // ->check if 'OnDemand' is set to false (e.g. HackingTeam)
    else if( ((-1 == runAtLoad) && (-1 == keepAlive)) &&
             (NO == onDemand) )
    {
        //auto
        isAutoRun = YES;
    }
    
//bail
bail:
    
    return isAutoRun;
}

@end

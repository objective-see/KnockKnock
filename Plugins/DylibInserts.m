//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "DylibInserts.h"

/*

 # for launch agents
 # edit com.blah.blah.plist
 # <key>EnvironmentVariables</key>
 #   <dict>
 #   <key>DYLD_INSERT_LIBRARIES</key>
 #   <string>/path/to/dylib</string>
 #  </dict>
 #
 # for apps
 # <key>LSEnvironment</key>
 #   <dict>
 # 	  <key>DYLD_INSERT_LIBRARIES</key>
 #	  <string>/path/to/dylib</string>
 #	  </dict>
 # /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -v -f /Applications/ApplicationName.app
 
*/

//plugin name
#define PLUGIN_NAME @"Library Inserts"

//plugin description
#define PLUGIN_DESCRIPTION @"libs inserted by DYLD_INSERT_LIBRARIES"

//plugin icon
#define PLUGIN_ICON @"dylibIcon"

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

//scan for launch items and installed applications
// ->looking for plists that contain DYLD_INSERT_LIBRARYs
-(void)scan
{
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //scan for launch items w/ DYLD_INSERT_LIBRARIES or __XPC_DYLD_INSERT_LIBRARIES
    // ->will report any findings to UI
    [self scanLaunchItems];
    
    //scan for applications w/ DYLD_INSERT_LIBRARIES or __XPC_DYLD_INSERT_LIBRARIES
    // ->will report any findings to UI
    [self scanApplications];
    
    return;
}

//scan all launch items
// ->looks in their plists for DYLD_INSERT_LIBRARIES or __XPC_DYLD_INSERT_LIBRARIES
-(void)scanLaunchItems
{
    //all launch items
    NSArray* launchItems = nil;
    
    //disable items
    NSArray* disabledItems = nil;
    
    //plist data
    NSDictionary* plistContents = nil;
    
    //environment var dictionary
    NSDictionary* enviroVars = nil;
    
    //path to inserted dylib
    NSString* dylibPath = nil;

    //detected (auto-started) login item
    File* fileObj = nil;

    //wait for shared item enumerator to complete enumeration of launch items
    do
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab launch items
        // ->will only !nil, when enumeration is complete
        launchItems = sharedItemEnumerator.launchItems;
        
    //keep trying until we get em!
    } while(nil == launchItems);
    
    //get disabled items
    disabledItems = [self getDisabledItems];
    
    //iterate over all launch items
    // ->scan/process each
    for(NSString* launchItemPlist in launchItems)
    {
        //load launch item's plist
        plistContents = [NSDictionary dictionaryWithContentsOfFile:launchItemPlist];
        
        /*
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
        */
        
        //extact environment vars dictionary
        enviroVars = plistContents[LAUNCH_ITEM_DYLD_KEY];
        
        //skip apps that don't have env var dictionary w/ 'DYLD_INSERT_LIBRARIES' or '__XPC_DYLD_INSERT_LIBRARIES'
        if( (nil == enviroVars) ||
            (YES != [enviroVars isKindOfClass:[NSDictionary class]]) ||
            ( (nil == enviroVars[@"DYLD_INSERT_LIBRARIES"]) && (nil == enviroVars[@"__XPC_DYLD_INSERT_LIBRARIES"]) ))
        {
            //skip
            continue;
        }
        
        //grab dylib path
        // ->first attempt via 'DYLD_INSERT_LIBRARIES'
        if(nil != enviroVars[@"DYLD_INSERT_LIBRARIES"])
        {
            //grab
            dylibPath = enviroVars[@"DYLD_INSERT_LIBRARIES"];
        }
        //grab dylib path
        // ->check in '__XPC_DYLD_INSERT_LIBRARIES'
        else
        {
            //grab
            dylibPath = enviroVars[@"__XPC_DYLD_INSERT_LIBRARIES"];
        }
        
        //create File object for injected dylib
        // ->skip those that err out for any reason
        if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:dylibPath, KEY_RESULT_PLIST:launchItemPlist}]))
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

//scan all installed applications
// ->looks in their plists for DYLD_INSERT_LIBRARYs
-(void)scanApplications
{
    //installed apps
    NSArray* installedApps = nil;
    
    //app's bundle
    NSBundle* appBundle = nil;
    
    //path to app's plist
    NSURL* appPlist = nil;
    
    //environment var dictionary
    NSDictionary* enviroVars = nil;
    
    //path to inserted dylib
    NSString* dylibPath = nil;
    
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //wait for shared item enumerator to complete enumeration of installed apps
    // ->give up after 5 minutes
    for(NSUInteger i=0; i<(10*60)*5; i++)
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab installed apps
        // ->will only !nil, when enumeration is complete
        installedApps = sharedItemEnumerator.applications;
        
        //exit loop once we have apps
        if(nil != installedApps)
        {
            //break
            break;
        }
        
    }//try up to 5 minutes?
    
    //make sure installed apps were found
    // ->i.e. didn't time out
    if(nil == installedApps)
    {
        //bail
        goto bail;
    }
    
    //iterate over all install apps
    // ->scan/process each
    for(NSDictionary* installedApp in installedApps)
    {
        //skip apps that don't have paths
        if(nil == installedApp[@"path"])
        {
            //skip
            continue;
        }
        
        //try grab app's bundle
        appBundle = [NSBundle bundleWithPath:installedApp[@"path"]];
        
        //skip apps that don't have bundle/info dictionary
        if( (nil == appBundle) ||
            (nil == appBundle.infoDictionary) )
        {
            //skip
            continue;
        }
        
        //extact environment vars dictionary
        enviroVars = appBundle.infoDictionary[APPLICATION_DYLD_KEY];
        
        //skip apps that don't have env var dictionary w/ 'DYLD_INSERT_LIBRARIES' or '__XPC_DYLD_INSERT_LIBRARIES'
        if( (nil == enviroVars) ||
            (YES != [enviroVars isKindOfClass:[NSDictionary class]]) ||
            ( (nil == enviroVars[@"DYLD_INSERT_LIBRARIES"]) && (nil == enviroVars[@"__XPC_DYLD_INSERT_LIBRARIES"]) ))
        {
            //skip
            continue;
        }
        
        //get path to app's Info.plist
        appPlist = appBundle.infoDictionary[@"CFBundleInfoPlistURL"];
        
        //skip apps that this fails
        if(nil == appPlist)
        {
            //skip
            continue;
        }
        
        //grab dylib path
        // ->first attempt via 'DYLD_INSERT_LIBRARIES'
        if(nil != enviroVars[@"DYLD_INSERT_LIBRARIES"])
        {
            //grab
            dylibPath = enviroVars[@"DYLD_INSERT_LIBRARIES"];
        }
        //grab dylib path
        // ->will be in '__XPC_DYLD_INSERT_LIBRARIES'
        else
        {
            //grab
            dylibPath = enviroVars[@"__XPC_DYLD_INSERT_LIBRARIES"];
        }
        
        //create File object for injected dylib
        // ->skip those that err out for any reason
        if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:dylibPath, KEY_RESULT_PLIST:appPlist.path}]))
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:fileObj];
    }
    
//bail
bail:
    
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

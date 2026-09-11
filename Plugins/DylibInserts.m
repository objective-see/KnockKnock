//
//  DylibInserts.m
//  KnockKnock
//

#import "File.h"
#import "utilities.h"
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
#define PLUGIN_DESCRIPTION NSLocalizedString(@"libs inserted by DYLD_INSERT_LIBRARIES", @"libs inserted by DYLD_INSERT_LIBRARIES")

//plugin icon
#define PLUGIN_ICON @"dylibIcon"

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
    
    //plist data
    NSDictionary* plistContents = nil;
    
    //environment var dictionary
    NSDictionary* enviroVars = nil;
    
    //path to inserted dylib
    NSString* dylibPath = nil;

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
        
        //process each inserted dylib
        // ->'DYLD_INSERT_LIBRARIES' is a colon-separated list, and each may not resolve (e.g. @executable_path/...)
        [self processInsertedDylibs:dylibPath plist:launchItemPlist];
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
        
        //build path to app's Info.plist
        // note: not via 'CFBundleInfoPlistURL' from the info dictionary, as that key can be supplied (as any type) by the Info.plist itself
        appPlist = [appBundle.bundleURL URLByAppendingPathComponent:@"Contents/Info.plist"];
        
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
        
        //process each inserted dylib
        // ->'DYLD_INSERT_LIBRARIES' is a colon-separated list, and each may not resolve (e.g. @executable_path/...)
        [self processInsertedDylibs:dylibPath plist:appPlist.path];
    }
    
//bail
bail:
    
    return;
}

//process (the value of) a 'DYLD_INSERT_LIBRARIES' variable
// ->it's a colon-separated list, so create (and report) an item for each entry
//   entries that can't be found as files (e.g. '@executable_path/...', or missing) are skipped, as they can't be loaded
-(void)processInsertedDylibs:(id)value plist:(NSString*)plist
{
    //item
    File* item = nil;
    
    //coerce
    // (untrusted) plist values can be any type
    value = stringValue(value);
    
    //process each entry
    for(NSString* dylib in [value componentsSeparatedByString:@":"])
    {
        //skip blanks
        if(0 == dylib.length)
        {
            //skip
            continue;
        }
        
        //create File object for injected dylib
        // ->skip those that err out for any reason (e.g. not found)
        if(nil == (item = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:dylib, KEY_RESULT_PLIST:plist}]))
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:item];
    }
    
    return;
}

@end

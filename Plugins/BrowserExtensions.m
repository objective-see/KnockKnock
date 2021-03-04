//
//  BrowserExtensions.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "BrowserExtensions.h"
#import "../Results/Extension.h"

#import <Security/Security.h>

//plugin name
#define PLUGIN_NAME @"Browser Extensions"

//plugin description
#define PLUGIN_DESCRIPTION @"extensions hosted in the browser"

//plugin icon
#define PLUGIN_ICON @"browserIcon"

//plugin search directory
// ->safari
#define SAFARI_EXTENSION_DIRECTORY @"~/Library/Safari/Extensions/"

//safari's default location
#define SAFARI_DEFAULT_LOCATION @"/Applications/Safari.app"

//google chrome's base directory
#define CHROME_BASE_PROFILE_DIRECTORY @"~/Library/Application Support/Google/Chrome/"

//plugin preferences file
// ->chrome
#define CHROME_PREFERENCES_FILE @"~/Library/Application Support/Google/Chrome/Default/Preferences"

//plugin secure preferences file
// ->chrome
#define CHROME_SECURE_PREFERENCES_FILE @"~/Library/Application Support/Google/Chrome/Default/Secure Preferences"


//plugin search directory
// ->firefox
#define FIREFOX_EXTENSION_DIRECTORY @"~/Library/Application Support/Firefox/Profiles/"

//opera base directory
// ->contains preferences, extensions,e tc
#define OPERA_INFO_BASE_DIRECTORY @"~/Library/Application Support/com.operasoftware.Opera/"

@implementation BrowserExtensions

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
    //installed browsers
    NSArray* installedBrowsers = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //get all installed browsers
    installedBrowsers = [self getInstalledBrowsers];
    
    //iterate over all browsers
    // ->handle Safari, Chrome, and Firefox
    for(NSString* installedBrowser in installedBrowsers)
    {
        //scan for Safari extensions
        if(NSNotFound != [installedBrowser rangeOfString:@"Safari.app"].location)
        {
            //scan
            [self scanExtensionsSafari:installedBrowser];
        }
        
        //scan for Chrome extensions
        else if(NSNotFound != [installedBrowser rangeOfString:@"Google Chrome.app"].location)
        {
            //scan
            [self scanExtensionsChrome:installedBrowser];
        }
        
        //scan for Firefox extensions
        else if(NSNotFound != [installedBrowser rangeOfString:@"Firefox.app"].location)
        {
            //scan
            [self scanExtensionsFirefox:installedBrowser];
        }
        
        //scan for Opera extensions
        else if(NSNotFound != [installedBrowser rangeOfString:@"Opera.app"].location)
        {
            //scan
            [self scanExtensionsOpera:installedBrowser];
        }
    }

    return;
}

//get all disabled launch items
// ->specified in various overrides.plist files
-(NSArray*)getInstalledBrowsers
{
    //installed browser
    NSMutableArray* browsers = nil;
    
    //installed browser IDs
    CFArrayRef browserIDs = NULL;
    
    //browser URL
    CFURLRef browserURL = NULL;
    
    //alloc browsers array
    browsers = [NSMutableArray array];
    
    //get IDs of all installed browsers
    // ->or things that can handle HTTPS
    browserIDs = LSCopyAllHandlersForURLScheme(CFSTR("https"));
    
    //iterate of all browser IDs
    // ->resolve ID to browser path
    for(NSString* browserID in (__bridge NSArray *)browserIDs)
    {
        //resolve browser URL
        if(STATUS_SUCCESS != LSFindApplicationForInfo(kLSUnknownCreator, (__bridge CFStringRef)(browserID), NULL, NULL, &browserURL))
        {
            //skip
            continue;
        }
        
        //save browser URL
        [browsers addObject:[(__bridge NSURL *)browserURL path]];
    }
    
    //release browser IDs
    if(nil != browserIDs)
    {
        //release
        CFRelease(browserIDs);
        browserIDs = nil;
    }
    
    return browsers;
}

//scan for Safari extensions
// invokes pluginkit to enumerate extensions...
-(void)scanExtensionsSafari:(NSString*)browserPath
{
    //output from pluginkit
    NSData* taskOutput = nil;
    
    //exec pluginkit for each type
    // then invoke helper to parse/create extension objects
    for(NSString* match in @[@"com.apple.Safari.extension", @"com.apple.Safari.content-blocker"])
    {
        //enumerate via pluginkit
        taskOutput = execTask(PLUGIN_KIT, @[@"-mAvv", @"-p", match]);
        if(0 != taskOutput.length)
        {
            //parse output
            [self parseSafariExtensions:taskOutput browserPath:browserPath];
        }
    }

    return;
}

//parse the output from pluginkit
// create extension objects for any/all
-(void)parseSafariExtensions:(NSData*)extensions browserPath:(NSString*)browserPath
{
    //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //split each time
    // and parse, extracing name, path, etc...
    for(NSString* line in [[[NSString alloc] initWithData:extensions encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
    {
        //key
        NSString* key = nil;
        
        //value
        NSString* value = nil;
        
        //components
        NSArray* components = nil;
        
        //details
        NSString* details = nil;
        
        //split
        components = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@"="];
        
        //init
        if(nil == extensionInfo)
        {
            //init
            extensionInfo = [NSMutableDictionary dictionary];
            
            //save plugin
            extensionInfo[KEY_RESULT_PLUGIN] = self;
            
            //save browser path (i.e. Safari)
            extensionInfo[KEY_EXTENSION_BROWSER] = browserPath;
        }
        
        //grab key
        key = [components.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        //grab value
        value = [components.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        //name
        if(YES == [key isEqualToString:@"Display Name"])
        {
            //save
            extensionInfo[KEY_RESULT_NAME] = value;
        }
        
        //path
        else if(YES == [key isEqualToString:@"Path"])
        {
            //save
            extensionInfo[KEY_RESULT_PATH] = value;
        }
        //uuid
        else if(YES == [key isEqualToString:@"UUID"])
        {
            //save
            extensionInfo[KEY_EXTENSION_ID] = value;
        }
        
        //have all three?
        if( (nil != extensionInfo[KEY_RESULT_NAME]) &&
            (nil != extensionInfo[KEY_RESULT_PATH]) &&
            (nil != extensionInfo[KEY_EXTENSION_ID]) )
        {
            //grab details
            // found in Info.plist -> 'NSHumanReadableDescription'
            details = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", extensionInfo[KEY_RESULT_PATH]]][@"NSHumanReadableDescription"];
            if(nil != details)
            {
                //add
                extensionInfo[KEY_EXTENSION_DETAILS] = details;
            }
            
            //create extension object
            if(nil != (extensionObj = [[Extension alloc] initWithParams:extensionInfo]))
            {
                //process item
                // save and report to UI
                [super processItem:extensionObj];
            }
            
            //unset
            // ...for next
            extensionInfo = nil;
        }
    }
    
    return;
}

//scan for Chrome extensions
-(void)scanExtensionsChrome:(NSString*)browserPath
{
    //console user
    NSString* currentUser = nil;
    
    //all users
    NSMutableDictionary* users = nil;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //preference files
    NSMutableArray* preferenceFiles = nil;
    
    //profile directories
    NSArray* profiles = nil;
    
    //(current) profile directory
    NSString* profileDirectory = nil;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //extensions
    NSDictionary* extensions = nil;
    
    //current extension
    NSDictionary* extension = nil;
    
    //current extension manifest
    NSDictionary* manifest = nil;
    
    //extension path
    NSString* path = nil;
    
    //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //alloc list for preference files
    preferenceFiles = [NSMutableArray array];
    
    //alloc users dictionary
    users = [NSMutableDictionary dictionary];
    
    //root?
    // can scan all users
    if(0 == geteuid())
    {
        //all
        users = allUsers();
    }
    //just current user
    else
    {
        //get current/console user
        currentUser = getConsoleUser();
        
        //get their home directory
        userDirectory = NSHomeDirectoryForUser(currentUser);
        
        //save
        if( (0 != currentUser.length) &&
            (0 != userDirectory.length) )
        {
            //current
            users[currentUser] = @{USER_NAME:currentUser, USER_DIRECTORY:userDirectory};
        }
    }
    
    //get profile files for all users
    for(NSString* userID in users)
    {
        //add default ('Preferences')
        [preferenceFiles addObject:[users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[CHROME_PREFERENCES_FILE substringFromIndex:1]]];
        
        //add default ('Secure Preferences')
        [preferenceFiles addObject:[users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[CHROME_SECURE_PREFERENCES_FILE substringFromIndex:1]]];
        
        //get profile dirs
        // 'Profile 1', etc...
        profiles = directoryContents([users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[CHROME_BASE_PROFILE_DIRECTORY substringFromIndex:1]], @"self BEGINSWITH 'Profile'");
        
        //build and append full paths of preferences files to list
        for(NSString* profile in profiles)
        {
            //init profile directory
            profileDirectory = [users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[CHROME_BASE_PROFILE_DIRECTORY substringFromIndex:1]];
            
            //add default prefs
            [preferenceFiles addObject:[NSString stringWithFormat:@"%@/%@/Preferences", profileDirectory, profile]];
            
            //add secure prefs
            [preferenceFiles addObject:[NSString stringWithFormat:@"%@/%@/Secure Preferences", profileDirectory, profile]];
        }
    }
    
    //now process all preference files
    // load/parse/extract extensions from each file
    for(NSString* preferenceFile in preferenceFiles)
    {
        //skip non-existent preference files
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:preferenceFile])
        {
            //skip
            continue;
        }
        
        //load preferences
        // ->wrap since we are serializing JSON
        @try
        {
            //load prefs
            preferences = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:preferenceFile] options:kNilOptions error:NULL];
        }
        //skip to next, on any exceptions
        @catch(NSException *exception)
        {
            //err msg
            //NSLog(@"OBJECTIVE-SEE ERROR: converting chrome pref's to JSON threw %@", exception);
            
            //skip
            continue;
        }
        
        //extract extensions
        extensions = preferences[@"extensions"][@"settings"];
        
        //iterate over all extensions
        // ->skip disabled ones, etc
        for(NSString* key in extensions)
        {
            //alloc extension info
            extensionInfo = [NSMutableDictionary dictionary];
            
            //extract current extension
            extension = extensions[key];
            
            //skip disabled ones
            if(YES != [extension[@"state"] boolValue])
            {
                //skip
                continue;
            }
            
            //skip extensions that are installed by default
            // ->hope this is ok
            if(YES == [extension[@"was_installed_by_default"] boolValue])
            {
                //skip
                continue;
            }
            
            //skip extensions w/o paths
            if(nil == extension[@"path"])
            {
                //skip
                continue;
            }
            
            //save key as id
            extensionInfo[KEY_EXTENSION_ID] = key;
            
            //extact path
            // ->sometimes its a full path
            if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extension[@"path"]])
            {
                //extract full path
                path = extension[@"path"];
            }
            //extract path
            // ->generally have to build it
            else
            {
                //build path
                path = [NSString stringWithFormat:@"%@/Extensions/%@", [preferenceFile stringByDeletingLastPathComponent], extension[@"path"]];
                
                //skip paths that don't exist
                if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
                {
                    //skip
                    continue;
                }
            }
            
            //save path
            extensionInfo[KEY_RESULT_PATH] = path;
            
            //extract manifest
            // ->contains name, etc
            manifest = extension[@"manifest"];
            
            //skip blank names
            if(nil == manifest[@"name"])
            {
                //skip
                continue;
            }
            
            //extract/save name
            extensionInfo[KEY_RESULT_NAME] = manifest[@"name"];
            
            //save any details (description)
            if(nil != manifest[@"description"])
            {
                //save
                extensionInfo[KEY_EXTENSION_DETAILS] = manifest[@"description"];
            }
            
            //save browser path (i.e. Chrome)
            extensionInfo[KEY_EXTENSION_BROWSER] = browserPath;
            
            //save plugin
            extensionInfo[KEY_RESULT_PLUGIN] = self;
            
            //create Extension object for launch item
            // ->skip those that err out for any reason
            if(nil == (extensionObj = [[Extension alloc] initWithParams:extensionInfo]))
            {
                //skip
                continue;
            }
            
            //process item
            // ->save and report to UI
            [super processItem:extensionObj];

        }//for all extensions

    }//for all profile files
    
bail:
    
    return;
}

//scan for Firefox extensions
-(void)scanExtensionsFirefox:(NSString*)browserPath
{
    //console user
    NSString* currentUser = nil;
    
    //users
    NSMutableDictionary* users = nil;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //Firefox profiles
    NSArray* profiles = nil;

    //path to extensions
    NSString* extensionsFile = nil;
    
    //list of extension files
    NSMutableArray* extensionFiles = nil;
    
    //the extensions
    NSDictionary* extensions = nil;
    
    //list of extension IDs
    // ->prevents dupes
    NSMutableArray* extensionIDs = nil;

    //default locale
    NSDictionary* defaultLocale = nil;
    
    //extension path
    NSMutableString* path = nil;
        //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //init extension IDs array
    extensionIDs = [NSMutableArray array];
    
    //alloc users dictionary
    users = [NSMutableDictionary dictionary];
    
    //root?
    // can scan all users
    if(0 == geteuid())
    {
        //all
        users = allUsers();
    }
    //just current user
    else
    {
        //get current/console user
        currentUser = getConsoleUser();
        
        //get their home directory
        userDirectory = NSHomeDirectoryForUser(currentUser);
        
        //save
        if( (0 != currentUser.length) &&
            (0 != userDirectory.length) )
        {
            //current
            users[currentUser] = @{USER_NAME:currentUser, USER_DIRECTORY:userDirectory};
        }
    }
    
    //get profile files for all users
    for(NSString* userID in users)
    {
        //get user profiles
        profiles = directoryContents([users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[FIREFOX_EXTENSION_DIRECTORY substringFromIndex:1]], nil);
                                     
        //iterate over all addons and extensions files in profile directories
        //->extact all addons and extensions
        for(NSString* profile in profiles)
        {
            //init extension files array
            extensionFiles = [NSMutableArray array];
            
            //init extension info dictionary
            extensionInfo = [NSMutableDictionary dictionary];
            
            //init path to first extensions (addons.json) file
            extensionsFile = [NSString stringWithFormat:@"%@/%@/addons.json", [users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[FIREFOX_EXTENSION_DIRECTORY substringFromIndex:1]], profile];
            if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extensionsFile])
            {
                //save
                [extensionFiles addObject:extensionsFile];
            }
            
            //init path to second extensions (extensions.json) file
            extensionsFile = [NSString stringWithFormat:@"%@/%@/extensions.json", [users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[FIREFOX_EXTENSION_DIRECTORY substringFromIndex:1]], profile];
            if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extensionsFile])
            {
                //save
                [extensionFiles addObject:extensionsFile];
            }
            
            //process both files
            for(NSString* extensionFile in extensionFiles)
            {
                //load extensions
                // ->wrap since we are serializing JSON
                @try
                {
                    //load em
                    // ->extension files, under 'addons' key
                    extensions = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:extensionFile] options:kNilOptions error:NULL][@"addons"];
                }
                //catch any exceptions
                // ->just try next
                @catch(NSException *exception)
                {
                    //next
                    continue;
                }
                
                //parse out all extensions
                for(NSDictionary* extension in extensions)
                {
                    //ignore dups
                    if(YES == [extensionIDs containsObject:extension[@"id"]])
                    {
                        //skip
                        continue;
                    }
                    
                    //extract/save extension ID
                    extensionInfo[KEY_EXTENSION_ID] = extension[@"id"];
                    
                    //extract/save path, name, details
                    // ->case: addons.json file
                    if(YES == [[extensionFile lastPathComponent] isEqualToString:@"addons.json"])
                    {
                        //extract path
                        path = [NSMutableString stringWithFormat:@"%@/extensions/%@.xpi", [extensionFile stringByDeletingLastPathComponent], extension[@"id"]];
                        
                        //skip invalid/not found paths
                        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
                        {
                            //skip
                            continue;
                        }
                        
                        //save path
                        extensionInfo[KEY_RESULT_PATH] = path;
                        
                        //skip blank names
                        if(nil == extension[@"name"])
                        {
                            //skip
                            continue;
                        }
                        
                        //extract/save name
                        extensionInfo[KEY_RESULT_NAME] = extension[@"name"];
                        
                        //extract/save details
                        if(nil != extension[@"description"])
                        {
                            //save
                            extensionInfo[KEY_EXTENSION_DETAILS] = extension[@"description"];
                        }
                    }
                    //extract/save path, name, details
                    // ->case: extensions.json file
                    else
                    {
                        //extract path
                        path = [NSMutableString stringWithFormat:@"%@/extensions/%@", [extensionFile stringByDeletingLastPathComponent], extension[@"id"]];
                        
                        //skip invalid/not found paths
                        // ->note: also checks for extensions that end in .xpi (to account for newer versions of firefox)
                        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
                        {
                            //create .xpi version
                            [path appendString:@".xpi"];
                            
                            //check this variation too
                            if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
                            {
                                //skip
                                continue;
                            }
                        }
                        
                        //save path
                        extensionInfo[KEY_RESULT_PATH] = path;
                        
                        //extract default locale
                        defaultLocale = extension[@"defaultLocale"];
                        
                        //skip nil defaultLocales
                        if(nil == defaultLocale)
                        {
                            //skip
                            continue;
                        }
                        
                        //skip blank names
                        if(nil == defaultLocale[@"name"])
                        {
                            //skip
                            continue;
                        }
                        
                        //extract/save name
                        extensionInfo[KEY_RESULT_NAME] = defaultLocale[@"name"];
                        
                        //extract/save details
                        if(nil != defaultLocale[@"description"])
                        {
                            //save
                            extensionInfo[KEY_EXTENSION_DETAILS] = defaultLocale[@"description"];
                        }
                    }
                    
                    //save extension ID
                    // ->prevents dups (since multiple files are being parsed)
                    [extensionIDs addObject:extensionInfo[KEY_EXTENSION_ID]];
                    
                    //save browser path (i.e. Firefox)
                    extensionInfo[KEY_EXTENSION_BROWSER] = browserPath;
                    
                    //save plugin
                    extensionInfo[KEY_RESULT_PLUGIN] = self;
                    
                    //create Extension object for launch item
                    // ->skip those that err out for any reason
                    if(nil == (extensionObj = [[Extension alloc] initWithParams:extensionInfo]))
                    {
                        //skip
                        continue;
                    }
                    
                    //process item
                    // ->save and report to UI
                    [super processItem:extensionObj];
                    
                }//for all extension in file
                
            }//for all extension files
            
        }//for all profiles
        
    }//for all users

    return;
}

//scan for Opera extensions
// note: this seems identical to chrome!
//       so updates to that should go here too?
-(void)scanExtensionsOpera:(NSString*)browserPath
{
    //preferences file
    NSString* preferenceFile = nil;
    
    //extensions
    NSDictionary* extensions = nil;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //current extension
    NSDictionary* extension = nil;
    
    //current extension manifest
    NSDictionary* manifest = nil;
    
    //extension path
    NSString* path = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //build path to preferences
    preferenceFile = [NSString stringWithFormat:@"%@/Preferences", [OPERA_INFO_BASE_DIRECTORY stringByExpandingTildeInPath]];
    
    //make sure preference file exists
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:preferenceFile])
    {
        //bail
        goto bail;
    }
    
    //load preferences
    // ->wrap since we are serializing JSON
    @try
    {
        //load prefs
        preferences = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:preferenceFile] options:kNilOptions error:NULL];
    }
    //skip to next, on any exceptions
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }
    
    //extract extensions
    extensions = preferences[@"extensions"][@"settings"];
    
    //iterate over all extensions
    // ->skip disabled ones, etc
    for(NSString* key in extensions)
    {
        //alloc extension info
        extensionInfo = [NSMutableDictionary dictionary];
        
        //extract current extension
        extension = extensions[key];
        
        //skip black-listed ones
        if(YES == [extensions[@"blacklist"] boolValue])
        {
            //skip
            continue;
        }
        
        //skip disabled ones
        if(YES != [extension[@"state"] boolValue])
        {
            //skip
            continue;
        }
        
        //skip extensions that are installed by default
        // ->hope this is ok
        if(YES == [extension[@"was_installed_by_default"] boolValue])
        {
            //skip
            continue;
        }
        
        //skip extensions w/o paths
        if(nil == extension[@"path"])
        {
            //skip
            continue;
        }
        
        //save key as id
        extensionInfo[KEY_EXTENSION_ID] = key;
        
        //extact path
        // ->sometimes its a full path
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extension[@"path"]])
        {
            //extract full path
            path = extension[@"path"];
        }
        //extract path
        // ->generally have to build it
        else
        {
            //build path
            path = [NSString stringWithFormat:@"%@/Extensions/%@", [OPERA_INFO_BASE_DIRECTORY stringByExpandingTildeInPath], extension[@"path"]];
            
            //skip paths that don't exist
            if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                //skip
                continue;
            }
        }
        
        //save path
        extensionInfo[KEY_RESULT_PATH] = path;
        
        //extract manifest
        // ->contains name, etc
        manifest = extension[@"manifest"];
        
        //skip blank names
        if(nil == manifest[@"name"])
        {
            //skip
            continue;
        }
        
        //extract/save name
        extensionInfo[KEY_RESULT_NAME] = manifest[@"name"];
        
        //save any details (description)
        if(nil != manifest[@"description"])
        {
            //save
            extensionInfo[KEY_EXTENSION_DETAILS] = manifest[@"description"];
        }
        
        //save browser path (i.e. Chrome)
        extensionInfo[KEY_EXTENSION_BROWSER] = browserPath;
        
        //save plugin
        extensionInfo[KEY_RESULT_PLUGIN] = self;
        
        //create Extension object for launch item
        // ->skip those that err out for any reason
        if(nil == (extensionObj = [[Extension alloc] initWithParams:extensionInfo]))
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:extensionObj];
        
    }//for all extensions
    
bail:
    
    return;
}

@end

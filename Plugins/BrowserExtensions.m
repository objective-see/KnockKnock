//
//  LaunchItems.m
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
#define PLUGIN_DESCRIPTION @"code that is hosted and executed by the browser"

//plugin icon
#define PLUGIN_ICON @"browserIcon"

//plugin search directory
// ->safari
#define SAFARI_EXTENSION_DIRECTORY @"~/Library/Safari/Extensions/"

//name of service for safari extensions
#define SAFARI_KEYCHAIN_SERVICE "Extended Preferences"

//name account for safari extensions
#define SAFARI_KEYCHAIN_ACCOUNT "Safari"

//plugin search directory
// ->chrome
#define CHROME_EXTENSION_DIRECTORY @"~/Library/Application Support/Google/Chrome/Default/Preferences/"

//plugin search directory
// ->chrome
#define FIREFOX_EXTENSION_DIRECTORY @"~/Library/Application Support/Firefox/Profiles/"

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
    NSLog(@"%@: scanning", PLUGIN_NAME);
    
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
    
    return browsers;
}


//scan for Safari extensions
-(void)scanExtensionsSafari:(NSString*)browserPath
{
    //status
    OSStatus status = !noErr;
    
    //keychain data
    // ->binary plist of extensions
    void *keychainData = NULL;
    
    //item ref
    SecKeychainItemRef keychainItemRef = NULL;
    
    //length of keychain data
    UInt32 keychainDataLength = 0;
    
    //dictionary of extensions info
    NSDictionary* extensions = nil;
    
    //extension path
    NSString* path = nil;
    
    //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //query keychain to get safari extensions
    status = SecKeychainFindGenericPassword (NULL, (UInt32)strlen(SAFARI_KEYCHAIN_SERVICE), SAFARI_KEYCHAIN_SERVICE, (UInt32)strlen(SAFARI_KEYCHAIN_ACCOUNT), SAFARI_KEYCHAIN_ACCOUNT, &keychainDataLength, &keychainData, &keychainItemRef);
    
    //check success
    if(STATUS_SUCCESS != status)
    {
        //err msg
        NSLog(@"KNOCKKNOCK ERROR: querying keychain for Safari extensions failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //convert binary plist keychain data to NSDictionary
    extensions = [NSPropertyListSerialization propertyListWithData: [NSData dataWithBytes:keychainData length:keychainDataLength] options:0 format:NULL error:NULL];
    
    //iterate over all installed extensions
    // ->save/report enabled ones
    for(NSDictionary* extension in extensions[@"Installed Extensions"])
    {
        //dbg msg
        //NSLog(@"Safari ext: %@", extension);
        
        //alloc extension info
        extensionInfo = [NSMutableDictionary dictionary];
            
        //skip disable ones
        if(YES != [extension[@"Enabled"] boolValue])
        {
            //skip
            continue;
        }
        
        //skip extensions without paths or names
        if( (nil == extension[@"Archive File Name"]) ||
            (nil == extension[@"Bundle Directory Name"]) )
        {
            //skip
            continue;
        }
        
        //save name
        extensionInfo[KEY_RESULT_NAME] = extension[@"Bundle Directory Name"];
        
        //extract path component
        // ...and build full path
        path = [NSString stringWithFormat:@"%@/%@", [SAFARI_EXTENSION_DIRECTORY stringByExpandingTildeInPath], extension[@"Archive File Name"]];
        
        //skip extensions w/ invalid paths
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            //skip
            continue;
        }
        
        //save plugin
        extensionInfo[KEY_RESULT_PLUGIN] = self;
        
        //save path
        extensionInfo[KEY_RESULT_PATH] = path;
        
        //extract/save identifier
        extensionInfo[KEY_EXTENSION_ID] = extension[@"Bundle Identifier"];
        
        //save browser path (i.e. Safari)
        extensionInfo[KEY_EXTENSION_BROWSER] = browserPath;
        
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
    }
    
//bail
bail:
    
    //release keychain item reference
    if(NULL != keychainItemRef)
    {
        //release
        CFRelease(keychainItemRef);
    }
    
    return;
}

//scan for Chrome extensions
-(void)scanExtensionsChrome:(NSString*)browserPath
{
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
    
    //load preferences
    preferences = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[CHROME_EXTENSION_DIRECTORY stringByExpandingTildeInPath]] options:kNilOptions error:NULL];
    
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
            path = [NSString stringWithFormat:@"%@/Extensions/%@", [[CHROME_EXTENSION_DIRECTORY stringByExpandingTildeInPath] stringByDeletingLastPathComponent], extension[@"path"]];
            
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
    
    }
    
    return;
}


//scan for Firefox extensions
-(void)scanExtensionsFirefox:(NSString*)browserPath
{
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
    NSString* path = nil;
    
    //extension info
    NSMutableDictionary* extensionInfo = nil;
    
    //Extension object
    Extension* extensionObj = nil;
    
    //init extension IDs array
    extensionIDs = [NSMutableArray array];
    
    //get all profiles
    profiles = directoryContents([FIREFOX_EXTENSION_DIRECTORY stringByExpandingTildeInPath], nil);
    
    //iterate over all addons and extensions files in profile directories
    //->extact all addons and extensions
    for(NSString* profile in profiles)
    {
        //init extension files array
        extensionFiles = [NSMutableArray array];
        
        //init extension info dictionary
        extensionInfo = [NSMutableDictionary dictionary];
        
        //init path to first extensions (addons.json) file
        extensionsFile = [NSString stringWithFormat:@"%@/%@/addons.json", [FIREFOX_EXTENSION_DIRECTORY stringByExpandingTildeInPath], profile];
        
        //only add to list if it exists
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extensionsFile])
        {
            //save
            [extensionFiles addObject:extensionsFile];
        }
        
        //init path to second extensions (extensions.json) file
        extensionsFile = [NSString stringWithFormat:@"%@/%@/extensions.json", [FIREFOX_EXTENSION_DIRECTORY stringByExpandingTildeInPath], profile];
        
        //only add to list if it exists
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:extensionsFile])
        {
            //save
            [extensionFiles addObject:extensionsFile];
        }
        
        //process both files
        for(NSString* extensionFile in extensionFiles)
        {
            //load extensions
            // ->in all extension files, under 'addons' key
            extensions = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:extensionFile] options:kNilOptions error:NULL][@"addons"];
            
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
                    path = [NSString stringWithFormat:@"%@/extensions/%@.xpi", [extensionFile stringByDeletingLastPathComponent], extension[@"id"]];
                    
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
                    path = [NSString stringWithFormat:@"%@/extensions/%@", [extensionFile stringByDeletingLastPathComponent], extension[@"id"]];
                    
                    //skip invalid/not found paths
                    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
                    {
                        //skip
                        continue;
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
    
    return;
}

@end

//
//  Utilities.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

#import <fcntl.h>
#import <os/log.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <libproc.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreServices/CoreServices.h>
#import <Collaboration/Collaboration.h>
#import <SystemConfiguration/SystemConfiguration.h>

//get OS's major or minor version
SInt32 getVersion(OSType selector)
{
    //version
    // ->major or minor
    SInt32 version = -1;
    
    //get version info
    if(noErr != Gestalt(selector, &version))
    {
        //reset version
        version = -1;
        
        //err
        goto bail;
    }
    
bail:
    
    return version;
}


//console user (cached)
// resolved once (on first successful lookup), so it can't drift (fast user switching) or go nil (logout) mid-session
// ...as root, we key prefs/keychain/login item/etc. off this, so it must stay consistent
static NSString* consoleUserName = nil;
static uid_t consoleUserUID = 0;

//resolve (and cache) console user
static void resolveConsoleUser(void)
{
    //uid
    uid_t uid = 0;
    
    //user name
    CFStringRef userName = NULL;
    
    //sync
    @synchronized([NSApplication class])
    {
        //already resolved?
        if(nil != consoleUserName)
        {
            //done
            return;
        }
        
        //get console user (& uid)
        userName = SCDynamicStoreCopyConsoleUser(NULL, &uid, NULL);
        if(NULL != userName)
        {
            //cache
            consoleUserName = CFBridgingRelease(userName);
            consoleUserUID = uid;
        }
    }
    
    return;
}

//get name of logged in user
// nil if none (e.g. headless)
NSString* getConsoleUser(void)
{
    //resolve
    resolveConsoleUser();
    
    return consoleUserName;
}

//get uid of logged in user
// returns 0 (root) if there's no console user
uid_t getConsoleUserID(void)
{
    //resolve
    resolveConsoleUser();
    
    return consoleUserUID;
}

//get home directory of logged in user
// falls back to (our own) home directory
NSString* getConsoleUserHome(void)
{
    //home
    NSString* home = nil;
    
    //console user
    NSString* consoleUser = getConsoleUser();
    if(0 != consoleUser.length)
    {
        //get home
        home = NSHomeDirectoryForUser(consoleUser);
    }
    
    //fallback
    if(0 == home.length)
    {
        //ours
        home = NSHomeDirectory();
    }
    
    return home;
}

/* PREFERENCES */

//should we use the console user's preferences (vs. our own)?
// yes, when we're root and there's a (non-root) console user
static BOOL useConsoleUserPreferences(void)
{
    return ( (0 == geteuid()) && (0 != getConsoleUserID()) );
}

//registered defaults
NSDictionary* preferenceDefaults(void)
{
    return @{PREF_SHOW_TRUSTED_ITEMS:@NO, PREF_START_AT_LOGIN:@NO, PREF_DISABLE_UPDATE_CHECK:@NO, PREF_DISABLE_VT_QUERIRES:@YES};
}

//get a preference (or its registered default)
id getPreference(NSString* key)
{
    //value
    id value = nil;
    
    //root?
    // read console user's preferences
    if(YES == useConsoleUserPreferences())
    {
        //read
        value = CFBridgingRelease(CFPreferencesCopyValue((__bridge CFStringRef)key, (__bridge CFStringRef)NSBundle.mainBundle.bundleIdentifier, (__bridge CFStringRef)getConsoleUser(), kCFPreferencesAnyHost));
    }
    //normal
    else
    {
        //read
        value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    }
    
    //unset?
    // use registered default
    if(nil == value)
    {
        //default
        value = preferenceDefaults()[key];
    }
    
    return value;
}

//get a (bool) preference (or its registered default)
BOOL getPreferenceBool(NSString* key)
{
    //value
    id value = getPreference(key);
    
    //bool (or number)?
    if(YES == [value isKindOfClass:[NSNumber class]])
    {
        return [value boolValue];
    }
    
    return NO;
}

//set a preference
void setPreference(NSString* key, id value)
{
    //root?
    // write console user's preferences
    if(YES == useConsoleUserPreferences())
    {
        //write
        CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)NSBundle.mainBundle.bundleIdentifier, (__bridge CFStringRef)getConsoleUser(), kCFPreferencesAnyHost);
        
        //flush
        CFPreferencesSynchronize((__bridge CFStringRef)NSBundle.mainBundle.bundleIdentifier, (__bridge CFStringRef)getConsoleUser(), kCFPreferencesAnyHost);
    }
    //normal
    else
    {
        //write
        [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    }
    
    return;
}

//get all user
// includes name/home directory
NSMutableDictionary* allUsers(void)
{
    //users
    NSMutableDictionary* users = nil;
    
    //query
    CSIdentityQueryRef query = nil;
    
    //query results
    CFArrayRef results = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //identiry
    CBIdentity* identity = NULL;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //alloc dictionary
    users = [NSMutableDictionary dictionary];
    
    //init query
    query = CSIdentityQueryCreate(NULL, kCSIdentityClassUser, CSGetLocalIdentityAuthority());
    
    //exec query
    if(true != CSIdentityQueryExecute(query, 0, &error))
    {
        //bail
        goto bail;
    }
    
    //grab results
    results = CSIdentityQueryCopyResults(query);
    
    //process all results
    // add user and home directory
    for (int i = 0; i < CFArrayGetCount(results); ++i)
    {
        //grab identity
        identity = [CBIdentity identityWithCSIdentity:(CSIdentityRef)CFArrayGetValueAtIndex(results, i)];
        
        //skip blank users
        if(0 == identity.posixName.length) continue;
        
        //get user's home directory
        // skip any that are blank/nil
        userDirectory = NSHomeDirectoryForUser(identity.posixName);
        if(0 == userDirectory.length) continue;
        
        //add user
        users[identity.UUIDString] = @{USER_NAME:identity.posixName, USER_DIRECTORY:userDirectory};
    }

bail:
    
    //release results
    if(NULL != results)
    {
        //release
        CFRelease(results);
    }
    
    //release query
    if(NULL != query)
    {
        //release
        CFRelease(query);
    }

    return users;
}

//give a list of paths
// convert any `~` to all or current user
NSMutableArray* expandPaths(const __strong NSString* const paths[], int count)
{
    //expanded paths
    NSMutableArray* expandedPaths = nil;
    
    //(current) path
    const NSString* path = nil;
    
    //all users
    NSMutableDictionary* users = nil;
    
    //grab all users
    users = allUsers();
    
    //alloc list
    expandedPaths = [NSMutableArray array];
    
    //iterate/expand
    for(NSInteger i = 0; i < count; i++)
    {
        //grab path
        path = paths[i];
        
        //no `~`?
        // just add and continue
        if(YES != [path hasPrefix:@"~"])
        {
            //add as is
            [expandedPaths addObject:path];
            
            //next
            continue;
        }
        
        //handle '~' case
        // root? add each user
        if(0 == geteuid())
        {
            //add each user
            for(NSString* user in users)
            {
                [expandedPaths addObject:[users[user][USER_DIRECTORY] stringByAppendingPathComponent:[path substringFromIndex:1]]];
            }
        }
        //otherwise
        // just convert to current user
        else
        {
            [expandedPaths addObject:[path stringByExpandingTildeInPath]];
        }
    }
        
    return expandedPaths;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
           (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
        //scan until we get to root
        // ->of course, loop will be exited if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* icon = nil;
    
    //no bundle?
    // try find one
    if(nil == bundle)
    {
        //load bundle
        bundle = findAppBundle(binary);
    }
    
    //for app's
    // extract their icon
    if(nil != bundle)
    {
        //get file
        // coerce, as (untrusted) Info.plist values can be any type
        iconFile = stringValue(bundle.infoDictionary[@"CFBundleIconFile"]);
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process not app or couldn't get icon
    // try to get it via shared workspace...
    if( (nil == bundle) ||
        (nil == icon) )
    {
        //mach-O (executable)?
        // use the generic executable icon, as 'iconForFile' picks by file *name*
        // ...so e.g. 'com.foo.extension' would get a (blank) document icon, not the 'exec' one
        if(YES == isBinary(binary))
        {
            //via content type
            if(@available(macOS 11.0, *))
            {
                //get
                icon = [[NSWorkspace sharedWorkspace] iconForContentType:UTTypeUnixExecutable];
            }
        }
        
        //(still) no icon?
        // get via file
        if(nil == icon)
        {
            //extract icon
            icon = [[NSWorkspace sharedWorkspace] iconForFile:binary];
        }
        
        //'iconForFileType' returns small icons
        //  so set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
    }
    
    return icon;
}


//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate)
{
    //(unfiltered) directory contents
    NSArray* directoryContents = nil;
    
    //matches
    NSArray* matches = nil;
    
    //sanity check
    if(0 == [directory length])
    {
        //bail
        goto bail;
    }
    
    //get (unfiltered) directory contents
    directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    
    //filter out matches
    if(nil != predicate)
    {
        //filter
        matches = [directoryContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:predicate]];
    }
    //no need to filter
    else
    {
        //no filter
        matches = directoryContents;
    }

//bail
bail:
    
    return matches;
}

//open a regular file for reading
// returns fd, or -1 if path can't be opened, isn't a regular file (device, fifo, etc), or exceeds max size
// note: opens w/ O_NONBLOCK (so never blocks on a fifo) and checks via fstat (so no race between check & open)
int openRegularFile(NSString* path, off_t maxSize, off_t* size)
{
    //file descriptor
    int fd = -1;
    
    //file info
    struct stat fileInfo = {0};
    
    //open
    // non-blocking, so a fifo, etc. won't hang us
    fd = open(path.fileSystemRepresentation, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if(-1 == fd)
    {
        //bail
        goto bail;
    }
    
    //stat (via fd, so no race)
    // then make sure it's a regular file, that isn't too big
    if( (0 != fstat(fd, &fileInfo)) ||
        (!S_ISREG(fileInfo.st_mode)) ||
        (fileInfo.st_size > maxSize) )
    {
        //close
        close(fd);
        
        //reset
        fd = -1;
        
        //bail
        goto bail;
    }
    
    //save size
    if(NULL != size)
    {
        //save
        *size = fileInfo.st_size;
    }
    
bail:
    
    return fd;
}

//hash a file
// md5/sha1/sha256
NSDictionary* hashFile(NSString* itemPath)
{
    //file descriptor
    int fd = -1;
    
    //file hashes
    NSDictionary* hashes = nil;
    
    //flag
    BOOL isDirectory = NO;
    
    //bundle
    NSBundle* bundle = nil;
    
    //handle
    NSFileHandle* handle = nil;
    
    //path
    // might be app's binary
    NSString* path = nil;
    
    //file's contents
    // per chunk (to handle big files)
    NSData* chunk = nil;
    
    //md5 context
    CC_MD5_CTX md5Context = {0};
    
    //hash digest (md5)
    uint8_t md5Digest[CC_MD5_DIGEST_LENGTH] = {0};
    
    //md5 hash as string
    NSMutableString* md5 = nil;
    
    //sha1 context
    CC_SHA1_CTX sha1Context = {0};
    
    //hash digest (sha1)
    uint8_t sha1Digest[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha1 = nil;
    
    //sha256 context
    CC_SHA256_CTX sha256Context = {0};
    
    //hash digest (sha256)
    uint8_t sha256Digest[CC_SHA256_DIGEST_LENGTH] = {0};
    
    //sha256 hash as string
    NSMutableString* sha256 = nil;
        
    //index var
    NSUInteger index = 0;
    
    //init md5 hash string
    md5 = [NSMutableString string];
    
    //init sha1 hash string
    sha1 = [NSMutableString string];
    
    //init sha256 string
    sha256 = [NSMutableString string];
    
    //init path
    // might be updated if app bundle
    path = itemPath;
    
    //set directory flag
    [NSFileManager.defaultManager fileExistsAtPath:itemPath isDirectory:&isDirectory];
    
    //directories might be bundles
    // in that case get main binary to hash
    if(isDirectory) {
        
        //is bundle?
        if([NSWorkspace.sharedWorkspace isFilePackageAtPath:itemPath]) {
            
            //load bundle
            bundle = [NSBundle bundleWithPath:itemPath];
            
            //sanity check
            // bundle w/ executable path?
            if( (nil == bundle) ||
                (nil == bundle.executablePath) )
            {
                //bail
                goto bail;
            }
            
            //update path
            path = bundle.executablePath;
        }
        
        //not bundle
        // can't hash a directory, so bail
        else
        {
            goto bail;
        }
    }
    
    //open file
    // only regular files (no devices, fifos, etc), and not too big
    fd = openRegularFile(path, MAX_FILE_SIZE, NULL);
    if(-1 == fd)
    {
        goto bail;
    }
    
    //init handle
    // will close fd on dealloc/close
    handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    
    //init hash contexts
    CC_MD5_Init(&md5Context);
    CC_SHA1_Init(&sha1Context);
    CC_SHA256_Init(&sha256Context);
                 
    //read/hash file
    // in chunks, to handle large files
    while(YES)
    {
        //wrap
        // 'readDataOfLength' can throw
        @try
        {
            //read in chunk
            chunk = [handle readDataOfLength:1024*1024];
            if(chunk.length == 0) break;
        }
        @catch(NSException* exception)
        {
            //bail
            goto bail;
        }
        
        //hash updates
        CC_MD5_Update(&md5Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        CC_SHA1_Update(&sha1Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        CC_SHA256_Update(&sha256Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        
    }
    
    //finalize hashes
    CC_MD5_Final(md5Digest, &md5Context);
    CC_SHA1_Final(sha1Digest, &sha1Context);
    CC_SHA256_Final(sha256Digest, &sha256Context);
    
    //convert md5 to NSString
    for(index=0; index < CC_MD5_DIGEST_LENGTH; index++)
    {
        //format/append
        [md5 appendFormat:@"%02lX", (unsigned long)md5Digest[index]];
    }
    
    //convert sha1 to NSString
    for(index=0; index < CC_SHA1_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha1 appendFormat:@"%02lX", (unsigned long)sha1Digest[index]];
    }
    
    //convert sha256 to NSString
    for(index=0; index < CC_SHA256_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha256 appendFormat:@"%02lX", (unsigned long)sha256Digest[index]];
    }
    
    //init hash dictionary
    hashes = @{KEY_HASH_MD5:md5, KEY_HASH_SHA1:sha1, KEY_HASH_SHA256:sha256};
    
bail:

    //close handle?
    if(nil != handle)
    {
        //close
        [handle closeFile];
        handle = nil;
    }
    
    return hashes;
}

//get launchd's overrides (i.e. 'launchctl enable/disable' state)
// returns dictionary of label -> @YES (disabled) / @NO (explicitly enabled)
// note: when root, merges all users' overrides; when a label conflicts across users, 'enabled' wins (so item is reported)
NSDictionary* launchdOverrides(void)
{
    //overrides
    NSMutableDictionary* overrides = nil;
    
    //override files
    NSMutableArray* overrideFiles = nil;
    
    //override file contents
    NSDictionary* contents = nil;
    
    //(current) state
    NSNumber* state = nil;
    
    //alloc
    overrides = [NSMutableDictionary dictionary];
    
    //alloc
    overrideFiles = [NSMutableArray array];
    
    //system domain
    [overrideFiles addObject:@"disabled.plist"];
    
    //root?
    // add all users' (per-user domain) overrides
    if(0 == geteuid())
    {
        //add each
        for(NSString* file in directoryContents(LAUNCHD_OVERRIDES_DIRECTORY, @"self BEGINSWITH 'disabled.' AND self ENDSWITH '.plist'"))
        {
            //skip system domain (already added)
            if(YES != [file isEqualToString:@"disabled.plist"])
            {
                //add
                [overrideFiles addObject:file];
            }
        }
    }
    //not root
    // just add current user's (per-user domain) overrides
    else
    {
        //add
        [overrideFiles addObject:[NSString stringWithFormat:@"disabled.%d.plist", geteuid()]];
    }
    
    //process each override file
    for(NSString* overrideFile in overrideFiles)
    {
        //load
        // note: skips files that don't exist, aren't readable, etc.
        contents = [NSDictionary dictionaryWithContentsOfFile:[LAUNCHD_OVERRIDES_DIRECTORY stringByAppendingPathComponent:overrideFile]];
        
        //process each label
        for(NSString* label in contents)
        {
            //skip non-strings, non-bools
            if( (YES != [label isKindOfClass:[NSString class]]) ||
                (YES != [contents[label] isKindOfClass:[NSNumber class]]) )
            {
                //skip
                continue;
            }
            
            //state
            state = contents[label];
            
            //merge
            // 'enabled' (NO) wins over 'disabled' (YES), so when in doubt, item will be reported
            if( (nil == overrides[label]) ||
                (YES != [state boolValue]) )
            {
                //save
                overrides[label] = @([state boolValue]);
            }
        }
    }
    
    return overrides;
}

//coerce an (untrusted) object to a string
// strings are returned as is, nil stays nil, anything else (arrays, numbers, etc.) becomes its description
// note: plist/JSON values from user-writable files can be any type, and UI/string APIs throw on non-strings
NSString* stringValue(id object)
{
    //string
    NSString* string = nil;
    
    //nil?
    if(nil == object)
    {
        //bail
        goto bail;
    }
    
    //string?
    if(YES == [object isKindOfClass:[NSString class]])
    {
        //as is
        string = object;
    }
    //anything else
    else
    {
        //description
        string = [object description];
    }
    
bail:
    
    return string;
}

//coerce an (untrusted) object to a bool
// numbers (incl. bools) are evaluated; anything else (nil, strings, arrays, null, etc.) is NO
// note: 'boolValue' on a dictionary/array/NSNull throws, and plist/JSON values from user-writable files can be any type
BOOL boolValue(id object)
{
    return ( (YES == [object isKindOfClass:[NSNumber class]]) && (YES == [object boolValue]) );
}

//convert an object (e.g. plist) into something NSJSONSerialization can serialize
// data/dates/etc. become strings, non-finite numbers & overly nested objects become descriptions
static id makeJSONSafeAtDepth(id object, NSUInteger depth)
{
    //safe object
    id safe = nil;
    
    //max nesting
    // deeper than this? just use description
    #define MAX_JSON_DEPTH 32
    
    //nil?
    if(nil == object)
    {
        //null
        safe = [NSNull null];
    }
    
    //too deep?
    else if(depth > MAX_JSON_DEPTH)
    {
        //description
        safe = [object description];
    }
    
    //string, null
    // fine as is
    else if( (YES == [object isKindOfClass:[NSString class]]) ||
             (YES == [object isKindOfClass:[NSNull class]]) )
    {
        //as is
        safe = object;
    }
    
    //number
    // fine, unless not finite (JSON has no NaN/Inf)
    else if(YES == [object isKindOfClass:[NSNumber class]])
    {
        //finite?
        if(YES == isfinite([object doubleValue]))
        {
            //as is
            safe = object;
        }
        else
        {
            //description
            safe = [object description];
        }
    }
    
    //dictionary
    // (recursively) sanitize keys and values
    else if(YES == [object isKindOfClass:[NSDictionary class]])
    {
        //init
        safe = [NSMutableDictionary dictionary];
        
        //sanitize each
        // keys must be strings
        for(id key in object)
        {
            //add
            safe[[key isKindOfClass:[NSString class]] ? key : [key description]] = makeJSONSafeAtDepth(object[key], depth+1);
        }
    }
    
    //array/set
    // (recursively) sanitize each
    else if( (YES == [object isKindOfClass:[NSArray class]]) ||
             (YES == [object isKindOfClass:[NSSet class]]) )
    {
        //init
        safe = [NSMutableArray array];
        
        //sanitize each
        for(id item in object)
        {
            //add
            [safe addObject:makeJSONSafeAtDepth(item, depth+1)];
        }
    }
    
    //data
    // base64 encode
    else if(YES == [object isKindOfClass:[NSData class]])
    {
        //encode
        safe = [object base64EncodedStringWithOptions:0];
    }
    
    //anything else (dates, etc)
    // use description
    else
    {
        //description
        safe = [object description];
    }
    
    return safe;
}

//convert an object (e.g. plist) into something NSJSONSerialization can serialize
id makeJSONSafe(id object)
{
    return makeJSONSafeAtDepth(object, 0);
}

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void)
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url)
{
    //hyperlink
    NSMutableAttributedString *hyperlinkString = nil;
    
    //range
    NSRange range = {0};
    
    //init hyper link
    hyperlinkString = [[NSMutableAttributedString alloc] initWithString:textField.stringValue];
    
    //init range
    range = NSMakeRange(0, [hyperlinkString length]);
   
    //start editing
    [hyperlinkString beginEditing];
    
    //add url
    [hyperlinkString addAttribute:NSLinkAttributeName value:url range:range];
    
    //make it blue
    [hyperlinkString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:NSMakeRange(0, [hyperlinkString length])];
    
    //underline
    [hyperlinkString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:NSMakeRange(0, [hyperlinkString length])];
    
    //done editing
    [hyperlinkString endEditing];
    
    //set text
    [textField setAttributedStringValue:hyperlinkString];
    
    return;
}

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color)
{
    //colored string
    NSMutableAttributedString *coloredString = nil;

    //alloc/init colored string from existing one
    coloredString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    
    //set color
    [coloredString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [coloredString length])];
    
    return coloredString;
}

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments, int* exitCode)
{
    //task
    NSTask* task = nil;
    
    //output pipe
    NSPipe *outPipe = nil;
    
    //read handle
    NSFileHandle* readHandle = nil;
    
    //output
    NSMutableData* output = nil;
    
    //init
    if(NULL != exitCode)
    {
        //init
        *exitCode = -1;
    }
    
    //init task
    task = [NSTask new];
    
    //init output pipe
    outPipe = [NSPipe pipe];
    
    //init read handle
    readHandle = [outPipe fileHandleForReading];
    
    //init output buffer
    output = [NSMutableData data];
    
    //set task's path
    [task setLaunchPath:binaryPath];
    
    //set task's args
    [task setArguments:arguments];
    
    //set task's output
    [task setStandardOutput:outPipe];
    
    //ignore stderr
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    
    //wrap task launch
    // can throw exception if binary path not found, etc
    @try{
        
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }

    //read in output
    while(YES == [task isRunning])
    {
        //accumulate output
        [output appendData:[readHandle readDataToEndOfFile]];
    }
    
    //grab any left over data
    [output appendData:[readHandle readDataToEndOfFile]];
    
    //save termination status
    if(NULL != exitCode)
    {
        //save
        *exitCode = task.terminationStatus;
    }

bail:

    return output;
}


//exec a process (as the console user, when we're root) and grab it's output
// for per-user tools (e.g. pluginkit), whose output as root would be root's (empty) view
// note: uses 'launchctl asuser <uid>', which runs the tool in that user's (launchd) context
NSData* execTaskAsConsoleUser(NSString* binaryPath, NSArray* arguments, int* exitCode)
{
    //console user's uid
    uid_t consoleUID = 0;
    
    //not root?
    // just exec as is
    if(0 != geteuid())
    {
        //exec
        return execTask(binaryPath, arguments, exitCode);
    }
    
    //root
    // exec as console user (if there is one)
    consoleUID = getConsoleUserID();
    if(0 == consoleUID)
    {
        //exec (as root)
        return execTask(binaryPath, arguments, exitCode);
    }
    
    //exec as console user
    return execTask(LAUNCHCTL, [@[@"asuser", [NSString stringWithFormat:@"%u", consoleUID], binaryPath] arrayByAddingObjectsFromArray:arguments], exitCode);
}

//check if computer has network connection
BOOL isNetworkConnected(void)
{
    //flag
    BOOL isConnected = NO;
    
    //sock addr stuct
    struct sockaddr zeroAddress = {0};
    
    //reachability ref
    SCNetworkReachabilityRef reachabilityRef = NULL;
    
    //reachability flags
    SCNetworkReachabilityFlags flags = 0;
    
    //reachable flag
    BOOL isReachable = NO;
    
    //connection required flag
    BOOL connectionRequired = NO;
    
    //ensure its cleared out
    bzero(&zeroAddress, sizeof(zeroAddress));
    
    //set size
    zeroAddress.sa_len = sizeof(zeroAddress);
    
    //set family
    zeroAddress.sa_family = AF_INET;
    
    //create reachability ref
    reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)&zeroAddress);
    
    //sanity check
    if(NULL == reachabilityRef)
    {
        //bail
        goto bail;
    }
    
    //get flags
    if(TRUE != SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        //bail
        goto bail;
    }
    
    //set reachable flag
    isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
    
    //set connection required flag
    connectionRequired = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
    
    //finally
    // ->determine if network is available
    isConnected = (isReachable && !connectionRequired) ? YES : NO;
    
//bail
bail:

    //cleanup
    if(NULL != reachabilityRef)
    {
        //release
        CFRelease(reachabilityRef);
    }
    
    return isConnected;
}

//find a constraint (by name) of a view
NSLayoutConstraint* findConstraint(NSView* view, NSString* constraintName)
{
    //constraint
    NSLayoutConstraint* constraint = nil;
    
    //iterate over all view
    for(NSLayoutConstraint* currentConstraint in view.constraints)
    {
        //find item path's constraint
        if(YES == [currentConstraint.identifier isEqualToString:constraintName])
        {
            //save constraint
            constraint = currentConstraint;
            
            //bail
            break;
        }
    }
    
    return constraint;
}

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName)
{
    //full path
    NSString* fullPath = nil;
    
    //get path
    NSString* path = nil;
    
    //tokenized paths
    NSArray* pathComponents = nil;
    
    //candidate file
    NSString* candidateBinary = nil;
    
    //get path
    path = [[[NSProcessInfo processInfo]environment]objectForKey:@"PATH"];
    
    //split on ':'
    pathComponents = [path componentsSeparatedByString:@":"];
    
    //iterate over all path components
    // ->build candidate path and check if it exists
    for(NSString* pathComponent in pathComponents)
    {
        //build candidate path
        // ->current path component + process name
        candidateBinary = [pathComponent stringByAppendingPathComponent:processName];
        
        //check if it exists
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:candidateBinary])
        {
            //check its executable
            if(YES == [[NSFileManager defaultManager] isExecutableFileAtPath:candidateBinary])
            {
                //ok, happy now
                fullPath = candidateBinary;
                
                //stop processing
                break;
            }
        }
        
    }//for path components
    
    return fullPath;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* taskPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        taskPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // ->try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ->ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        // ->at start of buffer
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // ->follows # of args (int) and is NULL-terminated
        taskPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
//bail
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return taskPath;
}

//get array of running procs
// ->returns an array of process paths
NSMutableArray* runningProcesses(void)
{
    //running procs
    NSMutableArray* processes = nil;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //alloc array
    processes = [NSMutableArray array];
    
    //get # of procs
    numberOfProcesses = proc_listallpids(NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    if(proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t)) < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get name
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
           (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //add to array
        [processes addObject:processPath];
    }
    
    //remove dups
    processes = [[[NSSet setWithArray:processes] allObjects] mutableCopy];
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return processes;
}

//check if a file is a binary
BOOL isBinary(NSString* file)
{
    //architecture ref
    CFArrayRef architectures = NULL;
    
    //once
    static dispatch_once_t once;
    
    //architectures
    static NSMutableArray* supportedArchitectures = nil;
    
    //match
    NSNumber* matchedArchitecture = nil;
    
    //init architecture array
    dispatch_once(&once, ^ {
        
        //init with i386 & x6_64
        supportedArchitectures = [@[[NSNumber numberWithInt:kCFBundleExecutableArchitectureI386], [NSNumber numberWithInt:kCFBundleExecutableArchitectureX86_64]] mutableCopy];
        
        //add arm on newer
        if(@available(macOS 11, *))
        {
            [supportedArchitectures addObject:[NSNumber numberWithInt:kCFBundleExecutableArchitectureARM64]];
        }
    });
    
    //get executable arch's
    architectures = CFBundleCopyExecutableArchitecturesForURL((__bridge CFURLRef)[NSURL fileURLWithPath:file]);
    if( (NULL == architectures) ||
        (CFArrayGetCount(architectures) == 0) )
    {
        //bail
        goto bail;
    }
    
    //check for match
    matchedArchitecture = [(__bridge NSArray*)architectures firstObjectCommonWithArray:supportedArchitectures];
    
bail:
    
    //free arch ref
    if(NULL != architectures)
    {
        //free
        CFRelease(architectures);
    }
    
    return nil != matchedArchitecture;
}

//lookup object in dictionary
// note: key can be case-insensitive
id extractFromDictionary(NSDictionary* dictionary, NSString* sensitiveKey)
{
    //object
    __block id object;
    
    //look for key
    [dictionary enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
      usingBlock:^(id key, id obj, BOOL *stop)
      {
          //(case insenstive) match?
          if( (YES == [key isKindOfClass:[NSString class]]) &&
              (NSOrderedSame == [(NSString*)key caseInsensitiveCompare:sensitiveKey]) )
          {
            object = obj;
            *stop = YES;
          }
    }];
    
    return object;
}

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode(void)
{
    //flag
    BOOL darkMode = NO;
    
    //not mojave?
    // bail, since not true dark mode
    if(YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 14, 0}])
    {
        //bail
        goto bail;
    }
    
    //ask AppKit what it's actually drawing
    // note: reading 'AppleInterfaceStyle' from defaults is wrong when running as root (root's defaults, not the user's)
    if(@available(macOS 10.14, *))
    {
        //app's effective appearance
        // (in cmdline mode there's no NSApp, but then there's no UI either)
        if(nil != NSApp)
        {
            //dark?
            darkMode = [[NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
            
            //done
            goto bail;
        }
    }
    
    //fallback
    // (no NSApp, or pre-10.14) check defaults
    darkMode = [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"];
    
bail:
    
    return darkMode;
}

//adopt the console user's appearance (light/dark)
// needed when running as root (e.g. relaunched via admin auth), as root's own defaults have no appearance set
// ...so AppKit would render everything light, regardless of what the (logged in) user has selected
void adoptConsoleUserAppearance(void)
{
    //console user
    NSString* consoleUser = nil;
    
    //user's interface style
    CFPropertyListRef style = NULL;
    
    //only on 10.14+
    // (no dark mode before that)
    if(@available(macOS 10.14, *))
    {
        //get console user
        consoleUser = getConsoleUser();
        if(0 == consoleUser.length)
        {
            //bail
            goto bail;
        }
        
        //read the console user's (global) 'AppleInterfaceStyle'
        // note: root can read any user's preferences by specifying the user
        style = CFPreferencesCopyValue(CFSTR("AppleInterfaceStyle"), kCFPreferencesAnyApplication, (__bridge CFStringRef)consoleUser, kCFPreferencesAnyHost);
        
        //dark?
        if( (NULL != style) &&
            (CFGetTypeID(style) == CFStringGetTypeID()) &&
            (YES == [(__bridge NSString*)style isEqualToString:@"Dark"]) )
        {
            //set dark
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        }
        //light (key absent when light)
        else
        {
            //set light
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        }
    }
    
bail:
    
    //free
    if(NULL != style)
    {
        //free
        CFRelease(style);
    }
    
    return;
}

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location)
{
    //process serial no
    ProcessSerialNumber processSerialNo;
    
    //init process stuct
    // ->high to 0
    processSerialNo.highLongOfPSN = 0;
    
    //init process stuct
    // ->low to self
    processSerialNo.lowLongOfPSN = kCurrentProcess;
    
    //transform to foreground
    TransformProcessType(&processSerialNo, location);
    
    return;
}

//set line spacing
void setLineSpacing(NSTextField* textField, CGFloat lineSpacing)
{
    NSString *text = textField.stringValue;
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = lineSpacing;
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, attributedString.length)];
    
    textField.attributedStringValue = attributedString;
    
    return;
}

//full disk access check
// no API for this, so let's just see if we can read a (FDA-protected) TCC.db
// note: for root, that's the system's; otherwise it's the (effective) user's own
//       ...previously keyed off the console user, which fails headless (e.g. ssh) or when another user is logged in
BOOL hasFDA(void) {
    
    //tcc path
    NSString* tccPath = nil;
    
    //user's home
    NSString* userDirectory = nil;
    
    //root?
    // check system's TCC.db
    if(0 == geteuid())
    {
        //init
        tccPath = @"/Library/Application Support/com.apple.TCC/TCC.db";
    }
    //user
    // check their own TCC.db
    else
    {
        //get (effective) user's home directory
        userDirectory = NSHomeDirectory();
        if(0 == userDirectory.length)
        {
            //bail
            return NO;
        }
        
        //init
        tccPath = [userDirectory stringByAppendingPathComponent:@"Library/Application Support/com.apple.TCC/TCC.db"];
    }
    
    //FDA check
    // is 'protected' file readable
    return [NSFileManager.defaultManager isReadableFileAtPath:tccPath];
}

//for keychain access as root
// we use the (legacy) keychain APIs to target the console user's login keychain
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//get the console user's login keychain
// only when we're root; otherwise nil (so default keychain is used)
static SecKeychainRef consoleUserKeychain(void)
{
    //keychain
    SecKeychainRef keychain = NULL;
    
    //path
    NSString* path = nil;
    
    //root, with a console user?
    if( (0 == geteuid()) &&
        (0 != getConsoleUserID()) )
    {
        //build path
        path = [getConsoleUserHome() stringByAppendingPathComponent:@"Library/Keychains/login.keychain-db"];
        
        //open
        if(errSecSuccess != SecKeychainOpen(path.fileSystemRepresentation, &keychain))
        {
            //reset
            keychain = NULL;
        }
    }
    
    return keychain;
}

//save (user's) VT API key to keyhain
// note: when root, targets the console user's login keychain (not root's)
BOOL saveAPIKeyToKeychain(NSString* apiKey)
{
    OSStatus status = 0;
    NSData *apiKeyData = [apiKey dataUsingEncoding:NSUTF8StringEncoding];
    SecKeychainRef keychain = consoleUserKeychain();
    
    NSMutableDictionary *query = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: VT_API_KEYCHAIN_ATTR,
        (__bridge id)kSecAttrAccount: @"api_key",
    } mutableCopy];
    
    //root? target console user's keychain
    if(NULL != keychain) {
        query[(__bridge id)kSecMatchSearchList] = @[(__bridge id)keychain];
    }
    
    //delete old
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    //no (new) key?
    // just the delete then, we're done
    if(0 == apiKeyData.length) {
        status = errSecSuccess;
        goto bail;
    }
    
    //add new
    [query removeObjectForKey:(__bridge id)kSecMatchSearchList];
    query[(__bridge id)kSecValueData] = apiKeyData;
    if(NULL != keychain) {
        query[(__bridge id)kSecUseKeychain] = (__bridge id)keychain;
    }
    status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if(errSecSuccess != status) {
        //log
        os_log_error(OS_LOG_DEFAULT, "KnockKnock: failed to save VT API key to keychain (status: %d, root: %d)", (int)status, (0 == geteuid()));
    }
    
bail:
    
    if(NULL != keychain) {
        CFRelease(keychain);
    }
    
    return status == errSecSuccess;
}

//(re)load key from keychain
// note: when root, targets the console user's login keychain (not root's)
NSString* loadAPIKeyFromKeychain(void)
{
    NSString* key = nil;
    SecKeychainRef keychain = consoleUserKeychain();
    
    NSMutableDictionary *query = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: VT_API_KEYCHAIN_ATTR,
        (__bridge id)kSecAttrAccount: @"api_key",
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    } mutableCopy];
    
    //root? target console user's keychain
    if(NULL != keychain) {
        query[(__bridge id)kSecMatchSearchList] = @[(__bridge id)keychain];
    }
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        key = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    if(NULL != keychain) {
        CFRelease(keychain);
    }
    
    return key;
}

#pragma clang diagnostic pop

//file protected by SIP?
BOOL isRestricted(const char *path) {
    struct stat sb;
    return (stat(path, &sb) == 0) && (sb.st_flags & SF_RESTRICTED);
}

//for login item enable/disable
// we use the launch services APIs, since replacements don't always work :(
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, NSControlStateValue state)
{
    //flag
    BOOL toggled = NO;
    
    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //for priv drop/restore
    uid_t originalUID = geteuid();
    
    //running as root?
    // temporarily drop to console user, so the login item is (un)installed for them (not root)
    if(0 == originalUID) {
        
        uid_t consoleUID = getConsoleUserID();
        if( (consoleUID != 0) &&
            (0 != seteuid(consoleUID)) ) {
            
            //failed to drop
            // bail, else we'd (un)install the login item for root
            goto bail;
        }
    }
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if(!loginItemsRef) {
        goto bail;
    }
    
    //add (install)
    if(NSControlStateValueOn == state)
    {
        //add
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(loginItem), NULL, NULL);
        
        //release item ref
        if(NULL != itemRef)
        {
            //happy
            toggled = YES;
            
            //release
            CFRelease(itemRef);
            itemRef = NULL;
        }
    }
    //remove (uninstall)
    else
    {
        //happy
        // (removing is best-effort; no item to remove is also fine)
        toggled = YES;
        
        //grab existing login items
        loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
        
        //iterate over all login items
        // look for self, then remove it
        for(id item in (__bridge NSArray *)loginItems)
        {
            //get current login item
            currentLoginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, NULL);
            if(NULL == currentLoginItem)
            {
                //skip
                continue;
            }
            
            //current login item match self?
            if(YES == [(__bridge NSURL *)currentLoginItem isEqual:loginItem])
            {
                //remove
                LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item);
                
                //done
                goto bail;
            }
            
            //release
            CFRelease(currentLoginItem);
            currentLoginItem = NULL;
            
        }//all login items
        
    }//remove/uninstall
    
bail:
    
    //release login items
    if(NULL != loginItems) {
        CFRelease(loginItems);
        loginItems = NULL;
    }
    
    //release login ref
    if(NULL != loginItemsRef) {
        CFRelease(loginItemsRef);
        loginItemsRef = NULL;
    }
    
    //release url
    if(NULL != currentLoginItem) {
        CFRelease(currentLoginItem);
        currentLoginItem = NULL;
    }
    
    //restore (root) privs
    // note: can't fail for a process whose real/saved uid is root
    if( (originalUID != geteuid()) &&
        (0 != seteuid(originalUID)) ) {
        
        //log
        os_log_error(OS_LOG_DEFAULT, "KnockKnock: failed to restore euid %u (errno: %d)", originalUID, errno);
    }
    
    return toggled;
}

#pragma clang diagnostic pop

//escape a string for use in an AppleScript string literal
// only backslashes and double quotes need escaping
static NSString* escapeForAppleScript(NSString* string)
{
    return [[string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

//build AppleScript that (re)launches an executable (with arguments) as root
// via 'do shell script ... with administrator privileges'
// note: AppleScript's 'quoted form of' handles quoting (of each argument) for the shell
//       'with prompt' replaces the default "<app> wants to make changes." text in the auth dialog
NSString* authorizationScript(NSString* executablePath, NSArray<NSString*>* arguments, NSString* prompt)
{
    //command (as AppleScript expression)
    NSMutableString* command = nil;
    
    //start w/ executable
    command = [NSMutableString stringWithFormat:@"(quoted form of \"%@\")", escapeForAppleScript(executablePath)];
    
    //add each argument
    for(NSString* argument in arguments)
    {
        //add
        [command appendFormat:@" & \" \" & (quoted form of \"%@\")", escapeForAppleScript(argument)];
    }
    
    //build script
    // detach (stdin/out/err to /dev/null, background), then echo pid of (root) instance
    return [NSString stringWithFormat:@"do shell script %@ & \" </dev/null >/dev/null 2>&1 & echo $!\" with prompt \"%@\" with administrator privileges", command, escapeForAppleScript(prompt)];
}

//relaunch ourselves as root
// prompts user to authenticate, and returns pid of new (root) instance, or -1 on error
// note: must be invoked on the main thread (NSAppleScript requirement)
pid_t relaunchAsRoot(NSError** error)
{
    //pid of root instance
    pid_t pid = -1;
    
    //script error
    NSDictionary* scriptError = nil;
    
    //script result
    NSAppleEventDescriptor* result = nil;
    
    //executable (to launch as root)
    NSString* executable = nil;
    
    //arguments (for root instance)
    NSMutableArray* arguments = nil;
    
    //console user's uid
    uid_t consoleUID = getConsoleUserID();
    
    //launch (as root) *within the console user's launchd/GUI session* via 'launchctl asuser'
    // otherwise the root instance lands in the system domain, where per-user services (e.g. the pasteboard) can't be reached
    // ...so copy/paste, etc. would fail; note: 'launchctl asuser' exec's the target, so '$!' is still our (root) instance's pid
    if(0 != consoleUID)
    {
        //launchctl
        executable = LAUNCHCTL;
        
        //asuser <uid> <us> -relaunched
        arguments = [NSMutableArray arrayWithObjects:@"asuser", [NSString stringWithFormat:@"%u", consoleUID], NSBundle.mainBundle.executablePath, ARG_RELAUNCHED_AS_ROOT, nil];
    }
    //no console user (shouldn't happen for a GUI launch)
    // just launch directly
    else
    {
        //us
        executable = NSBundle.mainBundle.executablePath;
        
        //-relaunched
        arguments = [NSMutableArray arrayWithObject:ARG_RELAUNCHED_AS_ROOT];
    }
    
    //execute script
    // blocks while user is prompted to authenticate
    result = [[[NSAppleScript alloc] initWithSource:authorizationScript(executable, arguments, NSLocalizedString(@"KnockKnock needs administrator privileges to scan all persistent items.", @"KnockKnock needs administrator privileges to scan all persistent items."))] executeAndReturnError:&scriptError];
    
    //extract pid
    pid = (pid_t)[result.stringValue intValue];
    
    //error?
    // script failed (e.g. -128: user cancelled), or no (valid) pid
    if( (pid <= 0) &&
        (NULL != error) )
    {
        //init error
        // preserve AppleScript's error number
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:[scriptError[NSAppleScriptErrorNumber] integerValue] userInfo:@{NSLocalizedDescriptionKey:scriptError[NSAppleScriptErrorMessage] ?: @"unexpected result"}];
    }
    
    return (pid > 0) ? pid : -1;
}

//wait for an instance of this app (via pid) to start
// returns YES if it started within timeout, NO otherwise
BOOL waitForApplication(pid_t pid, NSTimeInterval timeout)
{
    //flag
    BOOL started = NO;
    
    //deadline
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    //wait until started, or timeout
    while(YES != started)
    {
        //look for instance (via pid)
        for(NSRunningApplication* application in [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier])
        {
            //match?
            if(pid == application.processIdentifier)
            {
                //set flag
                started = YES;
                
                //done
                break;
            }
        }
        
        //timeout?
        if(NSOrderedDescending == [NSDate.date compare:deadline])
        {
            //bail
            break;
        }
        
        //nap
        [NSThread sleepForTimeInterval:0.25];
    }
    
    return started;
}

//
//  LoginItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "LoginItems.h"

#import <ServiceManagement/ServiceManagement.h>

//plugin name
#define PLUGIN_NAME @"Login Items"

//plugin description
#define PLUGIN_DESCRIPTION @"items started when the user logs in"

//plugin icon
#define PLUGIN_ICON @"loginIcon"

//plist (old)
#define LOGIN_ITEM_PLIST_OLD @"~/Library/Preferences/com.apple.loginitems.plist"

//plist (new)
#define LOGIN_ITEM_PLIST_NEW @"~/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"

@implementation LoginItems

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
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //login items
    // both traditional and sandboxed
    NSMutableArray* loginItems = nil;

    //first get traditional items
    loginItems = [self enumTraditionalItems];
    
    //then get (and append!) sandboxed items
    [loginItems addObjectsFromArray:[self enumSandboxItems]];
    
    //remove any duplicates
    loginItems = [[[NSSet setWithArray:loginItems] allObjects] mutableCopy];

    //process all
    for(NSString* loginItem in loginItems)
    {
        //create File object for login item
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:loginItem}];
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

//enumerate traditional login items
// invoke LSSharedFileListCopySnapshot(), etc to get list of items
-(NSMutableArray*)enumTraditionalItems
{
    //(traditional) login items
    NSMutableArray* traditionalItems = nil;
    
    //shared list reference
    LSSharedFileListRef sharedListRef = NULL;
    
    //all login items
    CFArrayRef loginItems = nil;
    
    //seed
    // needed for 'LSSharedFileListCopySnapshot' function
    UInt32 snapshotSeed = 0;
    
    //login item reference
    LSSharedFileListItemRef itemRef = NULL;
    
    //item path
    CFURLRef itemPath = nil;
    
    //alloc array
    traditionalItems = [NSMutableArray array];
    
    //create shared file list reference
    sharedListRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //grab login items
    loginItems = LSSharedFileListCopySnapshot(sharedListRef, &snapshotSeed);
    
    //iterate over all items
    // extracting path for each
    for(id item in (__bridge NSArray *)loginItems)
    {
        //type-cast
        itemRef = (__bridge LSSharedFileListItemRef)item;
        
        //get path
        if(STATUS_SUCCESS != LSSharedFileListItemResolve(itemRef, 0, &itemPath, NULL))
        {
            //skip
            continue;
        }
        
        //save path of item
        [traditionalItems addObject:[(__bridge NSURL *)itemPath path]];
        
        //free path
        CFRelease(itemPath);
    }
    
    //free array
    if(NULL != loginItems)
    {
        //free
        CFRelease(loginItems);
    }
    
    return traditionalItems;
}

//extract login items from alias data
// older versions of OSX use this format...
-(NSMutableDictionary*)extractFromAlias:(NSDictionary*)data
{
    //login items
    NSMutableDictionary* loginItems = nil;
    
    //init
    loginItems = [NSMutableDictionary dictionary];
    
    //name
    NSString* name = nil;
    
    //alias
    NSData* alias = nil;
    
    //bookmark
    CFDataRef bookmark = NULL;
    
    //bookmark url
    CFURLRef url = NULL;
    
    //path
    NSString* path = nil;
    
    //extract current login items
    for(NSDictionary* loginItem in data[@"SessionItems"][@"CustomListItems"])
    {
        //extract alias
        alias = loginItem[@"Alias"];
        if(nil == alias)
        {
            //skip
            continue;
        }
        
        //create bookmark
        bookmark = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault,(__bridge CFDataRef)(alias));
        if(NULL == bookmark)
        {
            //skip
            continue;
        }
        
        //resolve bookmark data into URL
        url = CFURLCreateByResolvingBookmarkData(kCFAllocatorDefault, bookmark, kCFBookmarkResolutionWithoutUIMask, nil, nil, nil, nil);
        
        //now release bookmark
        CFRelease(bookmark);
        
        //sanity check
        if(nil == url)
        {
            //skip
            continue;
        }
        
        //extract path
        path = CFBridgingRelease(CFURLCopyPath(url));
        
        //now release url
        CFRelease(url);
        
        //sanity check
        if(nil == path)
        {
            //skip
            continue;
        }
        
        //use name from app bundle
        // otherwise from 'NSURLNameKey'
        name = [NSBundle bundleWithPath:path].infoDictionary[@"CFBundleName"];
        if(0 == name.length)
        {
            //extract name
            name = loginItem[@"Name"];
        }
        
        //sanity check
        if(nil == name)
        {
            //skip
            continue;
        }
        
        //add
        // key: path
        // value: name
        loginItems[path] = name;
    }
    
    return loginItems;
}

//extract login items from bookmark data
// newer versions of macOS use this format...
-(NSMutableDictionary*)extractFromBookmark:(NSDictionary*)data
{
    //login items
    NSMutableDictionary* loginItems = nil;
    
    //init
    loginItems = [NSMutableDictionary dictionary];
    
    //bookmark data
    NSData* bookmark = nil;
    
    //bookmark properties
    NSDictionary* properties = nil;
    
    //name
    NSString* name = nil;
    
    //path
    NSString* path = nil;
    
    //extract current login items
    for(id object in data[@"$objects"])
    {
        //reset
        bookmark = nil;
        
        //straight data?
        if(YES == [object isKindOfClass:[NSData class]])
        {
            //assign
            bookmark = object;
        }
        
        //dictionary w/ data?
        if(YES == [object isKindOfClass:[NSDictionary class]])
        {
            //extract bookmark data
            bookmark = [object objectForKey:@"NS.data"];
        }
        
        //no data?
        if(nil == bookmark)
        {
            //skip
            continue;
        }
        
        //extact properties
        // 'resourceValuesForKeys' returns a dictionary, but we want the 'NSURLBookmarkAllPropertiesKey' dictionary inside that
        properties = [NSURL resourceValuesForKeys:@[@"NSURLBookmarkAllPropertiesKey"] fromBookmarkData:bookmark][@"NSURLBookmarkAllPropertiesKey"];
        if(nil == properties)
        {
            //skip
            continue;
        }
        
        //extract path
        path = properties[@"_NSURLPathKey"];
        
        //use name from app bundle
        // otherwise from 'NSURLNameKey'
        name = [NSBundle bundleWithPath:path].infoDictionary[@"CFBundleName"];
        if(0 == name.length)
        {
            //extract name
            name = properties[@"NSURLNameKey"];
        }
        
        //skip any issues
        if( (nil == name) ||
            (nil == path) )
        {
            //skip
            continue;
        }
        
        //add
        // key: path
        // value: name
        loginItems[path] = name;
    }
    
    return loginItems;
}

//enumerate registered login items
-(NSMutableDictionary*)enumRegisteredItems
{
    //flag
    BOOL aliasFormat = NO;
    
    //plist file
    NSString* plist = nil;
    
    //plist data
    NSDictionary* plistData = nil;
    
    //users
    NSMutableDictionary* users = nil;
    
    //user name
    NSString* user = nil;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //registered items
    NSMutableDictionary* registeredItems = nil;
    
    //alloc registered login items
    registeredItems = [NSMutableDictionary dictionary];
    
    //alloc users dictionary
    users = [NSMutableDictionary dictionary];
    
    //set flag
    // pre-10.13, did not use bookmark format
    aliasFormat = ( (getVersion(gestaltSystemVersionMajor) < 11) &&
                    (getVersion(gestaltSystemVersionMinor) < 13) );
    
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
        //get console user
        user = getConsoleUser();
        
        //get console user's home directory
        userDirectory = NSHomeDirectoryForUser(getConsoleUser());
        
        //sanity check(s)
        if( (0 == user.length) ||
            (0 == userDirectory.length) )
        {
            //bail
            goto bail;
        }
        
        //current
        users[user] = @{USER_NAME:user, USER_DIRECTORY:userDirectory};
    }
    
    //process all plists
    for(NSString* userID in users)
    {
        //old format
        // use old plist/alias
        if(YES == aliasFormat)
        {
            //old plist
            plist = [users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[LOGIN_ITEM_PLIST_OLD substringFromIndex:1]];
            
            //load plist data
            plistData = [NSDictionary dictionaryWithContentsOfFile:plist];
            if(0 == plistData.count)
            {
                //skip
                continue;
            }
            
            //extract login items
            [registeredItems addEntriesFromDictionary:[self extractFromAlias:plistData]];
        }
        
        //new format?
        // use new plist/bookmark data
        else
        {
            //new plist
            plist = [users[userID][USER_DIRECTORY] stringByAppendingPathComponent:[LOGIN_ITEM_PLIST_NEW substringFromIndex:1]];
            
            //load plist data
            plistData = [NSDictionary dictionaryWithContentsOfFile:plist];
            if(0 == plistData.count)
            {
                //skip
                continue;
            }
            
            //extract login items
            [registeredItems addEntriesFromDictionary:[self extractFromBookmark:plistData]];
        }
    }
    
bail:

    return registeredItems;
}


//enumerate sandboxed (app) login items
// scan /Applications for 'Contents/Library/LoginItems/' and xref w/ those in various plists jobs
-(NSMutableArray*)enumSandboxItems
{
    //(sandbox) login items
    NSMutableArray* sandboxItems = nil;
    
    //applications
    NSArray *applications = nil;
    
    //path to (sandboxed) login item directory
    NSString* loginItemDir = nil;
    
    //registered items
    // extracted from various plists
    NSMutableDictionary* registeredItems = nil;
    
    //candidate login items
    NSArray* candidateItems = nil;
    
    //login item bundle
    NSBundle* candidateItemBundle = nil;
    
    //alloc array
    sandboxItems = [NSMutableArray array];
    
    //generate list of registered items
    registeredItems = [self enumRegisteredItems];
    
    //get all installed applications
    applications = [[NSFileManager defaultManager] directoryContentsAtPath:@"/Applications"];
    
    //iterate overall looking for 'Contents/Library/LoginItems/'
    for(NSString* application in applications)
    {
        //init path to possible (sandboxed) login item dir
        loginItemDir = [NSString stringWithFormat:@"/Applications/%@/Contents/Library/LoginItems/", application];
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:loginItemDir])
        {
            //next
            continue;
        }
        
        //get all app's login items
        // these should (each) be apps/bundles themselves
        candidateItems = [[NSFileManager defaultManager] directoryContentsAtPath:loginItemDir];
        
        //process app's candidate login items
        //   get bundle, path, and bundle id
        //   then check to make sure there is a registered item that matches!
        for(NSString* candidateItem in candidateItems)
        {
            //get bundle for candidate login item
            candidateItemBundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", loginItemDir, candidateItem]];
            if( (nil == candidateItemBundle) ||
                (nil == candidateItemBundle.executablePath) )
            {
                //next
                continue;
            }
            
            //skip if does match any registered items
            if(nil == registeredItems[candidateItemBundle.bundlePath])
            {
                //skip
                continue;
            }
            
            //save (sandboxed) login item
            [sandboxItems addObject:candidateItemBundle.bundlePath];

        }//app's login item(s)
        
    }//all apps
    
    return sandboxItems;
}

@end

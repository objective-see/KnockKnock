//
//  LaunchItems.m
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

@implementation LoginItems

@synthesize enabledJobs;

//init
// ->set name, description, etc
-(id)init
{
    //super
    self = [super init];
    if(self)
    {
        //alloc array for enabled jobs
        enabledJobs = [NSMutableArray array];
        
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
    //all jobs
    NSArray* jobs = nil;
    
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //login items
    // ->both traditional and sandboxed
    NSMutableArray* loginItems = nil;
    
    //reset enabled jobs
    [self.enabledJobs removeAllObjects];
    
    //get all jobs
    // ->includes all enabled (sandboxed) login items, even if not running :)
    jobs = (__bridge NSArray *)SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    
    //build list of enabled jobs
    // ->save their bundle IDs
    for(NSDictionary* job in jobs)
    {
        //skip non-enabled jobs or jobs w/o bundles ids
        if( (YES != [[job objectForKey:@"OnDemand"] boolValue]) ||
            (nil == [job objectForKey:@"Label"]) )
        {
            //next
            continue;
        }
        
        //save enabled job
        [enabledJobs addObject:[job objectForKey:@"Label"]];
    }
    
    //first get traditional items
    loginItems = [self enumTraditionalItems];
    
    //then get (and append!) sandboxed items
    [loginItems addObjectsFromArray:[self enumSandboxItems]];
    
    //enum and create traditional login items
    for(NSString* loginItem in loginItems)
    {
        //create File object for login item
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:loginItem}];
    
        //skip File objects that err'd out for any reason
        if(nil == fileObj)
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:fileObj];
    }
    
    //release jobs
    CFRelease((CFArrayRef)jobs);
    
    return;
}

//enumerate traditional login items
// ->basically just invoke LSSharedFileListCopySnapshot(), etc to get list of items
-(NSMutableArray*)enumTraditionalItems
{
    //(traditional) login items
    NSMutableArray* traditionalItems = nil;
    
    //shared list reference
    LSSharedFileListRef sharedListRef = NULL;
    
    //all login items
    CFArrayRef loginItems = nil;
    
    //seed
    // ->needed for 'LSSharedFileListCopySnapshot' function
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
    // ->extract path, init File obj, and report to UI
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

//enumerate sandboxed login items
// ->scan /Applications for 'Contents/Library/LoginItems/' and xref w/ launchd jobs
-(NSMutableArray*)enumSandboxItems
{
    //(sandbox) login items
    NSMutableArray* sandboxItems = nil;
    
    //applications
    NSArray *applications = nil;
    
    //path to (sandboxed) login item directory
    NSString* loginItemDir = nil;
    
    //candidate login items
    NSArray* candidateItems = nil;
    
    //login item bundle
    NSBundle* candidateItemBundle = nil;
    
    //alloc array
    sandboxItems = [NSMutableArray array];
    
    //get all installed applications
    applications = [[NSFileManager defaultManager] directoryContentsAtPath:@"/Applications"];
    
    //iterate overall looking for 'Contents/Library/LoginItems/'
    for(NSString* application in applications)
    {
        //init path to possible (sandboxed) login item dir
        loginItemDir = [NSString stringWithFormat:@"/Applications/%@/Contents/Library/LoginItems/", application];
        
        //skip if app doesn't have any login items
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:loginItemDir])
        {
            //next
            continue;
        }
        
        //get all app's login items
        // ->these should (each) be apps/bundles themselves
        candidateItems = [[NSFileManager defaultManager] directoryContentsAtPath:loginItemDir];
        
        //process app's candidate login items
        // ->get bundle, path, and bundle id
        //   then check to make sure there is a job that matches!
        for(NSString* candidateItem in candidateItems)
        {
            //get bundle for candidate login item
            candidateItemBundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", loginItemDir, candidateItem]];
            
            //skip ones that don't have bundles, binary paths, etc
            if( (nil == candidateItemBundle) ||
                (nil == candidateItemBundle.executablePath) )
            {
                //next
                continue;
            }
            
            //skip items that aren't enabled
            if(YES != [self.enabledJobs containsObject:candidateItemBundle.bundleIdentifier])
            {
                //next
                continue;
            }
            
            //save (sandboxed) login item
            [sandboxItems addObject:candidateItemBundle.executablePath];

        }//app's login item(s)
        
    }//all apps
    
    return sandboxItems;
}

@end

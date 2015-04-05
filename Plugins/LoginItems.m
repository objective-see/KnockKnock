//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "LoginItems.h"

//plugin name
#define PLUGIN_NAME @"Login Items"

//plugin description
#define PLUGIN_DESCRIPTION @"items started when the user logs in"

//plugin icon
#define PLUGIN_ICON @"loginIcon"

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
    
    //detected (auto-started) login item
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
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
        
        //create File object for login item
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:[(__bridge NSURL *)itemPath path]}];
        
        //free path
        CFRelease(itemPath);
        
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
    
    //free array
    if(NULL != loginItems)
    {
        //free
        CFRelease(loginItems);
    }
    
    return;
}

@end

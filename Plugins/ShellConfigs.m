//
//  ShellConfigs.m
//  KnockKnock
//
//  Notes: Commands in these files are automatically executed when the shell is launched

#import "File.h"
#import "utilities.h"
#import "ShellConfigs.h"

//plugin name
#define PLUGIN_NAME @"Shell Config Files"

//plugin description
#define PLUGIN_DESCRIPTION NSLocalizedString(@"Commands executed at shell launch", @"Commands executed at shell launch")

//plugin icon
#define PLUGIN_ICON @"shellConfigIcon"


@implementation ShellConfigs

//init
// set name, description, etc
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

//scan for shell config scripts
-(void)scan
{
    //user-specific shell config files
    NSArray* userShellConfigs = @[
        @".zshenv",
        @".zprofile",
        @".zshrc",
        @".zlogin",
        @".zlogout",
        @".bash_profile",
        @".bashrc",
        @".profile"
    ];
    
    //system-wide shell config files
    NSArray* systemShellConfigs = @[
        @"/etc/zshenv",
        @"/etc/zprofile",
        @"/etc/zshrc",
        @"/etc/zlogin",
        @"/etc/zlogout",
        @"/etc/bashrc",
        @"/etc/profile"
    ];
    
    //collect all existing files
    NSMutableArray *shellConfigs = [NSMutableArray array];
    
    //alloc users dictionary
    NSMutableDictionary* users = [NSMutableDictionary dictionary];
    
    //root?
    // can scan all users
    if(0 == geteuid())
    {
        //all users
        users = allUsers();
    }
    //just current user
    else
    {
        //get current/console user
        NSString *currentUser = getConsoleUser();
        
        //get their home directory
        NSString *userDirectory = NSHomeDirectoryForUser(currentUser);
        
        //save
        if((0 != currentUser.length) &&
           (0 != userDirectory.length))
        {
            //current
            users[currentUser] = @{USER_NAME:currentUser, USER_DIRECTORY:userDirectory};
        }
    }
    
    //collect user-specific files for all users
    for(NSString* userID in users)
    {
        NSString *homeDirectory = users[userID][USER_DIRECTORY];
        
        //check each user config file
        for(NSString *configFile in userShellConfigs)
        {
            NSString *fullPath = [homeDirectory stringByAppendingPathComponent:configFile];
            
            //check if exists
            if([NSFileManager.defaultManager fileExistsAtPath:fullPath])
            {
                [shellConfigs addObject:fullPath];
            }
        }
    }
    
    //collect system-wide files
    for(NSString *systemConfig in systemShellConfigs)
    {
        //check if exists
        if([NSFileManager.defaultManager fileExistsAtPath:systemConfig])
        {
            [shellConfigs addObject:systemConfig];
        }
    }
    
    //process all collected files
    for(NSString *fullPath in shellConfigs)
    {
        //create File object
        File *fileObj = [[File alloc] initWithParams:@{
            KEY_RESULT_PLUGIN:self,
            KEY_RESULT_PATH:fullPath
        }];
        
        //skip if err'd out
        if(fileObj)
        {
            [super processItem:fileObj];
        }
    }

    return;
}

@end

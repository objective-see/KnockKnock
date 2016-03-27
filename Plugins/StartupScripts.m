//
//  StartupScripts.m
//  KnockKnock
//
//  Notes: OS scripts that are exec'd as OS X boot/starts/logs such as /etc/rc.* and /etc/launchd.conf
//         normally these scripts shouldn't exist, or are whitelisted - so any deviations, just show file

#import "File.h"
#import "Utilities.h"
#import "StartupScripts.h"

//plugin name
#define PLUGIN_NAME @"Startup Scripts"

//plugin description
#define PLUGIN_DESCRIPTION @"scripts executed during OS startup"

//plugin icon
#define PLUGIN_ICON @"startupScriptsIcon"

//plugin search directories
NSString* const STARTUP_SCRIPTS_SEARCH_FILES[] = {@"/etc/rc.cleanup", @"/etc/rc.common", @"/etc/rc.installer_cleanup", @"/etc/rc.server", @"/etc/launchd.conf"};

@implementation StartupScripts

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

//scan for startup scripts
// ->any that exist are reported (though known ones are whitelisted)
-(void)scan
{
    //File obj
    File* fileObj = nil;

    //iterate over all script directories
    // ->get all script files and process them
    for(NSUInteger i=0; i<sizeof(STARTUP_SCRIPTS_SEARCH_FILES)/sizeof(STARTUP_SCRIPTS_SEARCH_FILES[0]); i++)
    {
        //create File object for each file
        // ->note these generally shouldn't exist (on default install)
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:STARTUP_SCRIPTS_SEARCH_FILES[i]}];
            
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
    
    return;
}

@end

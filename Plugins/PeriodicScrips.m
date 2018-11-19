//
//  PeriodicScripts.m
//  KnockKnock
//
//  Notes: Authorization, or Authentication plugins can be used to customize logins,
//         example app (for testing, etc): http://www.rohos.com/2015/10/installing-rohos-logon-in-mac-os-10-11-el-capitan/

#import "File.h"
#import "Utilities.h"
#import "PeriodicScrips.h"

//plugin name
#define PLUGIN_NAME @"Periodic Scripts"

//plugin description
#define PLUGIN_DESCRIPTION @"scripts that are executed periodically"

//plugin icon
#define PLUGIN_ICON @"periodicIcon"

//plugin search directories
NSString* const PERIODIC_SCRIPTS_SEARCH_DIRECTORIES[] = {@"/etc/periodic/daily", @"/etc/periodic/weekly", @"/etc/periodic/monthly"};

//periodic config file
#define PERIOD_CONFIG @"/etc/defaults/periodic.conf"

@implementation PeriodicScripts

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

//scan for periodic scripts
-(void)scan
{
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //all period scripts
    NSArray* allPeriodicScripts = nil;
    
    //path to period script
    NSString* periodScriptPathPath = nil;
    
    //File obj
    File* fileObj = nil;
    
    //get number of search directories
    directoryCount = sizeof(PERIODIC_SCRIPTS_SEARCH_DIRECTORIES)/sizeof(PERIODIC_SCRIPTS_SEARCH_DIRECTORIES[0]);
    
    //always a period script config file
    // its executed by each period script, so should be reported
    fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:PERIOD_CONFIG}];
    if(nil != fileObj)
    {
        //process item
        // ->save and report to UI
        [super processItem:fileObj];
    }
    
    //iterate over all script directories
    // get all script files and process them
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //get all items in current directory
        allPeriodicScripts = directoryContents(PERIODIC_SCRIPTS_SEARCH_DIRECTORIES[i], nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* periodicScript in allPeriodicScripts)
        {
            //build full path to script
            periodScriptPathPath = [NSString stringWithFormat:@"%@/%@", PERIODIC_SCRIPTS_SEARCH_DIRECTORIES[i], periodicScript];
            
            //create File object for script
            fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:periodScriptPathPath}];
            
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
        
    }//periodic script directories
    
    return;
}

@end

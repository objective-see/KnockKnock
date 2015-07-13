//
//  CronJobs.m
//  KnockKnock
//

#import "Command.h"
#import "Cronjobs.h"
#import "Utilities.h"


//plugin name
#define PLUGIN_NAME @"Cron Jobs"

//plugin description
#define PLUGIN_DESCRIPTION @"current users cron jobs"

//plugin icon
#define PLUGIN_ICON @"cronIcon"

@implementation CronJobs

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
    //output from crontab
    NSData* taskOutput = nil;
    
    //converted to string
    NSString* cronJobs = nil;
    
    //cron file
    // ->for now, just current user's
    NSString* cronFile = nil;
    
    //Command obj
    Command* commandObj = nil;
    
    //init cron file
    // ->for now, just path to current users & only used for path of command (not directly read, etc)
    cronFile = [NSString stringWithFormat:@"%@/%@", CRON_FILES_DIRECTORY, NSUserName()];
    
    //exec cron
    // ->just for current user
    taskOutput = execTask(CRONTAB, @[@"-l"]);
    
    //sanity check
    if(nil == taskOutput)
    {
        //bail
        goto bail;
    }
    
    //convert to (trimmed) string
    cronJobs = [[[NSString alloc] initWithData:taskOutput encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    //sanity check
    // ->skip blank results
    if( (nil == cronJobs) ||
        (0 == cronJobs.length) )
    {
        //bail
        goto bail;
    }

    //create Command obj for each
    //  ->and call back up into UI to add
    for(NSString* cronJob in [cronJobs componentsSeparatedByString:@"\n"])
    {
        //create File object for importer
        commandObj = [[Command alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_COMMAND:cronJob, KEY_RESULT_PATH:cronFile}];
        
        //skip File objects that err'd out for any reason
        if(nil == commandObj)
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:commandObj];
    }
    
//bail
bail:
    
    return;
}

@end

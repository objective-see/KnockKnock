//
//  CronJobs.m
//  KnockKnock
//
//  Created by Patrick Wardle on 7/10/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.

#import "Command.h"
#import "Cronjobs.h"
#import "utilities.h"

//plugin name
#define PLUGIN_NAME @"Cron Jobs"

//plugin description
#define PLUGIN_DESCRIPTION NSLocalizedString(@"cron jobs", @"cron jobs")

//plugin icon
#define PLUGIN_ICON @"cronIcon"

@implementation CronJobs

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

//scan for login items
-(void)scan
{
    //output from crontab
    NSData* taskOutput = nil;
    
    //cron file
    // for now, just current user's
    NSString* cronFile = nil;
    
    //root?
    // scan all user's cron jobs
    if(0 == geteuid())
    {
        //get all users
        for(NSString* user in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:CRON_FILES_DIRECTORY error:nil])
        {
            //path
            cronFile = [NSString stringWithFormat:@"%@/%@", CRON_FILES_DIRECTORY, user];
            
            //exec cron
            // pass in user
            taskOutput = execTask(CRONTAB, @[@"-l", @"-u", user], NULL);
            if( (nil == taskOutput) ||
                (0 == taskOutput.length) )
            {
                //skip
                continue;
            }
            
            //process
            [self processJobs:taskOutput path:cronFile];
        }
    }
    
    //no root
    // only scan current user's
    else
    {
        //init cron file to current user
        cronFile = [NSString stringWithFormat:@"%@/%@", CRON_FILES_DIRECTORY, NSUserName()];
        
        //exec cron
        // just for current user
        taskOutput = execTask(CRONTAB, @[@"-l"], NULL);
        if( (nil == taskOutput) ||
            (0 == taskOutput.length) )
        {
            //bail
            goto bail;
        }
        
        //process
        [self processJobs:taskOutput path:cronFile];
    }
    
bail:
    
    return;
}

//parse/process cron jobs
-(void)processJobs:(NSData*)output path:(NSString*)path
{
    //converted to string
    NSString* cronJobs = nil;
    
    //Command obj
    Command* commandObj = nil;
    
    //(trimmed) line
    NSString* line = nil;
    
    //convert to string
    cronJobs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    
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
    for(NSString* cronJob in [cronJobs componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
    {
        //trim (each) line
        // ->cron ignores leading whitespace, so must we (else '\t* * * * * evil' would be hidden)
        line = [cronJob stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        //skip lines that aren't jobs
        // ->comments, etc
        if(YES != [self isJob:line])
        {
            //skip
            continue;
        }
        
        //create Command object for job
        commandObj = [[Command alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_COMMAND:line, KEY_RESULT_PATH:path}];
        
        //skip Command objects that err'd out for any reason
        if(nil == commandObj)
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:commandObj];
    }
    
bail:
    
    return;
}

//determines if a line is really a cronjob (or an environment assignment)
// ->jobs start with a digit, '*', or '@'
// ->environment assignments ('NAME=value') are also reported, as e.g. 'SHELL=/path/to/evil' means every job runs the attacker's binary
-(BOOL)isJob:(NSString*)possibleJob
{
    //flag
    BOOL isValidJob = NO;
    
    //regex for environment assignments
    static NSRegularExpression* assignment = nil;
    
    //once
    static dispatch_once_t onceToken = 0;
    
    //init regex
    dispatch_once(&onceToken, ^{
        
        //init
        // 'NAME = value' (cron allows whitespace around '=')
        assignment = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z_][A-Za-z0-9_]*\\s*=" options:0 error:nil];
    });
    
    //make sure length is decent
    if(0 == possibleJob.length)
    {
        //bail
        goto bail;
    }
    
    //job?
    // ->starts with a number, '*', or '@'
    if( (YES == isnumber([possibleJob characterAtIndex:0])) ||
        (YES == [possibleJob hasPrefix:@"*"]) ||
        (YES == [possibleJob hasPrefix:@"@"]) )
    {
        //happy
        isValidJob = YES;
        
        //done
        goto bail;
    }
    
    //environment assignment?
    // ->e.g. 'SHELL=/bin/sh', 'PATH=...'
    if(0 != [assignment numberOfMatchesInString:possibleJob options:0 range:NSMakeRange(0, possibleJob.length)])
    {
        //happy
        isValidJob = YES;
        
        //done
        goto bail;
    }
    
//bail
bail:
    
    return isValidJob;
}

@end

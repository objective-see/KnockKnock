//
//  CronJobs.m
//  KnockKnock
//
//  Created by Patrick Wardle on 7/18/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.

#import "File.h"
#import "Command.h"
#import "Utilities.h"
#import "LogInOutHooks.h"

//for some details/examples:
// -> http://apple.stackexchange.com/questions/16825/make-a-script-app-run-on-logout


//plugin name
#define PLUGIN_NAME @"Login/Logout Hooks"

//plugin description
#define PLUGIN_DESCRIPTION @"items executed upon login or logout"

//plugin icon
#define PLUGIN_ICON @"logInOutIcon"

//plugin search directories
NSString* const HOOK_SEARCH_FILES[] = {@"/Library/Preferences/com.apple.loginwindow.plist", @"~/Library/Preferences/com.apple.loginwindow.plist"};

@implementation LogInOutHooks

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
    //number of search directories
    NSUInteger fileCount = 0;
    
    //login window plist
    NSString* loginWindowPlist = nil;
    
    //plist data
    NSDictionary* plistContents = nil;
    
    //get number of login/out files
    fileCount = sizeof(HOOK_SEARCH_FILES)/sizeof(HOOK_SEARCH_FILES[0]);
    
    //iterate over all login/out file
    // ->get all hooks and process em
    for(NSUInteger i=0; i < fileCount; i++)
    {
        //extract current file
        loginWindowPlist = [HOOK_SEARCH_FILES[i] stringByExpandingTildeInPath];
        
        //load plist contents
        plistContents = [NSDictionary dictionaryWithContentsOfFile:loginWindowPlist];
        
        //process login hook
        if(nil != plistContents[@"LoginHook"])
        {
            //process
            [self processHook:plistContents[@"LoginHook"] parentFile:loginWindowPlist];
        }
        
        //process logout hook
        if(nil != plistContents[@"LogoutHook"])
        {
            //process
            [self processHook:plistContents[@"LogoutHook"] parentFile:loginWindowPlist];
        }
    }
    
//bail
bail:
    
    return;
}

//create a File or Command obj
// ->then save & report to UI
-(void)processHook:(NSString*)payload parentFile:(NSString*)parentFile
{
    //File or Command Obj
    ItemBase* item = nil;
    
    //hook payload will usually will be a file
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:payload])
    {
        //create File object for hook
        item = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:payload, KEY_RESULT_PLIST:parentFile}];
    }
    //otherwise
    // ->likely a command
    else
    {
        //create Command object for hook
        item = [[Command alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_COMMAND:payload, KEY_RESULT_PATH:parentFile}];
    }
    
    //ignore items w/ errors
    if(nil == item)
    {
        //ignore
        goto bail;
    }
    
    //save and report to UI
    [super processItem:item];
    
//bail
bail:
    
    return;
}

@end

//
//  EventRules.m
//  KnockKnock
//
//  Created by Patrick Wardle on 03/25/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Command.h"
#import "Utilities.h"
#import "EventRules.h"

//plugin name
#define PLUGIN_NAME @"Event Rules"

//plugin description
#define PLUGIN_DESCRIPTION @"actions executed by emond"

//plugin icon
#define PLUGIN_ICON @"eventRulesIcon"

//default rule directory
#define DEFAULT_EMOND_RULES @"/etc/emond.d/rules/"

//config file
#define EMOND_CONFIG @"/etc/emond.d/emond.plist"

@implementation EventRules

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

//scan for emond commands
-(void)scan
{
    //rules directories
    NSMutableArray* rulesDirectories = nil;
    
    //rule plists
    NSArray* ruleFiles = nil;
    
    //config
    NSDictionary* config = nil;
    
    //additional rule directories
    NSMutableArray* additionalRuleDirs = nil;
    
    //commands
    NSMutableArray* commands = nil;
    
    //Command obj
    Command* commandObj = nil;
    
    //alloc
    rulesDirectories = [NSMutableArray array];
    
    //load config
    config = [NSDictionary dictionaryWithContentsOfFile:EMOND_CONFIG][@"config"];
    if(nil != config)
    {
        //grab additional rules
        additionalRuleDirs = config[@"additionalRulesPaths"];
    }
    
    //add default
    [rulesDirectories addObject:DEFAULT_EMOND_RULES];
    
    //add any additional
    for(NSString* additionalRuleDir in additionalRuleDirs)
    {
        //add
        [rulesDirectories addObject:additionalRuleDir];
    }
    
    //process each rule directory
    for(NSString* ruleDirectory in rulesDirectories)
    {
        //get rule (plist) files
        ruleFiles = directoryContents(ruleDirectory, nil);
        
        //get commands for each rule file
        for(NSString* ruleFile in ruleFiles)
        {
            //get commands
            commands = [self extractCommands:[ruleDirectory stringByAppendingPathComponent:ruleFile]];
            
            //process all commands
            for(NSString* command in commands)
            {
                //create Command object for job
                commandObj = [[Command alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_COMMAND:command, KEY_RESULT_PATH:[ruleDirectory stringByAppendingPathComponent:ruleFile]}];
                if(nil == commandObj)
                {
                    //skip
                    continue;
                }
                
                //process item
                // save and report to UI
                [super processItem:commandObj];
            }
        }
    }
    
    return;
}

//extract commands from a rule file
-(NSMutableArray*)extractCommands:(NSString*)ruleFile
{
    //plist contents
    NSMutableArray* rules = nil;
    
    //commands
    NSMutableArray* commands = nil;
    
    //actions
    NSArray* actions = nil;
    
    //alloc
    commands = [NSMutableArray array];
    
    //load rule file
    rules = [NSMutableArray arrayWithContentsOfFile:ruleFile];
    if(nil == rules)
    {
        //bail
        goto bail;
    }
    
    //process all rules
    for(NSDictionary* rule in rules)
    {
        actions = rule[@"actions"];
        if( (nil == actions) ||
            (YES != [actions isKindOfClass:[NSArray class]]) )
        {
            //skip
            continue;
        }
        
        //process all actions
        for(NSDictionary* action in actions)
        {
            if(nil == action[@"command"])
            {
                //skip
                continue;
            }
            
            //add
            [commands addObject:action[@"command"]];
        }
    }
    
bail:
    
    return commands;
}
@end

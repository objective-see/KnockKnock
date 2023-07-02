//
//  BTM.m
//  KnockKnock
//
//  Created by Patrick Wardle on 6/26/23.
//  Copyright (c) 2023 Objective-See. All rights reserved.

#import "BTM.h"
#import "File.h"
#import "dumpBTM.h"
#import "Utilities.h"

//plugin name
#define PLUGIN_NAME @"Background Managed Tasks"

//plugin description
#define PLUGIN_DESCRIPTION @"agents, daemons, & login items managed by BTM"

//plugin icon
#define PLUGIN_ICON @"btmIcon"

@implementation BTM

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

//scan for btm items
-(void)scan
{
    //only available on macOS 13+
    if(@available(macOS 13, *))
    {
        //contents
        NSDictionary* contents = nil;
        
        //items
        NSMutableDictionary* items = nil;
        
        //items sorted
        NSArray* itemsSorted = nil;
        
        //paths (for dups)
        NSMutableSet* paths = nil;
        
        //parse BTM db
        contents = parseBTM(nil);
        if(noErr != [contents[KEY_BTM_ERROR] integerValue])
        {
            //error
            goto bail;
        }
        
        //init
        items = [NSMutableDictionary dictionary];
    
        //init
        paths = [NSMutableSet set];
        
        //iterate over all items
        // sorted by each user uuid
        for(NSString* uuid in contents[KEY_BTM_ITEMS_BY_USER_ID])
        {
            //iterate over each item
            for(NSDictionary* item in contents[KEY_BTM_ITEMS_BY_USER_ID][uuid])
            {
                //File obj
                File* fileObj = nil;
                
                //params to init file object
                NSMutableDictionary* parameters = nil;
                
                //path
                NSString* path = nil;
                
                //plist
                NSString* plist = nil;
                
                //params
                parameters = [NSMutableDictionary dictionary];
                
                //ignore any items that have "embeddded item ids"
                // these seem to be parents, and not the actual items persisted
                if(nil != item[KEY_BTM_ITEM_EMBEDDED_IDS])
                {
                    //skip
                    continue;
                }
                
                //executable path
                path = item[KEY_BTM_ITEM_EXE_PATH];
                if(nil == path)
                {
                    //no path
                    // skip item
                    continue;
                }
                
                //(optional) plist
                plist = item[KEY_BTM_ITEM_PLIST_PATH];
                
                //init params w/ self
                parameters[KEY_RESULT_PLUGIN] = self;
                
                //init params w/ path
                parameters[KEY_RESULT_PATH] = path;
                
                //got plist?
                if(nil != plist)
                {
                    //init params w/ plist
                    parameters[KEY_RESULT_PLIST] = plist;
                }
                
                //init file obj with params (path, etc)
                fileObj = [[File alloc] initWithParams:parameters];
                if(nil == fileObj)
                {
                    //error
                    // skip item
                    continue;
                }
                
                //new?
                // save
                if(YES != [paths containsObject:fileObj.path])
                {
                    //save path
                    [paths addObject:fileObj.path];
                    
                    //save
                    items[item[KEY_BTM_ITEM_UUID]] = fileObj;
                }
            }
        }
        
        //sort by name
        itemsSorted = [[items allValues] sortedArrayUsingComparator:^NSComparisonResult(File* itemOne, File* itemTwo) {
            return [itemOne.name compare:itemTwo.name];
        }];
        
        //add each to UI
        for(File* item in itemsSorted)
        {
            //process item
            // save and report to UI
            [super processItem:item];
        }
        
    bail:
        
        return;
        
    }//macOS 13+
}

@end

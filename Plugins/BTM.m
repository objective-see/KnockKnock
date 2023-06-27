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
        
        //parents
        NSMutableArray* parents = nil;
        
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
        parents = [NSMutableArray array];
        
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
                
                //type
                NSUInteger type = 0;
                
                //path
                NSString* path = nil;
                
                //plist
                NSString* plist = nil;
                
                //parent identifier
                NSString* parentID = nil;
                
                //extract type
                type = [item[KEY_BTM_ITEM_TYPE] unsignedIntegerValue];
                
                //ignore any items that have "embeddded item ids"
                // these seems to be parents, and not the actual items persisted
                if(nil != item[KEY_BTM_ITEM_EMBEDDED_IDS])
                {
                    //skip
                    continue;
                }
                
                //agent / daemon
                if( (type & 0x8) ||
                   (type & 0x10) )
                {
                    //path
                    path = item[KEY_BTM_ITEM_EXE_PATH];
                    
                    //plist
                    plist = [item[KEY_BTM_ITEM_URL] path];
                }
                
                //login item
                // don't have full path, so construct via parent
                else if(type & 0x4)
                {
                    //parent id
                    parentID = item[KEY_BTM_ITEM_PARENT_ID];
                    
                    //find parent
                    for(NSDictionary* parent in contents[KEY_BTM_ITEMS_BY_USER_ID][uuid])
                    {
                        //no match?
                        if(YES != [parent[KEY_BTM_ITEM_ID] isEqualToString:parentID])
                        {
                            //skip
                            continue;
                        }
                        
                        //path = parent URL + login item URL
                        path = [NSString stringWithFormat:@"%@%@", [parent[KEY_BTM_ITEM_URL] path], [item[KEY_BTM_ITEM_URL] path]];
                        
                        //update path from app's bundle to executable
                        path = [[NSBundle bundleWithPath:path] executablePath];
                        
                        //save parent uuid
                        [parents addObject:parent[KEY_BTM_ITEM_UUID]];
                        
                        //done
                        break;
                    }
                }
                
                //app
                else if(type & 0x2)
                {
                    //extract path
                    path = [item[KEY_BTM_ITEM_URL] path];
                    
                    //update path from app's bundle to executable
                    path = [[NSBundle bundleWithPath:path] executablePath];
                }
                
                //sanity check
                if( (nil == path) &&
                   (nil == plist) )
                {
                    //next
                    continue;
                }
                
                //plist nil
                // ...will for non agents/daemons
                if(nil == plist)
                {
                    //init w/o plist
                    fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:path}];
                }
                else
                {
                    fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:path, KEY_RESULT_PLIST:plist}];
                }
                
                //error in init?
                if(nil == fileObj)
                {
                    continue;
                }
                
                //new
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
        
        //remove all parents
        for(NSString* key in parents)
        {
            //remove
            [items removeObjectForKey:key];
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

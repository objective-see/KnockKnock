//
//  Diff.m
//  KnockKnock
//
//  Created by Patrick Wardle on 12/15/25.
//  Copyright © 2025 Objective-See. All rights reserved.
//

#include "diff.h"

//generate key for item comparison
NSString* keyForItem(NSDictionary* item)
{
    //command item? use command + file
    if([item[@"command"] length] > 0)
    {
        return [NSString stringWithFormat:@"%@|%@",
            item[@"command"] ?: @"", item[@"file"] ?: @""];
    }
    
    //default: use path
    return item[@"path"];
}

//check if item changed (compare hashes/signatures)
BOOL itemChanged(NSDictionary* prevItem, NSDictionary* currentItem)
{
    //fields to compare
    NSArray* fields = @[@"hashes", @"signature(s)", @"name", @"plist", @"command"];
    
    for(NSString* field in fields)
    {
        id prevValue = prevItem[field];
        id currentValue = currentItem[field];
        
        if(nil == prevValue && nil == currentValue) continue;
        
        if(![prevValue isEqual:currentValue]) return YES;
    }
    
    return NO;
}

//format item for display
NSString* formatItem(NSDictionary* item)
{
    //command item?
    if([item[@"command"] length] > 0)
    {
        return [NSString stringWithFormat:@"%@ (%@)", item[@"command"], item[@"file"]];
    }
    
    //default: name + path
    return [NSString stringWithFormat:@"%@ (%@)", item[@"name"] ?: @"unknown", item[@"path"]];
}

//compare two scans, return diff string (nil on error)
NSString* diffScans(NSDictionary* prevScan, NSDictionary* currentScan)
{
    //sanity check
    if(![prevScan isKindOfClass:[NSDictionary class]] ||
       ![currentScan isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    NSMutableString* diff = [NSMutableString string];
    
    //get all categories
    NSMutableSet* allCategories = [NSMutableSet setWithArray:prevScan.allKeys];
    [allCategories addObjectsFromArray:currentScan.allKeys];
    
    for(NSString* category in allCategories)
    {
        NSArray* prevItems = prevScan[category] ?: @[];
        NSArray* currentItems = currentScan[category] ?: @[];
        
        //build lookups
        NSMutableDictionary* prevLookup = [NSMutableDictionary dictionary];
        for(NSDictionary* item in prevItems)
        {
            NSString* key = keyForItem(item);
            if(key) prevLookup[key] = item;
        }
        
        NSMutableDictionary* currentLookup = [NSMutableDictionary dictionary];
        for(NSDictionary* item in currentItems)
        {
            NSString* key = keyForItem(item);
            if(key) currentLookup[key] = item;
        }
        
        NSMutableString* categoryDiff = [NSMutableString string];
        
        //removed (in prev but not current)
        for(NSString* key in prevLookup)
        {
            if(nil == currentLookup[key])
            {
                [categoryDiff appendFormat:@"  - %@\r\n", formatItem(prevLookup[key])];
            }
        }
        
        //added (in current but not prev)
        for(NSString* key in currentLookup)
        {
            if(nil == prevLookup[key])
            {
                [categoryDiff appendFormat:@"  + %@\r\n", formatItem(currentLookup[key])];
            }
        }
        
        //changed (in both but different)
        for(NSString* key in currentLookup)
        {
            if(nil != prevLookup[key])
            {
                if(itemChanged(prevLookup[key], currentLookup[key]))
                {
                    [categoryDiff appendFormat:@"  ~ %@\r\n", formatItem(currentLookup[key])];
                }
            }
        }
        
        //any diffs in this category?
        if(categoryDiff.length > 0)
        {
            [diff appendFormat:@"%@:\r\n%@\r\n", category, categoryDiff];
        }
    }
    
    //no changes?
    if(0 == diff.length)
    {
        return NSLocalizedString(@"No Changes Detected", @"No Changes Detected");
    }
    
    return diff;
}

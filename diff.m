//
//  Diff.m
//  KnockKnock
//
//  Created by Patrick Wardle on 12/15/25.
//  Copyright © 2025 Objective-See. All rights reserved.
//

#include "diff.h"

//generate key for item comparison
// note: items come from an untrusted (user-writable) file, so every value is type-checked
NSString* keyForItem(NSDictionary* item)
{
    //command item? use command + file
    if( (YES == [item[@"command"] isKindOfClass:[NSString class]]) &&
        ([item[@"command"] length] > 0) )
    {
        return [NSString stringWithFormat:@"%@|%@",
            item[@"command"], [item[@"file"] isKindOfClass:[NSString class]] ? item[@"file"] : @""];
    }
    
    //default: use path
    // (must be a string, else no key -> item is skipped)
    return [item[@"path"] isKindOfClass:[NSString class]] ? item[@"path"] : nil;
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
// note: '%@' is safe for any type, but 'length' is not, hence the type check
NSString* formatItem(NSDictionary* item)
{
    //command item?
    if( (YES == [item[@"command"] isKindOfClass:[NSString class]]) &&
        ([item[@"command"] length] > 0) )
    {
        return [NSString stringWithFormat:@"%@ (%@)", item[@"command"], item[@"file"] ?: @"unknown"];
    }
    
    //default: name + path
    return [NSString stringWithFormat:@"%@ (%@)", item[@"name"] ?: @"unknown", item[@"path"] ?: @"unknown"];
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
        //categories must map to arrays (of dictionaries)
        // ->anything else (from an untrusted file) is treated as empty
        NSArray* prevItems = [prevScan[category] isKindOfClass:[NSArray class]] ? prevScan[category] : @[];
        NSArray* currentItems = [currentScan[category] isKindOfClass:[NSArray class]] ? currentScan[category] : @[];
        
        //build lookups
        NSMutableDictionary* prevLookup = [NSMutableDictionary dictionary];
        for(NSDictionary* item in prevItems)
        {
            if(![item isKindOfClass:[NSDictionary class]]) continue;
            NSString* key = keyForItem(item);
            if(key) prevLookup[key] = item;
        }
        
        NSMutableDictionary* currentLookup = [NSMutableDictionary dictionary];
        for(NSDictionary* item in currentItems)
        {
            if(![item isKindOfClass:[NSDictionary class]]) continue;
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

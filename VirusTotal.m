//
//  VirusTotal.m
//  KnockKnock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import "File.h"
#import "ItemBase.h"
#import "PluginBase.h"
#import "VirusTotal.h"
#import "AppDelegate.h"

@implementation VirusTotal

//thread function
// ->runs in the background to get virus total info about a plugin's items
-(void)getInfo:(PluginBase*)plugin
{
    //plugin file items
    // ->in dictionary w/ SHA1 hash as key
    NSMutableDictionary* uniqueItems = nil;
    
    //File object
    File* item = nil;
    
    //item data
    NSMutableDictionary* itemData = nil;
    
    //items
    NSMutableArray* items = nil;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //results
    NSDictionary* results = nil;
    
    //alloc dictionary for plugin file items
    uniqueItems = [NSMutableDictionary dictionary];
    
    //alloc list for items
    items = [NSMutableArray array];
    
    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", VT_QUERY_URL, VT_API_KEY]];
    
    //place all plugin file items into dictionary
    // ->key: hash, filter's out dups for queries
    for(ItemBase* item in plugin.allItems)
    {
        //skip non-file items
        if(YES != [item isKindOfClass:[File class]])
        {
            //skip
            continue;
        }
        
        //skip item's without hashes
        // ...not sure how this could ever happen
        if(nil == ((File*)item).hashes[KEY_HASH_SHA1])
        {
            //skip
            continue;
        }
        
        //add item
        uniqueItems[((File*)item).hashes[KEY_HASH_SHA1]] = item;
    }
    
    //iterate over all hashes
    // ->create item dictionary (JSON), and add it to list
    for(NSString* itemKey in uniqueItems)
    {
        //extract item
        item = uniqueItems[itemKey];
        
        //alloc item data
        itemData = [NSMutableDictionary dictionary];
        
        //auto start location
        itemData[@"autostart_location"] = plugin.name;
        
        //set item name
        itemData[@"autostart_entry"] = item.name;
        
        //set item path
        itemData[@"image_path"] = item.path;
        
        //set hash
        itemData[@"hash"] = item.hashes[KEY_HASH_SHA1];
        
        //set creation times
        itemData[@"creation_datetime"] = [item.attributes.fileCreationDate description];
        
        //add item info to list
        [items addObject:itemData];
        
        //less then 25 items
        // ->just keep collecting items
        if(VT_MAX_QUERY_COUNT != items.count)
        {
            //next
            continue;
        }
        
        //make query to VT
        results = [self postRequest:queryURL parameters:items];
        if(nil != results)
        {
            //process results
            [self processResults:plugin items:plugin.allItems results:results];
        }
        
        //remove all items
        // ->since they've been processed
        [items removeAllObjects];
    }
    
    //process any remaining items
    if(0 != items.count)
    {
        //query virus total
        results = [self postRequest:queryURL parameters:items];
        if(nil != results)
        {
            //process results
            [self processResults:plugin items:plugin.allItems results:results];
        }
    }
    
    //exit if thread was cancelled
    // ->i.e. user pressed 'stop' scan
    if(YES == [[NSThread currentThread] isCancelled])
    {
        //exit
        [NSThread exit];
    }
    
    //tell UI plugin items have all be processed
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemsProcessed:plugin];

    return;
}

//get VT info for a single item
// ->will callback into AppDelegate to reload item in UI
-(void)getInfoForItem:(File*)fileObj rowIndex:(NSUInteger)rowIndex
{
    //item data
    NSMutableDictionary* itemData = nil;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //results
    NSDictionary* results = nil;
    
    //alloc item data
    itemData = [NSMutableDictionary dictionary];
    
    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", VT_QUERY_URL, VT_API_KEY]];
    
    //auto start location
    itemData[@"autostart_location"] = fileObj.plugin.name;
    
    //set item name
    itemData[@"autostart_entry"] = fileObj.name;
    
    //set item path
    itemData[@"image_path"] = fileObj.path;
    
    //set hash
    itemData[@"hash"] = fileObj.hashes[KEY_HASH_SHA1];
    
    //set creation times
    itemData[@"creation_datetime"] = [fileObj.attributes.fileCreationDate description];
    
    //make query to VT
    results = [self postRequest:queryURL parameters:@[itemData]];
    if(nil != results)
    {
        //process results
        // ->just first result (should only be one)
        if(nil != [results[VT_RESULTS] firstObject])
        {
            //extract result
            fileObj.vtInfo = [results[VT_RESULTS] firstObject];
        
            //callback up into UI to reload item
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemProcessed:fileObj rowIndex:rowIndex];
        }
    }
    
    return;
}

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url parameters:(id)params
{
    //results
    NSDictionary* results = nil;
    
    //request
    NSMutableURLRequest *request = nil;
    
    //post data
    // ->JSON'd items
    NSData* postData = nil;
    
    //error var
    NSError* error = nil;
    
    //data from VT
    NSData *vtData = nil;
    
    //response (HTTP) from VT
    NSURLResponse *httpResponse = nil;

    //alloc/init request
    request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    //set user agent
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    //serialize JSON
    if(nil != params)
    {
        //convert items to JSON'd data for POST request
        postData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:nil];
        if(nil == postData)
        {
            //err msg
            NSLog(@"OBJECTIVE-SEE ERROR: failed to convert request %@ to JSON", postData);
            
            //bail
            goto bail;
        }
        
        //set content type
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        //set content length
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-length"];
        
        //add POST data
        [request setHTTPBody:postData];
    }
    
    //set method type
    [request setHTTPMethod:@"POST"];
    
    //send request
    // ->synchronous, so will block
    vtData = [NSURLConnection sendSynchronousRequest:request returningResponse:&httpResponse error:&error];
    
    //sanity check(s)
    if( (nil == vtData) ||
        (nil != error) ||
        (200 != (long)[(NSHTTPURLResponse *)httpResponse statusCode]) )
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to query VirusTotal (%@, %@)", error, httpResponse);
        
        //bail
        goto bail;
    }
    
    //convert response (hopefully JSON)
    results = [NSJSONSerialization JSONObjectWithData:vtData options:kNilOptions error:nil];
    
    //sanity check
    if(nil == results)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to convert response %@ to JSON", vtData);
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return results;
}

//submit a file to VT
-(NSDictionary*)submit:(File*)fileObj
{
    //results
    NSDictionary* results = nil;
    
    //request
    NSMutableURLRequest *request = nil;
    
    
    //error var
    NSError* error = nil;
    
    //response
    NSData *response = nil;
    
    NSURLResponse *blah = nil;

    
    NSURL* submitURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?apikey=%@&resource=%@", VT_SUBMIT_URL, VT_API_KEY, fileObj.hashes[KEY_HASH_MD5]]];
    
    
    
    request = [[NSMutableURLRequest alloc] initWithURL:submitURL];
    
    // the boundary string. Can be whatever we want, as long as it doesn't appear as part of "proper" fields
    NSString *boundary = @"qqqq___knockknock___qqqq";
    
    // setting the HTTP method
    [request setHTTPMethod:@"POST"];
    
    // setting the Content-type and the boundary
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField: @"Content-Type"];
    
    //set user agent
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];

    
    
    
    
    
    // we need a buffer of mutable data where we will write the body of the request
    NSMutableData *body = [NSMutableData data];
    
    
    // creating a NSData representation of the image
    NSData *fileData = [NSData dataWithContentsOfFile:fileObj.pathForFinder];
    
    NSString *fileNameStr = [NSString stringWithFormat:@"%@", fileObj.name];
    
    // if we have successfully obtained a NSData representation of the image
    if (fileData) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileNameStr] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:fileData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else
        NSLog(@"no image data!!!");
    
    
    // we close the body with one last boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    // assigning the completed NSMutableData buffer as the body of the HTTP POST request
    [request setHTTPBody:body];
    
    
    //set content length
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-length"];

    
    
    //send request
    // ->synchronous, so will block
    response = [NSURLConnection sendSynchronousRequest:request returningResponse:&blah error:&error];
    
    //sanity check
    if(nil == response)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to query VirusTotal (%@)", error);
        
        //bail
        goto bail;
    }
    
    //convert response (hopefully JSON)
    results = [NSJSONSerialization JSONObjectWithData:response options:kNilOptions error:nil];
    if(nil == results)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to convert response to JSON");
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return results;
    
}

//submit a rescan request
-(NSDictionary*)reScan:(File*)fileObj
{
    //result data
    NSDictionary* result = nil;
    
    NSURL* reScanURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?apikey=%@&resource=%@", VT_RESCAN_URL, VT_API_KEY, fileObj.hashes[KEY_HASH_MD5]]];
    
    //make request to VT
    result = [self postRequest:reScanURL parameters:nil];
    if(nil == result)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to re-scan %@", fileObj.name);
        
        //bail
        goto bail;
    }

//bail
bail:
    
    return result;
}

//process results
// ->save VT info into each File obj
-(void)processResults:(PluginBase*)plugin items:(NSArray*)items results:(NSDictionary*)results
{
    //process all results
    // ->save VT result dictionary into File obj
    for(NSDictionary* result in results[VT_RESULTS])
    {
        //find all items that match
        // ->might be dupes, which is fine
        for(File* item in items)
        {
            //for matches, save vt info
            if(YES == [result[@"hash"] isEqualToString:item.hashes[KEY_HASH_SHA1]])
            {
                //save
                item.vtInfo = result;
            }
        }
    }
    
    return;
}

@end

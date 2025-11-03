//
//  VirusTotal.m
//  KnockKnock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "ItemBase.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "VirusTotal.h"
#import "AppDelegate.h"

/* GLOBALS */

//cmdline flag
extern BOOL cmdlineMode;

@implementation VirusTotal

//ask VT about all files for a given plugin
// note: skips Apple binaries
-(void)checkFiles:(PluginBase*)plugin {
    
    //load key
    NSString* vtAPIKey = loadAPIKeyFromKeychain();
    
    //all items in the plugin
    for(ItemBase* item in plugin.allItems) {
        
        //skip non-file items
        if(![item isKindOfClass:[File class]]) {
            continue;
        }
        
        //typecast
        File* file = (File*)item;
        
        //skip apple binaries
        if(Apple == [file.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) {
            continue;
        }
    
        //grab hash
        NSString *sha1 = file.hashes[KEY_HASH_SHA1];
        if (!sha1) {
            continue;
        }
        
        //build the API URL
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.virustotal.com/api/v3/files/%@", sha1]];
        
        //create the request
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setValue:vtAPIKey forHTTPHeaderField:@"x-apikey"];
        
        //kick off request
        NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            if (error) {
                NSLog(@"VirusTotal error: %@", error.localizedDescription);
                return;
            }
            
            //grab HTTP status
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
            
            //401 is API key issue :|
            if (httpResponse.statusCode == 401) {
                
                //dbg msg
                NSLog(@"VT ERROR: API KEY");
                
                return;
            }
            
            //404 is (unknown) file not found
            if (httpResponse.statusCode == 404) {
                
                //dbg msg
                NSLog(@"%@ is unknown to VirusTotal (hash: %@)", file.name, sha1);
                
                //add to unknown items
                @synchronized(item.plugin.unknownItems) {
                    [item.plugin.unknownItems addObject:item];
                }
                
                //save
                // blank to indicate not found
                file.vtInfo = @{};
                
                //notify UI on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [((AppDelegate*)NSApplication.sharedApplication.delegate) itemProcessed:file];
                });
                
                return;
            }
            
            
            //all other error(s)
            if (httpResponse.statusCode != 200) {
                NSLog(@"VirusTotal HTTP error: %ld", (long)httpResponse.statusCode);
                return;
            }
            
            //parse response (JSON)
            NSError* jsonError = nil;
            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (jsonError) {
                NSLog(@"VirusTotal JSON error: %@", jsonError.localizedDescription);
                return;
            }
            
            //extract
            NSDictionary* attributes = json[@"data"][@"attributes"];
            NSDictionary* stats = attributes[@"last_analysis_stats"];
            
            NSString* itemID = json[@"data"][@"id"];
            
            
            NSInteger malicious = [stats[@"malicious"] integerValue];
            NSInteger suspicious = [stats[@"suspicious"] integerValue];
            NSInteger undetected = [stats[@"undetected"] integerValue];
            NSInteger harmless = [stats[@"harmless"] integerValue];
            
            //(browser) report
            NSString* link = [NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", itemID];
            
            //calculate total
            //TODO: double check this
            NSInteger total = malicious + suspicious + undetected + harmless;
            
            //create result dictionary
            NSDictionary *result = @{
                VT_RESULTS_POSITIVES : @(malicious),
                @"suspicious": @(suspicious),
                @"undetected": @(undetected),
                @"harmless": @(harmless),
                VT_RESULTS_TOTAL : @(total),
                @"ratio": [NSString stringWithFormat:@"%ld/%ld", (long)malicious, (long)total],
                VT_RESULTS_URL: link
            };
            
            //save
            file.vtInfo = result;
            
            NSLog(@"File: %@ - Detection ratio: %ld/%ld", file.name, (long)malicious, (long)total);
            
            //malicious?
            // add to flagged items
            if (malicious > 0) {
                @synchronized(item.plugin.flaggedItems) {
                    [item.plugin.flaggedItems addObject:item];
                }
            }
            
            //notify UI on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [((AppDelegate*)NSApplication.sharedApplication.delegate) itemProcessed:file];
            });
        }];
        
        //query
        [task resume];
    }
}

//submit a file to VT
- (void)submitFile:(NSString *)filePath completion:(void (^)(NSDictionary *result, NSError *error))completion {
    
    //load key
    NSString* vtAPIKey = loadAPIKeyFromKeychain();
    
    // Check file exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"File does not exist"}];
        completion(nil, error);
        return;
    }
    
    // Check file size (32MB limit for regular endpoint)
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
    unsigned long long fileSize = [fileAttributes fileSize];
    const unsigned long long maxSize = 32 * 1024 * 1024; // 32MB
    
    if (fileSize > maxSize) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"File too large. Use upload_url endpoint for files > 32MB"}];
        completion(nil, error);
        return;
    }
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-3
                                         userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
        completion(nil, error);
        return;
    }
    
    // Build the API URL
    NSURL *url = [NSURL URLWithString:@"https://www.virustotal.com/api/v3/files"];
    
    // Create multipart form data
    NSString *boundary = [[NSUUID UUID] UUIDString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:vtAPIKey forHTTPHeaderField:@"x-apikey"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
   forHTTPHeaderField:@"Content-Type"];
    
    // Build the body
    NSMutableData *body = [NSMutableData data];
    NSString *fileName = [filePath lastPathComponent];
    
    // Add file parameter
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // End boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    // Send the request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            completion(nil, error);
            return;
        }
        
        // Check HTTP status
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *statusError = [NSError errorWithDomain:@"VirusTotal"
                                                       code:httpResponse.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            completion(nil, statusError);
            return;
        }
        
        // Parse JSON response
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            completion(nil, jsonError);
            return;
        }
        
        NSString *analysisID = json[@"data"][@"id"];
        
        // Base64 decode the analysis ID
        NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:analysisID options:0];
        if (!decodedData) {
            NSLog(@"Failed to decode base64 analysis ID");
            
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-3
                                             userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
            completion(nil, error);
            
            
        }
        
        // Convert to string
        NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
        if (!decodedString) {
            NSLog(@"Failed to convert decoded data to string");
            
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-3
                                             userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
            completion(nil, error);
        }
        
        // Split by colon to get the hash (first part)
        NSArray *components = [decodedString componentsSeparatedByString:@":"];
        if (components.count < 1) {
            NSLog(@"Unexpected format in decoded string: %@", decodedString);
            
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-3
                                             userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
            completion(nil, error);
        }
        
        NSString *fileHash = components[0];
        
        // Build the VirusTotal GUI URL
        NSString *vtURL = [NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", fileHash];
            
        NSDictionary *result = @{
            VT_RESULTS_URL: vtURL
        };
                
        completion(result, nil);
    }];
    
    [task resume];
}


//thread function
// runs in the background to get virus total info about a plugin's items
-(void)getInfo:(PluginBase*)plugin
{
    //plugin file items
    // in dictionary w/ SHA1 hash as key
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
    
    //sync
    // ->since array will be reset if user clicks 'stop' scan
    @synchronized(plugin.allItems)
    {
    
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
        
    }//sync
    
    //iterate over all hashes
    // ->create item dictionary (JSON), and add it to list
    for(NSString* itemKey in uniqueItems)
    {
        //sanitized path
        NSString* sanitizedPath = nil;
        
        //current user
        NSString* currentUser = nil;
        
        //alloc item data
        itemData = [NSMutableDictionary dictionary];
        
        //exit if thread was cancelled
        // ->i.e. user pressed 'stop' scan
        if(YES == [[NSThread currentThread] isCancelled])
        {
            //exit
            [NSThread exit];
        }
        
        //get current user
        currentUser = getConsoleUser();
        
        //sanitize path
        sanitizedPath = [item.path stringByReplacingOccurrencesOfString:currentUser withString:@"user"];
        
        //extract item
        item = uniqueItems[itemKey];
        
        //auto start location
        itemData[@"autostart_location"] = plugin.name;
        
        //set item name
        itemData[@"autostart_entry"] = item.name;
        
        //set item path
        itemData[@"image_path"] = sanitizedPath;
        
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
        if(200 == (long)[(NSHTTPURLResponse *)results[VT_HTTP_RESPONSE] statusCode])
        {
            //process results
            [self processResults:plugin.allItems results:results];
        }
        
        //remove all items
        // since they've been processed
        [items removeAllObjects];
    }
    
    //process any remaining items
    if(0 != items.count)
    {
        //query virus total
        results = [self postRequest:queryURL parameters:items];
        if(200 == (long)[(NSHTTPURLResponse *)results[VT_HTTP_RESPONSE] statusCode])
        {
            //process results
            [self processResults:plugin.allItems results:results];
        }
    }
    
    //exit if thread was cancelled
    // ->i.e. user pressed 'stop' scan
    if(YES == [[NSThread currentThread] isCancelled])
    {
        //exit
        [NSThread exit];
    }
    
    //tell UI all plugin's items have all be processed
    if(YES != cmdlineMode)
    {
        //on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //call up into UI
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemsProcessed:plugin];
            
        });
        
    }

    return;
}

//item data
//(NSMutableDictionary*)covertItemToRequest:(Item*)


//get VT info for a single item
// will then callback into AppDelegate to reload item in UI
-(BOOL)getInfoForItem:(File*)fileObj scanID:(NSString*)scanID
{
    //result
    BOOL gotInfo = NO;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //results
    NSDictionary* results = nil;
    
    //alert
    __block NSAlert* alert = nil;
    
    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?apikey=%@&resource=%@", VT_REQUERY_URL, VT_API_KEY, scanID]];
    
    //make queries until response is recieved
    while(YES)
    {
        //make query to VT
        results = [self postRequest:queryURL parameters:nil];
        if(200 != (long)[(NSHTTPURLResponse *)results[VT_HTTP_RESPONSE] statusCode])
        {
            //update status msg
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //alloc/init alert
                alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"ERROR:\nVirusTotal query for '%@' failed", @"ERROR:\nVirusTotal query for '%@' failed"), fileObj.name] defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"HTTP reponse: %ld", @"HTTP reponse: %ld"), (long)[(NSHTTPURLResponse *)results[VT_HTTP_RESPONSE] statusCode]];
                
                //show it
                [alert runModal];
                
            });
            
            break;
        }

        //check if scan is complete
        if( (nil != results) &&
            (1 == [results[VT_RESULTS_RESPONSE] integerValue]) )
        {
            //save result
            fileObj.vtInfo = results;
            
            //if its flagged save in File's plugin
            if(0 != [results[VT_RESULTS_POSITIVES] unsignedIntegerValue])
            {
                //sync
                // ->since array will be reset if user clicks 'stop' scan
                @synchronized(fileObj.plugin.flaggedItems)
                {
                    //save
                    [fileObj.plugin.flaggedItems addObject:fileObj];
                }
            }
            //if its unknown save
            if(nil == results[VT_RESULTS_URL])
            {
                //sync
                // since array will be reset if user clicks 'stop' scan
                @synchronized(fileObj.plugin.unknownItems)
                {
                    //save
                    [fileObj.plugin.unknownItems addObject:fileObj];
                }
            }
            
            //update status msg
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //callback up into UI to reload item
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemProcessed:fileObj];
                
            });
            
            //happy
            gotInfo = YES;

            //exit loop
            break;
        }
        
        //nap
        [NSThread sleepForTimeInterval:10.0f];
    }
    
    return gotInfo;
}

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url parameters:(id)params
{
    //results
    NSMutableDictionary* results = nil;
    
    //request
    NSMutableURLRequest* request = nil;
    
    //http response
    NSURLResponse* httpResponse = nil;
    
    //post data
    // ->JSON'd items
    NSData* postData = nil;
    
    //error var
    NSError* error = nil;
    
    //data from VT
    NSData* vtData = nil;

    //alloc/init request
    request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    //init
    results = [NSMutableDictionary dictionary];
    
    //set user agent
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];

    //serialize JSON
    if(nil != params)
    {
        //convert items to JSON'd data for POST request
        @try
        {
            //convert items
            postData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:nil];
            if(nil == postData)
            {
                //err msg
                NSLog(@"ERROR: failed to convert request %@ to JSON", postData);
                goto bail;
            }
            
        }
        //bail on exceptions
        @catch(NSException *exception)
        {
            //set error
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
    // synchronous, so will block
    vtData = [NSURLConnection sendSynchronousRequest:request returningResponse:&httpResponse error:&error];
    
    //save http response
    results[VT_HTTP_RESPONSE] = httpResponse;
    
    //sanity check(s)
    if( (nil == vtData) ||
        (nil != error) ||
        (200 != (long)[(NSHTTPURLResponse *)httpResponse statusCode]) )
    {
        //err msg
        NSLog(@"ERROR: failed to query VirusTotal (%@, %@)", error, httpResponse);
        goto bail;
    }
    
    //serialize response into NSData obj
    // wrap since we are serializing JSON
    @try
    {
        //serialized
        results = [[NSJSONSerialization JSONObjectWithData:vtData options:kNilOptions error:nil] mutableCopy];
        if(YES != [results isKindOfClass:[NSDictionary class]])
        {
            //bail
            goto bail;
        }
        
        //(re)add http response
        results[VT_HTTP_RESPONSE] = httpResponse;
    }
    //bail on any exceptions
    @catch (NSException *exception)
    {
        //err msg
        NSLog(@"ERROR: converting response %@ to JSON threw %@", vtData, exception);
        goto bail;
    }
    
    //sanity check
    if(nil == results)
    {
        //err msg
        NSLog(@"ERROR: failed to convert response %@ to JSON", vtData);
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
    NSMutableDictionary* results = nil;
    
    //submit URL
    NSURL* submitURL = nil;
    
    //request
    NSMutableURLRequest* request = nil;
    
    //body of request
    NSMutableData* body = nil;
    
    //file data
    NSData* fileContents = nil;
    
    //error var
    NSError* error = nil;
    
    //data from Vt
    NSData* vtData = nil;
    
    //response (HTTP) from VT
    NSURLResponse* httpResponse = nil;
    
    //init
    results = [NSMutableDictionary dictionary];

    //init submit URL
    submitURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?apikey=%@&resource=%@", VT_SUBMIT_URL, VT_API_KEY, fileObj.hashes[KEY_HASH_MD5]]];
    
    //init request
    request = [[NSMutableURLRequest alloc] initWithURL:submitURL];
    
    //set boundary string
    NSString *boundary = @"qqqq___knockknock___qqqq";
    
    //set HTTP method (POST)
    [request setHTTPMethod:@"POST"];
    
    //set the HTTP header 'Content-type' to the boundary
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField: @"Content-Type"];
    
    //set HTTP header, 'User-Agent'
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];

    //init body
    body = [NSMutableData data];
    
    //load file into memory
    fileContents = [NSData dataWithContentsOfFile:fileObj.pathForFinder];
    
    //sanity check
    if(nil == fileContents)
    {
        //err msg
        NSLog(@"ERROR: failed to load %@ into memory for submission", fileObj.path);
        goto bail;
    }
        
    //append boundary
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    //append 'Content-Disposition' file name, etc
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileObj.name] dataUsingEncoding:NSUTF8StringEncoding]];
    
    //append 'Content-Type'
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    //append file's contents
    [body appendData:fileContents];
    
    //append '\r\n'
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    //append final boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    //set body
    [request setHTTPBody:body];
    
    //set content length
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-length"];

    //send request
    // synchronous, so will block
    vtData = [NSURLConnection sendSynchronousRequest:request returningResponse:&httpResponse error:&error];
    
    //save http response
    results[VT_HTTP_RESPONSE] = httpResponse;
    
    //sanity check(s)
    if( (nil == vtData) ||
        (nil != error) ||
        (200 != (long)[(NSHTTPURLResponse *)httpResponse statusCode]) )
    {
        //err msg
        NSLog(@"ERROR: failed to query VirusTotal (%@, %@)", error, httpResponse);
        goto bail;
    }
    
    //serialize response into NSData obj
    // ->wrap since we are serializing JSON
    @try
    {
        //serialize
        results = [[NSJSONSerialization JSONObjectWithData:vtData options:kNilOptions error:nil] mutableCopy];
        if(YES != [results isKindOfClass:[NSDictionary class]])
        {
            //bail
            goto bail;
        }
        
        //(re)add http response
        results[VT_HTTP_RESPONSE] = httpResponse;
    }
    //bail on any exceptions
    @catch (NSException *exception)
    {
        //err msg
        NSLog(@"ERROR: converting response %@ to JSON threw %@", vtData, exception);
        goto bail;
    }
    
    //sanity check
    if(nil == results)
    {
        //err msg
        NSLog(@"ERROR: failed to convert response %@ to JSON", vtData);
        goto bail;
    }
    
bail:
    
    return results;
}

//submit a rescan request
-(NSDictionary*)reScan:(File*)fileObj
{
    //result data
    NSDictionary* results = nil;
    
    //scan url
    NSURL* reScanURL = nil;
    
    //http response
    NSURLResponse* httpResponse = nil;
    
    //init scan url
    reScanURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?apikey=%@&resource=%@", VT_RESCAN_URL, VT_API_KEY, fileObj.hashes[KEY_HASH_MD5]]];
    
    //make request to VT
    results = [self postRequest:reScanURL parameters:nil];
    if(200 != (long)[(NSHTTPURLResponse *)httpResponse statusCode])
    {
        //err msg
        NSLog(@"ERROR: failed to re-scan %@", fileObj.name);
        goto bail;
    }

bail:
    
    return results;
}

//process results
// save VT info into each File obj and all flagged files
-(void)processResults:(NSArray*)items results:(NSDictionary*)results
{
    //process all results
    // save VT result dictionary into File obj
    for(NSDictionary* result in results[VT_RESULTS])
    {
        //sync
        // ->since array will be reset if user clicks 'stop' scan
        @synchronized(items)
        {

        //find all items that match
        // ->might be dupes, which is fine
        for(ItemBase* item in items)
        {
            //skip non-file items
            if(YES != [item isKindOfClass:[File class]])
            {
                //skip
                continue;
            }
            
            //for matches, save vt info
            if(YES == [result[@"hash"] isEqualToString:((File*)item).hashes[KEY_HASH_SHA1]])
            {
                //save
                ((File*)item).vtInfo = result;
                
                //if its flagged save in File's plugin
                if(0 != [result[VT_RESULTS_POSITIVES] unsignedIntegerValue])
                {
                    //sync
                    // ->since array will be reset if user clicks 'stop' scan
                    @synchronized(item.plugin.flaggedItems)
                    {
                        //save
                        [item.plugin.flaggedItems addObject:item];
                    }
                }
                //if its unknown save
                if(nil == result[VT_RESULTS_URL])
                {
                    //sync
                    // ->since array will be reset if user clicks 'stop' scan
                    @synchronized(item.plugin.unknownItems)
                    {
                        //save
                        [item.plugin.unknownItems addObject:item];
                    }
                }
            }
        }
            
        }//sync
    }
    
    return;
}

@end

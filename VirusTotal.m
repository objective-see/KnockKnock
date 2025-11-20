//
//  VirusTotal.m
//  KnockKnock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "ItemBase.h"
#import "utilities.h"
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
                NSLog(@"VT ERROR: API key %@ is not valid", vtAPIKey);
                
                //show alert
                // just once though
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //alert
                        NSAlert* alert = nil;
                        
                        //alloc/init alert
                        alert = [NSAlert alertWithMessageText:@"ERROR: VirusTotal Responded with HTTP 401"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                    informativeTextWithFormat:@"%@", [NSString stringWithFormat:@"API key: '%@', likely invalid.", vtAPIKey]];
                        
                        //show it
                        [alert runModal];
                    });
                });
                
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
            
            //dbg msg
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
// completion callback invoked on error
- (void)submitFile:(NSString *)filePath completion:(void (^)(NSDictionary *result))completion {
    
    //load key
    NSString* vtAPIKey = loadAPIKeyFromKeychain();
    if(!vtAPIKey) {
        
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"API key is blank"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
        
    }
    
    // Check file exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"File does not exist"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
    }
    
    // Check file size (32MB limit for regular endpoint)
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
    unsigned long long fileSize = [fileAttributes fileSize];
    const unsigned long long maxSize = 32 * 1024 * 1024; // 32MB
    
    if (fileSize > maxSize) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-3
                                         userInfo:@{NSLocalizedDescriptionKey: @"Files over 32MB are not supported by VT endpoint"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
    }
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-4
                                         userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
        //return w/ error
        completion(@{VT_ERROR:error});
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
            //return w/ error
            completion(@{VT_ERROR:error});
            return;
        }
        
        // Check HTTP status
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSError *statusError = [NSError errorWithDomain:@"VirusTotal"
                                                       code:httpResponse.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            //return w/ error
            completion(@{VT_ERROR:statusError});
            return;
        }
        
        // Parse JSON response
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            //return w/ error
            completion(@{VT_ERROR:jsonError});
            return;
        }
        
        NSString *analysisID = json[@"data"][@"id"];
        
        // Base64 decode the analysis ID
        NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:analysisID options:0];
        if (!decodedData) {
            
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-5
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode base64 analysis ID"}];
            //return w/ error
            completion(@{VT_ERROR:error});
            return;
            
        }
        
        // Convert to string
        NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
        if (!decodedString) {
            
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-6
                                             userInfo:@{NSLocalizedDescriptionKey: @"Could not convert decoded data to string"}];
            //return w/ error
            completion(@{VT_ERROR:error});
            return;
        }
        
        // Split by colon to get the hash (first part)
        NSArray *components = [decodedString componentsSeparatedByString:@":"];
        if (components.count < 1) {
            NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                                 code:-7
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unexpected format in decoded string"}];
            //return w/ error
            completion(@{VT_ERROR:error});
            return;
        }
        
        NSString *fileHash = components[0];
        
        // Build the VirusTotal GUI URL
        NSString *vtURL = [NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", fileHash];
        
        completion(@{VT_RESULTS_URL: vtURL});
    
    }];
    
    [task resume];
}


@end

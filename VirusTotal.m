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
extern NSString* scanID;

@implementation VirusTotal

//ask VT about all files for a given plugin
// note: always skips Apple binaries, as these won't be malware, and API keys usually rate limited
-(void)checkFiles:(PluginBase*)plugin apiKey:(NSString*)apiKey uiMode:(BOOL)uiMode completion:(void(^)(void))completion
{
    //grab scan id
    NSString* currentScanID = scanID;
    
    //cmdline verbose mode
    BOOL isVerbose = NO;
        
    //make a snapshot
    // prevents issues if scan was (re)started
    NSArray* items = nil;
    @synchronized(plugin.allItems) {
        items = [plugin.allItems copy];
    }
    
    //sanity check
    if(!items.count) {
        if(completion) completion();
        return;
    }
    
    //for error msg
    if( (!uiMode) &&
        ([NSProcessInfo.processInfo.arguments containsObject:@"-verbose"]) )
    {
        isVerbose = YES;
    }

    //all items in the plugin
    for(ItemBase* item in items) {
        
        //check if scan was stopped restarted
        if( uiMode &&
            ![currentScanID isEqualToString:scanID])
        {
            if(completion) completion();
            return;
        }
        
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
        
        //semaphore for synchronous request
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        //build the API URL
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.virustotal.com/api/v3/files/%@", sha1]];
        
        //create the request
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setValue:apiKey forHTTPHeaderField:@"x-apikey"];
        
        //kick off request
        NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            if (error) {
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): %s\n", error.localizedDescription.UTF8String);
                }
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //grab HTTP status
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
            
            //401 is API key issue
            if (httpResponse.statusCode == 401) {
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): API key %s issue (not valid?)\n", apiKey.UTF8String);
                }
                
                if(uiMode) {
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert* alert = [NSAlert alertWithMessageText:@"ERROR: VirusTotal Responded with HTTP 401"
                                                    defaultButton:@"OK"
                                                  alternateButton:nil
                                                      otherButton:nil
                                        informativeTextWithFormat:@"%@", [NSString stringWithFormat:@"API key: '%@', likely invalid.", apiKey]];
                            [alert runModal];
                        });
                    });
                }
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //404 is file not found
            if (httpResponse.statusCode == 404) {
                //NSLog(@"%@ is unknown to VirusTotal (hash: %@)", file.name, sha1);
                
                @synchronized(item.plugin.unknownItems) {
                    [item.plugin.unknownItems addObject:item];
                }
                
                file.vtInfo = @{};
                
                if(uiMode) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [((AppDelegate*)NSApplication.sharedApplication.delegate) itemProcessed:file];
                    });
                }
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //all other error(s)
            if (httpResponse.statusCode != 200) {
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): HTTP %ld\n", (long)httpResponse.statusCode);
                }
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //parse response (JSON)
            NSError* jsonError = nil;
            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): invalid JSON %s\n", jsonError.localizedDescription.UTF8String);
                }
                
                //signal
                dispatch_semaphore_signal(sema);
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
            
            NSString* link = [NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", itemID];
            NSInteger total = malicious + suspicious + undetected + harmless;
            
            //save results
            file.vtInfo = @{
                VT_RESULTS_POSITIVES : @(malicious),
                @"suspicious": @(suspicious),
                @"undetected": @(undetected),
                @"harmless": @(harmless),
                VT_RESULTS_TOTAL : @(total),
                @"ratio": [NSString stringWithFormat:@"%ld/%ld", (long)malicious, (long)total],
                VT_RESULTS_URL: link
            };
            
            //malicious?
            if (malicious > 0) {
                @synchronized(item.plugin.flaggedItems) {
                    [item.plugin.flaggedItems addObject:item];
                }
            }
            
            //notify UI
            if(uiMode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [((AppDelegate*)NSApplication.sharedApplication.delegate) itemProcessed:file];
                });
            }
            
            //signal
            dispatch_semaphore_signal(sema);
        }];
        
        [task resume];
        
        //wait for this request to finish
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    
    //all files done
    if(completion) completion();
    
    return;
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
    
    //file exists?
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"File does not exist"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
    }
    
    //file size (32MB limit for regular endpoint)?
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
    
    //read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-4
                                         userInfo:@{NSLocalizedDescriptionKey: @"Could not read file"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
    }
    
    //build the API URL
    NSURL *url = [NSURL URLWithString:@"https://www.virustotal.com/api/v3/files"];
    
    //create multipart form data
    NSString *boundary = [[NSUUID UUID] UUIDString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:vtAPIKey forHTTPHeaderField:@"x-apikey"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
   forHTTPHeaderField:@"Content-Type"];
    
    //build the body
    NSMutableData *body = [NSMutableData data];
    NSString *fileName = [filePath lastPathComponent];
    
    //add file parameter
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    //end boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    //send the request
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

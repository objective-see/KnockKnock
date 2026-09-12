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
        
        //rate limit (quota) exhausted?
        // don't bother (each would burn through the full retry cycle), just mark as error
        if(YES == self.rateLimited) {
            [self markError:file uiMode:uiMode];
            continue;
        }
        
        //skip apple binaries
        if(Apple == [file.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) {
            continue;
        }
    
        //grab hash
        NSString *sha1 = file.hashes[KEY_HASH_SHA1];
        if (!sha1) {
            continue;
        }
        
        //retry delay (seconds)
        // set by the request when rate limited (HTTP 429)
        __block NSInteger retryDelay = 0;
        
        //request (with retries, for rate limiting)
        for(int attempt = 0; attempt < 4; attempt++) {
        
        //reset
        retryDelay = 0;
        
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
                
                //mark & notify
                // so the row resolves (to an error state) rather than staying 'pending' forever
                [self markError:file uiMode:uiMode];
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //grab HTTP status
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
            
            //401 is API key issue
            if (httpResponse.statusCode == 401) {
                
                //masked key (last 4 chars)
                // never print/show the full key
                NSString* maskedKey = (apiKey.length > 4) ? [@"..." stringByAppendingString:[apiKey substringFromIndex:apiKey.length - 4]] : @"...";
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): API key (%s) rejected (HTTP 401), likely invalid\n", maskedKey.UTF8String);
                }
                
                if(uiMode) {
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert* alert = [[NSAlert alloc] init];
                            alert.messageText = NSLocalizedString(@"ERROR: VirusTotal responded with HTTP 401", @"ERROR: VirusTotal responded with HTTP 401");
                            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"The API key (ending in '%@') was rejected, and is likely invalid.", @"The API key (ending in '%@') was rejected, and is likely invalid."), maskedKey];
                            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
                            [alert runModal];
                        });
                    });
                }
                
                //mark & notify
                [self markError:file uiMode:uiMode];
                
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
            
            //429 is rate limited (public keys: 4 lookups/minute)
            // ->back off (per 'Retry-After', default 15s) and retry, up to a few times
            if (httpResponse.statusCode == 429) {
                
                //retry after
                NSInteger retryAfter = [httpResponse.allHeaderFields[@"Retry-After"] integerValue];
                retryDelay = MIN(MAX(retryAfter, 15), 60);
                
                //err msg
                if(isVerbose) {
                    printf("\nVirusTotal rate limit (HTTP 429), retrying in %lds\n", (long)retryDelay);
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
                
                //mark & notify
                [self markError:file uiMode:uiMode];
                
                //signal
                dispatch_semaphore_signal(sema);
                return;
            }
            
            //parse response (JSON)
            NSError* jsonError = nil;
            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
                
                //err msg
                if(isVerbose) {
                    printf("\nERROR (VirusTotal): invalid JSON %s\n", jsonError.localizedDescription.UTF8String);
                }
                
                //mark & notify
                [self markError:file uiMode:uiMode];
                
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
        
        //not rate limited?
        // done with this item
        if(0 == retryDelay) {
            break;
        }
        
        //rate limited, last attempt?
        // mark as error (so row resolves), and set flag so remaining lookups are skipped
        if(3 == attempt) {
            
            //mark
            [self markError:file uiMode:uiMode];
            
            //set flag
            self.rateLimited = YES;
            
            //err msg
            if(isVerbose) {
                printf("\nERROR (VirusTotal): rate limit / quota exhausted, skipping remaining lookups\n");
            }
            
            //alert (once)
            if(uiMode) {
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSAlert* alert = [[NSAlert alloc] init];
                        alert.messageText = NSLocalizedString(@"VirusTotal daily limit reached", @"VirusTotal daily limit reached");
                        alert.informativeText = NSLocalizedString(@"The public API's daily limit (500 lookups) has been reached, so the remaining items were not checked.", @"The public API's daily limit (500 lookups) has been reached, so the remaining items were not checked.");
                        [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
                        [alert runModal];
                    });
                });
            }
            
            break;
        }
        
        //back off, then retry
        [NSThread sleepForTimeInterval:retryDelay];
        
        //another (plugin's) lookup exhausted the quota while we slept?
        // no point retrying, mark as error & move on (so the 'awaiting results' phase ends promptly)
        if(YES == self.rateLimited) {
            [self markError:file uiMode:uiMode];
            break;
        }
        
        }//attempts
    }
    
    //all files done
    if(completion) completion();
    
    return;
}

//mark a file's VT lookup as failed, and notify the UI
// so its row resolves (shows an error), rather than staying 'pending' forever
-(void)markError:(File*)file uiMode:(BOOL)uiMode {
    
    //mark
    file.vtInfo = @{VT_ERROR:@YES};
    
    //notify UI
    if(uiMode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [((AppDelegate*)NSApplication.sharedApplication.delegate) itemProcessed:file];
        });
    }
    
    return;
}

//submit a file to VT
// completion callback invoked on error
- (void)submitFile:(NSString *)filePath completion:(void (^)(NSDictionary *result))completion {
    
    //load key
    NSString* vtAPIKey = loadAPIKeyFromKeychain();
    if(0 == vtAPIKey.length) {
        
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"API key is blank"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
        
    }
    
    //open file
    // must be a regular file (no devices, fifos, etc), 32MB or less (limit for regular endpoint)
    const off_t maxSize = 32 * 1024 * 1024; // 32MB
    off_t fileSize = 0;
    int fd = openRegularFile(filePath, maxSize, &fileSize);
    if (-1 == fd) {
        NSError *error = [NSError errorWithDomain:@"VirusTotal"
                                             code:-3
                                         userInfo:@{NSLocalizedDescriptionKey: @"File must be a regular file, 32MB or less (limit of VT endpoint)"}];
        //return w/ error
        completion(@{VT_ERROR:error});
        return;
    }
    
    //read file data
    // just what was stat'd, in case file is growing
    NSData *fileData = nil;
    @try {
        fileData = [[[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] readDataOfLength:(NSUInteger)fileSize];
    }
    @catch (NSException *exception) {
        fileData = nil;
    }
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

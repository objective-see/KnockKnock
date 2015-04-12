//
//  File.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import "File.h"
#import "Consts.h"
#import "Utilities.h"
#import "AppDelegate.h"

@implementation File

@synthesize path;
@synthesize name;
@synthesize plist;
@synthesize bundle;
@synthesize hashes;
@synthesize signingInfo;

@synthesize vtInfo;



//init method
-(id)initWithParams:(NSDictionary*)params
{
    //flag for directories
    BOOL isDirectory = NO;
    
    //super
    // ->saves path, etc
    self = [super initWithParams:params];
    if(self)
    {
        //always skip not-existent paths
        // ->also get set a directory flag at the same time ;)
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:params[KEY_RESULT_PATH] isDirectory:&isDirectory])
        {
            //err msg
            NSLog(@"OBJECTIVE-SEE ERROR: %@ not found", params[KEY_RESULT_PATH]);
            
            //set self to nil
            self = nil;
            
            //bail
            goto bail;
        }
        
        //if path is directory
        // ->treat is as a bundle
        if(YES == isDirectory)
        {
            //load bundle
            // ->save this into 'bundle' iVar
            if(nil == (bundle = [NSBundle bundleWithPath:params[KEY_RESULT_PATH]]))
            {
                //err msg
                NSLog(@"OBJECTIVE-SEE ERROR: couldn't create bundle for %@", params[KEY_RESULT_PATH]);
                
                //set self to nil
                self = nil;
                
                //bail
                goto bail;
            }
            
            //extract executable from bundle
            // ->save this into 'path' iVar
            if(nil == (self.path = self.bundle.executablePath))
            {
                //err msg
                //NSLog(@"OBJECTIVE-SEE ERROR: couldn't find executable in bundle %@", itemPath);
                
                //set self to nil
                self = nil;
                
                //bail
                goto bail;
            }
        }
        
        //save (optional) plist
        // ->ok if this is nil
        self.plist = params[KEY_RESULT_PLIST];

        //extract name
        self.name = [[self.path lastPathComponent] stringByDeletingPathExtension];
        
        //computes hashes
        // ->set 'md5' and 'sha1' iVars
        self.hashes = hashFile(self.path);
        
        //grab attributes
        self.attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
        
        //extract signing info
        self.signingInfo = extractSigningInfo(self.path);
        
        //call into filter object to check if file is known
        // ->apple-signed or whitelisted
        self.isTrusted = [((AppDelegate*)[[NSApplication sharedApplication] delegate]).filterObj isTrustedFile:self];
    }
           
//bail
bail:
    
    return self;
}

//get the virus total page for the item
// ->can return nil if its an unknown binary
-(NSURL*)getVirusTotalPage
{
    //virus total url
    NSURL* virusTotalURL = nil;
    
    
    return virusTotalURL;
}

//format the signing info dictionary
-(NSString*)formatSigningInfo
{
    //pretty print
    NSMutableString* prettyPrint = nil;
    
    //sanity check
    if(nil == self.signingInfo)
    {
        //bail
        goto bail;
    }
    
    //switch on signing status
    switch([self.signingInfo[KEY_SIGNATURE_STATUS] integerValue])
    {
        //unsigned
        case errSecCSUnsigned:
        {
            //set string
            prettyPrint = [NSMutableString stringWithString:@"unsigned"];
            
            //brk
            break;
        }
            
        //errSecCSSignatureFailed
        case errSecCSSignatureFailed:
        {
            //set string
            prettyPrint = [NSMutableString stringWithString:@"invalid signature"];
            
            //brk
            break;
        }
            
        //happily signed
        case STATUS_SUCCESS:
        {
            //init
            prettyPrint = [NSMutableString string];//stringWithString:@"signed by:"];
            
            //add each signing auth
            for(NSString* signingAuthority in self.signingInfo[KEY_SIGNING_AUTHORITIES])
            {
                //append
                [prettyPrint appendString:[NSString stringWithFormat:@"%@, ", signingAuthority]];
            }
            
            //remove last comma & space
            if(YES == [prettyPrint hasSuffix:@", "])
            {
                //remove
                [prettyPrint deleteCharactersInRange:NSMakeRange([prettyPrint length]-2, 2)];
            }
            
            //brk
            break;
        }
    
        //unknown
        default:
            
            //set string
            prettyPrint = [NSMutableString stringWithFormat:@"unknown (status/error: %ld)", (long)[self.signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
            
            //brk
            break;
    }
    
//bail
bail:
    
    return prettyPrint;
}

//convert object to JSON string
-(NSString*)toJSON
{
    //json string
    NSString *json = nil;
    
    //json data
    // ->for intermediate conversions
    NSData *jsonData = nil;
    
    //hashes
    NSString* fileHashes = nil;
    
    //signing info
    NSString* fileSigs = nil;
    
    //VT detection ratio
    NSString* vtDetectionRatio = nil;
    
    //convert hash dictionary
    jsonData = [NSJSONSerialization dataWithJSONObject:self.hashes options:kNilOptions error:NULL];
    if(nil != jsonData)
    {
        //convert to data to string
        fileHashes = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    //convert signing dictionary
    jsonData = [NSJSONSerialization dataWithJSONObject:self.signingInfo options:kNilOptions error:NULL];
    if(nil != jsonData)
    {
        //convert to data to string
        fileSigs = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    //init VT detection ratio
    vtDetectionRatio = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[self.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue], (unsigned long)[self.vtInfo[VT_RESULTS_TOTAL] unsignedIntegerValue]];
    
    //init json
    json = [NSString stringWithFormat:@"\"name\": \"%@\", \"path\": \"%@\", \"plist\": \"%@\", \"hashes\": %@, \"signature(s)\": %@, \"VT detection\": \"%@\"", self.name, self.path, self.plist, fileHashes, fileSigs, vtDetectionRatio];
    
    return json;
}


@end

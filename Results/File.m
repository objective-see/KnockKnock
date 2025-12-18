//
//  File.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import "File.h"
#import "MachO/MachO.h"
#import "consts.h"
#import "Signing.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//should query VT
extern BOOL queryVT;

@implementation File

@synthesize path;
@synthesize name;
@synthesize plist;
@synthesize bundle;
@synthesize hashes;
@synthesize isPacked;
@synthesize isEncrypted;
@synthesize signingInfo;

@synthesize vtInfo;

//init method
-(id)initWithParams:(NSDictionary*)params
{
    //flag for directories
    BOOL isDirectory = NO;
    
    //cs flags
    SecCSFlags flags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures;
    
    //mach-O parser
    MachO* machoParser = nil;
    
    //super
    // ->saves path, etc
    self = [super initWithParams:params];
    if(self)
    {
        //skip not-existent paths
        // ->but also now check if they are just short paths (e.g. 'bash')
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:self.path isDirectory:&isDirectory])
        {
            //might just be a 'short' path, like 'bash'
            // ->try resolve to full path, such as: /bin/bash
            self.path = which(self.path);
            
            //still not found?
            // ->ignore/bail...
            if( (nil == self.path) ||
                (YES != [[NSFileManager defaultManager] fileExistsAtPath:self.path]) )
            {
                //set self to nil
                self = nil;
                
                //bail
                goto bail;
            }
        }
        
        //if path is directory
        // ->treat is as a bundle
        if(YES == isDirectory)
        {
            //load bundle
            // ->save this into 'bundle' iVar
            if(nil == (bundle = [NSBundle bundleWithPath:self.path]))
            {
                //err msg
                //NSLog(@"ERROR: couldn't create bundle for %@", params[KEY_RESULT_PATH]);
                
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
                //NSLog(@"ERROR: couldn't find executable path in bundle %@", itemPath);
                
                //set self to nil
                self = nil;
                
                //bail
                goto bail;
            }
        }
        
        //save (optional) plist
        // ->ok if this is nil
        self.plist = params[KEY_RESULT_PLIST];

        //determine name
        self.name = [self determineName];
        
        //computes hashes
        self.hashes = hashFile(self.path);
        
        //grab attributes
        self.attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
        
        //extract signing info statically
        self.signingInfo = extractSigningInfo(0, self.path, flags);
        
        //call into filter object to check if file is known
        // apple-signed or whitelisted (hash or signing id)
        self.isTrusted = [itemFilter isTrustedFile:self];
        
        //alloc macho parser iVar
        // ->new instance for each file!
        machoParser = [[MachO alloc] init];
        
        //parse
        // ->also perform packed/encryption checks
        if(YES == [machoParser parse:self.path classify:YES])
        {
            //unset 'packed' flag for apple signed binaries
            // as apple doesn't pack binaries, but packer algo has some false positives
            if(Apple == [self.signingInfo[KEY_SIGNATURE_SIGNER] intValue])
            {
                //unset
                machoParser.binaryInfo[KEY_IS_PACKED] = @NO;
            }
            
            //set packed flag
            self.isPacked = [machoParser.binaryInfo[KEY_IS_PACKED] boolValue];
            
            //set encrypted flag
            self.isEncrypted = [machoParser.binaryInfo[KEY_IS_ENCRYPTED] boolValue];
        }
    }
           
bail:
    
    return self;
}

//determine name
// ->extra logic for apps (plists), etc
-(NSString*)determineName
{
    //name
    NSString* fileName =  nil;
    
    //try find bundle
    if(nil == self.bundle)
    {
        //find
        self.bundle = findAppBundle(self.path);
    }

    //try either 'CFBundleName' or 'CFBundleDisplayName' from Info.plist
    if( (nil != self.bundle) &&
        (nil != self.bundle.infoDictionary) )
    {
        //default to 'CFBundleName'
        if(nil != [self.bundle.infoDictionary objectForKey:@"CFBundleName"])
        {
            //set
            fileName = [self.bundle.infoDictionary objectForKey:@"CFBundleName"];
        }
        //otherwise use 'CFBundleDisplayName'
        else if(nil != [self.bundle.infoDictionary objectForKey:@"CFBundleDisplayName"])
        {
            //set
            fileName = [self.bundle.infoDictionary objectForKey:@"CFBundleDisplayName"];
        }
    }
    
    //no bundle or file name extaction failed
    // ->use from path
    if(nil == fileName)
    {
        //from path
        fileName = [self.path lastPathComponent];
        //[[self.path lastPathComponent] stringByDeletingPathExtension];
    }

    return fileName;
}

//format the signing info dictionary
-(NSString*)formatSigningInfo
{
    //flag
    BOOL isNotarized = NO;
    
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
            
            //adhoc
            if(AdHoc == [self.signingInfo[KEY_SIGNATURE_SIGNER] unsignedIntValue])
            {
                //append to details
                [prettyPrint appendString:NSLocalizedString(@"Ad-hoc", @"Ad-hoc")];
                
                //done
                break;
            }
            
            //add each signing auth
            for(NSString* signingAuthority in self.signingInfo[KEY_SIGNATURE_AUTHORITIES])
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
            
            //for dev id items
            // add notarization
            if(DevID == [self.signingInfo[KEY_SIGNATURE_SIGNER] intValue])
            {
                //extract
                isNotarized = [self.signingInfo[KEY_SIGNATURE_IS_NOTARIZED] boolValue];
                
                //append notarization status
                [prettyPrint appendString:[NSString stringWithFormat:NSLocalizedString(@" (Notarized: %@)", @" (Notarized: %@)"), (YES == isNotarized) ? NSLocalizedString(@"Yes",@"Yes") : NSLocalizedString(@"No",@"No")]];
            }
            
            break;
        }
    
        //unknown
        default:
            
            //set string
            prettyPrint = [NSMutableString stringWithFormat:@"unknown (status/error: %ld)", (long)[self.signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
            
            //brk
            break;
    }
    
bail:
    
    return prettyPrint;
}

//convert obj to JSON
-(NSString*)toJSON
{
    NSData* jsonData = nil;
    NSString* json = nil;
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    //basic fields
    dict[@"name"] = self.name ?: @"unknown";
    dict[@"path"] = self.path ?: @"unknown";
    dict[@"plist"] = self.plist ?: @"n/a";
    
    //hashes
    dict[@"hashes"] = self.hashes ?: @"unknown";
    
    //signing info
    dict[@"signature(s)"] = self.signingInfo ?: @"unknown";
    
    //include VT?
    if(queryVT) {
    
        dict[@"VT detection"] = [NSString stringWithFormat:@"%lu/%lu",
                                     (unsigned long)[self.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue],
                                     (unsigned long)[self.vtInfo[VT_RESULTS_TOTAL] unsignedIntegerValue]];
    }
    
    //serialize
    @try
    {
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:NULL];
        if(jsonData) {
            json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    @catch(NSException* exception)
    {
        json = @"{\"error\": \"serialization failed\"}";
    }
    
    return json ?: @"{\"error\": \"serialization failed\"}";
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"name: %@, path: %@, plist: %@, hashes: %@, signature(s): %@, VT detection: %@", self.name, self.path, self.plist, self.hashes, self.signingInfo, self.vtInfo];
}


@end

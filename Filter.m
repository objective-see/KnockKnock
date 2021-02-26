//
//  Filter.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/21/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import "Consts.h"
#import "Filter.h"
#import "Utilities.h"

@implementation Filter

@synthesize trustedKexts;
@synthesize trustedFiles;
@synthesize knownCommands;
@synthesize trustedExtensions;

#define SOFTWARE_SIGNING @"Software Signing"
#define APPLE_SIGNING_AUTH @"Apple Code Signing Certification Authority"
#define APPLE_ROOT_CA @"Apple Root CA"

//init
-(id)init
{
    //super
    self = [super init];
    if(self)
    {
        //load known file hashes
        self.trustedFiles = [self loadWhitelist:WHITE_LISTED_FILES];
        
        //load known commands
        self.knownCommands = [self loadWhitelist:WHITE_LISTED_COMMANDS];
        
        //load known extensions
        self.trustedExtensions = [self loadWhitelist:WHITE_LISTED_EXTENSIONS];
        
        //load known kexts
        self.trustedKexts = [self loadWhitelist:WHITE_LISTED_KEXTS];
    }
    
    return self;
}


//load a (JSON) white list
// ->file hashes, known commands, etc
-(NSDictionary*)loadWhitelist:(NSString*)fileName
{
    //whitelisted data
    NSDictionary* whiteList = nil;
    
    //path
    NSString* path = nil;
    
    //error var
    NSError *error = nil;
    
    //json data
    NSData* whiteListJSON = nil;
    
    //init path
    path = [[NSBundle mainBundle] pathForResource:fileName ofType: @"json"];
    
    //load whitelist file data
    whiteListJSON = [NSData dataWithContentsOfFile:path];
    
    //convert JSON into dictionary
    whiteList = [NSJSONSerialization JSONObjectWithData:whiteListJSON options:kNilOptions error:&error];
    
    return whiteList;
}


//check if a File obj is known
// ->whitelisted *or* signed by apple
-(BOOL)isTrustedFile:(File*)file
{
    //flag
    BOOL isTrusted = NO;
    
    //known hashes for file name
    NSArray* knownHashes = nil;
    
    //lookup based on name
    knownHashes = self.trustedFiles[file.path];
    
    //check if hash is known
    if( (nil != knownHashes) &&
        (YES == [knownHashes containsObject:[file.hashes[KEY_HASH_MD5] lowercaseString]]) )
    {
        //got match
        isTrusted = YES;
        
        //bail
        goto bail;
    }
    
    //if kext
    // check if trusted (apple, or 3rd-party, ships with OS)
    if( (YES == [file.path hasPrefix:@"/Library/Extensions/"]) ||
        (YES == [file.path hasPrefix:@"/System/Library/Extensions/"]) )
    {
        //check
        isTrusted = [self isTrustedKext:file];
        
        //bail
        goto bail;
    }
    
    //finally, then check if its signed by apple
    // note: apple-signed files are always trusted
    isTrusted = (Apple == [file.signingInfo[KEY_SIGNATURE_SIGNER] intValue]);
    
bail:
    
    return isTrusted;
}

//check if a Command obj is whitelisted
-(BOOL)isKnownCommand:(Command*)commandObj
{
    //flag
    BOOL isKnown = NO;
    
    return isKnown;
}

//check if a Extension obj is whitelisted
-(BOOL)isTrustedExtension:(Extension*)extensionObj
{
    //flag
    BOOL isTrusted = NO;
    
    //check if extension ID is known/trusted
    if(nil != self.trustedExtensions[extensionObj.identifier])
    {
        //trusted
        isTrusted = YES;
    }
    
    return isTrusted;
}

//check if a kext obj is known
// whitelisted *or* signed by apple
-(BOOL)isTrustedKext:(File*)file
{
    //flag
    BOOL isTrusted = NO;
    
    //(trusted) signing id
    // either list of hashes, or dev id
    id whitelistInfo = nil;
    
    //ignore any signing issues
    if(noErr != [file.signingInfo[KEY_SIGNATURE_STATUS] intValue]) goto bail;
    
    //lookup based on name
    whitelistInfo = self.trustedKexts[file.path];

    //dev id?
    if( (YES == [((NSArray*)whitelistInfo).firstObject hasPrefix:@"Developer ID Application"]) &&
        (YES == [[file.signingInfo[KEY_SIGNATURE_AUTHORITIES] lastObject] isEqualToString:@"Apple Root CA"]) )
    {
        //check
        isTrusted = [whitelistInfo containsObject:[file.signingInfo[KEY_SIGNATURE_AUTHORITIES] firstObject]];
        if(YES == isTrusted) goto bail;
    }
    //hash
    else
    {
        isTrusted = [whitelistInfo containsObject:[file.hashes[KEY_HASH_MD5] lowercaseString]];
        if(YES == isTrusted) goto bail;
    }
    
    //check for apple signature
    // kexts that belong to apple, are trusted
    isTrusted = (Apple == [file.signingInfo[KEY_SIGNATURE_SIGNER] intValue]);
    
bail:
    
    return isTrusted;
}


@end

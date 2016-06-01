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
-(BOOL)isTrustedFile:(File*)fileObj
{
    //flag
    BOOL isTrusted = NO;
    
    //known hashes for file name
    NSArray* knownHashes = nil;
    
    //lookup based on name
    knownHashes = self.trustedFiles[fileObj.path];
    
    //first check if hash is known
    if( (nil != knownHashes) &&
        (YES == [knownHashes containsObject:[fileObj.hashes[KEY_HASH_MD5] lowercaseString]]) )
    {
        //got match
        isTrusted = YES;
    }
    //otherwise check if its signed by apple
    // ->apple-signed files are always trusted
    else
    {
        //check for apple signature
        isTrusted = [fileObj.signingInfo[KEY_SIGNING_IS_APPLE] boolValue];
    }
    
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


@end

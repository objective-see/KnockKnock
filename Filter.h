//
//  Filter.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/21/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import "Results/File.h"
#import "Results/Command.h"
#import "Results/Extension.h"

#import <Foundation/Foundation.h>

@interface Filter : NSObject
{
    
}

//white listed file hashes
@property(nonatomic, retain)NSDictionary* trustedFiles;

//white listed commands
@property(nonatomic, retain)NSDictionary* knownCommands;

//white listed extensions
@property(nonatomic, retain)NSDictionary* trustedExtensions;

//white listed kexts
@property(nonatomic, retain)NSDictionary* trustedKexts;

/* METHODS */

//load a (JSON) white list
// ->file hashes, known commands, etc
-(NSDictionary*)loadWhitelist:(NSString*)fileName;

//check if a File obj is white listed
-(BOOL)isTrustedFile:(File*)fileObj;

//check if a Command obj is white listed
-(BOOL)isKnownCommand:(Command*)commandObj;

//check if a Extension obj is white listed
-(BOOL)isTrustedExtension:(Extension*)extensionObj;

//check if kext is white listed
-(BOOL)isTrustedKext:(File*)fileObj;

@end

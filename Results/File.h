//
//  File.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "ItemBase.h"
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface File : ItemBase
{
    
}

/* PROPERTIES */

//name
@property(nonatomic, retain)NSString* name;

//path
@property(nonatomic, retain)NSString* path;

//plist
@property(nonatomic, retain)NSString* plist;

//bundle
@property(nonatomic, retain)NSBundle* bundle;

//hashes (md5, sha1)
@property(nonatomic, retain)NSDictionary* hashes;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

//is packed
@property BOOL isPacked;

//is encrypted
@property BOOL isEncrypted;

/* VIRUS TOTAL INFO */

//dictionary returned by VT
@property (nonatomic, retain)NSDictionary* vtInfo;


/* METHODS */

//init method
-(id)initWithParams:(NSDictionary*)params;

//determine name
// ->extra logic for apps (plists), etc
-(NSString*)determineName;

//format the signing info dictionary
-(NSString*)formatSigningInfo;


@end

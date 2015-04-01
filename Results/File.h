//
//  File.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
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

/* VIRUS TOTAL INFO */

//dictionary returned by VT
@property (nonatomic, retain)NSDictionary* vtInfo;


/* METHODS */

//init method
//-(id)initWithParams:(NSString*)filePath plist:(NSString*)filePlist;

//get the virus total page for the item
// ->can return nil if its an unknown binary
-(NSURL*)getVirusTotalPage;

//format the signing info dictionary
-(NSString*)formatSigningInfo;


@end

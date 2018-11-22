//
//  PlistWindowController.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlistWindowController : NSWindowController

//(path to) plist
@property(nonatomic, retain)NSString* plist;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

//plist contents
@property (unsafe_unretained) IBOutlet NSTextView *contents;

//plist path
@property (weak) IBOutlet NSTextField *path;

@end

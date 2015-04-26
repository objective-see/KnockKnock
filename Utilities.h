//
//  Utilities.h
//  DHS
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef DHS_Utilities_h
#define DHS_Utilities_h


//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path);


/* METHODS */

//check if OS is supported
BOOL isSupportedOS();

//get OS's major or minor version
SInt32 getVersion(OSType selector);

//if string is too long to fit into a the text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, NSString* string, float width);

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate);

//hash (sha1/md5) a file
NSDictionary* hashFile(NSString* filePath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path);

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url);

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path);

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

#endif

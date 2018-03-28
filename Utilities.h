//
//  Utilities.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef KnockKnock_Utilities_h
#define KnockKnock_Utilities_h

/* METHODS */

//check if OS is supported
BOOL isSupportedOS(void);

//get OS's major or minor version
SInt32 getVersion(OSType selector);

//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path);

//if string is too long to fit into a the text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, NSString* string, float width);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle);

//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate);

//hash (sha1/md5) a file
NSDictionary* hashFile(NSString* filePath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url);

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path);

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController);

//check if computer has network connection
BOOL isNetworkConnected(void);

//escape \ and "s in a string
NSString* escapeString(NSString* unescapedString);

//find a constraint (by name) of a view
NSLayoutConstraint* findConstraint(NSView* view, NSString* constraintName);

//check if app is pristine
// ->that is to say, nobody modified on-disk image/resources (white lists!, etc)
OSStatus verifySelf(void);

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName);

//get array of running procs
// ->returns an array of process paths
NSMutableArray* runningProcesses(void);

//check if a file is an executable
BOOL isURLExecutable(NSURL* file);

//lookup object in dictionary
// note: key can be case-insensitive
id extractFromDictionary(NSDictionary* dictionary, NSString* sensitiveKey);

#endif

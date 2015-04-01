//
//  Utilities.h
//  DHS
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#ifndef DHS_Utilities_h
#define DHS_Utilities_h


//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path);


/* METHODS */

//if string is too long to fit into a the text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, NSString* string, float width);

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//covert a time interval to a 'pretty' string
NSString* getTimeRepresentationFromDate(NSDate* iDate, NSTimeInterval iTimeInterval);

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

#endif

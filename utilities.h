//
//  utilities.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef KnockKnock_Utilities_h
#define KnockKnock_Utilities_h

/* FUNCTIONS */

//get OS's major or minor version
SInt32 getVersion(OSType selector);

//disable std err
void disableSTDERR(void);

//get name of logged in user
NSString* getConsoleUser(void);

//get uid of logged in user
// returns 0 (root) if there's no console user
uid_t getConsoleUserID(void);

//get home directory of logged in user
// falls back to (our own) home directory
NSString* getConsoleUserHome(void);

/* PREFERENCES */
// when running as root (e.g. relaunched via admin auth), these read/write the *console user's* preferences
// (via CFPreferences, which root may do for any user), rather than root's; otherwise they use NSUserDefaults

//registered defaults
NSDictionary* preferenceDefaults(void);

//get a preference (or its registered default)
id getPreference(NSString* key);

//get a (bool) preference (or its registered default)
BOOL getPreferenceBool(NSString* key);

//set a preference
void setPreference(NSString* key, id value);

//get all users
NSMutableDictionary* allUsers(void);

//give a list of paths
// convert any `~` to all or current user
NSMutableArray* expandPaths(const __strong NSString* const paths[], int count);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle);

//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate);

//open a regular file for reading
// returns fd, or -1 if path can't be opened, isn't a regular file (device, fifo, etc), or exceeds max size
// note: opens w/ O_NONBLOCK (so never blocks on a fifo) and checks via fstat (so no race between check & open)
int openRegularFile(NSString* path, off_t maxSize, off_t* size);

//hash a file
NSDictionary* hashFile(NSString* filePath);

//get launchd's overrides (i.e. 'launchctl enable/disable' state)
// returns dictionary of label -> @YES (disabled) / @NO (explicitly enabled)
// note: when root, merges all users' overrides; when a label conflicts across users, 'enabled' wins (so item is reported)
NSDictionary* launchdOverrides(void);

//coerce an (untrusted) object to a string
// strings are returned as is, nil stays nil, anything else (arrays, numbers, etc.) becomes its description
NSString* stringValue(id object);

//coerce an (untrusted) object to a bool
// numbers (incl. bools) are evaluated; anything else (nil, strings, arrays, null, etc.) is NO
// note: 'boolValue' on a dictionary/array/NSNull throws, and plist/JSON values from user-writable files can be any type
BOOL boolValue(id object);

//convert an object (e.g. plist) into something NSJSONSerialization can serialize
// data/dates/etc. become strings, non-finite numbers & overly nested objects become descriptions
id makeJSONSafe(id object);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url);

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments, int* exitCode);

//exec a process (as the console user, when we're root) and grab it's output
// for per-user tools (e.g. pluginkit), whose output as root would be root's (empty) view
NSData* execTaskAsConsoleUser(NSString* binaryPath, NSArray* arguments, int* exitCode);

//check if computer has network connection
BOOL isNetworkConnected(void);

//find a constraint (by name) of a view
NSLayoutConstraint* findConstraint(NSView* view, NSString* constraintName);

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName);

//get array of running procs
// ->returns an array of process paths
NSMutableArray* runningProcesses(void);

//check if a file is a binary
BOOL isBinary(NSString* file);

//lookup object in dictionary
// note: key can be case-insensitive
id extractFromDictionary(NSDictionary* dictionary, NSString* sensitiveKey);

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled (per the app's effective appearance)
BOOL isDarkMode(void);

//adopt the console user's appearance (light/dark)
// needed when running as root (e.g. relaunched via admin auth), as root's own defaults have no appearance set
void adoptConsoleUserAppearance(void);

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location);

//set line space
void setLineSpacing(NSTextField* textField, CGFloat lineSpacing);

//check for full disk access
BOOL hasFDA(void);

//save (user's) VT API key to keyhain
BOOL saveAPIKeyToKeychain(NSString* apiKey);

//(re)load key from
NSString* loadAPIKeyFromKeychain(void);

//file protected by SIP?
BOOL isRestricted(const char *path);

//toggle login item
// either add (install) or remove (uninstall); returns YES on success
BOOL toggleLoginItem(NSURL* loginItem, NSControlStateValue state);

//build AppleScript that (re)launches an executable (with arguments) as root
// via 'do shell script ... with administrator privileges'
NSString* authorizationScript(NSString* executablePath, NSArray<NSString*>* arguments, NSString* prompt);

//relaunch ourselves as root
// prompts user to authenticate, and returns pid of new (root) instance, or -1 on error
pid_t relaunchAsRoot(NSError** error);

//wait for an instance of this app (via pid) to start
// returns YES if it started within timeout, NO otherwise
BOOL waitForApplication(pid_t pid, NSTimeInterval timeout);

#endif

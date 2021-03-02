//
//  Utilities.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"

#import <libproc.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreServices/CoreServices.h>
#import <Collaboration/Collaboration.h>
#import <SystemConfiguration/SystemConfiguration.h>

//get OS's major or minor version
SInt32 getVersion(OSType selector)
{
    //version
    // ->major or minor
    SInt32 version = -1;
    
    //get version info
    if(noErr != Gestalt(selector, &version))
    {
        //reset version
        version = -1;
        
        //err
        goto bail;
    }
    
bail:
    
    return version;
}


//disable std err
void disableSTDERR()
{
    //file handle
    int devNull = -1;
    
    //open /dev/null
    devNull = open("/dev/null", O_RDWR);
    
    //dup
    dup2(devNull, STDERR_FILENO);
    
    //close
    close(devNull);
    
    return;
}

//get name of logged in user
NSString* getConsoleUser()
{
    //copy/return user
    return CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL));
}

//get all user
// includes name/home directory
NSMutableDictionary* allUsers()
{
    //users
    NSMutableDictionary* users = nil;
    
    //query
    CSIdentityQueryRef query = nil;
    
    //query results
    CFArrayRef results = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //identiry
    CBIdentity* identity = NULL;
    
    //home directory for user
    NSString* userDirectory = nil;
    
    //alloc dictionary
    users = [NSMutableDictionary dictionary];
    
    //init query
    query = CSIdentityQueryCreate(NULL, kCSIdentityClassUser, CSGetLocalIdentityAuthority());
    
    //exec query
    if(true != CSIdentityQueryExecute(query, 0, &error))
    {
        //bail
        goto bail;
    }
    
    //grab results
    results = CSIdentityQueryCopyResults(query);
    
    //process all results
    // add user and home directory
    for (int i = 0; i < CFArrayGetCount(results); ++i)
    {
        //grab identity
        identity = [CBIdentity identityWithCSIdentity:(CSIdentityRef)CFArrayGetValueAtIndex(results, i)];
        
        //skip blank users
        if(0 == identity.posixName.length) continue;
        
        //get user's home directory
        // skip any that are blank/nil
        userDirectory = NSHomeDirectoryForUser(identity.posixName);
        if(0 == userDirectory.length) continue;
        
        //add user
        users[identity.UUIDString] = @{USER_NAME:identity.posixName, USER_DIRECTORY:userDirectory};
    }

bail:
    
    //release results
    if(NULL != results)
    {
        //release
        CFRelease(results);
    }
    
    //release query
    if(NULL != query)
    {
        //release
        CFRelease(query);
    }

    return users;
}

//give a list of paths
// convert any `~` to all or current user
NSMutableArray* expandPaths(const __strong NSString* const paths[], int count)
{
    //expanded paths
    NSMutableArray* expandedPaths = nil;
    
    //(current) path
    const NSString* path = nil;
    
    //all users
    NSMutableDictionary* users = nil;
    
    //grab all users
    users = allUsers();
    
    //alloc list
    expandedPaths = [NSMutableArray array];
    
    //iterate/expand
    for(NSInteger i = 0; i < count; i++)
    {
        //grab path
        path = paths[i];
        
        //no `~`?
        // just add and continue
        if(YES != [path hasPrefix:@"~"])
        {
            //add as is
            [expandedPaths addObject:path];
            
            //next
            continue;
        }
        
        //handle '~' case
        // root? add each user
        if(0 == geteuid())
        {
            //add each user
            for(NSString* user in users)
            {
                [expandedPaths addObject:[users[user][USER_DIRECTORY] stringByAppendingPathComponent:[path substringFromIndex:1]]];
            }
        }
        //otherwise
        // just convert to current user
        else
        {
            [expandedPaths addObject:[path stringByExpandingTildeInPath]];
        }
    }
        
    return expandedPaths;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
           (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
        //scan until we get to root
        // ->of course, loop will be exited if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* icon = nil;
    
    //no bundle?
    // try find one
    if(nil == bundle)
    {
        //load bundle
        bundle = findAppBundle(binary);
    }
    
    //for app's
    // extract their icon
    if(nil != bundle)
    {
        //get file
        iconFile = bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process not app or couldn't get icon
    // try to get it via shared workspace...
    if( (nil == bundle) ||
        (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:binary];
        
        //'iconForFileType' returns small icons
        //  so set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
    }
    
    return icon;
}


//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate)
{
    //(unfiltered) directory contents
    NSArray* directoryContents = nil;
    
    //matches
    NSArray* matches = nil;
    
    //sanity check
    if(0 == [directory length])
    {
        //bail
        goto bail;
    }
    
    //get (unfiltered) directory contents
    directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    
    //filter out matches
    if(nil != predicate)
    {
        //filter
        matches = [directoryContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:predicate]];
    }
    //no need to filter
    else
    {
        //no filter
        matches = directoryContents;
    }

//bail
bail:
    
    return matches;
}

//hash a file
// ->md5 and sha1
NSDictionary* hashFile(NSString* filePath)
{
    //file hashes
    NSDictionary* hashes = nil;
    
    //file's contents
    NSData* fileContents = nil;
    
    //hash digest (md5)
    uint8_t digestMD5[CC_MD5_DIGEST_LENGTH] = {0};
    
    //md5 hash as string
    NSMutableString* md5 = nil;
    
    //hash digest (sha1)
    uint8_t digestSHA1[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha1 = nil;
    
    //index var
    NSUInteger index = 0;
    
    //init md5 hash string
    md5 = [NSMutableString string];
    
    //init sha1 hash string
    sha1 = [NSMutableString string];
    
    //load file
    if(nil == (fileContents = [NSData dataWithContentsOfFile:filePath]))
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: couldn't load %@ to hash", filePath);
        
        //bail
        goto bail;
    }
    
    //md5 it
    CC_MD5(fileContents.bytes, (unsigned int)fileContents.length, digestMD5);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_MD5_DIGEST_LENGTH; index++)
    {
        //format/append
        [md5 appendFormat:@"%02lX", (unsigned long)digestMD5[index]];
    }
    
    //sha1 it
    CC_SHA1(fileContents.bytes, (unsigned int)fileContents.length, digestSHA1);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_SHA1_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha1 appendFormat:@"%02lX", (unsigned long)digestSHA1[index]];
    }
    
    //init hash dictionary
    hashes = @{KEY_HASH_MD5: md5, KEY_HASH_SHA1: sha1};
    
//bail
bail:
    
    return hashes;
}

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url)
{
    //hyperlink
    NSMutableAttributedString *hyperlinkString = nil;
    
    //range
    NSRange range = {0};
    
    //init hyper link
    hyperlinkString = [[NSMutableAttributedString alloc] initWithString:textField.stringValue];
    
    //init range
    range = NSMakeRange(0, [hyperlinkString length]);
   
    //start editing
    [hyperlinkString beginEditing];
    
    //add url
    [hyperlinkString addAttribute:NSLinkAttributeName value:url range:range];
    
    //make it blue
    [hyperlinkString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:NSMakeRange(0, [hyperlinkString length])];
    
    //underline
    [hyperlinkString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:NSMakeRange(0, [hyperlinkString length])];
    
    //done editing
    [hyperlinkString endEditing];
    
    //set text
    [textField setAttributedStringValue:hyperlinkString];
    
    return;
}

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color)
{
    //colored string
    NSMutableAttributedString *coloredString = nil;

    //alloc/init colored string from existing one
    coloredString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    
    //set color
    [coloredString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [coloredString length])];
    
    return coloredString;
}

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments)
{
    //task
    NSTask* task = nil;
    
    //output pipe
    NSPipe *outPipe = nil;
    
    //read handle
    NSFileHandle* readHandle = nil;
    
    //output
    NSMutableData* output = nil;
    
    //init task
    task = [NSTask new];
    
    //init output pipe
    outPipe = [NSPipe pipe];
    
    //init read handle
    readHandle = [outPipe fileHandleForReading];
    
    //init output buffer
    output = [NSMutableData data];
    
    //set task's path
    [task setLaunchPath:binaryPath];
    
    //set task's args
    [task setArguments:arguments];
    
    //set task's output
    [task setStandardOutput:outPipe];
    
    //ignore stderr
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    
    //wrap task launch
    // ->can throw exception if binary path not found, etc
    @try{
        
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }

    //read in output
    while(YES == [task isRunning])
    {
        //accumulate output
        [output appendData:[readHandle readDataToEndOfFile]];
    }
    
    //grab any left over data
    [output appendData:[readHandle readDataToEndOfFile]];
    
bail:
    
    return output;
}

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController)
{
    //flag
    __block BOOL madeModal = NO;
    
    //wait up to 1 second window to be non-nil
    // ->then make modal
    for(int i=0; i<20; i++)
    {
        //nap
        [NSThread sleepForTimeInterval:0.05f];
        
        //make modal on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //can make it modal once we have a window
            if(nil != windowController.window)
            {
                //modal
                [[NSApplication sharedApplication] runModalForWindow:windowController.window];
        
                //set flag
                madeModal = YES;
            }
        });
        
        //done?
        if(YES == madeModal) break;
        
    }//until 1 second
    
    return;
}


//check if computer has network connection
BOOL isNetworkConnected()
{
    //flag
    BOOL isConnected = NO;
    
    //sock addr stuct
    struct sockaddr zeroAddress = {0};
    
    //reachability ref
    SCNetworkReachabilityRef reachabilityRef = NULL;
    
    //reachability flags
    SCNetworkReachabilityFlags flags = 0;
    
    //reachable flag
    BOOL isReachable = NO;
    
    //connection required flag
    BOOL connectionRequired = NO;
    
    //ensure its cleared out
    bzero(&zeroAddress, sizeof(zeroAddress));
    
    //set size
    zeroAddress.sa_len = sizeof(zeroAddress);
    
    //set family
    zeroAddress.sa_family = AF_INET;
    
    //create reachability ref
    reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)&zeroAddress);
    
    //sanity check
    if(NULL == reachabilityRef)
    {
        //bail
        goto bail;
    }
    
    //get flags
    if(TRUE != SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        //bail
        goto bail;
    }
    
    //set reachable flag
    isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
    
    //set connection required flag
    connectionRequired = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
    
    //finally
    // ->determine if network is available
    isConnected = (isReachable && !connectionRequired) ? YES : NO;
    
//bail
bail:

    //cleanup
    if(NULL != reachabilityRef)
    {
        //release
        CFRelease(reachabilityRef);
    }
    
    return isConnected;
}

//escape \ and "s in a string
NSString* escapeString(NSString* unescapedString)
{
    //return string
    NSMutableString *escapedString = nil;
    
    //char
    unichar c = 0;
    
    //alloc escaped string
    escapedString = [[NSMutableString alloc] init];
    
    //check each char
    // ->escape as needed
    for(int i = 0; i < [unescapedString length]; i++) {
        
        //grab char
        c = [unescapedString characterAtIndex:i];
        
        //escape chars
        if( ('\'' == c) ||
            ('"' == c) )
        {
            //escape
            [escapedString appendFormat:@"\\%c", c];
        }
        //no need to escape
        else
        {
            //use as is
            [escapedString appendFormat:@"%c", c];
        }
    }
    
    return escapedString;
}

//find a constraint (by name) of a view
NSLayoutConstraint* findConstraint(NSView* view, NSString* constraintName)
{
    //constraint
    NSLayoutConstraint* constraint = nil;
    
    //iterate over all view
    for(NSLayoutConstraint* currentConstraint in view.constraints)
    {
        //find item path's constraint
        if(YES == [currentConstraint.identifier isEqualToString:constraintName])
        {
            //save constraint
            constraint = currentConstraint;
            
            //bail
            break;
        }
    }
    
    return constraint;
}

//check if app is pristine
// ->that is to say, nobody modified on-disk image/resources (white lists!, etc)
OSStatus verifySelf()
{
    //status
    OSStatus status = !noErr;
    
    //sec ref (for self)
    SecCodeRef secRef = NULL;
    
    //get sec ref to self
    status = SecCodeCopySelf(kSecCSDefaultFlags, &secRef);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
   
    //validate
    status = SecStaticCodeCheckValidity(secRef, kSecCSDefaultFlags, NULL);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
//bail
bail:
    
    //release sec ref
    if(NULL != secRef)
    {
        //release
        CFRelease(secRef);
    }
    
    return status;
}

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName)
{
    //full path
    NSString* fullPath = nil;
    
    //get path
    NSString* path = nil;
    
    //tokenized paths
    NSArray* pathComponents = nil;
    
    //candidate file
    NSString* candidateBinary = nil;
    
    //get path
    path = [[[NSProcessInfo processInfo]environment]objectForKey:@"PATH"];
    
    //split on ':'
    pathComponents = [path componentsSeparatedByString:@":"];
    
    //iterate over all path components
    // ->build candidate path and check if it exists
    for(NSString* pathComponent in pathComponents)
    {
        //build candidate path
        // ->current path component + process name
        candidateBinary = [pathComponent stringByAppendingPathComponent:processName];
        
        //check if it exists
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:candidateBinary])
        {
            //check its executable
            if(YES == [[NSFileManager defaultManager] isExecutableFileAtPath:candidateBinary])
            {
                //ok, happy now
                fullPath = candidateBinary;
                
                //stop processing
                break;
            }
        }
        
    }//for path components
    
    return fullPath;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* taskPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        taskPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // ->try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ->ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        // ->at start of buffer
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // ->follows # of args (int) and is NULL-terminated
        taskPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
//bail
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return taskPath;
}

//get array of running procs
// ->returns an array of process paths
NSMutableArray* runningProcesses()
{
    //running procs
    NSMutableArray* processes = nil;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //alloc array
    processes = [NSMutableArray array];
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    if(proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t)) < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get name
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
           (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //add to array
        [processes addObject:processPath];
    }
    
    //remove dups
    processes = [[[NSSet setWithArray:processes] allObjects] mutableCopy];
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return processes;
}

//check if a file is an executable
BOOL isExecutable(NSString* file)
{
    //return
    BOOL isExecutable = NO;
    
    //architecture ref
    CFArrayRef archArrayRef = NULL;
    
    //get executable arch's
    archArrayRef = CFBundleCopyExecutableArchitecturesForURL((__bridge CFURLRef)[NSURL fileURLWithPath:file]);
    
    //check arch for i386/x6_64
    if(NULL != archArrayRef)
    {
        //set flag
        isExecutable = [(__bridge NSArray*)archArrayRef containsObject:[NSNumber numberWithInt:kCFBundleExecutableArchitectureX86_64]] || [(__bridge NSArray*)archArrayRef containsObject:[NSNumber numberWithInt:kCFBundleExecutableArchitectureI386]];
    }
    
    //free arch ref
    if(NULL != archArrayRef)
    {
        //free
        CFRelease(archArrayRef);
    }
    
    return isExecutable;
}

//lookup object in dictionary
// note: key can be case-insensitive
id extractFromDictionary(NSDictionary* dictionary, NSString* sensitiveKey)
{
    //object
    __block id object;
    
    //look for key
    [dictionary enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
      usingBlock:^(id key, id obj, BOOL *stop)
      {
          //(case insenstive) match?
          if( (YES == [key isKindOfClass:[NSString class]]) &&
              (NSOrderedSame == [(NSString*)key caseInsensitiveCompare:sensitiveKey]) )
          {
            object = obj;
            *stop = YES;
          }
    }];
    
    return object;
}

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode()
{
    //flag
    BOOL darkMode = NO;
    
    //not mojave?
    // bail, since not true dark mode
    if(YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 14, 0}])
    {
        //bail
        goto bail;
    }
    
    //not dark mode?
    if(YES != [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"])
    {
        //bail
        goto bail;
    }
    
    //ok, mojave dark mode it is!
    darkMode = YES;
    
bail:
    
    return darkMode;
}

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location)
{
    //process serial no
    ProcessSerialNumber processSerialNo;
    
    //init process stuct
    // ->high to 0
    processSerialNo.highLongOfPSN = 0;
    
    //init process stuct
    // ->low to self
    processSerialNo.lowLongOfPSN = kCurrentProcess;
    
    //transform to foreground
    TransformProcessType(&processSerialNo, location);
    
    return;
}

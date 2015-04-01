//
//  Scanner.m
//  DHS
//
//  Created by Patrick Wardle on 2/4/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import <libproc.h>
#import <sys/proc_info.h>
#import <mach-o/loader.h>

#import "Consts.h"
#import "Binary.h"
#import "Scanner.h"
#import "Utilities.h"
#import "AppDelegate.h"


@implementation Scanner

@synthesize doFullScan;
@synthesize machoParser;
@synthesize scannedBinaries;
@synthesize scan4WeakHijackers;


//init
// ->sets scanner options
-(id)initWithOptions:(NSDictionary*)options
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        scannedBinaries = [NSMutableArray array];
        
        //extract flag for full scan
        self.doFullScan = [options[KEY_SCANNER_FULL] boolValue];
        
        //extract flag for hijack scanner options
        self.scan4WeakHijackers = [options[KEY_SCANNER_WEAK_HIJACKERS] boolValue];
    }
    
    return self;
}

//do scan!
-(void)scan
{
    //full scan?
    // ->yes: get all binaries on file system
    if(YES == self.doFullScan)
    {
        //dbg msg
        NSLog(@"scanning *all* binaries on file system");
        
        //get all binaries on file system
        [self scanBinariesFileSys];
    }
    
    //full scan?
    // ->no: get binaries from process list
    else
    {
        //dbg msg
        NSLog(@"getting binaries from process list");
        
        //get binaries from process list
        [self scanBinariesProcList];
    }
    
    //dbg msg
    NSLog(@"scan complete!");

    return;
}

//get/scan all binaries on file system
-(void)scanBinariesFileSys
{
    //directory enumerator
    NSDirectoryEnumerator *enumerator = nil;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //init enumerator
    enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:@"/"]
                   includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey] options:0
                   errorHandler:^BOOL(NSURL *url, NSError *error)
                   {
                       //ignore errors
                       return YES;
                   }];
    
    //iterate over all files
    // ->save all executable binaries
    for(NSURL *fileURL in enumerator)
    {
        //ensure that memory cleanup happens after each binary
        // ->helps keep memory usage in check
        @autoreleasepool {
        
        //check if scanner thread was cancelled
        // ->should exit if so
        if(YES == [[NSThread currentThread] isCancelled])
        {
            //dbg msg
            NSLog(@"thread is cancelled, killing it!");
            
            //bail
            [NSThread exit];
        }
        
        //skip non-existent files and directories
        if( (YES != [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&isDirectory]) ||
            (YES == isDirectory) )
        {
            //skip
            continue;
        }
        
        //skip non-executable files
        // ->that is, non i386/x86_64
        if(YES != isURLExecutable(fileURL))
        {
            //skip
            continue;
        }
        
        //save it
        [self.scannedBinaries addObject:fileURL.path];
        
        //scan it
        [self scanBinary:[[Binary alloc] initWithPath:fileURL.path]];
            
        }//autorelease
    }
    
    return;
}

//get/scan binaries from process list
-(void)scanBinariesProcList
{
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //process name
    NSString* processName = nil;
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);

    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //err
        NSLog(@"error, proc_listpids() failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //check if scan thread was cancelled
        if(YES == [[NSThread currentThread] isCancelled])
        {
            //dbg msg
            NSLog(@"thread is cancelled, killing it!");
            
            //bail
            [NSThread exit];
        }

        //reset buffer
        bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
        
        //get path
        status = proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer));
        
        //sanity check
        // ->this generally just fails if process has exited....
        if( (status < 0) ||
            (0 == strlen(pathBuffer)) )
        {
            //skip
            continue;
        }
        
        //init process name
        processName = [NSString stringWithUTF8String:pathBuffer];
        
        //ignore dupes
        if(YES ==[self.scannedBinaries containsObject:processName])
        {
            //skip
            continue;
        }
        
        //save it
        [self.scannedBinaries addObject:processName];
        
        //scan it
        [self scanBinary:[[Binary alloc] initWithPath:processName]];
    }
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    //dbg msg
    NSLog(@"done scanning running processes/dylibs");
    
    return;
}

//parse a binary
-(BOOL)parseBinary:(Binary*)binary
{
    //flag
    BOOL wasParsed = NO;
    
    //dbg msg
    //NSLog(@"parsing %@", binary);
    
    //alloc macho parser iVar
    // ->new instance for each file!
    machoParser = [[MachO alloc] init];
    
    //parse
    if(YES != [machoParser parse:binary.path])
    {
        //bail
        goto bail;
    }
    
    //happy
    wasParsed = YES;
    
    //save instance of parser into binary object
    binary.parserInstance = machoParser;

//bail
bail:
    
    return wasParsed;
}

//scan a binary
// ->determine if its hijacked or vulnerable
-(void)scanBinary:(Binary*)binary
{
    //dbg msg
    NSLog(@"scanning %@", binary.path);
    
    //first gotta parse it
    if(YES != [self parseBinary:binary])
    {
        //err msg
        NSLog(@"DHS ERROR: failed to parse %@", binary.path);
        
        //bail
        goto bail;
    }
    
    //skip dylibs!
    if(MH_EXECUTE != [binary getType])
    {
        //skip
        goto bail;
    }

    //resolve LC_LOAD_WEAK_DYLIB imports
    // ->need to do this, since we check to see if they exist
    binary.parserInstance.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] = [self resolvePaths:binary paths:binary.parserInstance.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS]];

    //resolve LC_RPATHS imports
    // ->need to do this, since we check to see if they exist, etc
    binary.parserInstance.binaryInfo[KEY_LC_RPATHS] = [self resolvePaths:binary paths:binary.parserInstance.binaryInfo[KEY_LC_RPATHS]];
    
    //check if its hijacked
    // ->set iVar within binary object
    [self scan4Hijack:binary];
    
    //check if its vulnerable
    // ->note, no need to scan hijacked binaries
    if(YES != binary.isHijacked)
    {
        //scan
        // ->sets iVar within binary obj
        [self scan4Vulnerable:binary];
    }
    
    //process results
    //hiijacked?
    if(YES == binary.isHijacked)
    {
        //dbg msg
        NSLog(@"binary is hijacked (type: %lu): %@!", (unsigned long)binary.issueType, binary.path);
        
        //call back up to UI in main thread
        // ->add binary to table
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //call back
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) addToTable:binary];
            
        });
        
        
        
    }
    
    //vulnerable?
    else if(YES == binary.isVulnerable)
    {
        //dbg msg
        NSLog(@"binary is vulnerable (type: %lu): %@!", (unsigned long)binary.issueType, binary.path);
        
        //call back up to UI in main thread
        // ->add binary to table
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //call back
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) addToTable:binary];
            
        });
    }
    
//bail
bail:
    
    return;
    
}

//check if a binary is hijacked
-(void)scan4Hijack:(Binary*)binary
{
    //first check for rpath hijack
    // ->is more conclusive (less false positives)
    [self scan4HijackRPath:binary];
    
    //if not rpath hijacked
    // ->check for weak hijack
    if( (YES == self.scan4WeakHijackers) &&
        (YES != binary.isHijacked) )
    {
        //scan
        [self scan4HijackWeak:binary];
    }
    
    return;
}

//check if a binary is hijacked by a weak dylib
// ->scan all LC_LOAD_WEAK_DYLIBS, look for existing lib that isn't signed?
-(void)scan4HijackWeak:(Binary*)binary
{
    //resolved path
    NSString* resolvedWeakDylib = nil;
    
    //build list of all LC_LOAD_WEAK_DYLIBS
    // ->@rpath'd ones have to be resolved
    for(NSString* weakDylib in binary.parserInstance.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS])
    {
        //resolve @rpath'd imports
        // ->just need first to check
        if(YES == [weakDylib hasPrefix:RUN_SEARCH_PATH])
        {
            //resolve
            resolvedWeakDylib = [[binary.parserInstance.binaryInfo[KEY_LC_RPATHS] firstObject] stringByAppendingPathComponent:[weakDylib substringFromIndex:[RUN_SEARCH_PATH length]]];
        }
        //no need to resolve
        else
        {
            //use as is
            resolvedWeakDylib = weakDylib;
        }
        
        //skip ones that aren't found
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:resolvedWeakDylib])
        {
            //skip
            continue;
        }
    
        //check if its suspicious
        if(YES == [self isWeakImportSuspicious:binary weakDylib:resolvedWeakDylib])
        {
            //dbg msg
            NSLog(@"%@ appears to be a weak hijack", resolvedWeakDylib);
            
            //set hijack flag
            binary.isHijacked = YES;
            
            //set type flag
            binary.issueType = ISSUE_TYPE_WEAK;
            
            //set issue item
            binary.issueItem = resolvedWeakDylib;
            
            //bail
            // ->don't need to scan for more instances, since this binary is hijacked!
            break;
        }

    }
    
    return;
}

//check if a binary is hijacked by abusing rpath seach order
// ->scan all @rpath'd LC_LOAD_DYLIBS to see if there are doubles...
-(void)scan4HijackRPath:(Binary*)binary
{
    //number of occurances of dylib
    NSUInteger dylibCount = 0;
    
    //rpath resolved path
    NSString* resolvedPath = nil;
    
    //initial resolved path
    // ->this is the one that could be hijacked
    NSString* initialResolvedPath = nil;
    
    //binary's signing info
    NSDictionary* binarySigningInfo = nil;
    
    //scan all LC_LOAD_DYLIBS
    for(NSString* importedDylib in binary.parserInstance.binaryInfo[KEY_LC_LOAD_DYLIBS])
    {
        //reset count
        dylibCount = 0;
        
        //reset initial resolved path
        initialResolvedPath = nil;
        
        //skip dylibs that are imported normally (e.g. without '@rpath')
        if(YES != [importedDylib hasPrefix:RUN_SEARCH_PATH])
        {
            //skip
            continue;
        }
        
        //scan all run paths
        // ->get count/save of each dylib
        for(NSString* runPath in binary.parserInstance.binaryInfo[KEY_LC_RPATHS])
        {
            //init rpath resolved path
            // ->current run path + path to dylib (with '@rpath') removed
            resolvedPath = [runPath stringByAppendingPathComponent:[importedDylib substringFromIndex:[RUN_SEARCH_PATH length]]];
            
            //dbg msg
            //NSLog(@"checking if %@ exists", resolvedPath);
            
            //check if it exists
            // ->save if first and inc count
            if(YES == [[NSFileManager defaultManager] fileExistsAtPath:resolvedPath])
            {
                //dbg msg
                //NSLog(@"found %@ in %@", resolvedPath, runPath);
                
                //want to save first instance
                if(nil == initialResolvedPath)
                {
                    //save
                    initialResolvedPath = resolvedPath;
                }
                
                //inc
                dylibCount++;
            }
        }
        
        //should only be one instance
        if(dylibCount < 2)
        {
            //ok
            continue;
        }
        
        //(possible) HIJACK DETECTED!
        // ->multiple instance of same named dylib in run-search paths
        
        //dbg msg
        NSLog(@"found %lu instance of %@ in run-path search directories", (unsigned long)dylibCount, importedDylib);
        
        /*
        //get binary's signing info
        binarySigningInfo = signingInfo(binary.path);
        
        //if binary is signed
        // ->a 'hijacker' dylib with the same signature is fine
        if( (nil != binarySigningInfo) &&
            (errSecCSUnsigned != [binarySigningInfo[KEY_SIGNATURE_STATUS] integerValue]) )
        {
            //not a real hijacker if binary and dylib are both signed by the same signing auths
            if(YES == [self doSignaturesMatch:binary dylib:initialResolvedPath])
            {
                //dbg msg
                NSLog(@"skipping since binary and dylib are both same-signed");
                
                //skip
                continue;
            }
        }
        */
           
        //set hijack flag
        binary.isHijacked = YES;
        
        //set type flag
        binary.issueType = ISSUE_TYPE_RPATH;
        
        //set issue item
        // ->the first dylib (of 2+) found in the @rpath directories
        binary.issueItem = initialResolvedPath;

        //bail
        // ->don't need to scan for more instances, since this binary is hijacked!
        break;
        
    }
    
    return;
}


//check if a binary is vulnerable
// ->either to weak or rpath hijack
//   note: results set in binary object
-(void)scan4Vulnerable:(Binary*)binary
{
    //check if its vulnerable to a rpath hijack
    [self hasVulnerableRPath:binary];
    
    //check if its vulnerable to a weak import hijack
    [self hasVulnerableWeakImport:binary];
    
    return;
}

//check if a binary vulnerable to a weak import hijack
// ->scan all weak imports to see if any don't exist!
-(void)hasVulnerableWeakImport:(Binary*)binary
{
    //resolved path
    NSString* absoluteDylib = nil;
    
    //build list of all LC_LOAD_WEAK_DYLIBS
    // ->@rpath'd ones have to be resolved
    for(NSString* weakDylib in binary.parserInstance.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS])
    {
        //resolve @rpath'd imports
        // ->just need first to check
        if(YES == [weakDylib hasPrefix:RUN_SEARCH_PATH])
        {
            //resolve
            absoluteDylib = [[binary.parserInstance.binaryInfo[KEY_LC_RPATHS] firstObject] stringByAppendingPathComponent:[weakDylib substringFromIndex:[RUN_SEARCH_PATH length]]];
        }
        //no need to resolve
        else
        {
            //use as is
            absoluteDylib = weakDylib;
        }
        
    
        
        //check if doesn't exists
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:absoluteDylib])
        {
            //not found
            // ->could be hijacked!
           
            //dbg msg
            NSLog(@"%@ is vulnerable to a weak hijack", absoluteDylib);
            
            //set vulnerable flag
            binary.isVulnerable = YES;
            
            //set type flag
            binary.issueType = ISSUE_TYPE_WEAK;
            
            //set issue item
            binary.issueItem = absoluteDylib;
            
            //bail
            // ->don't need to scan for more instances, since this binary is hijacked!
            break;
        }
    }
    
    return;
}

//check if a binary vulnerable to a rpath hijack
// ->are any @rpath'd imports not found in primary LC_RPATH directory?
-(void)hasVulnerableRPath:(Binary*)binary
{
    //rpath resolved path
    NSString* absoluteDylib = nil;
    
    //first run-path search directory
    NSString* firstRPathDirectory = nil;
    
    //skip binaries that don't have any LC_RPATHs
    // ->cuz obvs these can't be vulnerable to @rpath hijack
    if(0 == [binary.parserInstance.binaryInfo[KEY_LC_RPATHS] count])
    {
        //bail
        goto bail;
    }
    
    //scan all LC_LOAD_DYLIBS
    for(NSString* loadDylib in binary.parserInstance.binaryInfo[KEY_LC_LOAD_DYLIBS])
    {
        //skip dylibs that are imported normally (e.g. without '@rpath')
        if(YES != [loadDylib hasPrefix:RUN_SEARCH_PATH])
        {
            //skip
            continue;
        }
        
        //grab first run-path search directory
        // ->this is the only one we need to check
        firstRPathDirectory = [binary.parserInstance.binaryInfo[KEY_LC_RPATHS] firstObject];
        
        //init rpath resolved path
        // ->first run path + path to dylib (with '@rpath') removed
        absoluteDylib = [firstRPathDirectory stringByAppendingPathComponent:[loadDylib substringFromIndex:[RUN_SEARCH_PATH length]]];
        
        //check file doesn't exist
        // ->non-existing in first run-path search directory means its vulnerable
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:absoluteDylib])
        {
            
            //VULNERABILITY DETECTED!
            // ->dylib isn't found in first run-path search directory
        
            //dbg msg
            NSLog(@"%@ isn't in first run-path search directory %@", absoluteDylib, firstRPathDirectory);
        
            //set vulnerable flag
            binary.isVulnerable = YES;
            
            //set type flag
            binary.issueType = ISSUE_TYPE_RPATH;
            
            //set issue item
            binary.issueItem = absoluteDylib;
        
            //bail
            // ->don't need to scan for more instances, since this binary is vulnerable!
            break;
        }
        
    }
    
//bail
bail:
    
    return;
}

//resolve an array of paths
// ->any that start with w/ '@loader_path' or '@executable_path' will be resolved
-(NSMutableArray*)resolvePaths:(Binary*)binary paths:(NSMutableArray*)paths
{
    //resolved paths
    NSMutableArray* resolvedPaths = nil;
    
    //resolved path
    NSString* resolvedPath = nil;
    
    //alloc/init
    resolvedPaths = [NSMutableArray array];
    
    for(NSString* runPathDirectory in paths)
    {
        //only need to resolve paths with '@executable_path' or '@loader_path'
        if( (YES == [runPathDirectory hasPrefix:EXECUTABLE_PATH]) ||
            (YES == [runPathDirectory hasPrefix:LOADER_PATH]) )
        {
            //resolve it
            resolvedPath = [self resolvePath:binary path:runPathDirectory];
            
            //save it
            // ->only if its unique
            if(NO == [resolvedPaths containsObject:resolvedPath])
            {
                //save
                [resolvedPaths addObject:resolvedPath];
            }
        }
        
        //didn't need to resolve
        // ->just save as is
        else
        {
            //check if its unique
            if(YES != [resolvedPaths containsObject:runPathDirectory])
            {
                //save
                [resolvedPaths addObject:runPathDirectory];
            }
        }
    }
    
    return resolvedPaths;
}


//resolve a path that start w/ '@loader_path' or '@executable_path'
// ->since we aren't scanning modules, both are the same
//   see: https://www.mikeash.com/pyblog/friday-qa-2009-11-06-linking-and-install-names.html
-(NSString*)resolvePath:(Binary*)binary path:(NSString*)unresolvedPath
{
    //resolved path
    NSString* resolvedPath = nil;
    
    //prefix to remove
    NSString* prefix = nil;
    
    //default to existing path
    resolvedPath = unresolvedPath;
    
    //get prefix
    // ->'@executable_path'
    if(YES == [unresolvedPath hasPrefix:EXECUTABLE_PATH])
    {
        //executable path
        prefix = EXECUTABLE_PATH;
    }
    
    //get prefix
    // ->'@loader_path'
    else if(YES == [unresolvedPath hasPrefix:LOADER_PATH])
    {
        //loader path
        prefix = LOADER_PATH;
    }
    
    //build resolved path
    // 1: binary's directory +
    // 2: the unresolved path with '@executable_path' or '@loader_path' remove
    // 3: standardized to make it an absolute path
    resolvedPath = [[[binary.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[unresolvedPath substringFromIndex:[prefix length]]] stringByStandardizingPath];

    //dbg msg
    //NSLog(@"resolved %@ to %@", unresolvedPath, resolvedPath);
    
    return resolvedPath;
}

//check if a found weakly imported dylib is suspicious
// ->for now just make sure if parent is signed, so import...
-(BOOL)isWeakImportSuspicious:(Binary*)binary weakDylib:(NSString*)weakImport
{
    //return
    BOOL isSuspicious = NO;
    
    //signing dictionary for binary
    NSDictionary* binarySigningInfo = nil;
    
    //signing dictionary for weak import
    NSDictionary* importSigningInfo = nil;
    
    //get signing info for binary
    binarySigningInfo = signingInfo(binary.path);
    
    //get signin info for weak import
    importSigningInfo = signingInfo(weakImport);
    
    //check if parent is signed
    if( (nil != binarySigningInfo) &&
        (STATUS_SUCCESS == ((NSNumber*)binarySigningInfo[KEY_SIGNATURE_STATUS]).intValue) )
    {
        //weak import better be signed to y0
        if( (nil == importSigningInfo) ||
            (STATUS_SUCCESS != ((NSNumber*)importSigningInfo[KEY_SIGNATURE_STATUS]).intValue) )
        {
            //shady!
            isSuspicious = YES;
            
        }
    }
    
    return isSuspicious;
}



//check if the digital signatures of a binary and an dylib match
-(BOOL)doSignaturesMatch:(Binary*)binary dylib:(NSString*)dylib
{
    //return var
    BOOL doMatch = NO;
    
    //signing dictionary for binary
    NSDictionary* binarySigningInfo = nil;
    
    //signing authorities array for binary
    NSArray* binarySigningAuths = nil;
    
    //signing dictionary for weak import
    NSDictionary* dylibSigningInfo = nil;
    
    //signing authorities array for dylib
    NSArray* dylibSigningAuths = nil;
    
    //index var
    NSUInteger index = 0;

    //get signing info for binary
    binarySigningInfo = signingInfo(binary.path);
    
    //get signin info for weak import
    dylibSigningInfo = signingInfo(dylib);
    
    //both need to be signed
    if( (nil == binarySigningInfo) ||
        (nil == dylibSigningInfo) )
    {
        //bail
        goto bail;
    }
    
    //extract signing auths for binary
    binarySigningAuths = binarySigningInfo[KEY_SIGNING_AUTHORITIES];
    
    //extract signing auths for dylib
    dylibSigningAuths = dylibSigningInfo[KEY_SIGNING_AUTHORITIES];
    
    NSLog(@"binary signing auths: %@", binarySigningAuths);
    NSLog(@"dylib signing auths: %@", dylibSigningAuths);
    
    //make sure both have same non-zero number of signed authorities
    if( (0 == binarySigningAuths.count) ||
        (binarySigningAuths.count != dylibSigningAuths.count) )
    {
        //bail
        goto bail;
    }
    
    //check all signing auths
    // ->all gotta match!
    for(index = 0; index < binarySigningAuths.count; index++)
    {
        //check
        if(YES != [binarySigningAuths[index] isEqualToString:dylibSigningAuths[index]])
        {
            //no match
            // ->bail
            goto bail;
        }
    }
    
    //happy
    doMatch = YES;
    
    
//bail
bail:
    
    return doMatch;

}




@end

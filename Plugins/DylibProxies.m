//
//  DylibProxies.m
//  KnockKnock
//

#import "File.h"
#import "MachO.h"
#import "Utilities.h"
#import "DylibProxies.h"

//plugin name
#define PLUGIN_NAME @"Library Proxies"

//plugin description
#define PLUGIN_DESCRIPTION @"dylibs that proxy other libraries"

//plugin icon
#define PLUGIN_ICON @"proxyIcon"

//(privacy) protected directories
NSString * const PROTECTED_DIRECTORIES[] = {@"~/Library/Application Support/AddressBook", @"~/Library/Calendars", @"~/Pictures", @"~/Library/Mail", @"~/Library/Messages", @"~/Library/Safari", @"~/Library/Cookies", @"~/Library/HomeKit", @"~/Library/IdentityServices", @"~/Library/Metadata/CoreSpotlight", @"~/Library/PersonalizationPortrait", @"~/Library/Suggestions"};

@implementation DylibProxies

//init
// ->set name, description, etc
-(id)init
{
    //super
    self = [super init];
    if(self)
    {
        //set name
        self.name = PLUGIN_NAME;
        
        //set description
        self.description = PLUGIN_DESCRIPTION;
        
        //set icon
        self.icon = PLUGIN_ICON;
    }
    
    return self;
}

//find dylibs
// loaded in (user) processes & references by all running procs
-(NSMutableArray*)enumDylibs
{
    //dylibs
    NSMutableArray* dylibs = nil;
    
    //first get dylibs loaded into user procs
    dylibs = [self enumLoadedDylibs];
    
    //then get dylibs statically references by all running procs
    [dylibs addObjectsFromArray:[self enumLinkedDylibs:runningProcesses()]];
    
    //remove duplicates
    dylibs = [[[NSSet setWithArray:dylibs] allObjects] mutableCopy];
    
    return dylibs;
}

//enum dylibs loaded into user procs
-(NSMutableArray*)enumLoadedDylibs
{
    //dylibs
    NSMutableArray* dylibs = nil;
    
    //results
    NSData* results = nil;
    
    //results split on '\n'
    NSArray* splitResults = nil;
    
    //file path
    NSString* filePath = nil;
    
    //(privacy) protected directories
    NSArray* protectedDirectories = nil;
    
    //flag
    BOOL isProtected = NO;
    
    //pool
    @autoreleasepool
    {
    
    //alloc array
    dylibs = [NSMutableArray array];
        
    //init set of (privacy) protected directories
    // these will be skipped, as otherwise we will generate a privacy prompt
    protectedDirectories = expandPaths(PROTECTED_DIRECTORIES, sizeof(PROTECTED_DIRECTORIES)/sizeof(PROTECTED_DIRECTORIES[0]));
        
    //exec 'lsof' to get loaded libs
    results = execTask(LSOF, @[@"-Fn", @"/"]);
    if( (nil == results) ||
        (0 == results.length) )
    {
        //bail
        goto bail;
    }
    
    //split results into array
    splitResults = [[[NSString alloc] initWithData:results encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
    
    //sanity check(s)
    if( (nil == splitResults) ||
        (0 == splitResults.count) )
    {
        //bail
        goto bail;
    }
    
    //iterate over all results
    // make file info dictionary for files (not sockets, etc)
    for(NSString* result in splitResults)
    {
        //reset
        isProtected = NO;
        
        //skip any odd/weird/short lines
        // lsof outpupt will be in format: 'n<filePath'>
        if( (YES != [result hasPrefix:@"n"]) ||
            (result.length < 0x2) )
        {
            //skip
            continue;
        }
        
        //init file path
        // result, minus first (lsof-added) char
        filePath = [result substringFromIndex:0x1];
        
        //skip any files in (privacy) protected directories
        // as otherwise we will generate a privacy prompt (on Mojave)
        for(NSString* directory in protectedDirectories)
        {
            //reset
            isProtected = NO;
            
            //check
            if(YES == [filePath hasPrefix:directory])
            {
                //set flag
                isProtected = YES;
                
                //done
                break;
            }
        }
        
        //skip (privacy) protected files
        if(YES == isProtected)
        {
            //skip
            continue;
        }
        
        //skip 'non files' / non-executable files
        if( (YES != [[NSFileManager defaultManager] fileExistsAtPath:filePath]) ||
            (YES != isExecutable(filePath)) )
        {
            //skip
            continue;
        }
        
        //also skip files such as '/', /dev/null, etc
        if( (YES == [filePath isEqualToString:@"/"]) ||
            (YES == [filePath isEqualToString:@"/dev/null"]) )
        {
            //skip
            continue;
        }
        
        //save
        [dylibs addObject:filePath];
    }
    
    //remove duplicates
    dylibs = [[[NSSet setWithArray:dylibs] allObjects] mutableCopy];
        
    }//pool

bail:
    
    return dylibs;
}
     
//enum dylibs statically referenced by all running procs
-(NSMutableArray*)enumLinkedDylibs:(NSArray*)runningProcs
{
    //dylibs
    NSMutableArray* dylibs = nil;
    
    //macho parser
    MachO* machoParser = nil;
    
    //pool
    @autoreleasepool
    {
    
    //alloc array
    dylibs = [NSMutableArray array];
    
    //parse each
    for(NSString* runningProc in runningProcs)
    {
        //alloc macho parser
        // ->new instance for each file!
        machoParser = [[MachO alloc] init];
        
        //parse
        if(YES != [machoParser parse:runningProc classify:NO])
        {
            //skip
            continue;
        }
        
        //add all dylibs from LC_LOAD_DYLIBS
        [dylibs addObjectsFromArray:machoParser.binaryInfo[KEY_LC_LOAD_DYLIBS]];
        
        //add all dylibs from KEY_LC_LOAD_WEAK_DYLIBS
        [dylibs addObjectsFromArray:machoParser.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS]];
    }
    
    //remove duplicates
    dylibs = [[[NSSet setWithArray:dylibs] allObjects] mutableCopy];
        
    } //pool
    
    return dylibs;
}

//process dylibs
// ->determine if any looks like a proxy
-(NSMutableArray*)findProxies:(NSMutableArray*)dylibs
{
    //dylibs
    NSMutableArray* proxies = nil;
    
    //macho parser
    MachO* machoParser = nil;
    
    //alloc array
    proxies = [NSMutableArray array];
    
    //parse all
    // ->make sure its a dylib and then that it re-exports stuff?
    for(NSString* dylib in dylibs)
    {
        //pool
        @autoreleasepool
        {
            
        //alloc macho parser
        // ->new instance for each file!
        machoParser = [[MachO alloc] init];
        
        //parse
        if(YES != [machoParser parse:dylib classify:NO])
        {
            //skip
            continue;
        }
        
        //skip non-dylibs
        if(MH_DYLIB != [[machoParser.binaryInfo[KEY_MACHO_HEADERS] firstObject][KEY_HEADER_BINARY_TYPE] intValue])
        {
            //skip
            continue;
        }
        
        //skip dylibs without re-exports
        if(0 == [machoParser.binaryInfo[KEY_LC_REEXPORT_DYLIBS] count])
        {
            //skip
            continue;
        }
        
        //save
        [proxies addObject:dylib];
            
        }//pool
    }
    
bail:
    
    return proxies;
}

//scan for proxy dylibs
-(void)scan
{
    //File obj
    File* fileObj = nil;
    
    //proxy dylibs
    NSMutableArray* proxiedDylibs = nil;
    
    //find proxies
    proxiedDylibs = [self findProxies:[self enumDylibs]];
    
    //enumerate all proxy dylibs
    // ->creating file obj for each
    for(NSString* proxyDylib in proxiedDylibs)
    {
        //create File object
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:proxyDylib}];
        if(nil == fileObj)
        {
            //skip
            continue;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:fileObj];
    }
    
    return;
}

@end

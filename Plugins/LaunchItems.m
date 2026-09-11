//
//  LaunchItems.m
//  KnockKnock
//

#import "File.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "LaunchItems.h"

//plugin name
#define PLUGIN_NAME @"Launch Items"

//plugin description
#define PLUGIN_DESCRIPTION NSLocalizedString(@"daemons and agents loaded by launchd", @"daemons and agents loaded by launchd")

//plugin icon
#define PLUGIN_ICON @"launchIcon"

@implementation LaunchItems

@synthesize enabledItems;
@synthesize disabledItems;


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

//scan for login items
// note: keys in plist are all lower case'd for case-insensitive search
-(void)scan
{
    //all launch items
    NSArray* launchItems = nil;
    
    //plist data
    NSDictionary* plist = nil;
    
    //processed plist
    NSMutableDictionary* plistProcessed = nil;
    
    //launch item binary
    NSString* launchItemPath = nil;
    
    //detected (auto-started) login item
    File* fileObj = nil;

    //get overriden enabled & disabled items
    [self processOverrides];
    
    //wait for shared item enumerator to complete enumeration of launch items
    do
    {
        //nap
        [NSThread sleepForTimeInterval:0.1f];
        
        //try grab launch items
        // ->will only !nil, when enumeration is complete
        launchItems = sharedItemEnumerator.launchItems;
        
    //keep trying until we get em!
    } while(nil == launchItems);
    
    //iterate over all launch items
    // ->scan/process each
    for(NSString* launchItemPlist in launchItems)
    {
        //reset
        launchItemPath = nil;
        
        //load plist contents
        // ->skip any that error out
        plist = [NSDictionary dictionaryWithContentsOfFile:launchItemPlist];
        if(nil == plist)
        {
            //skip
            continue;
        }
        
        //alloc
        plistProcessed = [NSMutableDictionary dictionary];
        
        //convert keys to lower case
        for(NSString* key in plist)
        {
            //add lower-case'd
            plistProcessed[key.lowercaseString] = plist[key];
        }
        
        //skip non-auto run items
        if(YES != [self isAutoRun:plistProcessed])
        {
            //skip
            continue;
        }
        
        //extract path to launch item
        //  first, check 'Program' key
        if(nil != plistProcessed[@"program"])
        {
            //is it array?
            if(YES == [plistProcessed[@"program"] isKindOfClass:[NSArray class]])
            {
                //extract path
                launchItemPath = [plistProcessed[@"program"] firstObject];
            }
            
            //is it a string?
            else if(YES == [plistProcessed[@"program"] isKindOfClass:[NSString class]])
            {
                //extract path
                launchItemPath = plistProcessed[@"program"];
            }
        }
        
        //extact path to launch item
        // ->second, via 'ProgramArguments' (sometimes just has args)
        else if(nil != plistProcessed[@"programarguments"])
        {
            //should (usually) be an array
            // ->extract & grab first item
            if(YES == [plistProcessed[@"programarguments"] isKindOfClass:[NSArray class]])
            {
                //extract path
                launchItemPath = [plistProcessed[@"programarguments"] firstObject];
            }
            
            //sometime this is a string...
            // ->just save as path (assumes no args)
            else if(YES == [plistProcessed[@"programarguments"] isKindOfClass:[NSString class]])
            {
                //extract path
                launchItemPath = plistProcessed[@"programarguments"];
            }
        }
        
        //skip any that don't have a (string) path
        // note: a non-string (e.g. number/dict in 'ProgramArguments') isn't a path launchd would run either
        if( (nil == launchItemPath) ||
            (YES != [launchItemPath isKindOfClass:[NSString class]]) )
        {
            //skip
            continue;
        }
        
        //relative path (e.g. 'evil')?
        // ->launchd resolves it via the job's own 'EnvironmentVariables.PATH' (not ours), so try that first
        if(YES != [launchItemPath hasPrefix:@"/"])
        {
            //resolve
            launchItemPath = [self resolveViaJobPath:launchItemPath plist:plistProcessed] ?: launchItemPath;
        }
        
        //create File object for launch item
        // ->skip those that err out for any reason (e.g. binary not found, as then it can't be run)
        if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:launchItemPath, KEY_RESULT_PLIST:launchItemPlist}]))
        {
            //skip
            continue;
        }
        
        //don't trust 'Apple' binaries persisted by a non-Apple plist
        // e.g. /bin/bash launched via ~/Library/LaunchAgents/evil.plist (or /var/root/..., etc)
        // ...only plists on the (sealed) system volume get to vouch for an Apple binary
        if( (YES == fileObj.isTrusted) &&
            (YES != [fileObj.plist hasPrefix:@"/System/"]) )
        {
            //don't trust
            fileObj.isTrusted = NO;
        }
        
        //process item
        // ->save and report to UI
        [super processItem:fileObj];
    }

    return;
}

//resolve a relative program name via the job's own 'EnvironmentVariables.PATH'
// note: keys of plist are lower-cased (but not those of nested dictionaries)
-(NSString*)resolveViaJobPath:(NSString*)program plist:(NSDictionary*)plist
{
    //resolved path
    NSString* resolved = nil;
    
    //candidate
    NSString* candidate = nil;
    
    //job's environment variables
    NSDictionary* environment = nil;
    
    //job's PATH
    NSString* path = nil;
    
    //grab job's environment
    environment = plist[@"environmentvariables"];
    if(YES != [environment isKindOfClass:[NSDictionary class]])
    {
        //bail
        goto bail;
    }
    
    //grab job's PATH
    path = environment[@"PATH"];
    if(YES != [path isKindOfClass:[NSString class]])
    {
        //bail
        goto bail;
    }
    
    //check each directory in PATH
    for(NSString* directory in [path componentsSeparatedByString:@":"])
    {
        //skip blanks
        if(0 == directory.length)
        {
            //skip
            continue;
        }
        
        //build candidate
        candidate = [directory stringByAppendingPathComponent:program];
        
        //exists?
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:candidate])
        {
            //found
            resolved = candidate;
            
            //done
            break;
        }
    }
    
bail:
    
    return resolved;
}

//get all overridden enabled/disabled launch items
// ->from launchd's (live) override database (see 'launchdOverrides')
-(void)processOverrides
{
    //overrides
    NSDictionary* overrides = nil;
    
    //alloc enabled items array
    enabledItems = [NSMutableArray array];
    
    //alloc disabled items array
    disabledItems = [NSMutableArray array];
    
    //get overrides
    // label -> @YES (disabled) / @NO (explicitly enabled)
    overrides = launchdOverrides();
    
    //split into disabled/enabled
    for(NSString* label in overrides)
    {
        //disabled
        if(YES == [overrides[label] boolValue])
        {
            //add
            [self.disabledItems addObject:label];
        }
        //(explicitly) enabled
        else
        {
            //add
            [self.enabledItems addObject:label];
        }
    }
    
    return;
}

//checks if an item will be automatically run by the OS
// note: all keys are lower-case, as we've converted them this way...
// note: launchd has many triggers (see launchd.plist(5)); an item is considered auto-run if *any* are present
//       as when in doubt, we'd rather report an item than let malware pick a trigger we ignore
-(BOOL)isAutoRun:(NSDictionary*)plist
{
    //flag
    BOOL isAutoRun = NO;
    
    //triggers (keys) whose (mere) presence means launchd will run the item
    // 'StartInterval'/'StartCalendarInterval': periodically
    // 'WatchPaths'/'QueueDirectories': on file system changes
    // 'LaunchEvents': on system events (e.g. IOKit matching, notifications)
    // 'Sockets': on (network) connections
    // 'MachServices': on (mach) messages from clients (e.g. privileged helpers)
    static NSArray* triggers = nil;
    
    //once
    static dispatch_once_t onceToken = 0;
    
    //init triggers
    dispatch_once(&onceToken, ^{
        
        //init
        triggers = @[@"startinterval", @"startcalendarinterval", @"watchpaths", @"queuedirectories", @"launchevents", @"sockets", @"machservices"];
    });
    
    //skip launch items disabled via override (i.e. 'launchctl disable')
    if(YES == [self.disabledItems containsObject:plist[@"label"]])
    {
        //bail
        goto bail;
    }

    //skip items disabled in their plist ('Disabled' key)
    // ->unless explicitly enabled via override (i.e. 'launchctl enable'), as then launchd runs them
    if( (YES == [plist[@"disabled"] isKindOfClass:[NSNumber class]]) &&
        (YES == [plist[@"disabled"] boolValue]) &&
        (YES != [self.enabledItems containsObject:plist[@"label"]]) )
    {
        //bail
        goto bail;
    }
    
    //CHECK 0x1: 'RunAtLoad'
    // ->set to true, means auto run!
    if( (YES == [plist[@"runatload"] isKindOfClass:[NSNumber class]]) &&
        (YES == [plist[@"runatload"] boolValue]) )
    {
        //auto
        isAutoRun = YES;
        
        //done
        goto bail;
    }
    
    //CHECK 0x2: 'KeepAlive'
    // ->set to true, or a dictionary of conditions (e.g. 'PathState', 'SuccessfulExit', 'Crashed'), means auto run!
    if( ((YES == [plist[@"keepalive"] isKindOfClass:[NSNumber class]]) && (YES == [plist[@"keepalive"] boolValue])) ||
        (YES == [plist[@"keepalive"] isKindOfClass:[NSDictionary class]]) )
    {
        //auto
        isAutoRun = YES;
        
        //done
        goto bail;
    }
    
    //CHECK 0x3: 'StartOnMount'
    // ->set to true, means auto run (when a volume is mounted)
    if( (YES == [plist[@"startonmount"] isKindOfClass:[NSNumber class]]) &&
        (YES == [plist[@"startonmount"] boolValue]) )
    {
        //auto
        isAutoRun = YES;
        
        //done
        goto bail;
    }
    
    //CHECK 0x4: other triggers
    // ->any present, means will auto run (at some point)
    for(NSString* trigger in triggers)
    {
        //present?
        if(nil != plist[trigger])
        {
            //auto
            isAutoRun = YES;
            
            //done
            goto bail;
        }
    }
    
    //CHECK 0x5: legacy 'OnDemand'
    // ->set to false, means auto run (e.g. HackingTeam)
    // note: only if neither 'RunAtLoad' nor 'KeepAlive' were specified (as those take precedence)
    if( (nil == plist[@"runatload"]) &&
        (nil == plist[@"keepalive"]) &&
        (YES == [plist[@"ondemand"] isKindOfClass:[NSNumber class]]) &&
        (NO == [plist[@"ondemand"] boolValue]) )
    {
        //auto
        isAutoRun = YES;
        
        //done
        goto bail;
    }
    
//bail
bail:
    
    return isAutoRun;
}

@end

//
//  Kexts.m
//  KnockKnock
//

#import "File.h"
#import "Kexts.h"
#import "Utilities.h"

//plugin name
#define PLUGIN_NAME @"Kernel Extensions"

//plugin description
#define PLUGIN_DESCRIPTION @"installed kexts, likely kernel loaded"

//plugin icon
#define PLUGIN_ICON @"kernelIcon"

//plugin search directories
NSString * const KEXT_SEARCH_DIRECTORIES[] = {@"/System/Library/Extensions/", @"/Library/Extensions/"};

@implementation Kexts

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

//scan for kexts
-(void)scan
{
    //all kexts
    NSArray* allKexts = nil;
    
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //full path to kext
    NSString* kextPath = nil;
    
    //detected kext
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);

    //get number of search directories
    directoryCount = sizeof(KEXT_SEARCH_DIRECTORIES)/sizeof(KEXT_SEARCH_DIRECTORIES[0]);
    
    //iterate over all kext search directories
    // ->get all kexts and process 'em
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //get all kexts
        allKexts = directoryContents(KEXT_SEARCH_DIRECTORIES[i], @"self ENDSWITH '.kext'");
        
        //process a kext
        // ->create File objects and report to UI
        for(NSString* kext in allKexts)
        {
            //build full path to kext
            kextPath = [NSString stringWithFormat:@"%@%@", KEXT_SEARCH_DIRECTORIES[i], kext];
            
            //create File object for kext
            // ->skip those that err out for any reason
            if(nil == (fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:kextPath}]))
            {
                //skip
                continue;
            }
            
            //process item
            // ->save and report to UI
            [super processItem:fileObj];
        }
    }
    
    return;
}

@end

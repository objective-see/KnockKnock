//
//  SpotlightImporters.m
//  KnockKnock
//

#import "File.h"
#import "Utilities.h"
#import "SpotlightImporters.h"

//plugin name
#define PLUGIN_NAME @"Spotlight Importers"

//plugin description
#define PLUGIN_DESCRIPTION @"bundles loaded by Spotlight (mdworker)"

//plugin icon
#define PLUGIN_ICON @"spotlightIcon"

//plugin search directories
NSString * const SPOTLIGHT_SEARCH_DIRECTORIES[] = {@"/System/Library/Spotlight", @"/Library/Spotlight", @"~/Library/Spotlight"};


@implementation SpotlightImporters

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
-(void)scan
{
    //spotlight importer directory
    NSString* importerDirectory = nil;
    
    //number of search directories
    NSUInteger directoryCount = 0;
    
    //all spotlight importers
    NSArray* allImporters = nil;
    
    //path to importer
    NSString* importerPath = nil;
    
    //directory (bundle) flag
    BOOL isDirectory = NO;
    
    //File obj
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //get number of search directories
    directoryCount = sizeof(SPOTLIGHT_SEARCH_DIRECTORIES)/sizeof(SPOTLIGHT_SEARCH_DIRECTORIES[0]);
    
    //iterate over all login item search directories
    // ->get all login items plists and process 'em
    for(NSUInteger i=0; i < directoryCount; i++)
    {
        //extract current directory
        importerDirectory = [SPOTLIGHT_SEARCH_DIRECTORIES[i] stringByExpandingTildeInPath];
        
        //get all login items plists in current directory
        allImporters = directoryContents(importerDirectory, nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* importer in allImporters)
        {
            //build full path to importer
            importerPath = [NSString stringWithFormat:@"%@/%@", importerDirectory, importer];
            
            //get directory flag
            if(YES != [[NSFileManager defaultManager] fileExistsAtPath:importerPath isDirectory:&isDirectory])
            {
                //ignore errors
                continue;
            }
            
            //skip non-directories
            if(YES != isDirectory)
            {
                //skip
                continue;
            }
            
            //create File object for importer
            fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:importerPath}];
            
            //skip File objects that err'd out for any reason
            if(nil == fileObj)
            {
                //skip
                continue;
            }
            
            //process item
            // ->save and report to UI
            [super processItem:fileObj];
        }
        
    }//spotlight importer directories
    
    return;
}

@end

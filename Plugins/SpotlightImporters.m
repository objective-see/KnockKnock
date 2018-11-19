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

//scan for spotlight importers
-(void)scan
{
    //all spotlight importers
    NSArray* allImporters = nil;
    
    //path to importer
    NSString* importerPath = nil;
    
    //File obj
    File* fileObj = nil;
    
    //dbg msg
    //NSLog(@"%@: scanning", PLUGIN_NAME);
    
    //iterate over all spotlight importer search directories
    // get all spotlight importer bundles and process each of them
    for(NSString* importerDirectory in expandPaths(SPOTLIGHT_SEARCH_DIRECTORIES, sizeof(SPOTLIGHT_SEARCH_DIRECTORIES)/sizeof(SPOTLIGHT_SEARCH_DIRECTORIES[0])))
    {
        //get all items in current directory
        allImporters = directoryContents(importerDirectory, nil);
        
        //iterate over all importers
        // ->perform some sanity checks and then save
        for(NSString* importer in allImporters)
        {
            //build full path to importer
            importerPath = [NSString stringWithFormat:@"%@/%@", importerDirectory, importer];
            
            //make sure importer is a bundle
            // ->i.e. not just a random directory
            if(YES != [[NSWorkspace sharedWorkspace] isFilePackageAtPath:importerPath])
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

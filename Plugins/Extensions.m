//
//  Extensions.m
//  KnockKnock
//
//  Notes: view via these via System Preferences->Extensions, or pluginkit -vmA

#import "File.h"
#import "Utilities.h"
#import "Extensions.h"

//plugin name
#define PLUGIN_NAME @"Extensions and Widgets"

//plugin description
#define PLUGIN_DESCRIPTION @"plugins that extend or customize the OS"

//plugin icon
#define PLUGIN_ICON @"extensionIcon"

@implementation Extensions

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

//get list of installed extensions (via 'pluginkit -vmA')
-(NSMutableArray*)enumExtensions
{
    //all extensions
    NSMutableArray* extensions = nil;
    
    //task output
    NSData* taskOutput = nil;
    
    //alloc array for extensions
    extensions = [NSMutableArray array];
    
    //start of path
    NSRange pathOffset = {0};
    
    //exec 'pluginkit -vmA'
    taskOutput = execTask(PLUGIN_KIT, @[@"-vmA"]);
    if( (nil == taskOutput) ||
        (0 == taskOutput.length) )
    {
        //bail
        goto bail;
    }

    //process each line
    for(NSString* line in [[[[NSString alloc] initWithData:taskOutput encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"\n"])
    {
        //ignore those that aren't enabled
        // ->enabled plugins start with '+'
        if(YES != [line hasPrefix:@"+"])
        {
            //skip
            continue;
        }
        
        //find start of path
        // ->first occurance of '/'
        pathOffset =  [line rangeOfString:@"/"];
        if(NSNotFound == pathOffset.location)
        {
            //skip
            continue;
        }
        
        //add path
        [extensions addObject:[line substringFromIndex:pathOffset.location]];
        
    }
    
    
//bail
bail:
    
    return extensions;
    
}

//scan for extensions
-(void)scan
{
    //File obj
    File* fileObj = nil;
    
    //enumerate all extensions
    for(NSString* extension in [self enumExtensions])
    {
        //create File object
        fileObj = [[File alloc] initWithParams:@{KEY_RESULT_PLUGIN:self, KEY_RESULT_PATH:extension}];
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

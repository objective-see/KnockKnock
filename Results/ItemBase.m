//
//  PluginBase.m
//  KnockKnock

#import "Consts.h"
#import "Command.h"
#import "ItemBase.h"


#define kErrFormat @"%@ not implemented in subclass %@"
#define kExceptName @"KK Item"



@implementation ItemBase

@synthesize name;
@synthesize path;
@synthesize isTrusted;
@synthesize attributes;

//init method
-(id)initWithParams:(NSDictionary*)params
{
    //super
    self = [super init];
    if(nil != self)
    {
        //save plugin
        self.plugin = params[KEY_RESULT_PLUGIN];
    
        //extract/save name
        self.name = params[KEY_RESULT_NAME];
        
        //extract/save path
        self.path = params[KEY_RESULT_PATH];
        
        //for files/extensions
        // ->get attributes
        if(YES != [self isKindOfClass:[Command class]])
        {
            //get attributes
            // ->based off path
            self.attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
        }
    }
    
    return self;
}

//return a path that can be opened in Finder.app
-(NSString*)pathForFinder
{
    return self.path;
}


/* OPTIONAL METHODS */


/* REQUIRED METHODS */

//stubs for inherited methods
// ->all just throw exceptions as they should be implemented in sub-classes

//scan
-(void)scan:(NSDictionary*)scanOptions
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return;
}

//convert object to JSON string
-(NSString*)toJSON
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return nil;
}

@end

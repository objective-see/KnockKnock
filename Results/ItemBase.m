//
//  PluginBase.m
//  KnockKnock

#import "consts.h"
#import "Command.h"
#import "ItemBase.h"
#import "utilities.h"


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
        self.path = [[params[KEY_RESULT_PATH] stringByStandardizingPath] stringByResolvingSymlinksInPath];
        
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

//serialize a dictionary to a JSON string
// sanitizes values first, and on any failure, still emits name/path (so item never vanishes from output)
-(NSString*)serializeToJSON:(NSDictionary*)dictionary
{
    //json (string)
    NSString* json = nil;
    
    //json (data)
    NSData* jsonData = nil;
    
    //(sanitized) dictionary
    id sanitized = nil;
    
    //sanitize
    // e.g. (attacker-controlled) entitlements can contain data/dates, which JSON doesn't support
    sanitized = makeJSONSafe(dictionary);
    
    //serialize
    // wrap, as can throw on invalid objects
    @try
    {
        //serialize
        if(YES == [NSJSONSerialization isValidJSONObject:sanitized])
        {
            //serialize
            jsonData = [NSJSONSerialization dataWithJSONObject:sanitized options:kNilOptions error:NULL];
        }
    }
    @catch(NSException* exception)
    {
        //ignore
        // handled below
        ;
    }
    
    //convert to string
    if(nil != jsonData)
    {
        //convert
        json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    //failed?
    // still emit the basics (name/path), so item doesn't vanish from output
    if(nil == json)
    {
        //serialize basics
        // just strings, so can't fail
        jsonData = [NSJSONSerialization dataWithJSONObject:@{@"name":[self.name description] ?: @"unknown", @"path":[self.path description] ?: @"unknown", @"error":@"serialization failed"} options:kNilOptions error:NULL];
        
        //convert
        json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return json ?: @"{\"error\": \"serialization failed\"}";
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

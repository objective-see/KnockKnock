//
//  PluginBase.h
//  KnockKnock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PluginBase;

@interface ItemBase : NSObject
{
    
}

//plugin
@property(nonatomic, retain)PluginBase* plugin;

//name
@property(retain, nonatomic)NSString* name;

//path
@property(retain, nonatomic)NSString* path;

//file attributes
@property(nonatomic, retain)NSDictionary* attributes;

//flag if known
// ->signed by apple and/or whitelisted
@property BOOL isTrusted;


/* METHODS */

//init method
-(id)initWithParams:(NSDictionary*)params;

//return a path that can be opened in Finder.app
-(NSString*)pathForFinder;

//convert object to JSON string
-(NSString*)toJSON;




@end

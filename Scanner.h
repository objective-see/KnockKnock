//
//  Scanner.h
//  DHS
//
//  Created by Patrick Wardle on 2/4/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import "MachO.h"
#import "Binary.h"
#import <Foundation/Foundation.h>

@interface Scanner : NSObject
{
    
}

//binaries
@property(nonatomic, retain)NSMutableArray* scannedBinaries;

//instance of machO parser
@property(nonatomic, retain)MachO* machoParser;

//flag for full scan
@property BOOL doFullScan;

//flag for detecting weak hijackers
@property BOOL scan4WeakHijackers;

/* METHODS */

//init
// ->sets scanner options
-(id)initWithOptions:(NSDictionary*)options;

//begin/do scan
-(void)scan;

//get/scan all binaries on file system
-(void)scanBinariesFileSys;

//get/scan binaries from process list
-(void)scanBinariesProcList;

//parse a binary
-(BOOL)parseBinary:(Binary*)binary;

//scan a binary
// ->determine if its hijacked or vulnerable
-(void)scanBinary:(Binary*)binary;

//check if a binary is hijacked
-(void)scan4Hijack:(Binary*)binary;

//check if a binary is vulnerable
// ->either to weak or rpath hijack
-(void)scan4Vulnerable:(Binary*)binary;

//resolve an array of paths
// ->any that start with w/ '@loader_path' or '@executable_path' will be resolved
-(NSMutableArray*)resolvePaths:(Binary*)binary paths:(NSMutableArray*)paths;

//resolve a path that start w/ '@loader_path' or '@executable_path'
-(NSString*)resolvePath:(Binary*)binary path:(NSString*)unresolvedPath;

//check if a found weakly imported dylib is suspicious
-(BOOL)isWeakImportSuspicious:(Binary*)binary weakDylib:(NSString*)weakImport;

//check if the digital signatures of a binary and an dylib match
-(BOOL)doSignaturesMatch:(Binary*)binary dylib:(NSString*)dylib;

@end

//
//  MachO.m
//  MachOParser
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "MachO.h"

#import <math.h>
#import <mach-o/fat.h>
#import <mach-o/arch.h>
#import <mach-o/swap.h>
#import <mach-o/loader.h>

@implementation MachO

@synthesize binaryInfo;
@synthesize binaryData;
@synthesize packerSegmentNames;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc info dictionary
        // ->contains everything collected about the file
        binaryInfo = [NSMutableDictionary dictionary];
        
        //init array for machO headers
        self.binaryInfo[KEY_MACHO_HEADERS] = [NSMutableArray array];
        
        //init array for LC_RPATHS
        self.binaryInfo[KEY_LC_RPATHS] = [NSMutableArray array];
        
        //init array for LC_REEXPORT_DYLIBs
        self.binaryInfo[KEY_LC_REEXPORT_DYLIBS] = [NSMutableArray array];
        
        //init array for LC_LOAD_DYLIBs
        self.binaryInfo[KEY_LC_LOAD_DYLIBS] = [NSMutableArray array];
        
        //init array for LC_LOAD_WEAK_DYLIBs
        self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] = [NSMutableArray array];
        
        //init packer seg names
        // upx: __XHDR
        // mpress: __MPRESS__*
        packerSegmentNames = [NSSet setWithObjects:@"__XHDR", @"__MPRESS__", nil];
    }
    
    return self;
}

//parse a binary
// ->extract all required/interesting stuff
-(BOOL)parse:(NSString*)binaryPath classify:(BOOL)shouldClassify
{
    //ret var
    BOOL wasParsed = NO;
    
    //dbg msg
    //NSLog(@"parsing %@", binaryPath);
    
    //save path
    self.binaryInfo[KEY_BINARY_PATH] = binaryPath;
    
    //load binary into memory
    self.binaryData = [NSData dataWithContentsOfFile:binaryPath];
    if( (nil == self.binaryData) ||
        (NULL == [self.binaryData bytes]) )
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: failed to load %@ into memory", binaryPath);
        
        //bail
        goto bail;
    }
    
    //parse headers
    // ->populates 'KEY_MACHO_HEADERS' array in 'binaryInfo' iVar
    if(YES != [self parseHeaders])
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: failed to find any machO headers");
        
        //bail
        goto bail;
    }
    
    //parse headers
    // ->populates 'KEY_MACHO_HEADERS' array in 'binaryInfo' iVar
    if(YES != [self parseLoadCmds])
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: failed to parse load commands");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    //NSLog(@"parsed load commands");
    
    //only do packer/encryption checks if specified
    if(YES == shouldClassify)
    {
        //first determine if binary is encrypted
        self.binaryInfo[KEY_IS_ENCRYPTED] = [NSNumber numberWithBool:[self isEncrypted]];
        
        //all encrypted binaries will also appear packed
        // ->so only check if unencrypted binaries are unpacked
        if(YES != [self.binaryInfo[KEY_IS_ENCRYPTED] boolValue])
        {
            //determine if packed
            self.binaryInfo[KEY_IS_PACKED] = [NSNumber numberWithBool:[self isPacked]];
        }
    }
    
    //happy
    wasParsed = YES;
    
//bail
bail:
    
    return wasParsed;
}

//parse all machO headers
-(BOOL)parseHeaders
{
    //return var
    BOOL wasParsed = NO;
    
    //start of macho header
    const uint32_t *headerStart = NULL;
    
    //swapped flag
    BOOL shouldSwap = NO;
    
    //header dictionary
    NSDictionary* header = nil;
    
    //number of machO headers
    uint32_t headerCount = 0;
    
    //header offsets
    NSMutableArray* headerOffsets = nil;
    
    //per-architecture header
    struct fat_arch *arch = NULL;
    
    //pointer to binary's data
    const void* binaryBytes = NULL;
    
    //alloc array
    headerOffsets = [NSMutableArray array];
    
    //grab binary's bytes
    binaryBytes = [self.binaryData bytes];
    if(NULL == binaryBytes)
    {
        //bail
        goto bail;
    }
    
    //init start of header
    headerStart = binaryBytes;
    
    //handle universal (fat) case
    if( (FAT_MAGIC == *headerStart) ||
        (FAT_CIGAM == *headerStart) )
    {
        //dbg msg
        //NSLog(@"parsing universal binary");
        
        //swap if needed
        if(FAT_CIGAM == *headerStart)
        {
            //set flag
            shouldSwap = YES;
            
            //swap
            swap_fat_header((struct fat_header*)headerStart, 0);
        }
        
        //get number of fat_arch structs
        // ->one per each architecture
        headerCount = ((struct fat_header*)binaryBytes)->nfat_arch;
        
        //get offsets of all headers
        for(uint32_t i = 0; i < headerCount; i++)
        {
            //get current struct fat_arch *
            // ->base + size of fat_header + size of fat_archs
            arch = (struct fat_arch*)((unsigned char*)binaryBytes + sizeof(struct fat_header) + i * sizeof(struct fat_arch));
            
            //swap if needed
            if(YES == shouldSwap)
            {
                //swap
                swap_fat_arch(arch, 0x01, 0);
            }
            
            //sanity check
            // ->make sure arch is something 'within' binary
            if( ((unsigned char*)arch < (unsigned char*)binaryBytes) ||
                ((unsigned char*)(binaryBytes + self.binaryData.length) < (unsigned char*)((unsigned char*)arch + sizeof(struct fat_arch))) )
            {
                //err
                goto bail;
            }
            
            //save into header offset array
            [headerOffsets addObject:[NSNumber numberWithUnsignedInt:arch->offset]];
        }
    }
    
    //not fat
    // ->just add start as (only) header offset
    else
    {
        //dbg msg
        //NSLog(@"parsing non-universal binary");
        
        //add start
        [headerOffsets addObject:@0x0];
    }
    
    //classify all headers
    for(NSNumber* headerOffset in headerOffsets)
    {
        //skip invalid header offsets
        if(headerOffset.unsignedIntValue > [self.binaryData length])
        {
            //skip
            continue;
        }
        
        //grab start of header
        headerStart = binaryBytes + headerOffset.unsignedIntValue;
        
        //classify header
        switch(*headerStart)
        {
            //32bit mach-O
            // ->little-endian version
            case MH_CIGAM:
                
                //swap
                swap_mach_header((struct mach_header*)headerStart, 0);
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:LITTLE_ENDIAN],
                           KEY_LOAD_COMMANDS: [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            //32-bit mach-O
            // ->big-endian version
            case MH_MAGIC:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:BIG_ENDIAN],
                           KEY_LOAD_COMMANDS: [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            //64-bit mach-O
            // ->little-endian version
            case MH_CIGAM_64:
                
                //swap
                swap_mach_header_64((struct mach_header_64*)headerStart, 0);
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header_64)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header_64*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:LITTLE_ENDIAN],
                           KEY_LOAD_COMMANDS: [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            //64-bit mach-O
            // ->big-endian version
            case MH_MAGIC_64:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header_64)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header_64*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:BIG_ENDIAN],
                           KEY_LOAD_COMMANDS: [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            default:
                
                //err msg
                //NSLog(@"OBJECTIVE-SEE ERROR: unknown machO magic: %#x", *headerStart);
                
                //next
                break;
                
        }//switch, classifying headers
        
    }//for all headers
    
    //sanity check
    // ->make sure parser found at least one header
    if(0 != [self.binaryInfo[KEY_MACHO_HEADERS] count])
    {
        //happy
        wasParsed = YES;
    }
    
//bail
bail:
    
    return wasParsed;
}

//parse the load commands
// ->for now just save LC_RPATH, LC_LOAD_DYLIB, and LC_LOAD_WEAK_DYLIB
-(BOOL)parseLoadCmds
{
    //ret var
    BOOL wasParsed = NO;
    
    //pointer to load command structure
    struct load_command *loadCommand = NULL;
    
    //path in load commands such as LC_LOAD_DYLIB
    NSString* path = nil;
    
    //pointer to binary's data
    const void* binaryBytes = NULL;
    
    //current macho header
    struct mach_header* currentHeader =  NULL;

    //grab binary's bytes
    binaryBytes = [self.binaryData bytes];
    if(NULL == binaryBytes)
    {
        //bail
        goto bail;
    }
    
    //iterate over all machO headers
    for(NSDictionary* machoHeader in self.binaryInfo[KEY_MACHO_HEADERS])
    {
        //get pointer to current machO header
        currentHeader = (struct mach_header*)(unsigned char*)(binaryBytes + [machoHeader[KEY_HEADER_OFFSET] unsignedIntegerValue]);
    
        //get first load command
        // ->immediately follows header
        loadCommand = (struct load_command*)(unsigned char*)(binaryBytes + [machoHeader[KEY_HEADER_OFFSET] unsignedIntegerValue] + [machoHeader[KEY_HEADER_SIZE] unsignedIntValue]);
        
        //iterate over all load commands
        // ->number of commands is in 'ncmds' member of (current) header struct
        for(uint32_t i = 0; i < currentHeader->ncmds; i++)
        {
            //sanity check load command
            if((unsigned char*)loadCommand > (unsigned char*)((unsigned char*)currentHeader + [machoHeader[KEY_HEADER_SIZE] unsignedIntegerValue] + currentHeader->sizeofcmds))
            {
                //bail
                goto bail;
            }
            
            //swap if needed
            if(LITTLE_ENDIAN == [machoHeader[KEY_HEADER_BYTE_ORDER] unsignedIntegerValue])
            {
                //swap
                // ->manually swap, cuz don't won't to affect in memory values
                switch (OSSwapBigToHostInt32(loadCommand->cmd))
                {
                    case LC_SEGMENT:
                        
                        //swap
                        swap_segment_command((struct segment_command *)loadCommand, 0x0);
                        break;
                        
                    case LC_SEGMENT_64:
                        
                        //swap
                        swap_segment_command_64((struct segment_command_64 *)loadCommand, 0x0);
                        break;
                        
                    default:
                        
                        //swap
                        swap_load_command(loadCommand, 0x0);
                        break;
                        
                }//switch
                
            }//need to swap

            //save load command
            [machoHeader[KEY_LOAD_COMMANDS] addPointer:loadCommand];
            
            //handle load commands of interest
            switch(loadCommand->cmd)
            {
                //LC_RPATHs
                // ->extract and save path
                case LC_RPATH:
                    
                    //extract name
                    path = [self extractPath:loadCommand byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
                    
                    //save if new
                    if(YES != [self.binaryInfo[KEY_LC_RPATHS] containsObject:path])
                    {
                        //save
                        [self.binaryInfo[KEY_LC_RPATHS] addObject:path];
                    }
                    
                    break;
                    
                //LC_REEXPORT_DYLIB
                // ->extract and save path
                case LC_REEXPORT_DYLIB:
                    
                    //extract name
                    path = [self extractPath:loadCommand byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
                    
                    //save if new
                    if(YES != [self.binaryInfo[KEY_LC_REEXPORT_DYLIBS] containsObject:path])
                    {
                        //save
                        [self.binaryInfo[KEY_LC_REEXPORT_DYLIBS] addObject:path];
                    }
                    
                    break;
                    
                //LC_LOAD_DYLIB and LC_LOAD_WEAK_DYLIB
                // ->extract and save path
                case LC_LOAD_DYLIB:
                case LC_LOAD_WEAK_DYLIB:
                    
                    //extract name
                    path = [self extractPath:loadCommand byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
                    
                    //save if new dylib
                    if( (LC_LOAD_DYLIB == loadCommand->cmd) &&
                        (YES != [self.binaryInfo[KEY_LC_LOAD_DYLIBS] containsObject:path]) )
                    {
                        //save
                        [self.binaryInfo[KEY_LC_LOAD_DYLIBS] addObject:path];
                    }
                    
                    //save if new weak dylib
                    else if( (LC_LOAD_WEAK_DYLIB == loadCommand->cmd) &&
                             (YES != [self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] containsObject:path]) )
                    {
                        //save
                        [self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] addObject:path];
                    }
                    
                    break;
                    
                default:
                    
                    break;
            }
            
            //got to next load command
            // ->immediately follows current one
            loadCommand = (struct load_command *)(((unsigned char*)((unsigned char*)loadCommand + loadCommand->cmdsize)));
            
        }//all load commands
        
    }//all machO headers
    
    //happy
    wasParsed = YES;
    
//bail
bail:
    
    return wasParsed;
}

//determine if binary is encrypted
// with OS X's native encryption scheme
// see: http://osxbook.com/book/bonus/chapter7/tpmdrmmyth/
-(BOOL)isEncrypted
{
    //flag
    BOOL encrypted = NO;
    
    //load command
    struct load_command* loadCommand = NULL;
    
    //flags
    uint32_t segmentFlags = 0;
    
    //check text segments
    // ->any marked encrypted; set flag
    for(NSMutableDictionary* machoHeader in self.binaryInfo[KEY_MACHO_HEADERS])
    {
        //check all load commands
        for(NSUInteger i = 0; i< [machoHeader[KEY_LOAD_COMMANDS] count]; i++)
        {
            //grab load command
            loadCommand = [machoHeader[KEY_LOAD_COMMANDS] pointerAtIndex:i];
            
            //ignore non-segments
            if( (loadCommand->cmd != LC_SEGMENT) &&
                (loadCommand->cmd != LC_SEGMENT_64) )
            {
                //skip
                continue;
            }
            
            //ignore everything that is not a text segment
            // ->for name check, segment_command & segment_command_64 are same
            if(0 != strncmp(((struct segment_command *)loadCommand)->segname, SEG_TEXT, sizeof(((struct segment_command *)loadCommand)->segname)))
            {
                //skip
                continue;
            }
            
            //grab flags
            // ->32bit
            if(sizeof(struct mach_header) == [machoHeader[KEY_HEADER_SIZE] integerValue])
            {
                //flags
                segmentFlags = ((struct segment_command *)loadCommand)->flags;
                
            }
            //grab flags
            // ->64bit
            else if(sizeof(struct mach_header_64) == [machoHeader[KEY_HEADER_SIZE] integerValue])
            {
                //flags
                segmentFlags = ((struct segment_command_64 *)loadCommand)->flags;

            }
            
            //check if segment is protected
            if(SG_PROTECTED_VERSION_1 == (segmentFlags & SG_PROTECTED_VERSION_1))
            {
                //set flag
                encrypted = YES;
                
                //bail
                // ->any marked encrypted; set flag for all
                goto bail;
            }
        
        }//all load commands
    
    }//all macho headers (e.g. fat file)
    
//bail
bail:
    
    return encrypted;
}

//determine if packed
// segment names and/or entropy
// see: https://github.com/hiddenillusion/AnalyzePE/blob/master/peutils.py
-(BOOL)isPacked
{
    //flag
    BOOL packed = NO;
    
    //file's data
    NSData* fileData = nil;
    
    //file's data, as bytes
    char* fileBytes = NULL;
    
    //load command
    struct load_command* loadCommand = NULL;
    
    //segment offset
    u_int64_t segmentOffset = 0;
    
    //segment size
    u_int64_t segmentSize = 0;
    
    //segment entropy
    float segmentEntropy = 0.0f;
    
    //total
    float totalCompressedData = 0.0f;
    
    //segment name
    NSString* segmentName = nil;
    
    //segment name length
    NSUInteger segmentNameLength = 0;
    
    //open/read into file
    fileData = [NSData dataWithContentsOfFile:self.binaryInfo[KEY_BINARY_PATH]];
    if(nil == fileData)
    {
        //bail
        goto bail;
    }
    
    //get raw bytes
    fileBytes = (char*)[fileData bytes];
    
    //check text segments
    // ->any marked encrypted; set flag
    for(NSMutableDictionary* machoHeader in self.binaryInfo[KEY_MACHO_HEADERS])
    {
        //check all load commands
        for(NSUInteger i = 0; i<[machoHeader[KEY_LOAD_COMMANDS] count]; i++)
        {
            //grab load command
            loadCommand = [machoHeader[KEY_LOAD_COMMANDS] pointerAtIndex:i];
            
            //ignore non-segments
            if( (loadCommand->cmd != LC_SEGMENT) &&
                (loadCommand->cmd != LC_SEGMENT_64) )
            {
                //skip
                continue;
            }
            
            //init segment name length
            segmentNameLength = MIN(strlen(((struct segment_command *)loadCommand)->segname), sizeof(((struct segment_command *)loadCommand)->segname));
            
            //sanity check
            if(0 == segmentNameLength)
            {
                //skip
                continue;
            }
            
            //init segment name
            segmentName = [[NSString alloc] initWithBytes:((struct segment_command *)loadCommand)->segname length:segmentNameLength encoding:NSUTF8StringEncoding];
    
            //check if segment name matches known packer
            // ->upx, mpress etc have unique segment names
            if(YES == [self.packerSegmentNames containsObject:segmentName])
            {
                //dbg msg
                //NSLog(@"found match w/ packed section: %@", segmentName);
                
                //got match
                packed = YES;
                
                //bail
                // ->its packed
                goto bail;
                
            }
            
            //32bit
            // ->get offset/size of segment
            if(sizeof(struct mach_header) == [machoHeader[KEY_HEADER_SIZE] integerValue])
            {
                //offset
                segmentOffset = ((struct segment_command *)loadCommand)->fileoff;
                
                //size
                segmentSize = ((struct segment_command *)loadCommand)->filesize;
                
            }
            //64bit
            // ->get offset/size of segment
            else if(sizeof(struct mach_header_64) == [machoHeader[KEY_HEADER_SIZE] integerValue])
            {
                //offset
                segmentOffset = ((struct segment_command_64 *)loadCommand)->fileoff;
                
                //size
                segmentSize = ((struct segment_command_64 *)loadCommand)->filesize;
            }
            
            //calc entropy
            // ->does entire segment...
            segmentEntropy = [self calcEntropy:&fileBytes[segmentOffset] length:segmentSize];
            
            //dbg msg
            //NSLog(@"%s's entropy: %f", ((struct segment_command *)loadCommand)->segname, segmentEntropy);
            
            //TODO: test more!
            if(segmentEntropy > 7.2f)
            {
                //inc total
                totalCompressedData += segmentSize;
            }
        
        }//all load commands
        
        //dbg msg
        //NSLog(@"final calc: %f\n", (1.0 * totalCompressedData)/fileData.length);
        
        //final calculation for architecture
        if( ((1.0 * totalCompressedData)/fileData.length) > .2)
        {
            //set
            packed = YES;
            
            //bail
            // ->its packed
            goto bail;
            
        }
        
    }//for all macho headers (e.g. fat file)
    
//bail
bail:
    
    return packed;
}

//based on https://github.com/erocarrera/pefile/blob/master/pefile.py
-(float)calcEntropy:(char*)data length:(NSUInteger)length
{
    //entropy
    float entropy = 0.0f;
    
    //occurances array
    unsigned int occurrences[256] = {0};
    
    //intermediate var
    float pX = 0.0f;
    
    //sanity check
    if(0 == length)
    {
        //bail
        goto bail;
    }
    
    //count all occurances
    for(NSUInteger i = 0; i<length; i++)
    {
        //inc
        occurrences[0xFF & (int)data[i]]++;
    }
    
    //calc entropy
    for(NSUInteger i = 0; i<sizeof(occurrences)/sizeof(occurrences[0]); i++)
    {
        //skip non-occurances
        if(0 == occurrences[i])
        {
            //skip
            continue;
        }
        
        //calc
        pX = occurrences[i]/(float)length;
        
        entropy -= pX*log2(pX);
    }
    
//bail
bail:
    
    return entropy;
}

//helper function
// extract a path from an load command
// ->is a little tricky due to offsets and lengths of strings (null paddings, etc)
-(NSString*)extractPath:(struct load_command *)loadCommand byteOrder:(NSNumber*)byteOrder
{
    //offset
    size_t pathOffset = 0;
    
    //path bytes
    char* pathBytes = NULL;
    
    //length of path
    size_t pathLength = 0;
    
    //path
    NSString* path = nil;
    
    //set path offset
    // ->different based on load command type
    switch(loadCommand->cmd)
    {
        //LC_RPATHs
        case LC_RPATH:
            
            //set offset
            pathOffset = sizeof(struct rpath_command);
            
            break;
            
        //LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIBS
        case LC_LOAD_DYLIB:
        case LC_REEXPORT_DYLIB:
        case LC_LOAD_WEAK_DYLIB:
        
            //set offset
            pathOffset = sizeof(struct dylib_command);
            
            break;
            
        default:
            break;
    }
    
    //init pointer to path's bytes
    pathBytes = (char*)loadCommand + pathOffset;
    
    //set path's length
    // ->min of strlen/value calculated from load command size
    pathLength = MIN(strlen(pathBytes), (loadCommand->cmdsize - pathOffset));
    
    //create nstring version of path
    path = [[NSString alloc] initWithBytes:pathBytes length:pathLength encoding:NSUTF8StringEncoding];
    
    return path;
}


@end

//
//  Utilities.m
//  DHS
//
//  Created by Patrick Wardle on 2/7/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"

#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

//check if OS is supported
BOOL isSupportedOS()
{
    //return
    BOOL isSupported = NO;
    
    //major version
    SInt32 versionMajor = 0;
    
    //minor version
    SInt32 versionMinor = 0;
    
    //get major version
    versionMajor = getVersion(gestaltSystemVersionMajor);
    
    //get minor version
    versionMinor = getVersion(gestaltSystemVersionMinor);
    
    //sanity check
    if( (-1 == versionMajor) ||
        (-1 == versionMinor) )
    {
        //err
        goto bail;
    }
    
    //check that OS is supported
    // ->10.8+ ?
    if( (versionMajor == OS_MAJOR_VERSION_X) &&
        (versionMinor >= OS_MINOR_VERSION_LION) )
    {
        //set flag
        isSupported = YES;
    }
    
//bail
bail:
    
    return isSupported;
}

//get OS's major or minor version
SInt32 getVersion(OSType selector)
{
    //version
    // ->major or minor
    SInt32 version = -1;
    
    //get version info
    if(noErr != Gestalt(selector, &version))
    {
        //reset version
        version = -1;
        
        //err
        goto bail;
    }
    
//bail
bail:
    
    return version;
}


//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path)
{
    //info dictionary
    NSMutableDictionary* signingStatus = nil;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //status
    OSStatus status = !STATUS_SUCCESS;
    
    //signing information
    CFDictionaryRef signingInformation = NULL;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //init signing status
    signingStatus = [NSMutableDictionary dictionary];
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    
    //save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //sanity check
    if(STATUS_SUCCESS != status)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: SecStaticCodeCreateWithPath() failed on %@ with %d", path, status);
        
        //bail
        goto bail;
    }
    
    //check signature
    status = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSDoNotValidateResources, NULL, NULL);
    
    //(re)save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //if file is signed
    // ->grab signing authorities
    if(STATUS_SUCCESS == status)
    {
        //grab signing authorities
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingInformation);
        
        //sanity check
        if(STATUS_SUCCESS != status)
        {
            //err msg
            NSLog(@"OBJECTIVE-SEE ERROR: SecCodeCopySigningInformation() failed on %@ with %d", path, status);
            
            //bail
            goto bail;
        }
    }
    
    //init array for certificate names
    signingStatus[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //handle case there is no cert chain
    // ->adhoc? (/Library/Frameworks/OpenVPN.framework/Versions/Current/bin/openvpn-service)
    if(0 == certificateChain.count)
    {
        //set
        [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:@"signed, but no signing authorities (adhoc?)"];
    }
    
    //got cert chain
    // ->add each to list
    else
    {
        //get name of all certs
        for(index = 0; index < certificateChain.count; index++)
        {
            //extract cert
            certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
            
            //get common name
            status = SecCertificateCopyCommonName(certificate, &commonName);
            
            //skip ones that error out
            if( (STATUS_SUCCESS != status) ||
                (NULL == commonName))
            {
                //skip
                continue;
            }
            
            //save
            [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:(__bridge NSString*)commonName];
            
            //release name
            CFRelease(commonName);
        }
    }
    
//bail
bail:
    
    //free signing info
    if(NULL != signingInformation)
    {
        //free
        CFRelease(signingInformation);
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
    }
    
    return signingStatus;
}

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path)
{
    //flag
    BOOL isApple = NO;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //status
    OSStatus status = -1;
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: SecStaticCodeCreateWithPath() failed on %@ with %d", path, status);
        
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple'
    // (3rd party: 'anchor apple generic')
    status = SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &requirementRef);
    if( (STATUS_SUCCESS != status) ||
        (requirementRef == NULL) )
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: SecRequirementCreateWithString() failed on %@ with %d", path, status);
        
        //bail
        goto bail;
    }
    
    //check if file is signed by apple
    // ->i.e. it conforms to req string
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, requirementRef);
    if(STATUS_SUCCESS != status)
    {
        //bail
        // ->just means app isn't signed by apple
        goto bail;
    }
    
    //ok, happy (SecStaticCodeCheckValidity() didn't fail)
    // ->file is signed by Apple
    isApple = YES;
    
//bail
bail:
    
    //free req reference
    if(NULL != requirementRef)
    {
        //free
        CFRelease(requirementRef);
    }

    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
    }

    
    return isApple;
}


//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary, NSBundle* bundle)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //system's document icon
    NSData* documentIcon = nil;
    
    //icon
    NSImage* icon = nil;
    
    //if not bundle was passed in
    // ->try find one
    if(nil == bundle)
    {
        //load bundle
        bundle = findAppBundle(binary);
    }
    
    //for app's
    // ->extract their icon
    if(nil != bundle)
    {
        //get file
        iconFile = bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // ->try to get it via shared workspace
    if( (nil == bundle) ||
        (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:binary];
        
        //load system document icon
        documentIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:
                         NSFileTypeForHFSTypeCode(kGenericDocumentIcon)] TIFFRepresentation];
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // ->the system 'applicaiton' icon seems more applicable, so use that here...
        if(YES == [[icon TIFFRepresentation] isEqual:documentIcon])
        {
            //set icon to system 'applicaiton' icon
            icon = [[NSWorkspace sharedWorkspace]
                         iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // ->so set size to 64
        [icon setSize:NSMakeSize(64, 64)];
    }
    
    return icon;
}


//if string is too long to fit into a the text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, NSString* string, float width)
{
    //trucated string (with ellipis)
    NSMutableString *truncatedString = nil;
    
    //offset of last '/'
    NSRange lastSlash = {};
    
    //make copy of string
    truncatedString = [string mutableCopy];
    
    //sanity check
    // ->make sure string needs truncating
    if([string sizeWithAttributes: @{NSFontAttributeName: textField.font}].width < width)
    {
        //bail
        goto bail;
    }
    
    //find instance of last '/
    lastSlash = [string rangeOfString:@"/" options:NSBackwardsSearch];
    
    //sanity check
    // ->make sure found a '/'
    if(NSNotFound == lastSlash.location)
    {
        //bail
        goto bail;
    }
    
    //account for added ellipsis
    width -= [ELLIPIS sizeWithAttributes: @{NSFontAttributeName: textField.font}].width;
    
    //delete characters until string will fit into specified size
    while([truncatedString sizeWithAttributes: @{NSFontAttributeName: textField.font}].width > width)
    {
        //sanity check
        // ->make sure we don't run off the front
        if(0 == lastSlash.location)
        {
            //bail
            goto bail;
        }
        
        //skip back
        lastSlash.location--;
        
        //delete char
        [truncatedString deleteCharactersInRange:lastSlash];
    }
    
    //set length of range
    lastSlash.length = ELLIPIS.length;
    
    //back up location
    lastSlash.location -= ELLIPIS.length;
    
    //add in ellipis
    [truncatedString replaceCharactersInRange:lastSlash withString:ELLIPIS];
    
    
//bail
bail:
    
    return truncatedString;
}

//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate)
{
    //(unfiltered) directory contents
    NSArray* directoryContents = nil;
    
    //matches
    NSArray* matches = nil;
    
    //get (umfiltered) directory contents
    directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    
    //filter out matches
    if(nil != predicate)
    {
        //filter
        matches = [directoryContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:predicate]];
    }
    //no need to filter
    else
    {
        //no filter
        matches = directoryContents;
    }

    return matches;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
           (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
        //scan until we get to root
        // ->of course, loop will be exited if app info dictionary is found/loaded
    } while( (nil != appPath) &&
            (YES != [appPath isEqualToString:@"/"]) &&
            (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//hash a file
// ->md5 and sha1
NSDictionary* hashFile(NSString* filePath)
{
    //file hashes
    NSDictionary* hashes = nil;
    
    //file's contents
    NSData* fileContents = nil;
    
    //hash digest (md5)
    uint8_t digestMD5[CC_MD5_DIGEST_LENGTH] = {0};
    
    //md5 hash as string
    NSMutableString* md5 = nil;
    
    //hash digest (sha1)
    uint8_t digestSHA1[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha1 = nil;
    
    //index var
    NSUInteger index = 0;
    
    //init md5 hash string
    md5 = [NSMutableString string];
    
    //init sha1 hash string
    sha1 = [NSMutableString string];
    
    //load file
    if(nil == (fileContents = [NSData dataWithContentsOfFile:filePath]))
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: couldn't load %@ to hash", filePath);
        
        //bail
        goto bail;
    }
    
    //md5 it
    CC_MD5(fileContents.bytes, (unsigned int)fileContents.length, digestMD5);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_MD5_DIGEST_LENGTH; index++)
    {
        //format/append
        [md5 appendFormat:@"%02lX", (unsigned long)digestMD5[index]];
    }
    
    //sha1 it
    CC_SHA1(fileContents.bytes, (unsigned int)fileContents.length, digestSHA1);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_SHA1_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha1 appendFormat:@"%02lX", (unsigned long)digestSHA1[index]];
    }
    
    //init hash dictionary
    hashes = @{KEY_HASH_MD5: md5, KEY_HASH_SHA1: sha1};
    
//bail
bail:
    
    return hashes;
}

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url)
{
    //hyperlink
    NSMutableAttributedString *hyperlinkString = nil;
    
    //range
    NSRange range = {0};
    
    //init hyper link
    hyperlinkString = [[NSMutableAttributedString alloc] initWithString:textField.stringValue];
    
    //init range
    range = NSMakeRange(0, [hyperlinkString length]);
   
    //start editing
    [hyperlinkString beginEditing];
    
    //add url
    [hyperlinkString addAttribute:NSLinkAttributeName value:url range:range];
    
    //make it blue
    [hyperlinkString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:NSMakeRange(0, [hyperlinkString length])];
    
    //underline
    [hyperlinkString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:NSMakeRange(0, [hyperlinkString length])];
    
    //done editing
    [hyperlinkString endEditing];
    
    //set text
    [textField setAttributedStringValue:hyperlinkString];
    
    return;
}

//set the color of an attributed string
NSMutableAttributedString* setStringColor(NSAttributedString* string, NSColor* color)
{
    //colored string
    NSMutableAttributedString *coloredString = nil;

    //alloc/init colored string from existing one
    coloredString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    
    //set color
    [coloredString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [coloredString length])];
    
    return coloredString;
}


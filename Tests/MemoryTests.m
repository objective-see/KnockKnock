#import <Cocoa/Cocoa.h>
#import <mach-o/loader.h>
#import <sys/resource.h>
#import <fcntl.h>
#import <unistd.h>

#import "consts.h"
#import "utilities.h"
#import "Libraries/MachO/MachO.h"

static const size_t MiB = 1024 * 1024;

static void check(BOOL condition, const char* message)
{
    if(!condition)
    {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void writeAll(int fd, const void* bytes, size_t length)
{
    const char* cursor = bytes;
    while(length)
    {
        ssize_t count = write(fd, cursor, length);
        check(count > 0, "write fixture");
        cursor += count;
        length -= (size_t)count;
    }
}

static int createFile(NSString* path, off_t length)
{
    int fd = open(path.fileSystemRepresentation, O_CREAT | O_TRUNC | O_RDWR, 0600);
    check(fd >= 0, "create fixture");
    check(ftruncate(fd, length) == 0, "size fixture");
    return fd;
}

static void patternedFile(NSString* path, size_t length)
{
    int fd = createFile(path, (off_t)length);
    unsigned char buffer[8192];
    for(size_t offset = 0; offset < length;)
    {
        size_t count = MIN(sizeof(buffer), length - offset);
        for(size_t i = 0; i < count; ++i) buffer[i] = (offset + i) % 251;
        writeAll(fd, buffer, count);
        offset += count;
    }
    check(close(fd) == 0, "close patterned fixture");
}

static void machoFile(NSString* path, size_t length, BOOL encrypted)
{
    struct mach_header_64 header = {
        .magic = MH_MAGIC_64, .cputype = CPU_TYPE_X86_64,
        .cpusubtype = CPU_SUBTYPE_X86_64_ALL, .filetype = MH_DYLIB, .ncmds = 2,
        .sizeofcmds = sizeof(struct segment_command_64) + sizeof(struct dylib_command) + 32
    };
    struct segment_command_64 segment = {
        .cmd = LC_SEGMENT_64, .cmdsize = sizeof(segment), .segname = "__TEXT",
        .filesize = length, .flags = encrypted ? SG_PROTECTED_VERSION_1 : 0
    };
    struct dylib_command dylib = {
        .cmd = LC_LOAD_DYLIB, .cmdsize = sizeof(dylib) + 32,
        .dylib.name.offset = sizeof(dylib)
    };
    char name[32] = "/synthetic/libExample.dylib";
    int fd = createFile(path, (off_t)length);
    writeAll(fd, &header, sizeof(header));
    writeAll(fd, &segment, sizeof(segment));
    writeAll(fd, &dylib, sizeof(dylib));
    writeAll(fd, name, sizeof(name));
    check(close(fd) == 0, "close Mach-O fixture");
}

static void checkHashes(NSString* path, NSString* md5, NSString* sha1, NSString* sha256)
{
    NSDictionary* hashes = hashFile(path);
    check(hashes.count == 3, "all three hashes returned");
    check([hashes[KEY_HASH_MD5] isEqualToString:md5], "MD5 digest");
    check([hashes[KEY_HASH_SHA1] isEqualToString:sha1], "SHA1 digest");
    check([hashes[KEY_HASH_SHA256] isEqualToString:sha256], "SHA256 digest");
}

static void checkParser(NSString* path, BOOL classify, BOOL encrypted)
{
    MachO* parser = [[MachO alloc] init];
    check([parser parse:path classify:classify], "parse synthetic Mach-O");
    check([parser.binaryInfo[KEY_LC_LOAD_DYLIBS] isEqualToArray:@[@"/synthetic/libExample.dylib"]],
          "copied dylib path survives parse pool");
    NSArray* headers = parser.binaryInfo[KEY_MACHO_HEADERS];
    check(headers.count == 1, "one Mach-O header");
    check([headers[0][KEY_HEADER_BINARY_TYPE] intValue] == MH_DYLIB, "Mach-O file type");
    NSPointerArray* commands = headers[0][KEY_LOAD_COMMANDS];
    check(commands.count == 2, "both load commands survive parse pool");

    // The parser owns binaryData after parse returns; saved load commands point into it.
    struct segment_command_64* segment = [commands pointerAtIndex:0];
    struct dylib_command* dylib = [commands pointerAtIndex:1];
    const char* bytes = parser.binaryData.bytes;
    check((const char*)segment == bytes + sizeof(struct mach_header_64), "retained segment pointer");
    check(segment->cmd == LC_SEGMENT_64 && segment->filesize == parser.binaryData.length,
          "retained segment contents");
    check(dylib->cmd == LC_LOAD_DYLIB, "retained dylib command");
    check(strcmp((const char*)dylib + dylib->dylib.name.offset, "/synthetic/libExample.dylib") == 0,
          "retained dylib command bytes");
    if(classify)
    {
        check([parser.binaryInfo[KEY_IS_ENCRYPTED] boolValue] == encrypted, "encryption classification");
        if(!encrypted) check([parser.binaryInfo[KEY_IS_PACKED] isEqual:@NO], "packing classification");
    }
    else
    {
        check(parser.binaryInfo[KEY_IS_ENCRYPTED] == nil && parser.binaryInfo[KEY_IS_PACKED] == nil,
              "classification disabled");
    }
}

static void correctness(NSString* directory)
{
    NSString* path = [directory stringByAppendingPathComponent:@"hash-input"];
    close(createFile(path, 0));
    checkHashes(path, @"D41D8CD98F00B204E9800998ECF8427E", @"DA39A3EE5E6B4B0D3255BFEF95601890AFD80709",
                @"E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855");
    check([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO], "write abc fixture");
    checkHashes(path, @"900150983CD24FB0D6963F7D28E17F72", @"A9993E364706816ABA3E25717850C26C9CD0D89D",
                @"BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD");
    // Expected digests were independently calculated with Python hashlib for byte[i] = i % 251.
    patternedFile(path, MiB);
    checkHashes(path, @"8F293A2F6C19B345152F7A49BB4C643C", @"C2FC4CB20F1301A6B0DD211C19E69A13925DBE40",
                @"631B84027D6B9E52B539C4E8373622D23032DFADC64D60AF87339C9037E4F769");
    patternedFile(path, 2 * MiB + 17);
    checkHashes(path, @"A0C528060E3514B6DF937C15B8F1D2A8", @"A2AF63B2AD5410A4E9531CD5C5F3ED36CAD94C00",
                @"B057F26FAA652E9916AA08EED7E50906151F83DE0E878173E9D06E359C0DD75E");
    NSString* missing = [directory stringByAppendingPathComponent:@"does-not-exist"];
    check(hashFile(missing) == nil, "missing hash input rejected");
    check(hashFile(directory) == nil, "directory hash input rejected");

    path = [directory stringByAppendingPathComponent:@"valid.macho"];
    for(NSNumber* encrypted in @[@NO, @YES])
    {
        machoFile(path, 4096, encrypted.boolValue);
        checkParser(path, NO, encrypted.boolValue);
        checkParser(path, YES, encrypted.boolValue);
    }
    check(![[[MachO alloc] init] parse:missing classify:YES], "missing Mach-O rejected");
    close(createFile(path, 0));
    check(![[[MachO alloc] init] parse:path classify:NO], "empty Mach-O rejected");
    check([[@"not a Mach-O" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO],
          "write invalid fixture");
    check(![[[MachO alloc] init] parse:path classify:YES], "invalid Mach-O rejected");
    machoFile(path, 4096, NO);
    check(truncate(path.fileSystemRepresentation, 4) == 0, "truncate header fixture");
    check(![[[MachO alloc] init] parse:path classify:NO], "truncated Mach-O header rejected");
    machoFile(path, 4096, NO);
    check(truncate(path.fileSystemRepresentation, sizeof(struct mach_header_64) + 4) == 0,
          "truncate load command fixture");
    check(![[[MachO alloc] init] parse:path classify:YES], "truncated load command rejected");
    puts("PASS: hash and parser correctness");
}

static void checkMemory(const char* label)
{
    struct rusage usage = {0};
    check(getrusage(RUSAGE_SELF, &usage) == 0, "read peak resident memory");
    // On macOS ru_maxrss is measured in bytes. Leave ample room for framework/runtime overhead.
    double peakMiB = (double)usage.ru_maxrss / MiB;
    printf("%s peak resident memory: %.1f MiB (limit: 192 MiB)\n", label, peakMiB);
    check(peakMiB < 192, "temporary file buffers must not accumulate across 384 MiB of input");
}

int main(int argc, const char* argv[])
{
    check(argc == 3, "usage: memory-tests <correctness|parse-memory|hash-memory> <fixture-directory>");
    // Intentionally keep one outer pool alive through each worker's measurement, as in a long scan.
    @autoreleasepool
    {
        NSString* directory = [NSString stringWithUTF8String:argv[2]];
        if(strcmp(argv[1], "correctness") == 0)
        {
            correctness(directory);
        }
        else if(strcmp(argv[1], "parse-memory") == 0)
        {
            NSString* path = [directory stringByAppendingPathComponent:@"large.macho"];
            machoFile(path, 16 * MiB, NO);
            for(int i = 0; i < 24; ++i)
            {
                MachO* parser = [[MachO alloc] init];
                check([parser parse:path classify:(i % 2 == 0)], "parse repeated large Mach-O");
            }
            checkMemory("24 x 16 MiB Mach-O parses");
        }
        else if(strcmp(argv[1], "hash-memory") == 0)
        {
            NSString* path = [directory stringByAppendingPathComponent:@"large-hash-input"];
            close(createFile(path, 384 * MiB));
            checkHashes(path, @"5EC4C4CD4F2CB2450D3AA57DD6DF84BB", @"02D771088DEA1F8AC9D178C2BBDD226F3E1AA501",
                        @"3201548F7070F0AE5ADF2C869B15DF99B5F85CA51FEDA443C1597C130976619A");
            checkMemory("384 MiB file hash");
        }
        else check(NO, "unknown test mode");
    }
    return 0;
}

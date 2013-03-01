//
//  NSFileManager+MetaData.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 17/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NSFileManager+MetaData.h"

#include <sys/xattr.h>

@implementation NSFileManager (PLMetaData)

- (void) setMetaData:(NSString *)str forKey:(NSString *)key forFilename:(NSString *)filename
{
    const char * utf8;
    
    utf8 = [str UTF8String];
    setxattr([filename fileSystemRepresentation], [key UTF8String], utf8, strlen(utf8), 0, 0);
}

- (NSString *) metaDataForKey:(NSString *)key forFilename:(NSString *)filename
{
    ssize_t size;
    char * buffer;
    NSString * result;
    
    size = getxattr([filename fileSystemRepresentation], [key UTF8String], NULL, 0, 0, 0);
    if (size < 0)
        return nil;
    
    buffer = malloc(size + 1);
    buffer[size] = '\0';
    getxattr([filename fileSystemRepresentation], [key UTF8String], buffer, size, 0, 0);
    result = [NSString stringWithUTF8String:buffer];
    //NSLog(@"%@ %@ %u", key, result, size);
    free(buffer);
    
    return result;
}

@end

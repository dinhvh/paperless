//
//  NSFileManager+MetaData.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 17/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSFileManager (PLMetaData)

- (void) setMetaData:(NSString *)str forKey:(NSString *)key forFilename:(NSString *)filename;
- (NSString *) metaDataForKey:(NSString *)key forFilename:(NSString *)filename;

@end

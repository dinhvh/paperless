//
//  PLPDFPageGeneration.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface PLPDFPageGeneration : NSObject {
	NSMutableData * _data;
	PDFDocument * _document;
    NSSize _size;
    int _resolution;
}

- (id) init;
- (void) dealloc;

- (void) createDocument;

- (void) setPageSize:(NSSize)size;
- (void) setResolution:(int)resolution;

- (void) setImage:(NSString *)filename;

- (PDFDocument *) document;
- (PDFPage *) page;

@end

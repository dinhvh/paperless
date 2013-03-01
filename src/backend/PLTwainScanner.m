//
//  PLTwainScanner.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 27/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLTwainScanner.h"
#import "PLPageSizeInfo.h"
#import "PLScannerUtils.h"
#import "PLTwainSource.h"
#import "NSString+UUID.h"

@interface PLTwainScanner (Private) <PLTwainSourceDelegate>

- (void) plTwainSource:(PLTwainSource *)source imageFileData:(void *)data length:(size_t)length;
- (void) _removeFile;

@end

@implementation PLTwainScanner

@synthesize delegate = _delegate;

- (id) initWithTwainManagerSource:(PLTwainSource *)source
{
    PLPageSizeInfo * pageSize;
    
    self = [super init];
    
    _source = [source retain];
    [_source setDelegate:self];
    pageSize = [[[PLScannerUtils sharedManager] pageSizes] objectAtIndex:0];
	_size = [pageSize size];
    NSLog(@"initial page size : %g %g", _size.width, _size.height);
    [source setXferMode:twain_xfer_native];
    
    return self;
}

- (void) dealloc
{
    [self _removeFile];
    [_source release];
    [super dealloc];
}

- (NSString *) scannerName
{
    return [_source name];
}

- (void) setResolution:(int)resolution
{
    [_source setResolution:resolution];
}

- (void) setPageSizeFromName:(NSString *)pageSizeName
{
    PLPageSizeInfo * pageSize;
    CGRect layout;
    
    pageSize = [[PLScannerUtils sharedManager] pageSizeWithName:pageSizeName];
    NSLog(@"%@", pageSizeName);
    _size = [pageSize size];
    NSLog(@"set page size : %g %g", _size.width, _size.height);
    layout.origin = CGPointZero;
    layout.size = CGSizeMake(_size.width, _size.height);
    [_source setImageLayout:layout];
}

- (NSSize) pageSize
{
    NSLog(@"get page size : %g %g", _size.width, _size.height);
    return _size;
}

- (void) scan
{
    NSLog(@"%@ scan %@ %@", self, _filename, [self delegate]);
#if 0
    if (!_opened) {
        [_source open];
        _opened = YES;
    }
#endif
    [_source open];
    [_source acquire];
}

- (NSString *) filename
{
    return _filename;
}

- (NSError *) error
{
    return nil;
}

- (void) plTwainSource:(PLTwainSource *)source imageFileData:(void *)data length:(size_t)length
{
    NSImage * image;
    NSString * filename;
    
    [self _removeFile];
    
    image = [[NSImage alloc] initWithData: [NSData dataWithBytes:data length:length]];
    filename = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithNewUUID]];
    filename = [filename stringByAppendingPathExtension:@"tiff"];
    [[image TIFFRepresentation] writeToFile:filename atomically:NO];
    [image release];
    
    [_filename release];
    _filename = [filename retain];
    NSLog(@"saved %@ %@", _filename, [self delegate]);
    [[self delegate] plScanner_scanDone:self];
}

- (void) _removeFile
{
    if (_filename == nil)
        return;
    
    [[NSFileManager defaultManager] removeItemAtPath:_filename error:NULL];
    [_filename release];
    _filename = nil;
}

@end

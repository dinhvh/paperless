//
//  PLTwainSource.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 05/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLTwainSource.h"

#import "PLTwainManager.h"
#include "twain_client.h"

@interface PLTwainSource (Private)

- (void) _setupInThread;
- (BOOL) _acquireInThread;

@end


@implementation PLTwainSource

@synthesize name = _name;
@synthesize manager = _manager;
@synthesize delegate = _delegate;

- (id) initWithTwainSource:(struct twain_source *)source
{
    self = [super init];
    
    _source = source;
    _name = [[NSString stringWithUTF8String:twain_source_get_name(source)] retain];
    
    _pixelType = twain_pixel_type_rgb;
    _xferMode = twain_xfer_memory;
    _resolution = 300;
    _layout = CGRectMake(0, 0, 8.3, 11.7);
    _depth = 8;
    
    return self;
}

- (void) dealloc
{
    [_name release];
    [super dealloc];
}

- (void) open
{
    [self performSelector:@selector(_openInThread) onThread:[_manager thread] withObject:nil waitUntilDone:NO];
}

- (void) _openInThread
{
    twain_source_open(_source);
}

- (void) close
{
    twain_source_close(_source);
}

- (void) setPixelType:(enum twain_pixel_type)pixelType
{
    _pixelType = pixelType;
}

- (void) setImageLayout:(CGRect)layout
{
    _layout = layout;
}

- (void) setXferMode:(enum twain_xfer_mode)xferMode
{
    _xferMode = xferMode;
}

- (void) setBitDepth:(unsigned int)depth
{
    _depth = depth;
}

- (void) setResolution:(unsigned int)resolution
{
    _resolution = resolution;
}

- (void) setup
{
    NSLog(@"setup %@", self);
    [self performSelector:@selector(_setupInThread) onThread:[_manager thread] withObject:nil waitUntilDone:NO];
    //[[_manager threadRunLoop] performSelector:@selector(_setupInThread) target:self argument:nil order:0 modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (void) _setupInThread
{
    NSLog(@"setup run %@", self);
    twain_source_set_pixel_type(_source, _pixelType);
    twain_source_set_image_layout(_source, _layout.origin.x, _layout.origin.y, _layout.size.width, _layout.size.height);
    twain_source_set_xfer_mode(_source, _xferMode);
    twain_source_set_bit_depth(_source, _depth);
    twain_source_set_resolution(_source, _resolution);
    NSLog(@"setup run %@ done", self);
}

- (BOOL) uiControllable
{
    return twain_source_is_uicontrollable(_source);
}

- (void) acquire
{
    [self performSelector:@selector(_acquireInThread) onThread:[_manager thread] withObject:nil waitUntilDone:NO];
}

- (BOOL) _acquireInThread
{
    NSLog(@"acquireinthread");
    [self _setupInThread];
    
    [_manager setCurrentSource:self];
    
    twain_source_set_indicators_enabled(_source, 0);
    if (twain_source_acquire(_source, 0) == -1) {
        NSLog(@"acquireinthread failed");
        return NO;
    }
    
    NSLog(@"acquireinthread done");
    return YES;
}

- (void) setFeederEnabled:(BOOL)enabled
{
    twain_source_set_feeder_enabled(_source, enabled);
}

- (void) setAutoFeederEnabled:(BOOL)enabled
{
    twain_source_set_auto_feeder_enabled(_source, enabled);
}

- (BOOL) hasFeeder
{
    return twain_source_has_feeder(_source);
}

- (BOOL) isFeederLoaded
{
    return twain_source_is_feeder_loaded(_source);
}

- (struct twain_source *) source
{
    return _source;
}

- (void) imageBeginWithImageInfo:(pTW_IMAGEINFO)imageInfo
{
}

- (void) imageDataWithRow:(unsigned int)row data:(void *)data size:(size_t)size
{
}

- (void) imageEnd
{
}

- (void) imageFileData:(void *)data length:(size_t)length
{
    [_manager setCurrentSource:nil];
    NSLog(@"imageFileData:");
    [[self delegate] plTwainSource:self imageFileData:data length:length];
}

@end

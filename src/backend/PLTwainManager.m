//
//  PLTwainManager.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 05/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLTwainManager.h"

#include "twain_client.h"
#import "PLTwainSource.h"
#import "PLTwainScanner.h"

@interface PLTwainManager (Private) <PLScannerDelegate>

- (void) _startThread;
- (void) _stopThread;
- (void) _imageBegin:(struct twain_source *)source imageInfo:(pTW_IMAGEINFO)imageInfo;
- (void) _imageData:(struct twain_source *)source row:(unsigned int)row data:(void *)data size:(size_t)size;
- (void) _imageEnd:(struct twain_source *)source;
- (void) _imageFileData:(struct twain_source *)source data:(void *)data length:(size_t)length;

@end

@implementation PLTwainManager

@synthesize currentSource = _currentSource;

static void image_begin(struct twain_source * source, pTW_IMAGEINFO imageInfo, void * cb_data)
{
    PLTwainManager * manager;
    
    manager = cb_data;
    NSLog(@"image_begin");
    [manager _imageBegin:source imageInfo:imageInfo];
}

- (void) _imageBegin:(struct twain_source *)source imageInfo:(pTW_IMAGEINFO)imageInfo
{
    unsigned int i;
    
    for(i = 0 ; i < [[self sources] count] ; i ++) {
        PLTwainSource * aSource;
        
        aSource = [[self sources] objectAtIndex:i];
        if ([aSource source] == source) {
            [aSource imageBeginWithImageInfo:imageInfo];
        }
    }
}

static void image_data(struct twain_source * source, unsigned int row, void * data, size_t size, void * cb_data)
{
    PLTwainManager * manager;
    
    manager = cb_data;
    NSLog(@"image_data");
    [manager _imageData:source row:row data:data size:size];
}

- (void) _imageData:(struct twain_source *)source row:(unsigned int)row data:(void *)data size:(size_t)size
{
    unsigned int i;
    
    for(i = 0 ; i < [[self sources] count] ; i ++) {
        PLTwainSource * aSource;
        
        aSource = [[self sources] objectAtIndex:i];
        if ([aSource source] == source) {
            [aSource imageDataWithRow:row data:data size:size];
        }
    }
}

static void image_end(struct twain_source * source, void * cb_data)
{
    PLTwainManager * manager;
    
    manager = cb_data;
    NSLog(@"image_end");
    [manager _imageEnd:source];
}

- (void) _imageEnd:(struct twain_source *)source
{
    unsigned int i;
    
    for(i = 0 ; i < [[self sources] count] ; i ++) {
        PLTwainSource * aSource;
        
        aSource = [[self sources] objectAtIndex:i];
        if ([aSource source] == source) {
            [aSource imageEnd];
        }
    }
}

static void image_file_data(struct twain_source * source, void * data, size_t length, void * cb_data)
{
    PLTwainManager * manager;
    
    manager = cb_data;
    NSLog(@"image_file_data");
    [manager _imageFileData:source data:data length:length];
}

- (void) _imageFileData:(struct twain_source *)source data:(void *)data length:(size_t)length
{
    unsigned int i;
    
    for(i = 0 ; i < [[self sources] count] ; i ++) {
        PLTwainSource * aSource;
        
        aSource = [[self sources] objectAtIndex:i];
        NSLog(@"%p %p", [aSource source], source);
        if ([aSource source] == source) {
            [aSource imageFileData:data length:length];
        }
    }
}

- (id) init
{
    unsigned int i;
    
    self = [super init];
    
    _client = twain_client_new();
    twain_client_init_twain(_client);
    
    _sourceList = [[NSMutableArray alloc] init];
    for(i = 0 ; i < twain_client_get_source_count(_client) ; i ++) {
        struct twain_source * source;
        PLTwainSource * item;
        
        source = twain_client_get_source_with_index(_client, i);
        item = [[PLTwainSource alloc] initWithTwainSource:source];
        [item setManager:self];
        [_sourceList addObject:item];
        [item release];
    }
    
    struct twain_client_callback callback = {
        image_begin, image_data, image_end, image_file_data, self,
    };
    
    twain_client_set_callback(_client, &callback);
    
    [self _startThread];
    twain_client_register_runloop(_client, [_threadRunLoop getCFRunLoop]);
    
#if 0
    for(i = 0 ; i < [_sourceList count] ; i ++) {
        PLTwainSource * item;
        
        item = [_sourceList objectAtIndex:i];
        NSLog(@"name : [%@]", [item name]);
    	if (![[item name] isEqualToString:@"CanoScan LiDE 600F"]) {
            continue;
        }
        
        NSLog(@"setup : [%@]", [item name]);
        PLTwainScanner * scanner;
        
        scanner = [[PLTwainScanner alloc] initWithTwainManagerSource:item];
        [scanner setDelegate:self];
        [scanner scan];
    }
#endif
    
    return self;
}

- (void) plScanner_scanDone:(NSObject <PLScannerProtocol> *)scanner;
{
    NSLog(@"scan done %@", scanner);
}

- (void) dealloc
{
	[_sourceList release];
    
    twain_client_release_twain(_client);
    twain_client_free(_client);
    
    [super dealloc];
}

static PLTwainManager * _manager = nil;

+ (PLTwainManager *) sharedManager
{
    return nil;
    
#if 0
    @synchronized([PLTwainManager class]) {
        if (_manager == nil) {
            _manager = [[PLTwainManager alloc] init];
        }
    }
    
    return _manager;
#endif
}

- (NSArray * /* PLTwainSource */) sources
{
    return _sourceList;
}

- (void) _startThread
{
    _cond = [[NSCondition alloc] init];
    @synchronized(self) {
        _started = NO;
    }
    [NSThread detachNewThreadSelector:@selector(_threadRun) toTarget:self withObject:nil];
    [_cond lock];
    while (1) {
        BOOL started;
        
        @synchronized(self) {
            started = _started;
        }
        if (started)
            break;
        [_cond wait];
    }
    [_cond unlock];
}

- (void) _stopThread
{
    @synchronized(self) {
        _terminated = YES;
        _terminateDone = NO;
    }
    [_cond lock];
    
    CFRunLoopStop([_threadRunLoop getCFRunLoop]);
    CFRunLoopWakeUp([_threadRunLoop getCFRunLoop]);
    while (1) {
        BOOL terminateDone;
        
        @synchronized(self) {
            terminateDone = _terminateDone;
        }
        if (!terminateDone) {
            break;
        }
        [_cond wait];
    }
    
    [_cond unlock];
}

- (void) _threadRun
{
    NSAutoreleasePool * pool;
    unsigned int i;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    [self retain];
    
    _thread = [NSThread currentThread];
    _threadRunLoop = [NSRunLoop currentRunLoop];
    NSLog(@"threadunrloop : %@", _threadRunLoop);
    
    [_cond lock];
    @synchronized (self) {
        _started = YES;
    }
    [_cond signal];
    [_cond unlock];
    
    while (1) {
        BOOL terminated;
        NSAutoreleasePool * localPool;
        
        localPool = [[NSAutoreleasePool alloc] init];
        
        NSLog(@"runloop wait");
        CFRunLoopRun();
        NSLog(@"runloop signaled");
        @synchronized(self) {
            terminated = _terminated;
        }
        
        [localPool release];
        
        if (terminated) {
            break;
        }
    }
    
    NSLog(@"terminated");
    
    [_cond lock];
    @synchronized(self) {
        _terminateDone = YES;
    }
    [_cond signal];
    [_cond unlock];

    for(i = 0 ; i < [_sourceList count] ; i ++) {
        PLTwainSource * item;
        
        item = [_sourceList objectAtIndex:i];
        [item close];
    }
    
    [self release];
    
    [pool release];
}

- (void) terminate
{
    [self _stopThread];
}

- (NSRunLoop *) threadRunLoop
{
    return _threadRunLoop;
}

- (NSThread *) thread
{
    return _thread;
}

@end

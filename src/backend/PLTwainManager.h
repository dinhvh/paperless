//
//  PLTwainManager.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 05/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

struct twain_client;
@class PLTwainSource;

@interface PLTwainManager : NSObject {
	NSThread * _twainThread;
    NSRunLoop * _twainRunloop;
    struct twain_client * _client;
    NSMutableArray * _sourceList;
    NSThread * _thread;
    NSRunLoop * _threadRunLoop;
    NSCondition * _cond;
    BOOL _terminated;
    BOOL _started;
    BOOL _terminateDone;
    PLTwainSource * _currentSource;
}

@property (assign) PLTwainSource * currentSource;

- (id) init;
- (void) dealloc;

+ (PLTwainManager *) sharedManager;
- (void) terminate;

- (NSArray * /* PLTwainSource */) sources;

- (NSRunLoop *) threadRunLoop;
- (NSThread *) thread;

@end

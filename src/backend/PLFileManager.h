//
//  PLDocumentCopyScheduler.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 30/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PLDocument;

#define PLFILEMANAGER_FINISHED_NOTIFICATION @"PLFILEMANAGER_FINISHED_NOTIFICATION"
#define PLFILEMANAGER_PROGRESS_START_NOTIFICATION @"PLFILEMANAGER_PROGRESS_START_NOTIFICATION"
#define PLFILEMANAGER_PROGRESS_UPDATE_NOTIFICATION @"PLFILEMANAGER_PROGRESS_UPDATE_NOTIFICATION"
#define PLFILEMANAGER_PROGRESS_END_NOTIFICATION @"PLFILEMANAGER_PROGRESS_END_NOTIFICATION"

@interface PLFileManager : NSObject {
    NSOperationQueue * _opQueue;
    NSMutableSet * _pendingDoc;
    unsigned int _progressMaxValue;
    unsigned int _progressValue;
}

- (id) init;
- (void) dealloc;

+ (PLFileManager *) sharedManager;

- (void) cleanImport;
- (void) emptyTrash;
- (void) emptyDragFolder;
- (void) queueFile:(NSString *)filename document:(PLDocument *)doc;
- (void) queueDeleteDocument:(PLDocument *)doc;
- (void) queueUndeleteDocument:(PLDocument *)doc;
- (void) queueExportDocument:(PLDocument *)doc destination:(NSString *)destination;

- (NSSet *) pendingDoc;
- (BOOL) isPendingDoc:(PLDocument *)doc;

- (unsigned int) progressMaxValue;
- (unsigned int) progressValue;

- (NSString *) currentOperationDescription;

- (BOOL) hasPendingOperations;

@end

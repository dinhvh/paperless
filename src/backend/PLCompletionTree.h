//
//  PLCompletionTree.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PLCompletionTree : NSObject {
    unichar _ch;
	NSMutableArray * _nodeList;
    unsigned int _count;
    unsigned int _totalCount;
}

- (id) init;
- (id) initWithCharacter:(unichar)character;
- (void) dealloc;

- (PLCompletionTree *) nodeForCharacter:(unichar)ch;
- (PLCompletionTree *) addNodeForCharacter:(unichar)ch;
- (void) removeNodeForCharacter:(unichar)ch;

- (unichar) character;

- (void) addDocument;
- (void) removeDocument;

- (void) addDocumentWithName:(NSString *)name;
- (void) removeDocumentWithName:(NSString *)name;

- (PLCompletionTree *) nodeStartWith:(NSString *)name;

- (NSArray *) documentNameArrayWithPrefix:(NSString *)prefix;
- (NSArray *) documentNameArray;

- (unsigned int) totalCount;
- (void) updateTotalCount;

- (PLCompletionTree *) probableNodeWithString:(NSMutableString *)str;

- (void) showNodeAtLevel:(unsigned int)level indent:(BOOL)indent;
- (void) showNode;

@end

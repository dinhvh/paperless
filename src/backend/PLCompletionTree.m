//
//  PLCompletionTree.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLCompletionTree.h"


@implementation PLCompletionTree

- (id) init
{
    self = [self initWithCharacter:0];
    
    return self;
}

- (id) initWithCharacter:(unichar)character
{
    self = [super init];
    
    _ch = character;
    
    return self;
}

- (void) dealloc
{
    [_nodeList release];
    [super dealloc];
}

- (PLCompletionTree *) nodeForCharacter:(unichar)ch
{
    unsigned int i;
    
    if (_nodeList == nil)
        return nil;
    
    for(i = 0 ; i < [_nodeList count] ; i ++) {
        PLCompletionTree * node;
        
        node = [_nodeList objectAtIndex:i];
        if ([node character] == ch) {
            return node;
        }
    }
    
    return nil;
}

- (unichar) character
{
    return _ch;
}

- (PLCompletionTree *) addNodeForCharacter:(unichar)ch
{
    PLCompletionTree * tree;
    
    tree = [[PLCompletionTree alloc] initWithCharacter:ch];
    if (_nodeList == nil) {
        _nodeList = [[NSMutableArray alloc] init];
    }
    [_nodeList addObject:tree];
    
    return [tree autorelease];
}

- (void) removeNodeForCharacter:(unichar)ch
{
    unsigned int i;
    
    if (_nodeList == nil)
        return;
    
    for(i = 0 ; i < [_nodeList count] ; i ++) {
        PLCompletionTree * node;
        
        node = [_nodeList objectAtIndex:i];
        if ([node character] == ch) {
            [_nodeList removeObjectAtIndex:i];
            break;
        }
    }
}

- (void) addDocument
{
    _count ++;
}

- (void) removeDocument
{
    _count --;
}

- (unsigned int) documentCount
{
    return _count;
}

- (BOOL) isEmpty
{
    return (_count == 0) && ((_nodeList == nil) || ([_nodeList count] == 0));
}

- (void) addDocumentWithName:(NSString *)name
{
    unsigned int i;
    PLCompletionTree * currentNode;
    
    currentNode = self;
    
    for(i = 0 ; i < [name length] ; i ++) {
        unichar ch;
        PLCompletionTree * node;
        
        ch = [name characterAtIndex:i];
        node = [currentNode nodeForCharacter:ch];
        if (node == nil) {
            node = [currentNode addNodeForCharacter:ch];
        }
        
        currentNode = node;
    }
    
    [currentNode addDocument];
}

- (void) removeDocumentWithName:(NSString *)name
{
    unsigned int i;
    PLCompletionTree * currentNode;
    NSMutableArray * nodeChain;
    int parentIndex;
    
    currentNode = self;
    nodeChain = [[NSMutableArray alloc] init];
    
    for(i = 0 ; i < [name length] ; i ++) {
        unichar ch;
        PLCompletionTree * node;
        
        [nodeChain addObject:currentNode];
        ch = [name characterAtIndex:i];
        node = [currentNode nodeForCharacter:ch];
        if (node == nil) {
            //NSLog(@"error ! can't remove %@", name);
            return;
        }
        
        currentNode = node;
    }
    
    [currentNode removeDocument];
    parentIndex = [nodeChain count] - 1;
    while (parentIndex >= 0) {
        PLCompletionTree * parent;
        
        if (![currentNode isEmpty]) {
            break;
        }
        parent = [nodeChain objectAtIndex:parentIndex];
        [parent removeNodeForCharacter:[currentNode character]];
        parentIndex --;
        currentNode = parent;
    }
    
    [nodeChain release];
}

- (PLCompletionTree *) nodeStartWith:(NSString *)name
{
    unsigned int i;
    PLCompletionTree * currentNode;
    
    currentNode = self;
    
    for(i = 0 ; i < [name length] ; i ++) {
        unichar ch;
        PLCompletionTree * node;
        
        ch = [name characterAtIndex:i];
        node = [currentNode nodeForCharacter:ch];
        if (node == nil) {
            //NSLog(@"not found");
            return nil;
        }
        
        currentNode = node;
    }
    
    //NSLog(@"found at : %@", currentNode);
    return currentNode;
}

- (NSArray *) documentNameArrayWithPrefix:(NSString *)prefix
{
    NSMutableArray * result;
    
    result = [NSMutableArray array];
    
    if (_nodeList != nil) {
        unsigned int i;
        unichar ch;
        
        ch = [self character];
        
        for(i = 0 ; i < [_nodeList count] ; i ++) {
            NSArray * list;
            PLCompletionTree * node;
            NSString * nodePrefix;
            
            node = [_nodeList objectAtIndex:i];
            nodePrefix = [prefix stringByAppendingFormat:@"%C", [node character]];
            list = [node documentNameArrayWithPrefix:nodePrefix];
            
            [result addObjectsFromArray:list];
        }
    }
    
    if (_count > 0) {
        [result addObject:prefix];
    }
    
    return result;
}

- (NSArray *) documentNameArray
{
    return [self documentNameArrayWithPrefix:@""];
}


- (unsigned int) totalCount
{
    return _totalCount;
}

- (void) updateTotalCount
{
    unsigned int count;
    
    count = _count;
    if (_nodeList != nil) {
        unsigned int i;
        
        for(i = 0 ; i < [_nodeList count] ; i ++) {
            PLCompletionTree * node;
            
            node = [_nodeList objectAtIndex:i];
            [node updateTotalCount];
            count += [node totalCount];
        }
    }
    
    _totalCount = count;
}

- (PLCompletionTree *) probableNodeWithString:(NSMutableString *)str
{
    unsigned int i;
    unsigned int max;
    PLCompletionTree * nodeMax;
    
    if (_count != 0)
        return self;
    
    
    if (_nodeList == nil) {
        //NSLog(@"strange !");
    }
    
    max = 0;
    nodeMax = nil;
    for(i = 0 ; i < [_nodeList count] ; i ++) {
        PLCompletionTree * node;
        
        node = [_nodeList objectAtIndex:i];
        if ([node totalCount] > max) {
            max = [node totalCount];
            nodeMax = node;
        }
    }
    
    if (nodeMax == nil) {
        //NSLog(@"strange !");
    }
    
    //NSLog(@"%C", [nodeMax character]);
    [str appendFormat:@"%C", [nodeMax character]];
    
    return [nodeMax probableNodeWithString:str];
}

- (void) showNodeAtLevel:(unsigned int)level indent:(BOOL)indent
{
    unsigned int i;
    BOOL indentNext;
    
    if (indent) {
        for(i = 0 ; i < level ; i ++) {
            fprintf(stderr, " ");
        }
    }
    
    if (_count > 0) {
        fprintf(stderr, "%c*\n", [self character]);
        indentNext = YES;
    }
    else {
        if ([_nodeList count] == 1) {
            fprintf(stderr, "%c", [self character]);
            indentNext = NO;
        }
        else {
            fprintf(stderr, "%c\n", [self character]);
            indentNext = YES;
        }
    }
    for(i = 0 ; i < [_nodeList count] ; i ++) {
        PLCompletionTree * node;
        
        node = [_nodeList objectAtIndex:i];
        [node showNodeAtLevel:level + 1 indent:indentNext];
    }
}

- (void) showNode
{
    [self showNodeAtLevel:0 indent:YES];
}

@end

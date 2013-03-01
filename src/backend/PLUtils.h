//
//  PLUtils.h
//  DocScan
//
//  Created by DINH Viêt Hoà on 6/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static inline void OBSERVE(id observer, SEL selector,
    NSString * name, id sender)
{
    [[NSNotificationCenter defaultCenter]
       addObserver:observer
          selector:selector
              name:name
            object:sender];
}

static inline void UNOBSERVE(id observer, NSString * name, id sender)
{
    [[NSNotificationCenter defaultCenter]
       removeObserver:observer
                 name:name
               object:sender];
}

static inline void POSTNOTIFICATION(NSString * name, id sender,
    NSDictionary * userInfo)
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:name
                      object:sender
                    userInfo:userInfo];
}


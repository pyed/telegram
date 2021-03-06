//
//  ComposeAction.h
//  Telegram
//
//  Created by keepcoder on 28.08.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ComposeActionBehavior.h"
#import "TMViewController.h"
@interface ComposeResult : NSObject

@property (nonatomic,strong) id singleObject;
@property (nonatomic,strong,readonly) NSArray *multiObjects;


-(id)initWithMultiObjects:(NSArray *)multiObjects;

@end




@interface ComposeAction : NSObject

@property (nonatomic,strong) ComposeResult *result;

@property (nonatomic,strong,readonly) ComposeActionBehavior *behavior;
@property (nonatomic,strong,readonly) NSArray *filter;
@property (nonatomic,strong,readonly) id object;

@property (nonatomic,strong) id reservedObject1;
@property (nonatomic,strong) id reservedObject2;
@property (nonatomic,strong) id reservedObject3;


@property (nonatomic,strong) TMViewController *currentViewController;

-(id)initWithBehaviorClass:(Class)behavior;
-(id)initWithBehaviorClass:(Class)behavior filter:(NSArray *)filter object:(id)object;

-(id)initWithBehaviorClass:(Class)behavior filter:(NSArray *)filter object:(id)object reservedObjects:(NSArray *)objects;
@end

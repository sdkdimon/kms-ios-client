//
//  UIGestureRecognizer+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import "UIGestureRecognizer+RACSignalSupport.h"
#import <RACObjC/RACEXTScope.h>
#import <RACObjC/NSObject+RACDeallocating.h>
#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/RACCompoundDisposable.h>
#import <RACObjC/RACDisposable.h>
#import <RACObjC/RACSignal.h>
#import <RACObjC/RACSubscriber.h>

@implementation UIGestureRecognizer (RACSignalSupport)

- (RACSignal *)rac_gestureSignal {
	@weakify(self);

	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			[self addTarget:subscriber action:@selector(sendNext:)];
			[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[subscriber sendCompleted];
			}]];

			return [RACDisposable disposableWithBlock:^{
				@strongify(self);
				[self removeTarget:subscriber action:@selector(sendNext:)];
			}];
		}]
		setNameWithFormat:@"%@ -rac_gestureSignal", RACDescription(self)];
}

@end

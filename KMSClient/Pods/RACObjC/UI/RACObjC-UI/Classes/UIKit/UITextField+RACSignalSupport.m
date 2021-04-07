//
//  UITextField+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UITextField+RACSignalSupport.h"
#import <RACObjC/RACEXTKeyPathCoding.h>
#import <RACObjC/RACEXTScope.h>
#import <RACObjC/NSObject+RACDeallocating.h>
#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/RACSignal+Operations.h>
#import "UIControl+RACSignalSupport.h"
#import "UIControl+RACSignalSupportPrivate.h"

@implementation UITextField (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	@weakify(self);
	return [[[[[RACSignal
		defer:^{
			@strongify(self);
			return [RACSignal return:self];
		}]
		concat:[self rac_signalForControlEvents:UIControlEventAllEditingEvents]]
		map:^(UITextField *x) {
			return x.text;
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_textSignal", RACDescription(self)];
}

- (RACChannelTerminal *)rac_newTextChannel {
	return [self rac_channelForControlEvents:UIControlEventAllEditingEvents key:@keypath(self.text) nilValue:@""];
}

@end

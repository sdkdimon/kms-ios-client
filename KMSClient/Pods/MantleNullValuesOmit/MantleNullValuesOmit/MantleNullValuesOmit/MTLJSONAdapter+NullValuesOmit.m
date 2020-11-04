//
//  MTLJSONAdapter+NullValuesOmit.m
//  Copyright (c) 2016 Dmitry Lizin (sdkdimon@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "MTLJSONAdapter+NullValuesOmit.h"

#import "MTLModel+NullValuesOmit.h"
#import <objc/runtime.h>

@interface NSDictionary (MTL_MutableIfNeeded)

- (NSMutableDictionary *)mtl_mutableCopyIfNeeded;

@end

@implementation NSDictionary (MTL_MutableIfNeeded)

- (NSMutableDictionary *)mtl_mutableCopyIfNeeded
{
    return [self isKindOfClass:[NSMutableDictionary class]] ? self : [self mutableCopy];
}

@end

static IMP __Original_JSONDictionaryFromModel_IMP;
static IMP __Original_modelFromJSONDictionary_IMP;

@implementation MTLJSONAdapter (NullValuesOmit)

NSDictionary *__Swizzle_JSONDictionaryFromModel(id self, SEL _cmd, id <MTLJSONSerializing> model, NSError *__autoreleasing *error)
{
    NSDictionary *(* __original_JSONDictionaryFromModel_IMP)(id, SEL, ...) = (NSDictionary *(*)(id, SEL, ...))__Original_JSONDictionaryFromModel_IMP;
    NSMutableDictionary *JSONDictionary = [__original_JSONDictionaryFromModel_IMP(self, _cmd, model, error) mtl_mutableCopyIfNeeded];
    if ([model respondsToSelector:@selector(isOmitNullValues)] && [(MTLModel *)model isOmitNullValues])
    {
        NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
        for(NSString *key in JSONDictionary){
            id value = JSONDictionary[key];
            if(value == [NSNull null]) {[keysToRemove addObject:key];}
        }
        [JSONDictionary removeObjectsForKeys:keysToRemove];
        return JSONDictionary;
    }
    return JSONDictionary;
}

id __Swizzle_modelFromJSONDictionary(id self, SEL _cmd, NSDictionary *JSONDictionary, NSError *__autoreleasing *error)
{
    id (* __original_modelFromJSONDictionary_IMP)(id, SEL, ...) = (id (*)(id, SEL, ...))__Original_modelFromJSONDictionary_IMP;
    NSMutableDictionary *JSONDictionaryMutable = [JSONDictionary mutableCopy];
    NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
    for (NSString *key in JSONDictionaryMutable)
    {
        id value = JSONDictionaryMutable[key];
        if (value == NSNull.null) {[keysToRemove addObject:key];}
    }
    [JSONDictionaryMutable removeObjectsForKeys:keysToRemove];
    
    id model = __original_modelFromJSONDictionary_IMP(self, _cmd, JSONDictionaryMutable, error);
    return model;
}

+ (void)load
{
    Method JSONDictionaryFromModel_Method = class_getInstanceMethod(self, @selector(JSONDictionaryFromModel:error:));
    __Original_JSONDictionaryFromModel_IMP = method_setImplementation(JSONDictionaryFromModel_Method, (IMP)__Swizzle_JSONDictionaryFromModel);
    Method modelFromJSONDictionary_Method = class_getInstanceMethod(self, @selector(modelFromJSONDictionary:error:));
    __Original_modelFromJSONDictionary_IMP = method_setImplementation(modelFromJSONDictionary_Method, (IMP)__Swizzle_modelFromJSONDictionary);
}

@end

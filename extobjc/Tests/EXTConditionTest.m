//
//  EXTConditionTest.m
//  extobjc
//
//  Created by Justin Spahr-Summers on 08.01.12.
//  Released into the public domain.
//

#import "EXTConditionTest.h"
#import "EXTCondition.h"
#import "EXTSafeCategory.h"

NSMutableArray *handlers;
NSMutableDictionary *restarts;
jmp_buf context;

typedef enum {
    EXTHandlerStatusInstallingHandlers = 0,
    EXTHandlerStatusRunning,
    EXTHandlerStatusDone
} EXTHandlerStatus;

typedef enum {
    EXTConditionStatusNoException = 0,
    EXTConditionStatusExceptionThrown
} EXTConditionStatus;

#define handle \
    for (EXTHandlerStatus handlerStatus_ = EXTHandlerStatusInstallingHandlers; handlerStatus_ != EXTHandlerStatusDone; ++handlerStatus_) \
        switch (handlerStatus_) \
            for (BOOL loop2Done_ = NO; !loop2Done_; loop2Done_ = YES) \
                default: \
                    if (handlerStatus_ == EXTHandlerStatusRunning)
                        /* @handle block begins with user code */

#define rescue(TYPE, VAR) \
    else if (handlerStatus_ == EXTHandlerStatusInstallingHandlers) \
        for (id handler_ = nil; !handler_; (handler_ && ([handlers addObject:handler_], YES))) \
            handler_ = ^(TYPE *VAR)

#define restart(...) \
    if (!setjmp(context) && ((restarts = [NSDictionary dictionaryWithKeysAndCopiedObjects:__VA_ARGS__, nil]) || YES))

#define invoke(RESTART, ...) \
    NSLog(@"%@", RESTART) \

@interface NSDictionary (ConditionExtensions)
+ (id)dictionaryWithKeysAndCopiedObjects:(id)firstKey, ... NS_REQUIRES_NIL_TERMINATION;
@end

@interface TestCondition : NSObject
+ (void)raise;
@end

@implementation TestCondition
+ (void)raise; {
    NSLog(@"jumping");
    longjmp(context, 1);
}

@end

@implementation EXTConditionTest

- (void)testRestart {
    handlers = [[NSMutableArray alloc] init];

    handle {
        __block NSString *str = @"foobar";

        restart(
            @"invalid-string", ^(NSString *newString){ str = newString; }
        ) {
            if ([str isEqualToString:@"foobar"])
                [TestCondition raise];
        }

        NSLog(@"restarts: %@", restarts);

        STAssertEqualObjects(str, @"fizzbuzz", @"");
    } rescue (TestCondition, condition) {
        invoke(@"invalid-string", @"fizzbuzz");
    };

    void (^testHandler)(TestCondition *) = [handlers objectAtIndex:0];
    testHandler(nil);
}

@end

@safecategory (NSDictionary, ConditionExtensions)
+ (id)dictionaryWithKeysAndCopiedObjects:(id)firstKey, ... {
    if (!firstKey)
        return [NSDictionary dictionary];

    va_list args;
    va_start(args, firstKey);

    id firstObject = va_arg(args, id);

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setObject:[firstObject copy] forKey:firstKey];

    for (;;) {
        id nextKey = va_arg(args, id);
        if (!nextKey)
            break;

        id nextObject = va_arg(args, id);
        [dictionary setObject:[nextObject copy] forKey:nextKey];
    }

    va_end(args);

    return [dictionary copy];
}
@end

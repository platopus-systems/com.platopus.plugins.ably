//

#import <Foundation/Foundation.h>

@protocol AspectToken;

/// `NSObject` extensions. Aspects lib allows you to add code to existing methods but it has some limitations with Swift because the NSInvocation is unavailable: https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSInvocation_Class/
@interface NSObject (TestSuite)

NS_ASSUME_NONNULL_BEGIN

/// Get each return value generated by the identified instance method.
- (id<AspectToken>)testSuite_getReturnValueFrom:(SEL)selector callback:(void (^)(id))callback;

/// Get argument at index from the identified instance method.
- (id<AspectToken>)testSuite_getArgumentFrom:(SEL)selector atIndex:(NSInteger)index callback:(void (^)(id))callback;

/// Change the returning value using a date from the identified instance method.
- (id<AspectToken>)testSuite_returnValueFor:(SEL)selector withDate:(NSDate *)value;

/// Inject a block of code after the identified instance method.
- (id<AspectToken>)testSuite_injectIntoMethodAfter:(SEL)selector code:(void (^)(void))block;

/// Inject a block of code before the identified instance method.
- (id<AspectToken>)testSuite_injectIntoMethodBefore:(SEL)selector code:(void (^)(void))block;

/// Replace the identified instance method.
- (id<AspectToken>)testSuite_replaceMethod:(SEL)selector code:(void (^)(void))block;

NS_ASSUME_NONNULL_END

@end

NSException * _Nullable tryInObjC(void(NS_NOESCAPE^_Nonnull tryBlock)(void));

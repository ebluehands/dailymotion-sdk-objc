//
//  DailymotionTest.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 13/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DailymotionTest.h"
#import "DailymotionTestConfig.h"

#define INIT dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);\
             NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
#define REINIT semaphore = dispatch_semaphore_create(0);
#define DONE dispatch_semaphore_signal(semaphore);
#define WAIT while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))\
                 [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];\
             dispatch_release(semaphore);


@implementation NSURLRequest (IgnoreSSL)

// Workaround for strange SSL with SenTestCase invalid certificate bug
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}

@end

@implementation DailymotionTest
{
    NSString *username;
    NSString *password;
}

- (void)setUp
{
    username = nil;
    password = nil;
}

- (Dailymotion *)api
{
    Dailymotion *api = [[Dailymotion alloc] init];
#ifdef kDMAPIEndpointURL
    api.APIBaseURL = kDMAPIEndpointURL;
#endif
#ifdef kDMOAuthAuthorizeEndpointURL
    api.oAuthAuthorizationEndpointURL = kDMOAuthAuthorizeEndpointURL;
#endif
#ifdef kDMOAuthTokenEndpointURL
    api.oAuthTokenEndpointURL = kDMOAuthTokenEndpointURL;
#endif
    return api;
}

- (void)testSingleCall
{
    INIT

    [self.api get:@"/echo" args:[NSDictionary dictionaryWithObject:@"test" forKey:@"message"] callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertEqualObjects([result objectForKey:@"message"], @"test", @"Is valid result.");
        DONE
    }];

    WAIT
}

/* TODO
- (void)testMultiCall
{
    Dailymotion *api = self.api;
    [api get:@"/echo" args:[NSDictionary dictionaryWithObject:@"test" forKey:@"message"] callback:self];
    [api get:@"/echo" delegate:self];
    [api request:@"video.subscriptions" delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)3, @"There's is 3 results.");
    STAssertEqualObjects([[results objectAtIndex:0] valueForKey:@"type"], @"success", @"First result is success.");
    STAssertEqualObjects([[[results objectAtIndex:0] objectForKey:@"result"] objectForKey:@"message"], @"test", @"First result is valid.");
    STAssertEqualObjects([[results objectAtIndex:1] valueForKey:@"type"], @"error", @"Second result is error.");
    STAssertEqualObjects([[results objectAtIndex:2] valueForKey:@"type"], @"auth_required", @"Third result is auth_required.");

}

- (void)testMultiCallIntermix
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call1" forKey:@"message"] delegate:self];

    // Roll the runloop once in order send the request
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call2" forKey:@"message"] delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 results.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call1", @"Is first call.");

    // Reinit the result queue
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 results.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call2", @"Is first call.");

}

- (void)testMultiCallLimit
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call1" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call2" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call3" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call4" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call5" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call6" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call7" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call8" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call9" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call10" forKey:@"message"] delegate:self];
    [api request:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call11" forKey:@"message"] delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)10, @"There's is 10 results, not 11.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call10", @"The last result is the 10th.");

    // Reinit the result queue
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"The 11th result made its way on a second request.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call11", @"It's the 11th one.");

}
*/

- (void)testCallInvalidMethod
{
    INIT

    [self.api get:@"/invalid/path" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNotNil(error, @"Is error response");
        STAssertNil(result, @"Result is nil");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeClientCredentials
{
    INIT

    Dailymotion *api = self.api;
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read"];
    [api clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeClientCredentialsRefreshToken
{
    INIT

    Dailymotion *api = self.api;
    api.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertNotNil(api.session.refreshToken, @"Got a refresh token");

        NSString *accessToken = api.session.accessToken;
        NSString *refreshToken = api.session.refreshToken;
        api.session.expires = [NSDate dateWithTimeIntervalSince1970:0];

        [api get:@"/auth" callback:^(NSDictionary *result2, NSError *error2)
        {
            STAssertNil(error2, @"Is success response");
            STAssertEqualObjects(refreshToken, api.session.refreshToken, @"Same refresh token");
            STAssertFalse([accessToken isEqual:api.session.accessToken], @"Access token refreshed");
            DONE
        }];
    }];

    WAIT
}

- (void)testGrantTypeClientCredentialsRefreshWithNoRefreshToken
{
    INIT

    Dailymotion *api = self.api;
    api.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertNotNil(api.session.refreshToken, @"Got a refresh token");
         
        NSString *accessToken = api.session.accessToken;
        api.session.accessToken = nil;
        api.session.expires = [NSDate dateWithTimeIntervalSince1970:0];
        api.session.refreshToken = nil;
         
        [api get:@"/auth" callback:^(NSDictionary *result2, NSError *error2)
        {
            STAssertNil(error2, @"Is success response");
            STAssertFalse([accessToken isEqual:api.session.accessToken], @"Access token refreshed with no refresh_token");
            DONE
        }];
    }];
    
    WAIT
}


- (void)testGrantTypeWrongPassword
{
    INIT

    Dailymotion *api = self.api;
    api.delegate = self;
    username = @"username";
    password = @"wrong_password";
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNotNil(error, @"Is error response");
        STAssertNil(result, @"Result is nil");
        DONE
    }];

    WAIT
}

- (void)testSessionStorage
{
    INIT

    Dailymotion *api = self.api;
    api.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"write"];
    [api clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
        STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `write' scope.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `delete' scope.");
        DONE
    }];
    
    WAIT
    REINIT

    api = self.api;
    api.delegate = self;
    username = nil; // should not ask for credentials
    password = nil;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"write"];
    [api get:@"/auth" callback:^(NSDictionary *result, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertEqualObjects([result objectForKey:@"username"], kDMUsername, @"Is valid username.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
        STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `write' scope.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `delete' scope.");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeAuthorization
{
    // TODO: implement authorization grant type test
}

- (void)testUploadFile
{
    INIT

    Dailymotion *api = self.api;
    api.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api uploadFile:kDMTestFilePath callback:^(NSString *url, NSError *error)
    {
        STAssertNil(error, @"Is success response");
        STAssertNotNil(url, @"Got an URL.");
        STAssertEqualObjects([[NSURL URLWithString:url] absoluteString], url, @"URL is valid");
        DONE
    }];

    WAIT
}

- (void)testSessionStoreKey
{
    Dailymotion *api = self.api;
    STAssertNil([api sessionStoreKey], @"Session store key is nil if no grant type");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    NSString *sessionStoreKey = [api sessionStoreKey];
    STAssertNotNil(sessionStoreKey, @"Session store key is not nil if grant type defined");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:@"another secret" scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api sessionStoreKey]], @"Session store key is different when API secret changes");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:@"another key" secret:kDMAPISecret scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api sessionStoreKey]], @"Session store key is different when API key changes");

}

- (void)dailymotionDidRequestUserCredentials:(Dailymotion *)dailymotion handler:(void (^)(NSString *, NSString *))setCredentials
{
    if (username)
    {
        setCredentials(username, password);
    }
    else
    {
        STFail(@"API unexpectedly asked for end-user credentials");
    }
}

@end

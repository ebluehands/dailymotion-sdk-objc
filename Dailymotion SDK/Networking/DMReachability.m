/*
 Copyright (c) 2011, Tony Million.
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

#import "DMReachability.h"


NSString *const DMReachabilityChangedNotification = @"DMReachabilityChangedNotification";

@interface DMReachability ()

@property (nonatomic, assign) SCNetworkReachabilityRef _reachabilityRef;
@property (nonatomic, strong) id _reachabilityObject;
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t _reachabilitySerialQueue;
#else
@property (nonatomic, assign) dispatch_queue_t _reachabilitySerialQueue;
#endif

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags;
- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags;

@end


static NSString *reachabilityFlags(SCNetworkReachabilityFlags flags)
{
    return [NSString stringWithFormat:@"%c%c %c%c%c%c%c%c%c",
#if	TARGET_OS_IPHONE
            (flags & kSCNetworkReachabilityFlagsIsWWAN)               ? 'W' : '-',
#else
            'X',
#endif
            (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
            (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
            (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
            (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
            (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'];
}

//Start listening for reachability notifications on the current run loop
static void DMReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
#pragma unused (target)
    DMReachability *reachability = ((__bridge DMReachability *)info);

    // we probably dont need an autoreleasepool here as GCD docs state each queue has its own autorelease pool
    // but what the heck eh?
    @autoreleasepool
    {
        [reachability reachabilityChanged:flags];
    }
}


@implementation DMReachability

#pragma mark - class constructor methods

+ (DMReachability *)reachabilityWithHostname:(NSString *)hostname
{
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
    if (ref)
    {
        return [[self alloc] initWithReachabilityRef:ref];
    }

    return nil;
}

+ (DMReachability *)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress
{
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)hostAddress);
    if (ref)
    {
        return [[self alloc] initWithReachabilityRef:ref];
    }

    return nil;
}

+ (DMReachability *)reachabilityForInternetConnection
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    return [self reachabilityWithAddress:&zeroAddress];
}

+ (DMReachability *)reachabilityForLocalWiFi
{
    struct sockaddr_in localWifiAddress;
    bzero(&localWifiAddress, sizeof(localWifiAddress));
    localWifiAddress.sin_len = sizeof(localWifiAddress);
    localWifiAddress.sin_family = AF_INET;
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
    localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);

    return [self reachabilityWithAddress:&localWifiAddress];
}


// initialization methods

- (DMReachability *)initWithReachabilityRef:(SCNetworkReachabilityRef)ref
{
    self = [super init];
    if (self != nil)
    {
        self.reachableOnWWAN = YES;
        self._reachabilityRef = ref;
    }

    return self;
}

- (void)dealloc
{
    [self stopNotifier];

    if(self._reachabilityRef)
    {
        CFRelease(self._reachabilityRef);
        self._reachabilityRef = nil;
    }
#ifdef DEBUG
    NSLog(@"Reachability: dealloc");
#endif
}

#pragma mark - notifier methods

// Notifier
// NOTE: this uses GCD to trigger the blocks - they *WILL NOT* be called on THE MAIN THREAD
// - In other words DO NOT DO ANY UI UPDATES IN THE BLOCKS.
//   INSTEAD USE dispatch_async(dispatch_get_main_queue(), ^{UISTUFF}) (or dispatch_sync if you want)

- (BOOL)startNotifier
{
    SCNetworkReachabilityContext context = {0, NULL, NULL, NULL, NULL};

    // this should do a retain on ourself, so as long as we're in notifier mode we shouldn't disappear out from under ourselves
    // woah
    self._reachabilityObject = self;



    // first we need to create a serial queue
    // we allocate this once for the lifetime of the notifier
    self._reachabilitySerialQueue = dispatch_queue_create("com.dailymotion.reachability", NULL);
    if(!self._reachabilitySerialQueue)
    {
        return NO;
    }


    context.info = (__bridge void *)self;

    if (!SCNetworkReachabilitySetCallback(self._reachabilityRef, DMReachabilityCallback, &context))
    {
#ifdef DEBUG
        NSLog(@"SCNetworkReachabilitySetCallback() failed: %s", SCErrorString(SCError()));
#endif

        //clear out the dispatch queue
        if(self._reachabilitySerialQueue)
        {
            dispatch_release(self._reachabilitySerialQueue);
            self._reachabilitySerialQueue = nil;
        }

        self._reachabilityObject = nil;

        return NO;
    }

    // set it as our reachability queue which will retain the queue
    if(!SCNetworkReachabilitySetDispatchQueue(self._reachabilityRef, self._reachabilitySerialQueue))
    {
#ifdef DEBUG
        NSLog(@"SCNetworkReachabilitySetDispatchQueue() failed: %s", SCErrorString(SCError()));
#endif

        //UH OH - FAILURE!

        // first stop any callbacks!
        SCNetworkReachabilitySetCallback(self._reachabilityRef, NULL, NULL);

        // then clear out the dispatch queue
        if(self._reachabilitySerialQueue)
        {
            dispatch_release(self._reachabilitySerialQueue);
            self._reachabilitySerialQueue = nil;
        }

        self._reachabilityObject = nil;

        return NO;
    }

    return YES;
}

- (void)stopNotifier
{
    // first stop any callbacks!
    SCNetworkReachabilitySetCallback(self._reachabilityRef, NULL, NULL);

    // unregister target from the GCD serial dispatch queue
    SCNetworkReachabilitySetDispatchQueue(self._reachabilityRef, NULL);

    if(self._reachabilitySerialQueue)
    {
        dispatch_release(self._reachabilitySerialQueue);
        self._reachabilitySerialQueue = nil;
    }

    self._reachabilityObject = nil;
}

#pragma mark - reachability tests

// this is for the case where you flick the airplane mode
// you end up getting something like this:
//Reachability: WR ct-----
//Reachability: -- -------
//Reachability: WR ct-----
//Reachability: -- -------
// we treat this as 4 UNREACHABLE triggers - really apple should do better than this

#define testcase (kSCNetworkReachabilityFlagsConnectionRequired | kSCNetworkReachabilityFlagsTransientConnection)

- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags
{
    BOOL connectionUP = YES;

    if(!(flags & kSCNetworkReachabilityFlagsReachable))
    {
        connectionUP = NO;
    }

    if((flags & testcase) == testcase)
    {
        connectionUP = NO;
    }

#if	TARGET_OS_IPHONE
    if(flags & kSCNetworkReachabilityFlagsIsWWAN)
    {
        // we're on 3G
        if(!self.reachableOnWWAN)
        {
            // we dont want to connect when on 3G
            connectionUP = NO;
        }
    }
#endif

    return connectionUP;
}

- (BOOL)isReachable
{
    SCNetworkReachabilityFlags flags;

    if(!SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
        return NO;

    return [self isReachableWithFlags:flags];
}

- (BOOL)isReachableViaWWAN
{
#if	TARGET_OS_IPHONE

    SCNetworkReachabilityFlags flags = 0;

    if(SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
        // check we're REACHABLE
        if(flags & kSCNetworkReachabilityFlagsReachable)
        {
            // now, check we're on WWAN
            if(flags & kSCNetworkReachabilityFlagsIsWWAN)
            {
                return YES;
            }
        }
    }
#endif

    return NO;
}

- (BOOL)isReachableViaWiFi
{
    SCNetworkReachabilityFlags flags = 0;

    if(SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
        // check we're reachable
        if((flags & kSCNetworkReachabilityFlagsReachable))
        {
#if	TARGET_OS_IPHONE
            // check we're NOT on WWAN
            if((flags & kSCNetworkReachabilityFlagsIsWWAN))
            {
                return NO;
            }
#endif
            return YES;
        }
    }

    return NO;
}


// WWAN may be available, but not active until a connection has been established.
// WiFi may require a connection for VPN on Demand.
- (BOOL)isConnectionRequired
{
    SCNetworkReachabilityFlags flags;

	if(SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
		return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
	}

    return NO;
}

// Dynamic, on demand connection?
- (BOOL)isConnectionOnDemand
{
	SCNetworkReachabilityFlags flags;

	if (SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
		return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
				(flags & (kSCNetworkReachabilityFlagsConnectionOnTraffic | kSCNetworkReachabilityFlagsConnectionOnDemand)));
	}

	return NO;
}

// Is user intervention required?
- (BOOL)isInterventionRequired
{
    SCNetworkReachabilityFlags flags;

	if (SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
		return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
				(flags & kSCNetworkReachabilityFlagsInterventionRequired));
	}

	return NO;
}


#pragma mark - reachability status stuff

- (DMNetworkStatus)currentReachabilityStatus
{
    if([self isReachable])
    {
        if([self isReachableViaWiFi])
        {
            return DMReachableViaWiFi;
        }

#if	TARGET_OS_IPHONE
        return DMReachableViaWWAN;
#endif
    }

    return DMNotReachable;
}

- (SCNetworkReachabilityFlags)reachabilityFlags
{
    SCNetworkReachabilityFlags flags = 0;

    if(SCNetworkReachabilityGetFlags(self._reachabilityRef, &flags))
    {
        return flags;
    }

    return 0;
}

- (NSString *)currentReachabilityString
{
	DMNetworkStatus temp = [self currentReachabilityStatus];

	if(temp == _reachableOnWWAN)
	{
        // updated for the fact we have CDMA phones now!
		return NSLocalizedString(@"Cellular", @"");
	}
	if (temp == DMReachableViaWiFi)
	{
		return NSLocalizedString(@"WiFi", @"");
	}

	return NSLocalizedString(@"No Connection", @"");
}

- (NSString *)currentReachabilityFlags
{
    return reachabilityFlags([self reachabilityFlags]);
}

#pragma mark - callback function calls this method

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
#ifdef DEBUG
    NSLog(@"Reachability: %@", reachabilityFlags(flags));
#endif

    if([self isReachableWithFlags:flags])
    {
        if(self.reachableBlock)
        {
#ifdef DEBUG
            NSLog(@"Reachability: blocks are not called on the main thread.\n Use dispatch_async(dispatch_get_main_queue(), ^{}); to update your UI!");
#endif
            self.reachableBlock(self);
        }
    }
    else
    {
        if(self.unreachableBlock)
        {
#ifdef DEBUG
            NSLog(@"Reachability: blocks are not called on the main thread.\n Use dispatch_async(dispatch_get_main_queue(), ^{}); to update your UI!");
#endif
            self.unreachableBlock(self);
        }
    }

    // this makes sure the change notification happens on the MAIN THREAD
    dispatch_async(dispatch_get_main_queue(),
    ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DMReachabilityChangedNotification
                                                            object:self];
    });
}

@end

//
//  NRVAVideoLifecycleObserver.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoLifecycleObserver.h"
#import "NRVAHarvestComponentFactory.h"
#import "NRVASchedulerInterface.h"
#import "NRVAVideoConfiguration.h"
#import "NRVALog.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

@interface NRVAVideoLifecycleObserver ()

@property (nonatomic, weak) id<NRVAHarvestComponentFactory> crashSafeFactory;
@property (nonatomic, assign) BOOL isAppleTVDevice;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) BOOL emergencyBackupInProgress;

@end

@implementation NRVAVideoLifecycleObserver

- (instancetype)initWithCrashSafeFactory:(id<NRVAHarvestComponentFactory>)crashSafeFactory {
    self = [super init];
    if (self) {
        _crashSafeFactory = crashSafeFactory;
        // Get the configuration and check if it's a TV device
        NRVAVideoConfiguration *config = [crashSafeFactory getConfiguration];
        _isAppleTVDevice = (config != nil) ? [config isTV] : NO;
        _emergencyBackupInProgress = NO;
        
        [self setupCrashDetection];
        
        NRVA_DEBUG_LOG(@"Lifecycle observer initialized for %@", _isAppleTVDevice ? @"Apple TV" : @"iOS");
    }
    return self;
}

- (void)startObserving {
    if (self.isObserving) {
        return;
    }
    
    self.isObserving = YES;
    
#if TARGET_OS_IOS || TARGET_OS_TV
    // Register for app lifecycle notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
#endif
    
    NRVA_DEBUG_LOG(@"Lifecycle observer started");
}

- (void)stopObserving {
    if (!self.isObserving) {
        return;
    }
    
    self.isObserving = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NRVA_DEBUG_LOG(@"Lifecycle observer stopped");
}

#pragma mark - Lifecycle Event Handlers

- (void)handleAppDidEnterBackground:(NSNotification *)notification {
    @try {
        NRVA_DEBUG_LOG(@"🌅 [LIFECYCLE] App entering background - starting emergency sequence");
        
        // IMMEDIATE harvest regardless of harvest cycle (requirement)
        [self performEmergencyHarvest:@"APP_BACKGROUNDED"];
        
        // Control scheduler directly using interface methods
        NRVA_DEBUG_LOG(@"🛑 [LIFECYCLE] About to pause scheduler");
        [self.crashSafeFactory.getScheduler pause];
        
        // For TV: resume with extended intervals, Mobile: stay paused
        if (self.isAppleTVDevice) {
            NRVA_DEBUG_LOG(@"📺 [LIFECYCLE] TV device - resuming with extended intervals");
            [self.crashSafeFactory.getScheduler resume:YES]; // Extended intervals for TV
        } else {
            NRVA_DEBUG_LOG(@"📱 [LIFECYCLE] Mobile device - staying paused (no resume call)");
            // Mobile: Do NOT call resume - scheduler stays paused until foreground
        }
        
        NRVA_DEBUG_LOG(@"%@ backgrounded - immediate harvest triggered", self.isAppleTVDevice ? @"TV" : @"Mobile");
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Background handling error: %@", exception.reason);
    }
}

- (void)handleAppWillEnterForeground:(NSNotification *)notification {
    @try {
        // Resume normal scheduler behavior
        [self.crashSafeFactory.getScheduler resume:NO]; // Normal intervals
        
        // Check for recovery data
        NRVA_DEBUG_LOG(@"Recovery detected: %@", [self.crashSafeFactory getRecoveryStats]);
        
        NRVA_DEBUG_LOG(@"%@ foregrounded - normal operation resumed", self.isAppleTVDevice ? @"TV" : @"Mobile");
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Foreground handling error: %@", exception.reason);
    }
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    [self performEmergencyHarvest:@"APP_TERMINATING"];
    [self.crashSafeFactory cleanup];
}

- (void)handleMemoryWarning:(NSNotification *)notification {
    // System might kill app - emergency harvest
    [self performEmergencyHarvest:@"MEMORY_WARNING"];
}

#pragma mark - Private Methods

- (void)performEmergencyHarvest:(NSString *)reason {
    if (self.emergencyBackupInProgress) {
        return; // Already in progress
    }
    
    self.emergencyBackupInProgress = YES;
    
    @try {
        // SKIP immediate network harvest - prioritize reliable file-based backup
        // Immediate network operations during app lifecycle transitions often fail
        
        // Always perform emergency backup to files (reliable)
        [self.crashSafeFactory performEmergencyBackup];
        
        NRVA_DEBUG_LOG(@"Emergency backup to files completed - %@ - Reason: %@ (network harvest skipped for reliability)", 
                      self.isAppleTVDevice ? @"TV" : @"Mobile", reason);
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Emergency backup failed: %@", exception.reason);
    } @finally {
        self.emergencyBackupInProgress = NO;
    }
}

- (void)setupCrashDetection {
    // Setup crash detection with immediate storage
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    // Store reference for crash handler
    static __weak NRVAVideoLifecycleObserver *weakSelf;
    weakSelf = self;
    
    // Signal handler for SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE
    signal(SIGABRT, signalHandler);
    signal(SIGILL, signalHandler);
    signal(SIGSEGV, signalHandler);
    signal(SIGFPE, signalHandler);
    signal(SIGBUS, signalHandler);
    signal(SIGPIPE, signalHandler);
}

// C function for uncaught exception handling
void uncaughtExceptionHandler(NSException *exception) {
    // CRITICAL: Immediate emergency harvest and storage before crash
    NRVA_ERROR_LOG(@"CRASH DETECTED: %@", exception.reason);
    
    // Perform emergency backup synchronously
    @try {
        // Get the shared instance and perform emergency backup
        // This is a simplified approach - in production, you'd want a more robust mechanism
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NRVANeedsRecovery"];
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"NRVACrashTime"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NRVA_ERROR_LOG(@"Emergency crash backup completed");
    } @catch (NSException *backupException) {
        NRVA_ERROR_LOG(@"Emergency crash backup failed: %@", backupException.reason);
    }
}

// C function for signal handling
void signalHandler(int sig) {
    NRVA_ERROR_LOG(@"SIGNAL CRASH DETECTED: %d", sig);
    
    @try {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NRVANeedsRecovery"];
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"NRVASignalCrashTime"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } @catch (NSException *exception) {
        // Silent fail during signal handling
    }
    
    // Re-raise the signal
    signal(sig, SIG_DFL);
    raise(sig);
}

- (void)dealloc {
    [self stopObserving];
}

@end
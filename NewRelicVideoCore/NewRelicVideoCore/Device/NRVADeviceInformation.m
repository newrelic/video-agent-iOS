//
//  NRVADeviceInformation.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVADeviceInformation.h"
#import "NRVAUtils.h"
#import "NRVALog.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>

static NRVADeviceInformation *_sharedInstance = nil;
static dispatch_once_t onceToken;

@interface NRVADeviceInformation ()

// Private properties for initialization
@property (nonatomic, readwrite) NSString *osName;
@property (nonatomic, readwrite) NSString *osVersion;
@property (nonatomic, readwrite) NSString *osBuild;
@property (nonatomic, readwrite) NSString *model;
@property (nonatomic, readwrite) NSString *agentName;
@property (nonatomic, readwrite) NSString *agentVersion;
@property (nonatomic, readwrite) NSString *manufacturer;
@property (nonatomic, readwrite) NSString *deviceId;
@property (nonatomic, readwrite) NSString *architecture;
@property (nonatomic, readwrite) NSString *runTime;
@property (nonatomic, readwrite) NSString *size;
@property (nonatomic, readwrite) NSString *applicationFramework;
@property (nonatomic, readwrite) NSString *applicationFrameworkVersion;
@property (nonatomic, readwrite) NSString *userAgent;
@property (nonatomic, readwrite) BOOL isTV;
@property (nonatomic, readwrite) BOOL isLowMemoryDevice;

@end

@implementation NRVADeviceInformation

+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initializeDeviceInformation];
    }
    return self;
}

- (void)initializeDeviceInformation {
    @try {
        // Core device information
        self.osName = [NRVAUtils osName];
        self.osVersion = [[UIDevice currentDevice] systemVersion];
        self.osBuild = [self getOSBuildVersion];
        self.model = [[UIDevice currentDevice] model];
        self.agentName = @"NewRelic-VideoAgent-iOS";
        self.agentVersion = @"4.0.3"; // Should be pulled from build configuration
        self.manufacturer = @"Apple";
        self.deviceId = [self generatePersistentDeviceId];
        self.architecture = [self getSystemArchitecture];
        self.runTime = [self getRuntimeVersion];
        
        // Enhanced device detection
        self.isTV = [self detectTVPlatform];
        self.isLowMemoryDevice = [self detectLowMemoryDevice];
        self.size = @""; // Empty string for now
        self.applicationFramework = [self determineApplicationFramework];
        self.applicationFrameworkVersion = [self determineFrameworkVersion];
        self.userAgent = [self createUserAgent];
        
        NRVA_DEBUG_LOG(@"Device information initialized for %@", self.isTV ? @"TV" : @"Mobile");
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to initialize device information: %@", exception.reason);
        [self setDefaultValues];
    }
}

- (void)setDefaultValues {
    // Fallback values in case of initialization failure
    self.osName = @"iOS";
    self.osVersion = @"Unknown";
    self.osBuild = @"Unknown";
    self.model = @"Unknown";
    self.agentName = @"NewRelic-VideoAgent-iOS";
    self.agentVersion = @"4.0.3";
    self.manufacturer = @"Apple";
    self.deviceId = [[NSUUID UUID] UUIDString];
    self.architecture = @"unknown";
    self.runTime = @"unknown";
    self.size = @""; // Empty string for now
    self.applicationFramework = @"Native iOS";
    self.applicationFrameworkVersion = @"Unknown";
    self.userAgent = @"NewRelic-VideoAgent-iOS/4.0.3";
    self.isTV = NO;
    self.isLowMemoryDevice = NO;
}

#pragma mark - Private Methods

- (NSString *)getOSBuildVersion {
    @try {
        struct utsname systemInfo;
        uname(&systemInfo);
        return [NSString stringWithCString:systemInfo.version encoding:NSUTF8StringEncoding];
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to get OS build version: %@", exception.reason);
        return @"Unknown";
    }
}

- (NSString *)generatePersistentDeviceId {
    @try {
        // Use device identifierForVendor for consistency across app sessions
        NSString *vendorId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        if (vendorId && vendorId.length > 0) {
            return vendorId;
        }
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to get vendor identifier: %@", exception.reason);
    }
    
    // Fallback to random UUID
    return [[NSUUID UUID] UUIDString];
}

- (NSString *)getSystemArchitecture {
    @try {
        struct utsname systemInfo;
        uname(&systemInfo);
        return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to get system architecture: %@", exception.reason);
        return @"unknown";
    }
}

- (NSString *)getRuntimeVersion {
    @try {
        return [[NSProcessInfo processInfo] operatingSystemVersionString];
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to get runtime version: %@", exception.reason);
        return @"unknown";
    }
}

- (BOOL)detectLowMemoryDevice {
    @try {
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        
        // Check physical memory
        if ([processInfo respondsToSelector:@selector(physicalMemory)]) {
            unsigned long long physicalMemory = [processInfo physicalMemory];
            // Consider devices with less than 2GB RAM as low memory
            return physicalMemory < (2ULL * 1024 * 1024 * 1024);
        }
        
        // Fallback: check available memory
        vm_size_t pageSize;
        host_page_size(mach_host_self(), &pageSize);
        
        vm_statistics64_data_t vmStats;
        mach_msg_type_number_t infoCount = HOST_VM_INFO64_COUNT;
        
        if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStats, &infoCount) == KERN_SUCCESS) {
            uint64_t freeMemory = (uint64_t)(vmStats.free_count * pageSize);
            uint64_t totalMemory = (uint64_t)((vmStats.free_count + vmStats.active_count + vmStats.inactive_count + vmStats.wire_count) * pageSize);
            
            // Consider low memory if less than 15% available or total memory < 2GB
            return (freeMemory < totalMemory * 0.15) || (totalMemory < (2ULL * 1024 * 1024 * 1024));
        }
        
        return NO;
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to detect low memory device: %@", exception.reason);
        return NO;
    }
}

/**
 * Detect iOS/tvOS platform with multiple strategies
 * Thread-safe and optimized for performance
 */
- (BOOL)detectTVPlatform {
    @try {
        // Primary detection: Compile-time check (most reliable)
        #if TARGET_OS_TV
            return YES;
        #endif
        
        // Secondary detection: Runtime interface idiom check
        #if TARGET_OS_IOS
        if (@available(iOS 3.2, *)) {
            UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
            if (idiom == UIUserInterfaceIdiomTV) {
                return YES;
            }
        }
        #endif
        
        // Tertiary detection: Screen size analysis for Apple TV
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = MAX(screenBounds.size.width, screenBounds.size.height);
        CGFloat screenHeight = MIN(screenBounds.size.width, screenBounds.size.height);
        
        // Apple TV typical resolutions: 1920x1080, 3840x2160
        if ((screenWidth >= 1920 && screenHeight >= 1080) || 
            (screenWidth >= 3840 && screenHeight >= 2160)) {
            return YES;
        }
        
        return NO;
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to detect TV platform: %@", exception.reason);
        return NO;
    }
}

- (NSString *)determineApplicationFramework {
    @try {
        // Detect common frameworks by checking for framework classes
        if (NSClassFromString(@"RCTBridge") || NSClassFromString(@"RCTRootView")) {
            return @"React Native";
        } else if (NSClassFromString(@"FlutterEngine") || NSClassFromString(@"FlutterViewController")) {
            return @"Flutter";
        } else if (NSClassFromString(@"CDVViewController") || NSClassFromString(@"CDVPlugin")) {
            return @"Cordova";
        } else if (NSClassFromString(@"WKWebView")) {
            // Check if it's a hybrid app using WKWebView
            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *bundlePath = [mainBundle bundlePath];
            if ([bundlePath containsString:@"www"] || [bundlePath containsString:@"web"]) {
                return @"Hybrid WebView";
            }
        }
        
        return @"Native iOS";
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to determine application framework: %@", exception.reason);
        return @"Unknown";
    }
}

- (NSString *)determineFrameworkVersion {
    return self.osVersion;
}

- (NSString *)createUserAgent {
    @try {
        return [NSString stringWithFormat:@"%@/%@ (%@ %@; %@ %@%@)",
                self.agentName, self.agentVersion, self.osName, self.osVersion, 
                self.manufacturer, self.model,
                self.isTV ? @"; TV" : self.isLowMemoryDevice ? @"; LowMem" : @""];
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Failed to create user agent: %@", exception.reason);
        return [NSString stringWithFormat:@"%@/%@", self.agentName, self.agentVersion];
    }
}

@end
// Headless Sparkle installation test. Never accepts an installed user app.
#import <AppKit/AppKit.h>
#import <Sparkle/Sparkle.h>

@interface UpdateTestDriver : NSObject <SPUUserDriver>
@end
@implementation UpdateTestDriver
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply {
    reply([[SUUpdatePermissionResponse alloc] initWithAutomaticUpdateChecks:NO sendSystemProfile:NO]);
}
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancel { NSLog(@"CHECKING"); }
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    NSLog(@"FOUND %@ build %@", item.displayVersionString, item.versionString);
    reply(SPUUserUpdateChoiceInstall);
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error { NSLog(@"NOTES ERROR %@", error); }
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))reply { NSLog(@"NOT FOUND %@", error); reply(); exit(3); }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))reply { NSLog(@"UPDATE ERROR %@", error); reply(); exit(1); }
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancel { NSLog(@"DOWNLOADING"); }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length { NSLog(@"EXPECTED %llu", length); }
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { NSLog(@"EXTRACTING"); }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { NSLog(@"READY"); reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry { NSLog(@"INSTALLING terminated=%d", terminated); }
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))reply { NSLog(@"INSTALLED relaunched=%d", relaunched); reply(); exit(0); }
- (void)dismissUpdateInstallation {}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *path = [[NSString stringWithUTF8String:argv[1]] stringByResolvingSymlinksInPath];
        if (![path hasPrefix:@"/private/tmp/planora-updater-fixture/"] || ![path hasSuffix:@"/planora.app"]) {
            NSLog(@"Refusing to modify anything outside the isolated test fixture.");
            return 2;
        }
        NSBundle *host = [NSBundle bundleWithPath:path];
        if (![host.bundleIdentifier isEqualToString:@"com.zhangchengze.planora.mac"]) return 2;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        UpdateTestDriver *driver = [UpdateTestDriver new];
        SPUUpdater *updater = [[SPUUpdater alloc] initWithHostBundle:host applicationBundle:NSBundle.mainBundle userDriver:driver delegate:nil];
        NSError *error = nil;
        if (![updater startUpdater:&error]) { NSLog(@"START ERROR %@", error); return 1; }
        [updater checkForUpdates];
        [NSTimer scheduledTimerWithTimeInterval:240 repeats:NO block:^(NSTimer *timer) { NSLog(@"TIMEOUT"); exit(2); }];
        [NSApp run];
    }
    return 1;
}

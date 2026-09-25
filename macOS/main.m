#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

@interface DraggableWebView : WKWebView
@end

@implementation DraggableWebView
- (void)mouseDown:(NSEvent *)event {
    if (event.clickCount == 2) {
        [NSApp terminate:nil];
        return;
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window performWindowDragWithEvent:event];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *alwaysOnTopItem;
@property(nonatomic, strong) NSMenuItem *showNumbersItem;
@property(nonatomic, strong) NSMenu *sizeMenu;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self createWindow];
    [self createStatusMenu];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)setBackgroundAppearance:(BOOL)backgrounded {
    self.window.alphaValue = 1.0;
    NSString *script = backgrounded
        ? @"setBackgrounded(true)"
        : @"setBackgrounded(false)";
    [self.webView evaluateJavaScript:script completionHandler:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self setBackgroundAppearance:NO];
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    BOOL alwaysOnTop = self.alwaysOnTopItem.state == NSControlStateValueOn;
    [self setBackgroundAppearance:!alwaysOnTop];
}

- (void)createWindow {
    NSString *sizeKey = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"BlockClockDisplaySize"] ?: @"medium";
    CGFloat scale = [self scaleForSizeKey:sizeKey];
    NSRect defaultFrame = NSMakeRect(120, 120, 490 * scale, 270 * scale);
    self.window = [[NSWindow alloc]
        initWithContentRect:defaultFrame
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
    self.window.hasShadow = YES;
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.window.movableByWindowBackground = YES;
    [self.window setFrameAutosaveName:@"BlockClockWindowFrame"];

    NSString *savedFrame = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"BlockClockWindowFrame"];
    if (savedFrame.length > 0) {
        NSRect restoredFrame = NSRectFromString(savedFrame);
        restoredFrame.size = defaultFrame.size;
        [self.window setFrame:restoredFrame display:NO];
    } else {
        [self.window center];
    }

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    NSNumber *savedShowNumbers = [[NSUserDefaults standardUserDefaults]
        objectForKey:@"BlockClockShowNumbers"];
    BOOL showNumbers = savedShowNumbers == nil ? YES : savedShowNumbers.boolValue;
    if (!showNumbers) {
        WKUserScript *hideNumbersScript = [[WKUserScript alloc]
            initWithSource:@"setNumberVisible(false)"
            injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
            forMainFrameOnly:YES];
        [configuration.userContentController addUserScript:hideNumbersScript];
    }
    DraggableWebView *webView = [[DraggableWebView alloc]
        initWithFrame:self.window.contentView.bounds
        configuration:configuration];
    webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [webView setValue:@NO forKey:@"drawsBackground"];
    webView.allowsMagnification = YES;
    webView.pageZoom = scale;
    self.webView = webView;
    self.window.contentView = webView;

    NSURL *htmlURL = [[NSBundle mainBundle] URLForResource:@"clock" withExtension:@"html"];
    if (htmlURL == nil) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"clock.html が見つかりません";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }
    [webView loadFileURL:htmlURL allowingReadAccessToURL:htmlURL.URLByDeletingLastPathComponent];
}

- (void)createStatusMenu {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"◷";
    self.statusItem.button.toolTip = @"Block Clock";

    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *toggleItem = [[NSMenuItem alloc]
        initWithTitle:@"時計を表示／隠す"
               action:@selector(toggleWindow:)
        keyEquivalent:@"b"];
    toggleItem.target = self;
    [menu addItem:toggleItem];

    self.alwaysOnTopItem = [[NSMenuItem alloc]
        initWithTitle:@"常に手前に表示"
               action:@selector(toggleAlwaysOnTop:)
        keyEquivalent:@""];
    self.alwaysOnTopItem.target = self;
    self.alwaysOnTopItem.state = NSControlStateValueOn;
    [menu addItem:self.alwaysOnTopItem];

    NSNumber *savedShowNumbers = [[NSUserDefaults standardUserDefaults]
        objectForKey:@"BlockClockShowNumbers"];
    BOOL showNumbers = savedShowNumbers == nil ? YES : savedShowNumbers.boolValue;
    self.showNumbersItem = [[NSMenuItem alloc]
        initWithTitle:@"数字を表示"
               action:@selector(toggleShowNumbers:)
        keyEquivalent:@""];
    self.showNumbersItem.target = self;
    self.showNumbersItem.state = showNumbers ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:self.showNumbersItem];

    NSMenuItem *sizeParentItem = [[NSMenuItem alloc]
        initWithTitle:@"表示サイズ"
               action:nil
        keyEquivalent:@""];
    self.sizeMenu = [[NSMenu alloc] initWithTitle:@"表示サイズ"];
    NSArray<NSArray *> *sizeOptions = @[
        @[@"小", @"small"],
        @[@"中", @"medium"],
        @[@"大", @"large"]
    ];
    NSString *currentSize = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"BlockClockDisplaySize"] ?: @"medium";
    for (NSArray *option in sizeOptions) {
        NSMenuItem *item = [[NSMenuItem alloc]
            initWithTitle:option[0]
                   action:@selector(changeDisplaySize:)
            keyEquivalent:@""];
        item.target = self;
        item.representedObject = option[1];
        item.state = [currentSize isEqualToString:option[1]]
            ? NSControlStateValueOn
            : NSControlStateValueOff;
        [self.sizeMenu addItem:item];
    }
    sizeParentItem.submenu = self.sizeMenu;
    [menu addItem:sizeParentItem];
    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc]
        initWithTitle:@"Block Clockを終了"
               action:@selector(quit:)
        keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    self.statusItem.menu = menu;
}

- (void)toggleWindow:(id)sender {
    if (self.window.visible) {
        [self.window orderOut:nil];
    } else {
        [self.window makeKeyAndOrderFront:nil];
    }
}

- (void)toggleAlwaysOnTop:(id)sender {
    BOOL enabled = self.alwaysOnTopItem.state != NSControlStateValueOn;
    self.alwaysOnTopItem.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.window.level = enabled ? NSFloatingWindowLevel : NSNormalWindowLevel;
    [self setBackgroundAppearance:(!enabled && !NSApp.isActive)];
}

- (void)toggleShowNumbers:(id)sender {
    BOOL showNumbers = self.showNumbersItem.state != NSControlStateValueOn;
    self.showNumbersItem.state = showNumbers ? NSControlStateValueOn : NSControlStateValueOff;
    [[NSUserDefaults standardUserDefaults]
        setBool:showNumbers
          forKey:@"BlockClockShowNumbers"];

    NSString *script = showNumbers ? @"setNumberVisible(true)" : @"setNumberVisible(false)";
    [self.webView evaluateJavaScript:script completionHandler:nil];
}

- (CGFloat)scaleForSizeKey:(NSString *)sizeKey {
    if ([sizeKey isEqualToString:@"small"]) return 0.78;
    if ([sizeKey isEqualToString:@"large"]) return 1.30;
    return 1.0;
}

- (void)changeDisplaySize:(NSMenuItem *)sender {
    NSString *sizeKey = sender.representedObject;
    CGFloat scale = [self scaleForSizeKey:sizeKey];
    NSRect oldFrame = self.window.frame;
    NSSize newSize = NSMakeSize(490 * scale, 270 * scale);
    NSRect newFrame = NSMakeRect(
        NSMidX(oldFrame) - newSize.width / 2,
        NSMidY(oldFrame) - newSize.height / 2,
        newSize.width,
        newSize.height
    );

    self.webView.pageZoom = scale;
    [self.window setFrame:newFrame display:YES animate:YES];
    [[NSUserDefaults standardUserDefaults]
        setObject:sizeKey
           forKey:@"BlockClockDisplaySize"];

    for (NSMenuItem *item in self.sizeMenu.itemArray) {
        item.state = [item.representedObject isEqualToString:sizeKey]
            ? NSControlStateValueOn
            : NSControlStateValueOff;
    }
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults]
        setObject:NSStringFromRect(self.window.frame)
           forKey:@"BlockClockWindowFrame"];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}

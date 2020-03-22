// https://stackoverflow.com/questions/2997333/creating-a-cocoa-application-without-nib-files/3272447#3272447

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate> {
  NSWindow* window;
  WKWebView* webView;
  WKWebViewConfiguration* configuration;
  WKUserContentController* contentController;
  NSTask* jupyterTask;
  NSString* host;
  int port;
  int loadAttempts;
  double loadDelay;
  NSString* token;
}
@end

@interface NSConcreteTask : NSTask {
}
// https://github.com/facebook/xctool/commit/e61f436
//
// When YES (default), a new progress group is created for the child (via
// POSIX_SPAWN_SETPGROUP to posix_spawnattr_setflags).  If YES, then the child
// will continue running even if the parent is killed or interrupted.
//
- (void)setStartsNewProcessGroup:(BOOL)startsNewProcessGroup;
@end

@implementation AppDelegate : NSObject

- (id)init {
  if (self = [super init]) {
    jupyterTask = [self newJupyterCommandTask];
    if (!jupyterTask) {
      [[NSApplication sharedApplication] terminate:self];
      return self;
    }
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 480)
                                         styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    window.frameAutosaveName = @"MainWindow";

    configuration = [WKWebViewConfiguration new];
    contentController = configuration.userContentController;
    webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0) configuration:configuration];
    webView.navigationDelegate = self;
    window.contentView = webView;
    loadAttempts = 5;
  }
  return self;
}

- (NSTask*)newJupyterCommandTask {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSString* commandPath = [defaults stringForKey:@"CommandPath"] ?: @"jupyter-lab";
  NSString* notebookPath = [defaults stringForKey:@"NotebookPath"] ?: @"~/Documents/Notebooks";
  host = [defaults stringForKey:@"Host"] ?: @"127.0.0.1";
  port = [defaults integerForKey:@"Port"] ?: 11011;
  token = [defaults stringForKey:@"Token"] ?: @"deadbeefb00b";
  loadDelay = [defaults doubleForKey:@"LoadDelay"] ?: 0.5;
  NSTask* task = [NSTask new];
  task.executableURL = [NSURL fileURLWithPath:commandPath];
  task.arguments = [NSArray arrayWithObjects:@"--no-browser", [@"--ip=" stringByAppendingString:host],
                                             [@"--port=" stringByAppendingFormat:@"%d", port, nil],
                                             [@"--notebook-dir=" stringByAppendingString:notebookPath],
                                             [@"--NotebookApp.token=" stringByAppendingString:token], nil];
  @try {
    if ([task respondsToSelector:@selector(setStartsNewProcessGroup:)]) {
      // Ensure process dies when this application dies.
      [(NSConcreteTask*)task setStartsNewProcessGroup:NO];
    } else {
      NSLog(@"Task %@ is not NSConcreteTask and may become stray.", task);
    }
    [task launch];
  } @catch (NSException* exception) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Cannot run command `%@': %@\nAdjust CommandPath setting.",
                                                   commandPath, exception.reason, nil];
    [alert runModal];
    return nil;
  }

  if (!task.isRunning) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText =
        [NSString stringWithFormat:@"Command `%@' is not running. Adjust CommandPath setting.", commandPath, nil];
    [alert runModal];
    return nil;
  }

  return task;
}

- (void)loadJupyterPage {
  NSString* address = [NSString stringWithFormat:@"http://%@:%d/?token=%@", host, port, token, nil];
  // NSLog(@"Opening: %@", address);
  NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:address]];
  [webView loadRequest:request];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// WKNavigationDelegate

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error {
  NSLog(@"Navigation %@ failed: %@", navigation, error.localizedDescription);
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"Failed to navigate `%@': %@", navigation, error.localizedDescription, nil];
  [alert runModal];
}

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error {
  if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == -1004 && loadAttempts > 0) {
    NSLog(@"Retrying (%d attempts) failed provisional navigation %@: %@", loadAttempts, navigation,
          error.localizedDescription);
    loadAttempts--;
    [self performSelector:@selector(loadJupyterPage) withObject:nil afterDelay:loadDelay];
    return;
  }

  NSLog(@"Provisional navigation %@ failed: %@", navigation, error.localizedDescription);
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"Failed to navigate `%@': %@", navigation, error.localizedDescription, nil];
  [alert runModal];
  [self loadJupyterPage];
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {

  // NSLog(@"Navigation %@ finished.", navigation);
  loadAttempts = 0;
}

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURL* url = navigationAction.request.URL;
  bool isLocal = [url.scheme isEqualToString:@"http"] && [url.host isEqualToString:host] && url.port.intValue == port;
  if (isLocal || [url.scheme isEqualToString:@"https"]) {
    decisionHandler(WKNavigationActionPolicyAllow);
  } else {
    switch (navigationAction.navigationType) {
    case WKNavigationTypeLinkActivated:
      NSLog(@"Opening navigation action %ld in regular browser instead for: %@", navigationAction.navigationType, url);
      [NSWorkspace.sharedWorkspace openURL:url];
      decisionHandler(WKNavigationActionPolicyCancel);
      break;
    default:
      NSLog(@"Disallowed navigation action %ld to: %@", navigationAction.navigationType, url);
      decisionHandler(WKNavigationActionPolicyCancel);
      break;
    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// WKUIDelegate

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NSApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
  NSApplication* application = [NSApplication sharedApplication];
  NSString* title = NSProcessInfo.processInfo.processName;
  application.mainMenu = [self newMainMenu:title];
  window.title = title;
  // [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
  [window makeKeyAndOrderFront:self];

  [self performSelector:@selector(loadJupyterPage) withObject:nil afterDelay:loadDelay];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification*)notification {
  // NOTE: [jupyterTask terminate]; is not reliable with conjunction with
  // [(NSConcreteTask*)task setStartsNewProcessGroup:NO];
  // Using POSIX way instead
  kill(jupyterTask.processIdentifier, SIGTERM);
  [jupyterTask waitUntilExit];
}

- (NSMenu*)newMainMenu:(NSString*)title {
  NSMenu* mainMenu = [NSMenu new];

  NSMenuItem* appMenuItem = [NSMenuItem new];
  NSMenu* appMenu = [[NSMenu alloc] initWithTitle:title];
  [appMenu addItemWithTitle:[@"About " stringByAppendingString:title]
                     action:@selector(orderFrontStandardAboutPanel:)
              keyEquivalent:@""];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:[@"Hide " stringByAppendingString:title] action:@selector(hide:) keyEquivalent:@"h"];
  [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"H"];
  [appMenu addItemWithTitle:[@"Quit " stringByAppendingString:title] action:@selector(terminate:) keyEquivalent:@"q"];
  [appMenu addItem:[NSMenuItem separatorItem]];
  appMenuItem.submenu = appMenu;
  [mainMenu addItem:appMenuItem];

  NSMenuItem* editMenuItem = [NSMenuItem new];
  NSMenu* editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"A"];
  [editMenu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* findMenuItem = [editMenu addItemWithTitle:@"Find" action:nil keyEquivalent:@""];
  NSMenu* findMenu = [[NSMenu alloc] initWithTitle:@"Find"];
  [findMenu addItemWithTitle:@"Find..." action:@selector(performTextFinderAction:) keyEquivalent:@"f"];
  [findMenu addItemWithTitle:@"Find Next" action:@selector(performTextFinderAction:) keyEquivalent:@"g"];
  [findMenu addItemWithTitle:@"Find Previous" action:@selector(performTextFinderAction:) keyEquivalent:@"G"];
  [findMenu addItemWithTitle:@"Use Selection for Find" action:@selector(performTextFinderAction:) keyEquivalent:@"e"];
  [findMenu addItemWithTitle:@"Jump to Selection" action:@selector(performTextFinderAction:) keyEquivalent:@"j"];
  findMenuItem.submenu = findMenu;
  editMenuItem.submenu = editMenu;
  [mainMenu addItem:editMenuItem];

  NSMenuItem* helpMenuItem = [NSMenuItem new];
  NSMenu* helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
  [helpMenu addItemWithTitle:[title stringByAppendingString:@" Help"] action:@selector(help:) keyEquivalent:@"?"];
  helpMenuItem.submenu = helpMenu;
  [mainMenu addItem:helpMenuItem];

  return mainMenu;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// main

int main(int argc, char* argv[]) {
  @autoreleasepool {
    NSApplication* application = [NSApplication sharedApplication];
    application.activationPolicy = NSApplicationActivationPolicyRegular;
    AppDelegate* appDelegate = [[AppDelegate alloc] init];
    [application setDelegate:appDelegate];
    [application run];
  }
  return EXIT_SUCCESS;
}

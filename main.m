// https://stackoverflow.com/questions/2997333/creating-a-cocoa-application-without-nib-files/3272447#3272447

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate
    : NSObject <NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate> {
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

@implementation AppDelegate : NSObject

- (id)init {
  if (self = [super init]) {
    jupyterTask = [self runJupyterCommandTask];
    if (!jupyterTask) {
      [[NSApplication sharedApplication] terminate:self];
      return self;
    }
    window =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 480)
                                    styleMask:NSWindowStyleMaskTitled |
                                              NSWindowStyleMaskClosable |
                                              NSWindowStyleMaskMiniaturizable |
                                              NSWindowStyleMaskResizable
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    window.frameAutosaveName = @"MainWindow";

    configuration = [WKWebViewConfiguration new];
    contentController = configuration.userContentController;
    webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)
                                 configuration:configuration];
    webView.navigationDelegate = self;
    window.contentView = webView;
    loadAttempts = 5;
  }
  return self;
}

- (NSTask*)runJupyterCommandTask {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSString* commandPath =
      [defaults stringForKey:@"CommandPath"] ?: @"jupyter-lab";
  NSString* notebookPath =
      [defaults stringForKey:@"NotebookPath"] ?: @"~/Documents/Notebooks";
  host = [defaults stringForKey:@"Host"] ?: @"127.0.0.1";
  port = [defaults integerForKey:@"Port"] ?: 11011;
  token = [defaults stringForKey:@"Token"] ?: @"deadbeefb00b";
  loadDelay = [defaults doubleForKey:@"LoadDelay"] ?: 0.5;
  NSTask* task = [NSTask new];
  task.executableURL = [NSURL fileURLWithPath:commandPath];
  task.arguments = [NSArray
      arrayWithObjects:@"--no-browser", [@"--ip=" stringByAppendingString:host],
                       [@"--port=" stringByAppendingFormat:@"%d", port, nil],
                       [@"--notebook-dir="
                           stringByAppendingString:notebookPath],
                       [@"--NotebookApp.token=" stringByAppendingString:token],
                       nil];
  @try {
    [task launch];
  } @catch (NSException* exception) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = [NSString
        stringWithFormat:
            @"Cannot run command `%@': %@\nAdjust CommandPath setting.",
            commandPath, exception.reason, nil];
    [alert runModal];
    return nil;
  }

  if (!task.isRunning) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = [NSString
        stringWithFormat:
            @"Command `%@' is not running. Adjust CommandPath setting.",
            commandPath, nil];
    [alert runModal];
    return nil;
  }

  return task;
}

- (void)loadJupyterPage {
  NSString* address = [NSString
      stringWithFormat:@"http://%@:%d/?token=%@", host, port, token, nil];
  // NSLog(@"Opening: %@", address);
  NSURLRequest* request =
      [NSURLRequest requestWithURL:[NSURL URLWithString:address]];
  [webView loadRequest:request];
}

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
  NSApplication* application = [NSApplication sharedApplication];
  NSString* title = NSProcessInfo.processInfo.processName;
  application.mainMenu = [self newMainMenu:title];
  window.title = title;
  // [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
  [window makeKeyAndOrderFront:self];

  [self performSelector:@selector(loadJupyterPage)
             withObject:nil
             afterDelay:loadDelay];
}

- (void)webView:(WKWebView*)webView
    didFailNavigation:(WKNavigation*)navigation
            withError:(NSError*)error {
  NSLog(@"Navigation %@ failed: %@", navigation, error.localizedDescription);
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"Failed to navigate `%@': %@", navigation,
                                 error.localizedDescription, nil];
  [alert runModal];
}

- (void)webView:(WKWebView*)webView
    didFailProvisionalNavigation:(WKNavigation*)navigation
                       withError:(NSError*)error {
  if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == -1004 &&
      loadAttempts > 0) {
    NSLog(@"Retrying (%d attempts) failed provisional navigation %@: %@",
          loadAttempts, navigation, error.localizedDescription);
    loadAttempts--;
    [self performSelector:@selector(loadJupyterPage)
               withObject:nil
               afterDelay:loadDelay];
    return;
  }

  NSLog(@"Provisional navigation %@ failed: %@", navigation,
        error.localizedDescription);
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"Failed to navigate `%@': %@", navigation,
                                 error.localizedDescription, nil];
  [alert runModal];
  [self loadJupyterPage];
}

- (void)webView:(WKWebView*)webView
    didFinishNavigation:(WKNavigation*)navigation {

  // NSLog(@"Navigation %@ finished.", navigation);
  loadAttempts = 0;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification*)notification {
  [jupyterTask interrupt];
  [NSThread sleepForTimeInterval:0.5];
  [jupyterTask interrupt]; // needs twice to skip confirmation
  [jupyterTask waitUntilExit];
}

- (NSMenu*)newMainMenu:(NSString*)title {
  NSMenu* mainMenu = [NSMenu new];
  NSMenuItem* appMenuItem = [NSMenuItem new];
  appMenuItem.submenu = [NSMenu new];
  [appMenuItem.submenu
      addItem:[[NSMenuItem alloc]
                  initWithTitle:[@"About " stringByAppendingString:title]
                         action:@selector(orderFrontStandardAboutPanel:)
                  keyEquivalent:@""]];
  [appMenuItem.submenu addItem:[NSMenuItem separatorItem]];
  [appMenuItem.submenu
      addItem:[[NSMenuItem alloc]
                  initWithTitle:[@"Hide " stringByAppendingString:title]
                         action:@selector(hide:)
                  keyEquivalent:@"h"]];
  [appMenuItem.submenu
      addItem:[[NSMenuItem alloc]
                  initWithTitle:@"Hide Others"
                         action:@selector(hideOtherApplications:)
                  keyEquivalent:@"H"]];
  [appMenuItem.submenu
      addItem:[[NSMenuItem alloc]
                  initWithTitle:[@"Quit " stringByAppendingString:title]
                         action:@selector(terminate:)
                  keyEquivalent:@"q"]];
  [appMenuItem.submenu addItem:[NSMenuItem separatorItem]];
  [mainMenu addItem:appMenuItem];
  return mainMenu;
}

@end

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

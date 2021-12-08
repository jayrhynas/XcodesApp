import AppKit
import Sparkle
import SwiftUI
import Intents

@main
struct XcodesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase
    @SwiftUI.Environment(\.openURL) var openURL: OpenURLAction
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup("Xcodes") {
            MainWindow()
                .environmentObject(appState)
                // This is intentionally used on a View, and not on a WindowGroup, 
                // so that it's triggered when an individual window's phase changes instead of all window phases.
                // When used on a View it's also invoked on launch, which doesn't occur with a WindowGroup. 
                // FB8954581 ScenePhase read from App doesn't return a value on launch
                .onChange(of: scenePhase) { newScenePhase in
                    guard !isTesting else { return }
                    if case .active = newScenePhase {
                        appState.updateIfNeeded()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Xcodes") {
                    appDelegate.showAboutWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }
        
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button("Refresh") {
                    appState.update()
                }
                .keyboardShortcut(KeyEquivalent("r"))
                .disabled(appState.isUpdating)
            }

            XcodeCommands(appState: appState)
            
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Button("Xcodes GitHub Repo") {
                    let xcodesRepoURL = URL(string: "https://github.com/RobotsAndPencils/XcodesApp/")!
                    openURL(xcodesRepoURL)
                }
                
                Divider()
                
                Button("Report a Bug") {
                    let bugReportURL = URL(string: "https://github.com/RobotsAndPencils/XcodesApp/issues/new?assignees=&labels=bug&template=bug_report.md&title=")!
                    openURL(bugReportURL)
                }
                
                Button("Request a New Feature") {
                    let featureRequestURL = URL(string: "https://github.com/RobotsAndPencils/XcodesApp/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=")!
                    openURL(featureRequestURL)
                }
            }
        }
        #if os(macOS)
        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
        #endif
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var aboutWindow = configure(NSWindow(
        contentRect: .zero,
        styleMask: [.closable, .resizable, .miniaturizable, .titled],
        backing: .buffered,
        defer: false
    )) {
        $0.title = "About Xcodes"
        $0.contentView = NSHostingView(rootView: AboutView(showAcknowledgementsWindow: showAcknowledgementsWindow))
        $0.isReleasedWhenClosed = false
    }
    
    private let acknowledgementsWindow = configure(NSWindow(
        contentRect: .zero,
        styleMask: [.closable, .resizable, .miniaturizable, .titled],
        backing: .buffered,
        defer: false
    )) {
        $0.title = "Xcodes Acknowledgements"
        $0.contentView = NSHostingView(rootView: AcknowledgmentsView())
        $0.isReleasedWhenClosed = false
    }

    /// If we wanted to use only SwiftUI API to do this we could make a new WindowGroup and use openURL and handlesExternalEvents.
    /// WindowGroup lets the user open more than one window right now, which is a little strange for an About window.
    /// (It's also weird that the main Xcode list window can be opened more than once, there should only be one.)
    /// To work around this, an AppDelegate holds onto a single instance of an NSWindow that is shown here.  
    /// FB8954588 Scene / WindowGroup is missing API to limit the number of windows that can be created
    func showAboutWindow() {
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
    }
    
    func showAcknowledgementsWindow() {
        acknowledgementsWindow.center()
        acknowledgementsWindow.makeKeyAndOrderFront(nil)
    }
    
    func checkForUpdates() {
        SUUpdater.shared()?.checkForUpdates(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize manually
        SUUpdater.shared()
    }
    
    func application(_ application: NSApplication, handlerFor intent: INIntent) -> Any? {
        if intent is DownloadXcodeVersionIntent {
            return IntentHandler()
        }
        return nil
    }
}

class IntentHandler: NSObject, DownloadXcodeVersionIntentHandling {
    var appState: AppState = AppState()
    
    func provideVersionOptionsCollection(for intent: DownloadXcodeVersionIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<XcodeVersion>?, Error?) -> Void) {
        guard let searchTerm = searchTerm else {
            return
        }
        
        let xcodes = appState.allXcodes.filter { $0.description.contains(searchTerm) }
        let versions: [XcodeVersion] = xcodes.map { XcodeVersion(identifier: $0.id.appleDescription, display: $0.description)}
        completion(INObjectCollection(items: versions), nil)
    }
    
    // check the version parameter
    func resolveVersion(for intent: DownloadXcodeVersionIntent, with completion: @escaping (DownloadXcodeVersionVersionResolutionResult) -> Void) {
        guard let version = intent.version else {
            return completion(.needsValue())
        }
        
        return completion(.success(with: version))
    }
    
    func handle(intent: DownloadXcodeVersionIntent, completion: @escaping (DownloadXcodeVersionIntentResponse) -> Void) {
        // do actual downloading 
        
        
        let response = DownloadXcodeVersionIntentResponse(code: .success, userActivity: nil)
        response.versionString = intent.version?.description
        completion(response)
    }
   
    

    
//    func provideVersionOptionsCollection(for intent: DownloadXcodeVersionIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<Type>?, Error?) -> Void) {
//        guard let searchTerm = searchTerm else {
//            return
//        }
//
//        let xcodes = appState.allXcodes.filter { $0.description.contains(searchTerm) }
//        let versions: [NSString] = xcodes.map { $0.version.descriptionWithoutBuildMetadata }
//        let xcodeVersions = INObjectCollection(items: xcodes)
        
//    }

}

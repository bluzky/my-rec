//
//  AppDelegate.swift
//  MyRec
//
//  Created by Flex on 11/14/25.
//

import Cocoa
import SwiftUI
#if canImport(MyRecCore)
import MyRecCore
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar
        statusBarController = StatusBarController()

        print("✅ MyRec launched successfully")
        print("✅ Status bar controller initialized")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 MyRec terminating")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close (menu bar app)
        return false
    }
}

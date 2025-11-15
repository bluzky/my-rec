//
//  MyRecApp.swift
//  MyRec
//
//  Created by Flex on 11/14/25.
//

import SwiftUI

@main
struct MyRecApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

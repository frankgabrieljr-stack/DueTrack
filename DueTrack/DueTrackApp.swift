//
//  DueTrackApp.swift
//  DueTrack
//
//  Created by Frank Gabriel on 11/8/25.
//

import SwiftUI
import CoreData

@main
struct DueTrackApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

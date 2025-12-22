//
//  DueTrackNextBillWidgetLiveActivity.swift
//  DueTrackNextBillWidget
//
//  Created by Frank Gabriel on 12/9/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DueTrackNextBillWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DueTrackNextBillWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DueTrackNextBillWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DueTrackNextBillWidgetAttributes {
    fileprivate static var preview: DueTrackNextBillWidgetAttributes {
        DueTrackNextBillWidgetAttributes(name: "World")
    }
}

extension DueTrackNextBillWidgetAttributes.ContentState {
    fileprivate static var smiley: DueTrackNextBillWidgetAttributes.ContentState {
        DueTrackNextBillWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DueTrackNextBillWidgetAttributes.ContentState {
         DueTrackNextBillWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DueTrackNextBillWidgetAttributes.preview) {
   DueTrackNextBillWidgetLiveActivity()
} contentStates: {
    DueTrackNextBillWidgetAttributes.ContentState.smiley
    DueTrackNextBillWidgetAttributes.ContentState.starEyes
}

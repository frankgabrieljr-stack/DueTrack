//
//  DueTrackNextBillWidgetBundle.swift
//  DueTrackNextBillWidget
//
//  Created by Frank Gabriel on 12/9/25.
//

import WidgetKit
import SwiftUI

@main
struct DueTrackNextBillWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Put the calendar-style widget first so it is the default pick
        DueTrackThisWeekWidget()
        DueTrackNextBillWidget()
        DueTrackNextBillWidgetControl()
        DueTrackNextBillWidgetLiveActivity()
    }
}

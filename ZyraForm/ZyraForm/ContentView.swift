//
//  ContentView.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI

func PrintDebug(_ items: Any..., emoji: String = "", separator: String = " ", terminator: String = "\n", debug: Bool = true) {
    #if DEBUG
    if debug {
        let message = items.map { "\($0)" }.joined(separator: separator)
        let emojiPrefix = emoji.isEmpty ? "" : "\(emoji) "
        let styledMessage = "[DEBUG] \(emojiPrefix)\(message)"
        
        print(styledMessage, terminator: terminator)
    }
    #endif
}

struct ContentView: View {
    var body: some View {
        EmployeesListView()
    }
}

#Preview {
    ContentView()
}

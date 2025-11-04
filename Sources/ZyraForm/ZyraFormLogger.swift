//
//  ZyraFormLogger.swift
//  ZyraForm
//
//  Centralized logging utility for ZyraForm
//

import Foundation
import OSLog

public enum ZyraFormLogLevel {
    case debug
    case info
    case warning
    case error
}

public struct ZyraFormLogger {
    private static let subsystem = "com.zyraform"
    private static let category = "ZyraForm"
    private static let logger = Logger(subsystem: subsystem, category: category)
    
    public static var isEnabled: Bool = true
    
    public static func log(_ level: ZyraFormLogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
            print("🔍 [ZyraForm DEBUG] \(logMessage)")
        case .info:
            logger.info("\(logMessage)")
            print("ℹ️ [ZyraForm INFO] \(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
            print("⚠️ [ZyraForm WARNING] \(logMessage)")
        case .error:
            logger.error("\(logMessage)")
            print("❌ [ZyraForm ERROR] \(logMessage)")
        }
    }
    
    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    public static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
}


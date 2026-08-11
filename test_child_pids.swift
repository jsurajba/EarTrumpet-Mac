import Foundation
import AppKit

print("--- TESTING SYSTEMATIC CHILD PID DISCOVERY VIA PROC_LISTCHILD PIDS ---")

func getChildPIDs(parentPID: pid_t) -> [pid_t] {
    var pids = [pid_t](repeating: 0, count: 1024)
    let bytes = proc_listchildpids(parentPID, &pids, Int32(MemoryLayout<pid_t>.size * 1024))
    if bytes > 0 {
        let count = Int(bytes) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(count))
    }
    return []
}

let runningApps = NSWorkspace.shared.runningApplications
for app in runningApps {
    if app.activationPolicy == .regular, let name = app.localizedName {
        let mainPID = app.processIdentifier
        let children = getChildPIDs(parentPID: mainPID)
        if !children.isEmpty {
            print("App '\(name)' (PID \(mainPID)) has \(children.count) child PIDs: \(children)")
        }
    }
}

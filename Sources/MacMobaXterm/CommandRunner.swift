import Foundation

struct CommandResult {
    let status: Int32
    let output: String
    let timedOut: Bool
    
    var succeeded: Bool { status == 0 && !timedOut }
}

enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 20) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: "启动失败: \(error.localizedDescription)", timedOut: false)
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        let timedOut = semaphore.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            process.waitUntilExit()
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var output = String(data: data, encoding: .utf8) ?? ""
        if timedOut {
            if !output.isEmpty { output += "\n" }
            output += "命令超时，已终止。"
        } else if output.isEmpty {
            output = "命令已完成，退出码: \(process.terminationStatus)"
        }
        return CommandResult(status: process.terminationStatus, output: output, timedOut: timedOut)
    }

    static func runExpectingPassword(
        _ executable: String,
        _ arguments: [String],
        password: String,
        timeout: TimeInterval = 20
    ) -> CommandResult {
        let script = """
        set timeout \(Int(timeout))
        set password [lindex $argv 0]
        set executable [lindex $argv 1]
        set commandArgs [lrange $argv 2 end]
        spawn -noecho $executable {*}$commandArgs
        expect {
            -re "(?i)password:" {
                send -- "$password\\r"
                exp_continue
            }
            -re "(?i)passphrase.*:" {
                send -- "$password\\r"
                exp_continue
            }
            eof {
                catch wait result
                exit [lindex $result 3]
            }
            timeout {
                exit 124
            }
        }
        """
        var expectArgs = ["-c", script, password, executable]
        expectArgs += arguments
        let result = run("/usr/bin/expect", expectArgs, timeout: timeout + 2)
        if result.status == 124 || result.timedOut {
            return CommandResult(status: result.status, output: "命令超时，已终止。", timedOut: true)
        }
        return result
    }
}

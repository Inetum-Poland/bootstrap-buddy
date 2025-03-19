//
//  BBMechanism.swift
//  Bootstrap Buddy
//
//  Copyright 2024 Inetum Poland
//
//  Based on Escrow Buddy
//  Copyright 2023 Netflix
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

//  Inspired by portions of Crypt.
//  https://github.com/grahamgilbert/crypt/

import Foundation
import Network
import Security
import os.log

class BBMechanism: NSObject {
    // Log Bootstrap Buddy Mechanism
    private static let log = OSLog(subsystem: "com.inetum.Bootstrap-Buddy", category: "BBMechanism")
    // Define a pointer to the MechanismRecord. This will be used to get and set
    // all the inter-mechanism data. It is also used to allow or deny the login.
    var mechanism: UnsafePointer<MechanismRecord>

    // init the class with a MechanismRecord
    @objc init(mechanism: UnsafePointer<MechanismRecord>) {
        os_log("• initWithMechanismRecord", log: BBMechanism.log, type: .default)
        self.mechanism = mechanism
    }

    // Allow the login. End of the mechanism
    func allowLogin() {
        os_log("allowLogin called", log: BBMechanism.log, type: .default)
        _ = self.mechanism.pointee.fPlugin.pointee.fCallbacks.pointee.SetResult(
            mechanism.pointee.fEngine, AuthorizationResult.allow)
        os_log("Proceeding with login.", log: BBMechanism.log, type: .default)
    }

    private func getContextData(key: AuthorizationString) -> NSData? {
        os_log("getContextData called", log: BBMechanism.log, type: .default)
        var value: UnsafePointer<AuthorizationValue>?
        let data = withUnsafeMutablePointer(to: &value) { (ptr: UnsafeMutablePointer) -> NSData? in
            var flags = AuthorizationContextFlags()
            if self.mechanism.pointee.fPlugin.pointee.fCallbacks.pointee.GetContextValue(
                self.mechanism.pointee.fEngine, key, &flags, ptr) != errAuthorizationSuccess
            {
                os_log("getContextData failed", log: BBMechanism.log, type: .error)
                return nil
            }
            guard let length = ptr.pointee?.pointee.length else {
                os_log("length failed to unwrap", log: BBMechanism.log, type: .error)
                return nil
            }
            guard let buffer = ptr.pointee?.pointee.data else {
                os_log("data failed to unwrap", log: BBMechanism.log, type: .error)
                return nil
            }
            if length == 0 {
                os_log("length is 0", log: BBMechanism.log, type: .error)
                return nil
            }
            return NSData.init(bytes: buffer, length: length)
        }
        os_log("getContextData succeeded", log: BBMechanism.log, type: .default)
        return data
    }

    var username: NSString? {
        os_log("Requesting username…", log: BBMechanism.log, type: .default)
        guard let data = getContextData(key: kAuthorizationEnvironmentUsername) else {
            return nil
        }
        guard
            let s = NSString.init(
                bytes: data.bytes,
                length: data.length,
                encoding: String.Encoding.utf8.rawValue)
        else { return nil }
        return s.replacingOccurrences(of: "\0", with: "") as NSString
    }

    var password: NSString? {
        os_log("Requesting password…", log: BBMechanism.log, type: .default)
        guard let data = getContextData(key: kAuthorizationEnvironmentPassword) else {
            return nil
        }
        guard
            let s = NSString.init(
                bytes: data.bytes,
                length: data.length,
                encoding: String.Encoding.utf8.rawValue)
        else { return nil }
        return s.replacingOccurrences(of: "\0", with: "") as NSString
    }

    // Get MDM Server FQDN and port:
    func getMDMServerDetails() -> (fqdn: String, port: UInt16)? {
        os_log("Getting MDM server details…", log: BBMechanism.log, type: .default)
        let task = Process()
        task.launchPath = "/usr/libexec/mdmclient"
        task.arguments = ["DumpManagementStatus"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()

            let exitStatus = task.terminationStatus
            if exitStatus != 0 {
                os_log("ERROR: mdmclient failed with non-zero exit status: %d", log: BBMechanism.log, type: .error, exitStatus)
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            guard let output: String = String(data: data, encoding: String.Encoding.utf8) else {
                os_log("Unable to decode output.", log: BBMechanism.log, type: .error)
                return nil
            }

            let regex = try NSRegularExpression(pattern: #"ServerURL = "(https?://[^"]+)""#, options: [])
            guard let match = regex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) else {
                os_log("ServerURL not found.", log: BBMechanism.log, type: .error)
                return nil
            }

            guard let matchRange = Range(match.range(at: 1), in: output) else {
                os_log("Invalid regex match, crashing prevented.", log: BBMechanism.log, type: .error)
                return nil
            }

            let urlString = String(output[matchRange])
            os_log("Extracted ServerURL: %{public}@", log: BBMechanism.log, type: .debug, urlString)

            if let urlComponents = URLComponents(string: urlString), let host = urlComponents.host {
                let port = urlComponents.port ?? 443
                os_log("Parsed FQDN: %{public}@, Port: %d", log: BBMechanism.log, type: .debug, host, port)
                return (fqdn: host, port: UInt16(port))
            } else {
                os_log("Failed to parse URL components.", log: BBMechanism.log, type: .error)
            }
        } catch {
            os_log("ERROR: %{public}@", log: BBMechanism.log, type: .error, error.localizedDescription)
        }
        return nil
    }

    // Function to check if the FQDN is reachable on the given port with detailed logging
    func checkMDMReachability(fqdn: String, port: UInt16) -> (Bool) {
        os_log("Checking reachability of %{public}@ on port %{public}@…", log: BBMechanism.log,
               type: .default, String(fqdn), String(port))
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            os_log("Invalid port number: %{public}@", log: BBMechanism.log, type: .error, String(port))
            return false
        }
        let connection = NWConnection(host: NWEndpoint.Host(fqdn), port: nwPort, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "com.inetum.Bootstrap-Buddy.checkMDM")
        var isReachable = false
        connection.stateUpdateHandler = { state in
            queue.sync {
                switch state {
                case .setup:
                    os_log("Connection setup initiated…", log: BBMechanism.log, type: .debug)
                case .waiting(let reason):
                    os_log("Connection waiting: %{public}@", log: BBMechanism.log, type: .debug, reason.localizedDescription)
                case .preparing:
                    os_log("Preparing connection…", log: BBMechanism.log, type: .debug)
                case .ready:
                    os_log("Connection successful!", log: BBMechanism.log, type: .default)
                    isReachable = true
                    semaphore.signal()
                case .failed(let error):
                    os_log("Connection failed: %{public}@", log: BBMechanism.log, type: .error, error.localizedDescription)
                    semaphore.signal()
                case .cancelled:
                    os_log("Connection was cancelled.", log: BBMechanism.log, type: .debug)
                default:
                    os_log("Unexpected connection state: %{public}@", log: BBMechanism.log, type: .error, state as! CVarArg)
                }
            }
        }
        connection.start(queue: .global())
        // Wait up to 5 seconds for a response:
        let timeout = DispatchTime.now() + 5
        if semaphore.wait(timeout: timeout) == .timedOut {
            os_log("Timeout: No response received in 5 seconds.", log: BBMechanism.log, type: .error)
            connection.cancel()
            return false
        }
        connection.cancel()
        return isReachable
    }

    // Check Bootstrap Token status, whether it's supported and escrowed:
    func getBootstrapStatus() -> (supported: Bool, escrowed: Bool) {
        os_log("Getting Bootstrap Token status…", log: BBMechanism.log, type: .default)
        let task = Process()
        task.launchPath = "/usr/bin/profiles"
        task.arguments = ["status", "-type", "bootstraptoken"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output: String = String(data: data, encoding: String.Encoding.utf8)
        else { return (false, false) }
        if (output.range(of: "Bootstrap Token supported on server: YES")) != nil {
            if (output.range(of: "Bootstrap Token escrowed to server: YES")) != nil {
                os_log("Bootstrap Token already escrowed.", log: BBMechanism.log, type: .default)
                return (true, true)
            } else {
                os_log("Bootstrap Token supported, but not escrowed.", log: BBMechanism.log, type: .default)
                return (true, false)
            }
        } else {
            os_log("Bootstrap Token is not supported.", log: BBMechanism.log, type: .error)
            return (false, false)
        }
    }

    // Check Bootstrap Token validity:
    func checkBootstrapValidity() -> (Bool) {
        os_log("Checking Bootstrap Token validity…", log: BBMechanism.log, type: .default)
        let task = Process()
        task.launchPath = "/usr/libexec/mdmclient"
        task.arguments = ["QueryDeviceInformation"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output: String = String(data: data, encoding: String.Encoding.utf8)
        else { return false }
        if (output.range(of: "EACSPreflight = success")) != nil {
            os_log("Bootstrap Token is valid.", log: BBMechanism.log, type: .default)
            return true
        } else {
            os_log("Bootstrap Token is NOT valid.", log: BBMechanism.log, type: .error)
            return false
        }
    }

    // Check if user at login window is and admin:
    func checkAdminStatus(username: String) -> (Bool) {
        os_log("Checking if user \"%{public}@\" is an admin…", log: BBMechanism.log, type: .default, username)
        let task = Process()
        task.launchPath = "/usr/bin/dscl"
        task.arguments = [".", "read", "/Groups/admin", "GroupMembership"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output: String = String(data: data, encoding: String.Encoding.utf8)
        else { return false }
        // Check if the username is in the output:
        os_log("dscl output: %{public}@", log: BBMechanism.log, type: .debug, output)
        os_log("Admin Status: %{public}@", log: BBMechanism.log, type: .debug, output.contains(username).description)
        return output.contains(username)
    }

    // Elevate user to admin
    func elevateUser(username: String) throws {
        os_log("Temporarily adding user \"%{public}@\" to admin group…", log: BBMechanism.log, type: .default, username)
        let task = Process()
        task.launchPath = "/usr/bin/dscl"
        task.arguments = [".", "append", "/Groups/admin", "GroupMembership", username]
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let termstatus = String(describing: task.terminationStatus)
            os_log(
                "User elevation failed with a non-zero exit status: %{public}@",
                log: BBMechanism.log, type: .error, termstatus)
        }
        os_log("User \"%{public}@\" elevated to admin.", log: BBMechanism.log, type: .default, username)
    }

    // Demote user to standard
    func demoteUser(username: String) throws {
        os_log("Removing user \"%{public}@\" from admin group…", log: BBMechanism.log, type: .default, username)
        let task = Process()
        task.launchPath = "/usr/bin/dscl"
        task.arguments = [".", "delete", "/Groups/admin", "GroupMembership", username]
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let termstatus = String(describing: task.terminationStatus)
            os_log(
                "User demotion failed with a non-zero exit status: %{public}@",
                log: BBMechanism.log, type: .error, termstatus)
        }
        os_log("User \"%{public}@\" demoted to standard.", log: BBMechanism.log, type: .default, username)
    }
}

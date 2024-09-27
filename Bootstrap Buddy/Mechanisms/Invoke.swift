//
//  Invoke.swift
//  Bootstrap Buddy
//
//  Copyright 2024 Inetum
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

import CoreFoundation
import Foundation
import Security
import os.log

class Invoke: BBMechanism {
    // Log for the Invoke functions
    private static let log = OSLog(subsystem: "com.inetum.Bootstrap-Buddy", category: "Invoke")

    // Preference bundle id
    fileprivate let bundleid = "com.inetum.Bootstrap-Buddy"

    @objc func run() {
        os_log("Starting Bootstrap Buddy:Invoke", log: Invoke.log, type: .default)

        // Get Bootstrap Token status
        let bootstrapstatus = getBootstrapStatus()
        let btSupported: Bool = bootstrapstatus.supported
        let btEscrowed: Bool = bootstrapstatus.escrowed
        
        // Get Bootstrap Token validity
        let bootstrapvalid: Bool = checkBootstrapValidity()

        // No action needed if Bootstrap token is escrowed or not supported
        if !btSupported {
            allowLogin()
            return
        }
        if btEscrowed {
            if bootstrapvalid {
                os_log("Bootstrap Token is escrowed and valid.", log: Invoke.log, type: .default)
                allowLogin()
                return
            } else {
                os_log("Bootstrap Token is escrowed, but invalid.", log: Invoke.log, type: .default)
            }
        }

        // Instantiate dictionary with credentials
        guard let username = self.username
        else {
            os_log("Unable to instantiate username.", log: Invoke.log, type: .error)
            allowLogin()
            return
        }
        guard let password = self.password
        else {
            os_log("Unable to instantiate password.", log: Invoke.log, type: .error)
            allowLogin()
            return
        }

        // EscrowBootstrapToken is True, call profiles to escrow Bootstrap Token
        os_log("Escrowing Bootstrap Token…", log: Invoke.log, type: .default)
        do {
            try _ = escrowBootstrapToken(theUsername: username as String, thePassword: password as String)
        } catch let error as NSError {
            os_log(
                "Caught error trying to escrow the token: %{public}@", log: Invoke.log,
                type: .error,
                error.localizedDescription)
        }

        allowLogin()
        return
    }

    // profiles Errors
    enum ProfilesError: Error {
        case profilesFailed(retCode: Int32)
        case outputPlistNull
        case outputPlistMalformed
    }

    func escrowBootstrapToken(theUsername: String, thePassword: String) throws -> Bool {
        os_log("escrowBootstrapToken called", log: Invoke.log, type: .default)

        let inPipe = Pipe.init()
        let outPipe = Pipe.init()
        let errorPipe = Pipe.init()

        os_log("Running profiles command for user %{public}@", log: Invoke.log, type: .debug, theUsername)

        let task = Process.init()
        task.launchPath = "/usr/bin/profiles"
        task.arguments = ["install", "-type", "bootstraptoken", "-user", theUsername, "-password", thePassword]
        task.standardInput = inPipe
        task.standardOutput = outPipe
        task.standardError = errorPipe
        task.launch()
        task.waitUntilExit()

        let errorOut = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorOut, encoding: .utf8)
        errorPipe.fileHandleForReading.closeFile()

        if task.terminationStatus != 0 {
            let termstatus = String(describing: task.terminationStatus)
            os_log(
                "ERROR: profiles command terminated with a non-zero exit status: %{public}@",
                log: Invoke.log, type: .error, termstatus)
            os_log(
                "profiles Standard Error: %{public}@", log: Invoke.log, type: .error,
                String(describing: errorMessage))
            throw ProfilesError.profilesFailed(retCode: task.terminationStatus)
        }
        os_log("escrowBootstrapToken succeeded", log: Invoke.log, type: .default)
        return true
    }
}

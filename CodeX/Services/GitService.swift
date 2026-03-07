import Foundation

class GitService {
    func current_branch(at url: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = url
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ Git rev-parse success: \(output ?? "nil") (Path: \(url.path))")
                return (output?.isEmpty == false) ? output : nil
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                print("❌ Git rev-parse failed (Code \(process.terminationStatus)): \(errorMessage ?? "nil") (Path: \(url.path))")
                return nil
            }
        } catch {
            print("GitService error: \(error)")
            return nil
        }
    }
    
    func get_branches(at url: URL) -> [GitBranch] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        // Liệt kê branch kèm tên Author và thời gian commit dạng relative
        process.arguments = ["branch", "--format=%(refname:short)|%(authorname)|%(committerdate:relative)"] 
        process.currentDirectoryURL = url
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                
                return lines.compactMap { line in
                    guard !line.isEmpty else { return nil }
                    let components = line.components(separatedBy: "|")
                    let name = components.count > 0 ? components[0] : line
                    let author = components.count > 1 ? components[1] : "Unknown"
                    let date = components.count > 2 ? components[2] : "Unknown date"
                    
                    return GitBranch(name: name, author: author, lastCommitDate: date)
                }
            }
        } catch {
            print("GitService get_branches error: \(error)")
        }
        return []
    }

    func file_statuses(at url: URL) -> [URL: GitFileStatus] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain=v1", "-z"]
        process.currentDirectoryURL = url

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return [:]
            }

            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return [:]
            }

            let records = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
            var statuses: [URL: GitFileStatus] = [:]
            var index = 0

            while index < records.count {
                let record = records[index]
                guard record.count >= 3 else {
                    index += 1
                    continue
                }

                let statusCharacters = Array(record.prefix(2))
                guard statusCharacters.count == 2 else {
                    index += 1
                    continue
                }

                let indexStatus = statusCharacters[0]
                let workTreeStatus = statusCharacters[1]
                guard let status = GitFileStatus.from(indexStatus: indexStatus, workTreeStatus: workTreeStatus) else {
                    index += 1
                    continue
                }

                let start = record.index(record.startIndex, offsetBy: 3)
                var targetPath = String(record[start...])

                let isRenameOrCopy = indexStatus == "R" || workTreeStatus == "R" || indexStatus == "C" || workTreeStatus == "C"
                if isRenameOrCopy, index + 1 < records.count {
                    targetPath = records[index + 1]
                    index += 1
                }

                let fileURL = url.appendingPathComponent(targetPath).standardizedFileURL
                statuses[fileURL] = status
                index += 1
            }

            return statuses
        } catch {
            print("GitService file_statuses error: \(error)")
            return [:]
        }
    }
        
        func checkout_branch(at url: URL, branch: String) -> Bool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["checkout", branch]
            process.currentDirectoryURL = url
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    print("✅ Git checkout \(branch) success")
                    return true
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                    print("❌ Git checkout \(branch) failed: \(errorMessage)")
                    return false
                }
            } catch {
                print("GitService checkout error: \(error)")
                return false
            }
        }
        
        func rename_branch(at url: URL, oldName: String, newName: String) -> Bool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["branch", "-m", oldName, newName]
            process.currentDirectoryURL = url
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    print("✅ Git rename branch from \(oldName) to \(newName) success")
                    return true
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                    print("❌ Git rename failed: \(errorMessage)")
                    return false
                }
            } catch {
                print("GitService rename error: \(error)")
                return false
            }
        }
        
        func create_branch(at url: URL, from baseBranch: String, newName: String) -> Bool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            // switch sang nhánh gốc trước rồi mới branch ra để đảm bảo an toàn
            process.arguments = ["checkout", "-b", newName, baseBranch]
            process.currentDirectoryURL = url
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    print("✅ Git create new branch \(newName) from \(baseBranch) success")
                    return true
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                    print("❌ Git create branch failed: \(errorMessage)")
                    return false
                }
            } catch {
                print("GitService create branch error: \(error)")
                return false
            }
        }
}

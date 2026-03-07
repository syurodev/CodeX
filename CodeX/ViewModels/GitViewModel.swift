    import Foundation
import SwiftUI

struct GitBranch: Hashable {
    let name: String
    let author: String
    let lastCommitDate: String
}

@Observable
class GitViewModel {
    var current_branch: String = "—"
    var is_git_repo: Bool = false
    var branches: [GitBranch] = []
    
    var search_text: String = ""
    var is_popover_presented: Bool = false
    
    // Alert variables
    var isShowingRenameAlert: Bool = false
    var isShowingNewBranchAlert: Bool = false
    var branchNameInput: String = ""
    var targetBranchForAction: String = ""
    
    var filtered_branches: [GitBranch] {
        if search_text.isEmpty {
            return branches
        }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(search_text) }
    }
    
    func load(url: URL, using service: GitService) {
        Task.detached(priority: .userInitiated) {
            let branch = service.current_branch(at: url)
            let branches = branch != nil ? service.get_branches(at: url) : [GitBranch]()
            await MainActor.run {
                if let branch = branch {
                    self.current_branch = branch
                    self.is_git_repo = true
                    self.branches = branches
                } else {
                    self.current_branch = "—"
                    self.is_git_repo = false
                    self.branches = []
                }
            }
        }
    }

    func checkout(branch: String, url: URL, using service: GitService, onSuccess: (() -> Void)? = nil) {
        Task.detached(priority: .userInitiated) {
            if service.checkout_branch(at: url, branch: branch) {
                await MainActor.run {
                    self.load(url: url, using: service)
                    onSuccess?()
                }
            }
        }
    }

    func rename_branch(oldName: String, newName: String, url: URL, using service: GitService, onSuccess: (() -> Void)? = nil) {
        Task.detached(priority: .userInitiated) {
            if service.rename_branch(at: url, oldName: oldName, newName: newName) {
                await MainActor.run {
                    self.load(url: url, using: service)
                    if self.current_branch == oldName {
                        self.current_branch = newName
                    }
                    onSuccess?()
                }
            }
        }
    }

    func create_branch(from baseBranch: String, newName: String, url: URL, using service: GitService, onSuccess: (() -> Void)? = nil) {
        Task.detached(priority: .userInitiated) {
            if service.create_branch(at: url, from: baseBranch, newName: newName) {
                await MainActor.run {
                    self.load(url: url, using: service)
                    self.current_branch = newName
                    onSuccess?()
                }
            }
        }
    }
}

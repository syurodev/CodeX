import SwiftUI

struct BranchPopoverView: View {
    @Bindable var appViewModel: AppViewModel
    
    // Tắt popover khi chọn xong
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Thanh Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Find", text: $appViewModel.gitViewModel.search_text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // Danh sách Branch
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Branches")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(appViewModel.gitViewModel.filtered_branches, id: \.self) { branch in
                        Button(action: {
                            appViewModel.switch_branch(branch.name)
                            dismiss()
                        }) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(appViewModel.projectName)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(branch.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text(branch.author)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text("committed \(branch.lastCommitDate)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Menu Rename/New Branch
                                Menu {
                                    Button("Rename \"\(branch.name)\"...") {
                                        appViewModel.gitViewModel.targetBranchForAction = branch.name
                                        appViewModel.gitViewModel.branchNameInput = branch.name
                                        appViewModel.gitViewModel.isShowingRenameAlert = true
                                    }
                                    Button("New Branch from \"\(branch.name)\"...") {
                                        appViewModel.gitViewModel.targetBranchForAction = branch.name
                                        appViewModel.gitViewModel.branchNameInput = "" // Clear text for new branch
                                        appViewModel.gitViewModel.isShowingNewBranchAlert = true
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .menuStyle(.borderlessButton)
                                .buttonStyle(.plain)
                                .opacity(0.6) // Hơi mờ để không quá nổi bật
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: {}) {
                            Text("Create Workflow...")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        
                        Button(action: {}) {
                            Text("Manage Workflows...")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxHeight: 400) // Cho phép co giãn tự nhiên nhưng cao tối đa 400
        }
        .frame(width: 320)
        .padding(.bottom, 8) 
    }
}

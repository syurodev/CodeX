import SwiftUI

struct NewBranchSheetView: View {
    @Bindable var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create new branch in \"\(appViewModel.projectName)\":")
                .font(.system(size: 13, weight: .bold))
            
            Text("Create a branch from the current branch and switch to it. All uncommitted changes will be preserved on the new branch.")
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("From:")
                        .font(.system(size: 13))
                        .frame(width: 40, alignment: .trailing)
                    Text(appViewModel.gitViewModel.targetBranchForAction)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    Text("To:")
                        .font(.system(size: 13))
                        .frame(width: 40, alignment: .trailing)
                    TextField("", text: $appViewModel.gitViewModel.branchNameInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 8)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create") {
                    let baseName = appViewModel.gitViewModel.targetBranchForAction
                    let newName = appViewModel.gitViewModel.branchNameInput.trimmingCharacters(in: .whitespaces)
                    if !newName.isEmpty {
                        appViewModel.create_branch(from: baseName, newName: newName)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appViewModel.gitViewModel.branchNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

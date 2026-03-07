import SwiftUI

struct SidebarToolbarView: View {
    @Bindable var viewModel: AppViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.selectedSidebarTab = tab
                    } label: {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 30, height: 26)
                            .background(
                                viewModel.selectedSidebarTab == tab ? Color.accentColor : Color.clear
                            )
                            .foregroundColor(
                                viewModel.selectedSidebarTab == tab ? .white : .secondary
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    if tab != SidebarTab.allCases.last {
                        Divider()
                            .frame(height: 14)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}

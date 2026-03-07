# CodeX Project Structure

Tài liệu này mô tả nhanh cấu trúc thư mục và vai trò từng phần trong project `CodeX`.

## 1) Tổng quan

Project được tổ chức theo hướng SwiftUI + MVVM:

- `App`: Điểm khởi chạy ứng dụng.
- `Models`: Các kiểu dữ liệu lõi (domain/state).
- `Services`: Tầng xử lý I/O, Git, LSP, lint/format.
- `ViewModels`: Logic điều phối state cho UI.
- `Views`: Giao diện theo từng khu vực chức năng.
- `Tests`: Unit tests và UI tests.

## 2) Cấu trúc chi tiết

### `CodeX/CodeX/App`

- `CodeXApp.swift`: Entry point (`@main`), khởi tạo `AppViewModel`, cấu hình `WindowGroup`, command menu và shutdown logic.

### `CodeX/CodeX/Extensions`

- `Color+CodeX.swift`: Mở rộng màu dùng trong app.
- `NSFont+CodeX.swift`: Mở rộng font cho AppKit/SwiftUI bridge.
- `String+Extensions.swift`: Các helper xử lý chuỗi.

### `CodeX/CodeX/Models`

- `AgentProvider.swift`: Định nghĩa provider cho Agent runtime.
- `EditorDocument.swift`: Model tài liệu đang mở trong editor.
- `EditorSettings.swift`: Cấu hình editor (font, minimap, wrapping...).
- `FileIcon.swift`: Mapping icon theo loại file.
- `FileNode.swift`: Node cây thư mục/file navigator.
- `GitFileStatus.swift`: Trạng thái file theo Git.
- `LSPModels.swift`: Các model liên quan LSP.
- `Project.swift`: Metadata project đang mở.
- `SidebarTab.swift`: Enum tab sidebar.

### `CodeX/CodeX/Resources`

- `biome`: Binary/resource phục vụ lint/format JS/TS.
- `deno`: Binary/resource phục vụ Deno LSP.

### `CodeX/CodeX/Services`

- `BiomeService.swift`: Chạy Biome lint/format.
- `FileSystemService.swift`: Đọc file, build file tree, detect language.
- `GitService.swift`: Gọi Git CLI (branch, checkout, status...).
- `LanguageClientService.swift`: JSON-RPC client cho LSP.
- `LSPManager.swift`: Quản lý vòng đời các process LSP.

### `CodeX/CodeX/Theme`

- `CodeXTheme.swift`: Theme editor/UI.

### `CodeX/CodeX/ViewModels`

- `AgentPanelViewModel.swift`: Quản lý danh sách runtime Agent và launcher state.
- `AgentRuntimeViewModel.swift`: Quản lý vòng đời 1 runtime ACP, stream message/activity.
- `AppViewModel.swift`: ViewModel trung tâm điều phối project/editor/git/agent.
- `EditorViewModel.swift`: Quản lý tab editor, LSP integration, completion, jump-to-definition.
- `FileNavigatorViewModel.swift`: Quản lý cây file và trạng thái expand/select.
- `GitViewModel.swift`: State hiển thị Git branch/popover và thao tác branch.

### `CodeX/CodeX/Views`

- `Agent/AgentPanelView.swift`: UI panel Agent.
- `Editor/CodeEditorView.swift`: Vùng code editor.
- `Editor/EditorTabBarView.swift`: Tab bar cho tài liệu đang mở.
- `FileNavigator/FileNavigatorView.swift`: Khung file explorer.
- `FileNavigator/FileOutlineView.swift`: Outline/tree container.
- `FileNavigator/FileTreeRowView.swift`: Row hiển thị từng node file.
- `MainWindow/MainWindowView.swift`: Layout cửa sổ chính.
- `MainWindow/WindowTitlebarAccessory.swift`: Thành phần titlebar accessory.
- `Sidebar/SidebarToolbarView.swift`: Toolbar trong sidebar.
- `StatusBar/StatusBarView.swift`: Thanh trạng thái editor.
- `Toolbar/BranchPopoverView.swift`: Popover branch Git.
- `Toolbar/NewBranchSheetView.swift`: Sheet tạo branch mới.
- `Toolbar/ToolbarView.swift`: Thành phần toolbar chung.

### `CodeX/CodeX/Assets.xcassets`

- Asset catalog (icons, colors, images).

### `CodeX/CodeXTests`

- `AgentPanelViewModelTests.swift`: Test chính cho luồng Agent runtime/panel.
- `CodeXTests.swift`: Các unit test lõi khác.

### `CodeX/CodeXUITests`

- `CodeXUITests.swift`: UI test behavior chính.
- `CodeXUITestsLaunchTests.swift`: UI test cho launch flow.

### `CodeX/Products`

- Artifact build output (`.app`, `.xctest`).

## 3) Luồng dữ liệu chính

1. `CodeXApp` tạo `AppViewModel`.
2. `MainWindowView` nhận state qua `.environment(appViewModel)`.
3. User action tại `Views` gọi `ViewModels`.
4. `ViewModels` gọi `Services` để thao tác filesystem/git/lsp/biome.
5. Kết quả trả về cập nhật state observable và render lại UI.

## 4) Gợi ý mở rộng tài liệu

- Thêm sơ đồ dependency giữa `AppViewModel` và các ViewModel con.
- Thêm sequence cho luồng `Open Project -> Open File -> LSP didOpen`.
- Thêm guideline naming/concurrency/error handling cho contributor mới.

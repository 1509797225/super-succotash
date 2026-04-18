import SwiftUI

private struct AppThemeModeKey: EnvironmentKey {
    static let defaultValue: AppThemeMode = .blackWhite
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appThemeMode: AppThemeMode {
        get { self[AppThemeModeKey.self] }
        set { self[AppThemeModeKey.self] = newValue }
    }

    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

enum L10n {
    static func t(_ key: Key, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return key.english
        case .chinese:
            return key.chinese
        }
    }

    enum Key {
        case add
        case addItem
        case appIcon
        case appearance
        case about
        case bigJelly
        case breakTime
        case cancel
        case closeSettingsMenu
        case completed
        case confirm
        case dailyDuration
        case dailyGoal
        case delete
        case designConcept
        case discard
        case edit
        case editProfile
        case editTask
        case enterTaskTitle
        case exit
        case focus
        case focusPlans
        case focusTime
        case focused
        case focusing
        case goalRate
        case haptics
        case huge
        case immersive
        case language
        case largeText
        case linkedTask
        case minDay
        case newItem
        case newPlan
        case newTask
        case noFocusDataToday
        case noPomodoroData
        case noPomodoroGuide
        case noPlansYet
        case pause
        case openSettingsMenu
        case paused
        case plan
        case plusDescription
        case pomodoroGoal
        case pomodoroStats
        case preferences
        case portrait
        case profile
        case ready
        case reset
        case resume
        case running
        case rotate
        case save
        case set
        case settings
        case small
        case start
        case startFocus
        case stats
        case stop
        case today
        case todayFocusChart
        case todayIsClear
        case todaySwipeAction
        case timer
        case timerDirection
        case taskCycle
        case taskDeleted
        case tapUnit
        case theme
        case version

        var english: String {
            switch self {
            case .add: return "Add"
            case .addItem: return "Add Item"
            case .appIcon: return "App Icon"
            case .appearance: return "Appearance"
            case .about: return "About"
            case .bigJelly: return "Big Jelly"
            case .breakTime: return "Break Time"
            case .cancel: return "Cancel"
            case .closeSettingsMenu: return "Close settings menu"
            case .completed: return "Completed"
            case .confirm: return "Confirm"
            case .dailyDuration: return "Daily Duration"
            case .dailyGoal: return "Daily Goal"
            case .delete: return "Delete"
            case .designConcept: return "Design"
            case .discard: return "Discard"
            case .edit: return "Edit"
            case .editProfile: return "Edit Profile"
            case .editTask: return "Edit Task"
            case .enterTaskTitle: return "Enter task title"
            case .exit: return "Exit"
            case .focus: return "Focus"
            case .focusPlans: return "Focus Plans"
            case .focusTime: return "Focus Time"
            case .focused: return "Focused"
            case .focusing: return "Focusing"
            case .goalRate: return "Goal Rate"
            case .haptics: return "Haptics"
            case .huge: return "Huge"
            case .immersive: return "Immersive"
            case .language: return "Language"
            case .largeText: return "Large Text"
            case .linkedTask: return "Linked task"
            case .minDay: return "min / day"
            case .newItem: return "New Item"
            case .newPlan: return "New Plan"
            case .newTask: return "New Task"
            case .noFocusDataToday: return "No focus data today"
            case .noPomodoroData: return "No pomodoro data"
            case .noPomodoroGuide: return "Complete a focus session to see stats"
            case .noPlansYet: return "No plans yet"
            case .pause: return "Pause"
            case .openSettingsMenu: return "Open settings menu"
            case .paused: return "Paused"
            case .plan: return "Plan"
            case .plusDescription: return "Unlock focus plans and stats"
            case .pomodoroGoal: return "Pomodoro Goal"
            case .pomodoroStats: return "Pomodoro Stats"
            case .preferences: return "Preferences"
            case .portrait: return "Portrait"
            case .profile: return "Profile"
            case .ready: return "Ready"
            case .reset: return "Reset"
            case .resume: return "Resume"
            case .running: return "Running"
            case .rotate: return "Rotate"
            case .save: return "Save"
            case .set: return "Set"
            case .settings: return "Settings"
            case .small: return "Small"
            case .start: return "Start"
            case .startFocus: return "Start Focus"
            case .stats: return "Stats"
            case .stop: return "Stop"
            case .today: return "Today"
            case .todayFocusChart: return "Today focus chart"
            case .todayIsClear: return "Today is clear"
            case .todaySwipeAction: return "Today"
            case .timer: return "Timer"
            case .timerDirection: return "Timer Direction"
            case .taskCycle: return "Task Cycle"
            case .taskDeleted: return "Task deleted"
            case .tapUnit: return "tap unit"
            case .theme: return "Theme"
            case .version: return "Version"
            }
        }

        var chinese: String {
            switch self {
            case .add: return "添加"
            case .addItem: return "添加事项"
            case .appIcon: return "应用图标"
            case .appearance: return "外观"
            case .about: return "关于"
            case .bigJelly: return "大果冻"
            case .breakTime: return "休息时长"
            case .cancel: return "取消"
            case .closeSettingsMenu: return "关闭设置菜单"
            case .completed: return "已完成"
            case .confirm: return "确认"
            case .dailyDuration: return "每天时长"
            case .dailyGoal: return "每日目标"
            case .delete: return "删除"
            case .designConcept: return "设计理念"
            case .discard: return "丢弃"
            case .edit: return "编辑"
            case .editProfile: return "编辑资料"
            case .editTask: return "编辑任务"
            case .enterTaskTitle: return "输入任务标题"
            case .exit: return "退出"
            case .focus: return "专注"
            case .focusPlans: return "专注计划"
            case .focusTime: return "专注时长"
            case .focused: return "已专注"
            case .focusing: return "专注中"
            case .goalRate: return "目标达成"
            case .haptics: return "触觉反馈"
            case .huge: return "放大"
            case .immersive: return "沉浸式"
            case .language: return "语言"
            case .largeText: return "大字体"
            case .linkedTask: return "关联任务"
            case .minDay: return "分钟/天"
            case .newItem: return "新事项"
            case .newPlan: return "新计划"
            case .newTask: return "新任务"
            case .noFocusDataToday: return "今日暂无专注数据"
            case .noPomodoroData: return "暂无番茄数据"
            case .noPomodoroGuide: return "完成一次专注后查看统计"
            case .noPlansYet: return "还没有计划"
            case .pause: return "暂停"
            case .openSettingsMenu: return "打开设置菜单"
            case .paused: return "已暂停"
            case .plan: return "计划"
            case .plusDescription: return "解锁专注计划和统计玩法"
            case .pomodoroGoal: return "番茄目标"
            case .pomodoroStats: return "番茄统计"
            case .preferences: return "基础设置"
            case .portrait: return "竖屏"
            case .profile: return "个人主页"
            case .ready: return "准备中"
            case .reset: return "重置"
            case .resume: return "继续"
            case .running: return "运行中"
            case .rotate: return "旋转"
            case .save: return "保存"
            case .set: return "设置"
            case .settings: return "设置"
            case .small: return "缩小"
            case .start: return "开始"
            case .startFocus: return "开始专注"
            case .stats: return "统计"
            case .stop: return "停止"
            case .today: return "今日"
            case .todayFocusChart: return "今日专注图表"
            case .todayIsClear: return "今日很清爽"
            case .todaySwipeAction: return "加入今日"
            case .timer: return "计时器"
            case .timerDirection: return "计时方向"
            case .taskCycle: return "任务周期"
            case .taskDeleted: return "任务已删除"
            case .tapUnit: return "点按切换"
            case .theme: return "主题"
            case .version: return "版本"
            }
        }
    }
}

enum ThemeTokens {
    struct Palette {
        let background: Color
        let card: Color
        let accent: Color
        let accentSoft: Color
    }

    enum Colors {
        static let backgroundPrimary = Color(hex: "#FFFFFF")
        static let backgroundSoft = Color(hex: "#F7F7F8")
        static let card = Color(hex: "#F5F5F7")
        static let textPrimary = Color(hex: "#333333")
        static let textSecondary = Color(hex: "#888888")
        static let subtleLine = Color(hex: "#E9E9EC")
    }

    enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 20
        static let cardHeight: CGFloat = 100
        static let controlHeight: CGFloat = 60
        static let cornerRadius: CGFloat = 32
    }

    enum Typography {
        static let pageTitle = Font.system(size: 40, weight: .bold, design: .rounded)
        static let largeStat = Font.system(size: 32, weight: .bold, design: .rounded)
        static let taskTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 24, weight: .bold, design: .rounded)
        static let tabLabel = Font.system(size: 20, weight: .bold, design: .rounded)
        static let body = Font.system(size: 20, weight: .bold, design: .rounded)
        static let caption = Font.system(size: 18, weight: .bold, design: .rounded)
    }

    static func background(for mode: AppThemeMode) -> Color {
        palette(for: mode).background
    }

    static func card(for mode: AppThemeMode) -> Color {
        palette(for: mode).card
    }

    static func accent(for mode: AppThemeMode) -> Color {
        palette(for: mode).accent
    }

    static func accentSoft(for mode: AppThemeMode) -> Color {
        palette(for: mode).accentSoft
    }

    static func palette(for mode: AppThemeMode) -> Palette {
        switch mode {
        case .pink:
            return Palette(
                background: Color(hex: "#FFF8FA"),
                card: Color(hex: "#FFF0F4"),
                accent: Color(hex: "#F58BA8"),
                accentSoft: Color(hex: "#FFDDE7")
            )
        case .blackWhite:
            return Palette(
                background: Colors.backgroundPrimary,
                card: Colors.card,
                accent: Colors.textPrimary,
                accentSoft: Colors.subtleLine
            )
        case .blue:
            return Palette(
                background: Color(hex: "#F7FBFF"),
                card: Color(hex: "#EEF6FF"),
                accent: Color(hex: "#78AEEA"),
                accentSoft: Color(hex: "#DCEEFF")
            )
        case .green:
            return Palette(
                background: Color(hex: "#F8FFF9"),
                card: Color(hex: "#EEFAF1"),
                accent: Color(hex: "#7BCB91"),
                accentSoft: Color(hex: "#DDF5E4")
            )
        case .rainbow:
            return Palette(
                background: Color(hex: "#FFFDF7"),
                card: Color(hex: "#FFF7EE"),
                accent: Color(hex: "#FF8A5B"),
                accentSoft: Color(hex: "#FFE8C7")
            )
        }
    }
}

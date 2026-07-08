import SwiftUI
import SwiftData
import UserNotifications

@main
struct LiftIQApp: App {
    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appTheme") private var appTheme = "dark"

    init() {
        do {
            container = try ModelContainer(
                for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
                TemplateFolder.self, Template.self, TemplateExercise.self,
                Split.self, SplitDay.self, BodyMeasurement.self, PersonalRecord.self
            )
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
        SeedImporter.importIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(colorScheme)
                .tint(Theme.accent)
                .environment(RestTimerService.shared)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SplitService.catchUp(context: container.mainContext)
                NotificationScheduler.rescheduleAll(context: container.mainContext)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "system": nil
        default: .dark // designed theme
        }
    }
}

// Shows rest-timer banner + sound while the app is foregrounded.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

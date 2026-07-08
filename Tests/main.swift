import Foundation

// Self-check for StreakEngine. Run from repo root (no Xcode needed):
//   swiftc -o /tmp/streak_check liftIQ/Services/StreakEngine.swift Tests/main.swift && /tmp/streak_check

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "UTC")!

func day(_ n: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 1, day: n))!
}

// PPL + Rest: orders 0,1,2 workouts; 3 rest.
let ppl: [StreakEngine.CycleDay] = [
    .init(order: 0, isRest: false),
    .init(order: 1, isRest: false),
    .init(order: 2, isRest: false),
    .init(order: 3, isRest: true),
]

// 1. Workouts on days 1-3, rest scheduled day 4, checking on day 5: streak = 4.
var s = StreakEngine.CycleState(currentIndex: 0, completedOrders: [],
                                lastAdvanceDate: day(1), streak: 0, longestStreak: 0)
for d in 1...3 {
    s = StreakEngine.catchUp(state: s, cycle: ppl, flexibleOrder: false,
                             workoutDays: Set((1..<d).map(day)), today: day(d), calendar: cal)
    s = StreakEngine.advance(state: s, cycle: ppl, flexibleOrder: false, templateOrder: d - 1)
}
assert(s.currentIndex == 3, "after 3 workouts cycle sits on rest day, got \(s.currentIndex)")
s = StreakEngine.catchUp(state: s, cycle: ppl, flexibleOrder: false,
                         workoutDays: Set([1, 2, 3].map(day)), today: day(5), calendar: cal)
assert(s.streak == 4, "3 workouts + kept rest day = 4, got \(s.streak)")
assert(s.currentIndex == 0, "rest day consumed, cycle wrapped, got \(s.currentIndex)")

// 2. Missing a scheduled workout day breaks the streak.
s = StreakEngine.catchUp(state: s, cycle: ppl, flexibleOrder: false,
                         workoutDays: Set([1, 2, 3].map(day)), today: day(7), calendar: cal)
assert(s.streak == 0, "missed scheduled workout days 5+6 break streak, got \(s.streak)")
assert(s.longestStreak == 4, "longest sticks at 4, got \(s.longestStreak)")

// 3. Today is pending — no break before midnight.
var t = StreakEngine.CycleState(currentIndex: 0, completedOrders: [],
                                lastAdvanceDate: day(10), streak: 7, longestStreak: 9)
t = StreakEngine.catchUp(state: t, cycle: ppl, flexibleOrder: false,
                         workoutDays: [], today: day(10), calendar: cal)
assert(t.streak == 7, "same-day catchUp changes nothing, got \(t.streak)")

// 4. Ad-hoc workout keeps streak but does not advance a strict cycle.
var a = StreakEngine.CycleState(currentIndex: 1, completedOrders: [],
                                lastAdvanceDate: day(10), streak: 0, longestStreak: 0)
a = StreakEngine.advance(state: a, cycle: ppl, flexibleOrder: false, templateOrder: nil)
assert(a.currentIndex == 1, "ad-hoc must not advance strict cycle")
a = StreakEngine.catchUp(state: a, cycle: ppl, flexibleOrder: false,
                         workoutDays: [day(10)], today: day(11), calendar: cal)
assert(a.streak == 1, "ad-hoc workout day still counts for streak")

// 5. Flexible order: any remaining template counts; rest is a free day; cycle wraps.
var f = StreakEngine.CycleState(currentIndex: 0, completedOrders: [],
                                lastAdvanceDate: day(1), streak: 0, longestStreak: 0)
f = StreakEngine.advance(state: f, cycle: ppl, flexibleOrder: true, templateOrder: 2) // legs first
assert(f.completedOrders == [2])
assert(StreakEngine.upToday(state: f, cycle: ppl, flexibleOrder: true)?.order == 0)
f = StreakEngine.advance(state: f, cycle: ppl, flexibleOrder: true, templateOrder: 2) // duplicate ignored
assert(f.completedOrders == [2])
f = StreakEngine.catchUp(state: f, cycle: ppl, flexibleOrder: true,
                         workoutDays: [day(1)], today: day(3), calendar: cal) // day 2 = no workout
assert(f.streak == 2, "workout + consumed flexible rest, got \(f.streak)")
assert(f.completedOrders.contains(3), "rest order consumed")
f = StreakEngine.catchUp(state: f, cycle: ppl, flexibleOrder: true,
                         workoutDays: [day(1)], today: day(4), calendar: cal) // no rest left
assert(f.streak == 0, "no remaining rest day -> break, got \(f.streak)")
for o in [0, 1] {
    f = StreakEngine.advance(state: f, cycle: ppl, flexibleOrder: true, templateOrder: o)
}
assert(f.completedOrders.isEmpty, "completing all orders wraps flexible cycle")

// 6. Weekly fallback streak.
// Goal 2/wk; workouts Mon+Wed this week and Mon+Wed last week -> 2.
let monThis = cal.date(from: DateComponents(year: 2026, month: 1, day: 19))! // Mon
let wedThis = cal.date(from: DateComponents(year: 2026, month: 1, day: 21))!
let monLast = cal.date(from: DateComponents(year: 2026, month: 1, day: 12))!
let wedLast = cal.date(from: DateComponents(year: 2026, month: 1, day: 14))!
let wk = StreakEngine.weeklyStreak(workoutDays: [monThis, wedThis, monLast, wedLast],
                                   goal: 2, today: wedThis, calendar: cal)
assert(wk == 2, "two consecutive goal-met weeks, got \(wk)")
// Current week not yet at goal is neutral, last week counts.
let wk2 = StreakEngine.weeklyStreak(workoutDays: [monThis, monLast, wedLast],
                                    goal: 2, today: monThis, calendar: cal)
assert(wk2 == 1, "incomplete current week is neutral, got \(wk2)")

print("StreakEngine self-check: all assertions passed")

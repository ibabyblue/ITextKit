# ITextKit Example API Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two long Example pages with separate SwiftUI and UIKit API-teaching catalogs containing live examples, complete copyable code, usage notes, and regression coverage for every meaningful public ITextKit capability.

**Architecture:** Keep the SwiftUI `TabView` root and use one iOS-15-compatible SwiftUI navigation stack for the SwiftUI catalog. The UIKit tab embeds one `UINavigationController`; all UIKit catalog and detail content after that boundary is UIKit. Share only presentation-neutral topic/snippet metadata, while each platform owns its catalog rows, teaching chrome, live examples, controls, and code blocks.

**Tech Stack:** Swift 5, SwiftUI, UIKit, XCTest/XCUITest, SwiftPM, XcodeGen, iOS 15+

## Global Constraints

- The deployment target remains iOS 15.0.
- Do not change or add ITextKit public API.
- Keep SwiftUI and UIKit live examples and teaching UI platform-native.
- Cover meaningful public uses without generating parameter permutations.
- Every live example includes complete code stored in the same source file.
- Code blocks use monospaced text, preserve indentation, scroll horizontally, and expose Copy plus `Copied` feedback.
- Styled text is visible in normal navigation; retain `-ITextStyledPerformance` as an isolated hidden launch path.
- Do not add dependencies, compatibility wrappers, timers, polling, fake VoiceOver/Reduce Motion switches, or production test seams.
- Use `apply_patch` for source and documentation edits; regenerate the Xcode project with `xcodegen generate` after source-tree changes.
- Run Example UI tests serially because the current simulator has previously produced noisy parallel runner failures.

## File Map

Create these platform-neutral files:

- `Example/ITextKitExample/Shared/DemoCapability.swift`: finite teaching tags.
- `Example/ITextKitExample/Shared/DemoTopic.swift`: the six topics, platform titles, summaries, and capabilities.
- `Example/ITextKitExample/Shared/DemoSnippet.swift`: stable snippet ID, title, summary, and complete code.

Create these SwiftUI catalog files:

- `Example/ITextKitExample/SwiftUI/Catalog/SwiftUICatalogView.swift`: six-topic list and navigation.
- `Example/ITextKitExample/SwiftUI/Catalog/SwiftUICatalogRow.swift`: title, summary, and tags.
- `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoPage.swift`: standard scroll/page structure.
- `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoSection.swift`: live example and explanation container.
- `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoCodeBlock.swift`: read-only code and pasteboard copy.
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUIStyledTextExamplesView.swift`
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUIRotatorExamplesView.swift`
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUIMarqueeExamplesView.swift`
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUITypewriterExamplesView.swift`
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUIShimmerExamplesView.swift`
- `Example/ITextKitExample/SwiftUI/Examples/SwiftUIEnvironmentExamplesView.swift`

Create these UIKit catalog files:

- `Example/ITextKitExample/UIKit/Catalog/UIKitCatalogViewController.swift`: native table catalog.
- `Example/ITextKitExample/UIKit/Catalog/UIKitCatalogCell.swift`: title, summary, and tags.
- `Example/ITextKitExample/UIKit/Components/UIKitDemoDetailViewController.swift`: scroll view and vertical content stack.
- `Example/ITextKitExample/UIKit/Components/UIKitDemoSectionView.swift`: live content, explanation, and snippet composition.
- `Example/ITextKitExample/UIKit/Components/UIKitDemoCodeView.swift`: noneditable code view and Copy action.
- `Example/ITextKitExample/UIKit/Examples/UIKitStyledTextExamplesViewController.swift`
- `Example/ITextKitExample/UIKit/Examples/UIKitRotatorExamplesViewController.swift`
- `Example/ITextKitExample/UIKit/Examples/UIKitMarqueeExamplesViewController.swift`
- `Example/ITextKitExample/UIKit/Examples/UIKitTypewriterExamplesViewController.swift`
- `Example/ITextKitExample/UIKit/Examples/UIKitShimmerExamplesViewController.swift`
- `Example/ITextKitExample/UIKit/Examples/UIKitEnvironmentExamplesViewController.swift`

Modify or remove:

- Modify `Example/ITextKitExample/ExampleRootView.swift` to route the two tabs to their catalogs.
- Modify `Example/ITextKitExample/UIKitExampleContainer.swift` to host one `UINavigationController`.
- Delete the superseded `SwiftUIExampleView.swift` and `UIKitExampleViewController.swift` only after all their regression coverage has moved.
- Retain `ITextKitExampleApp.swift` and `StyledTextPerformanceView.swift` except for imports/path adjustments required by XcodeGen.
- Replace the monolithic UI test file with focused test files under `Example/ITextKitExampleUITests`.
- Update `Example/README.md` and regenerate `Example/ITextKitExample.xcodeproj`.

---

### Task 1: Catalog Model, Platform Navigation, and Teaching Chrome

**Files:**
- Create: `Example/ITextKitExample/Shared/DemoCapability.swift`
- Create: `Example/ITextKitExample/Shared/DemoTopic.swift`
- Create: `Example/ITextKitExample/Shared/DemoSnippet.swift`
- Create: `Example/ITextKitExample/SwiftUI/Catalog/SwiftUICatalogView.swift`
- Create: `Example/ITextKitExample/SwiftUI/Catalog/SwiftUICatalogRow.swift`
- Create: `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoPage.swift`
- Create: `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoSection.swift`
- Create: `Example/ITextKitExample/SwiftUI/Components/SwiftUIDemoCodeBlock.swift`
- Create: `Example/ITextKitExample/UIKit/Catalog/UIKitCatalogViewController.swift`
- Create: `Example/ITextKitExample/UIKit/Catalog/UIKitCatalogCell.swift`
- Create: `Example/ITextKitExample/UIKit/Components/UIKitDemoDetailViewController.swift`
- Create: `Example/ITextKitExample/UIKit/Components/UIKitDemoSectionView.swift`
- Create: `Example/ITextKitExample/UIKit/Components/UIKitDemoCodeView.swift`
- Modify: `Example/ITextKitExample/ExampleRootView.swift`
- Modify: `Example/ITextKitExample/UIKitExampleContainer.swift`
- Create: `Example/ITextKitExampleUITests/ITextKitExampleUITestCase.swift`
- Create: `Example/ITextKitExampleUITests/CatalogUITests.swift`
- Create: `Example/ITextKitExampleUITests/PerformanceFixtureUITests.swift`
- Modify: `Example/ITextKitExampleUITests/ITextKitExampleUITests.swift`

**Interfaces:**
- Produces: `enum DemoCapability: String, CaseIterable`
- Produces: `enum DemoTopic: String, CaseIterable, Identifiable`
- Produces: `struct DemoSnippet: Identifiable` with `id`, `title`, `summary`,
  `capabilities`, and `code`
- Produces: `SwiftUICatalogView`, `UIKitCatalogViewController`, and platform teaching components consumed by Tasks 2-7.
- Preserves: `-ITextStyledPerformance` launch behavior and its 20-row UI assertion.

- [ ] **Step 1: Replace the old broad UI assertions with failing catalog tests**

Create the shared test base:

```swift
import XCTest

class ITextKitExampleUITestCase: XCTestCase {
    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func open(_ title: String, inUIKit: Bool = false) -> XCUIApplication {
        let app = launch()
        if inUIKit { app.tabBars.buttons["UIKit"].tap() }
        let entry = app.buttons[title]
        XCTAssertTrue(entry.waitForExistence(timeout: 2))
        entry.tap()
        return app
    }
}
```

Create `CatalogUITests` with exact expected entries:

```swift
final class CatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUICatalogExposesSixTopics() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["SwiftUI"].waitForExistence(timeout: 2))
        ["Styled Text", "Rotator", "Marquee", "Typewriter", "Shimmer",
         "Accessibility & Environment"].forEach {
            XCTAssertTrue(app.buttons[$0].exists, "Missing SwiftUI topic: \($0)")
        }
    }

    func testUIKitCatalogExposesSixNativeTopics() {
        let app = launch()
        app.tabBars.buttons["UIKit"].tap()
        XCTAssertTrue(app.navigationBars["UIKit"].waitForExistence(timeout: 2))
        ["Styled Label", "Rotator View", "Marquee View", "Typewriter View",
         "Shimmer Label", "Accessibility & Environment"].forEach {
            XCTAssertTrue(app.buttons[$0].exists, "Missing UIKit topic: \($0)")
        }
    }
}
```

Move the existing performance-launch test unchanged into
`PerformanceFixtureUITests`. Remove only old assertions that depend on the long
page; keep the shimmer pixel test for Task 6.

- [ ] **Step 2: Run the catalog tests and verify RED**

Run:

```bash
cd Example
xcodegen generate
xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExampleUITests/CatalogUITests test
```

Expected: FAIL because `Styled Text` and `Styled Label` catalog buttons do not
exist and the current pages are long-form examples.

- [ ] **Step 3: Implement the shared metadata with exact topic contracts**

Use these types:

```swift
enum DemoCapability: String, CaseIterable, Hashable {
    case plain = "Plain"
    case attributed = "Attributed"
    case styled = "Styled"
    case playback = "Playback"
    case rtl = "RTL"
    case dynamicType = "Dynamic Type"
    case accessibility = "Accessibility"
}

struct DemoSnippet: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let capabilities: [DemoCapability]
    let code: String
}

enum DemoTopic: String, CaseIterable, Identifiable {
    case styled, rotator, marquee, typewriter, shimmer, environment
    var id: String { rawValue }

    var swiftUITitle: String {
        switch self {
        case .styled: return "Styled Text"
        case .rotator: return "Rotator"
        case .marquee: return "Marquee"
        case .typewriter: return "Typewriter"
        case .shimmer: return "Shimmer"
        case .environment: return "Accessibility & Environment"
        }
    }

    var uiKitTitle: String {
        switch self {
        case .styled: return "Styled Label"
        case .rotator: return "Rotator View"
        case .marquee: return "Marquee View"
        case .typewriter: return "Typewriter View"
        case .shimmer: return "Shimmer Label"
        case .environment: return "Accessibility & Environment"
        }
    }

    var summary: String {
        switch self {
        case .styled:
            return "Fill and outline text with solid or linear-gradient paint."
        case .rotator:
            return "Rotate through plain, rich, or styled text at its natural height."
        case .marquee:
            return "Keep fitting text static and loop one overflowing line."
        case .typewriter:
            return "Reveal complete characters while intrinsic size grows."
        case .shimmer:
            return "Sweep a decorative highlight over real accessible text."
        case .environment:
            return "Inspect direction, Dynamic Type, and accessibility behavior."
        }
    }

    var capabilities: [DemoCapability] {
        switch self {
        case .styled:
            return [.plain, .attributed, .styled, .rtl, .dynamicType]
        case .rotator:
            return [.plain, .attributed, .styled, .playback, .dynamicType]
        case .marquee:
            return [.plain, .attributed, .styled, .playback, .rtl]
        case .typewriter:
            return [.plain, .attributed, .styled, .dynamicType]
        case .shimmer:
            return [.plain, .attributed, .styled, .accessibility]
        case .environment:
            return [.rtl, .dynamicType, .accessibility]
        }
    }
}
```

Do not store SwiftUI `View` or UIKit controller factories in the shared model.

- [ ] **Step 4: Implement platform-native catalogs and reusable teaching chrome**

Implement `SwiftUICatalogView` with `List(DemoTopic.allCases)` and
`NavigationLink`, using `.accessibilityIdentifier("catalog.swiftui.\(topic.id)")`.
Route each topic through a `@ViewBuilder` switch. Until its feature task lands,
the destination shows the real topic title, summary, capability tags, and an
`import ITextKit` snippet using the finished page/code components.

Implement `UIKitCatalogViewController` as `UITableViewController`, register
`UIKitCatalogCell`, and push the matching native detail controller through a
switch. Until its feature task lands, use `UIKitDemoDetailViewController` with
the topic title, summary, tags, and the same import snippet.

Implement code copy exactly through `UIPasteboard.general.string = snippet.code`.
The button begins as `Copy <snippet title> code`, changes its visible title to
`Copied`, and has identifier `copy.<snippet.id>`. Code content uses identifier
`code.<snippet.id>`.

Update the root:

```swift
TabView {
    NavigationView { SwiftUICatalogView() }
        .navigationViewStyle(.stack)
        .tabItem { Label("SwiftUI", systemImage: "swift") }

    UIKitExampleContainer()
        .tabItem { Label("UIKit", systemImage: "rectangle.3.group") }
}
```

`UIKitExampleContainer.makeUIViewController` returns
`UINavigationController(rootViewController: UIKitCatalogViewController())`.

- [ ] **Step 5: Regenerate and verify GREEN**

Run the Task 1 test command again, then run:

```bash
xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExampleUITests/PerformanceFixtureUITests test
```

Expected: both suites PASS; the normal launch shows catalogs and the hidden
launch still shows exactly 20 styled rows.

- [ ] **Step 6: Commit the catalog foundation**

```bash
git add Example/ITextKitExample Example/ITextKitExampleUITests \
  Example/ITextKitExample.xcodeproj Example/project.yml
git commit -m "refactor: organize example as API catalogs"
```

---

### Task 2: Complete SwiftUI and UIKit Styled Text Teaching Pages

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUIStyledTextExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitStyledTextExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/StyledTextCatalogUITests.swift`
- Modify: topic routers from Task 1.

**Interfaces:**
- Consumes: `DemoSnippet`, platform page/section/code components.
- Produces: visible normal-launch styled examples for native reference, fill,
  stroke widths, gradient stroke, combined styles, rich text, multiline, RTL,
  physical gradient coordinates, sizing, Auto Layout, and shimmer composition.

- [ ] **Step 1: Write failing styled-page matrix tests**

```swift
final class StyledTextCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIStyledPageShowsCompleteMatrixAndCopyableCode() {
        let app = open("Styled Text")
        ["Native reference", "Gradient fill", "0.5 pt", "1 pt", "2 pt",
         "3 pt", "Gradient stroke", "Fill + stroke", "Attributed",
         "Multiline gradient", "Semantic RTL", "Physical unit points",
         "Styled shimmer"].forEach { label in
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 2))
        }
        let code = app.otherElements["code.swiftui.styled.combined"]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextStyledText"))
        XCTAssertTrue(code.label.contains(".shimmerText()"))
        app.buttons["copy.swiftui.styled.combined"].tap()
        XCTAssertTrue(app.buttons["Copied"].exists)
    }

    func testUIKitStyledPageShowsCompleteMatrixAndSizingNotes() {
        let app = open("Styled Label", inUIKit: true)
        ["Native UILabel reference", "Gradient fill", "0.5 pt", "1 pt",
         "2 pt", "3 pt", "Gradient stroke", "Fill + stroke",
         "Attributed", "Multiline gradient", "Intrinsic size",
         "Auto Layout", "Semantic RTL"].forEach { label in
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 2))
        }
        let code = app.otherElements["code.uikit.styled.combined"]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextStyledLabel"))
        XCTAssertTrue(code.label.contains("width: 2"))
    }
}
```

- [ ] **Step 2: Run the styled tests and verify RED**

Run only `StyledTextCatalogUITests`. Expected: FAIL because Task 1 provides
only the topic introduction and import snippet.

- [ ] **Step 3: Implement SwiftUI live specimens and adjacent complete code**

Define reusable styles locally in this page:

```swift
private let gradientFill = ITextSwiftUIStyle(
    fill: .linearGradient(.init(
        colors: [.pink, .orange],
        startPoint: .leading,
        endPoint: .trailing
    ))
)

private let combinedStyle = ITextSwiftUIStyle(
    fill: .linearGradient(.init(colors: [.cyan, .blue, .purple])),
    stroke: .init(
        paint: .linearGradient(.init(
            colors: [.yellow, .orange, .red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )),
        width: 2
    )
)
```

Build the required sections with `ITextStyledText`, explicit `UIFont`, and
the exact visible labels from the UI test. The width row uses `[0.5, 1, 2, 3]`
and one `ITextStyledText` per value. The attributed specimen uses an
`NSAttributedString` with mixed fonts and underline. The multiline specimen is
width-constrained and uses one gradient across two lines. Put `.shimmerText()`
after `ITextStyledText` and before frame, padding, and background.

The `swiftui.styled.combined` snippet must include the complete styled-text
initializer, inline style value, and `.shimmerText()` ordering, not a reference
to a hidden helper.

- [ ] **Step 4: Implement the native UIKit page**

Subclass `UIKitDemoDetailViewController`. Create real `UILabel` and
`ITextStyledLabel` instances with Auto Layout. Use `UIStackView` for the stroke
width row. Demonstrate `numberOfLines = 0`, `preferredMaxLayoutWidth` through
constraints, intrinsic sizing without width/height constraints, and an
Auto Layout constrained multiline label.

The combined UIKit code block includes complete creation, font, text,
`ITextUIKitStyle`, `translatesAutoresizingMaskIntoConstraints`, and constraints.

- [ ] **Step 5: Run styled tests and existing visual renderer tests**

Run `StyledTextCatalogUITests`, then:

```bash
cd ..
xcodebuild -quiet -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitUIKitTests/ITextStyledTextVisualTests test
```

Expected: PASS. The package test ensures the teaching page did not require a
renderer change.

- [ ] **Step 6: Commit styled examples**

```bash
git add Example/ITextKitExample/SwiftUI/Examples/SwiftUIStyledTextExamplesView.swift \
  Example/ITextKitExample/UIKit/Examples/UIKitStyledTextExamplesViewController.swift \
  Example/ITextKitExampleUITests/StyledTextCatalogUITests.swift \
  Example/ITextKitExample.xcodeproj
git commit -m "feat: teach styled text in example catalogs"
```

---

### Task 3: Complete Rotator Teaching Pages and Preserve Playback Coverage

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUIRotatorExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitRotatorExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/RotatorCatalogUITests.swift`
- Modify: topic routers from Task 1.

**Interfaces:**
- Produces: plain, attributed, styled, variable-height, playback, and callback
  examples for `ITextRotator` and `ITextRotatorView`.

- [ ] **Step 1: Write failing Rotator navigation and behavior tests**

```swift
final class RotatorCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIRotatorTeachesInputsPlaybackAndCallback() {
        let app = open("Rotator")
        assertSections(in: app)
        XCTAssertTrue(app.otherElements["code.swiftui.rotator.styled"].exists)
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Pause"].exists)
        XCTAssertTrue(app.buttons["Resume"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
        XCTAssertTrue(app.staticTexts["Settled index: 0"].exists)
    }

    func testUIKitRotatorTeachesNativePlaybackAndCallback() {
        let app = open("Rotator View", inUIKit: true)
        assertSections(in: app)
        XCTAssertTrue(app.otherElements["code.uikit.rotator.styled"].exists)
        app.buttons["Pause"].tap()
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.staticTexts["Settled index: 1"]
            .waitForExistence(timeout: 5))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Plain input", "Attributed input", "Styled input", "Variable height"]
            .forEach { XCTAssertTrue(app.staticTexts[$0].exists) }
    }
}
```

- [ ] **Step 2: Run only `RotatorCatalogUITests` and verify RED**

Expected: FAIL because the topic page has no Rotator controls or live samples.

- [ ] **Step 3: Implement SwiftUI Rotator examples**

Use page-local:

```swift
@State private var playback: ITextPlaybackState = .playing
@State private var generation = 0
@State private var settledIndex = 0
```

Provide separate plain, attributed, and `textStyle:` samples. The variable
height sample uses one short and one wrapping value without a fixed height.
Start sets `.playing`, increments `generation`, and resets the displayed index.
Pause/Resume/Stop only change playback according to the public contract.

- [ ] **Step 4: Implement UIKit Rotator examples**

Create plain, attributed, styled, and variable-height
`ITextRotatorView` instances. Buttons call all sample views' public methods.
Update one caption through `onTextChange`. Keep the views constrained by
leading/trailing anchors and intrinsic height; add no fixed component height.

- [ ] **Step 5: Verify GREEN and commit**

Run `RotatorCatalogUITests` and package Rotator suites, then commit with:

```bash
git commit -m "feat: teach rotator APIs in example catalogs"
```

---

### Task 4: Complete Marquee Teaching Pages and RTL Coverage

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUIMarqueeExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitMarqueeExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/MarqueeCatalogUITests.swift`
- Modify: topic routers from Task 1.

**Interfaces:**
- Produces: fitting, overflowing, attributed, styled, configured, playback,
  semantic RTL, and inherited UIKit RTL examples.

- [ ] **Step 1: Write failing Marquee page tests**

```swift
final class MarqueeCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIMarqueeTeachesStaticOverflowRichStyledAndRTL() {
        let app = open("Marquee")
        assertSections(in: app)
        XCTAssertTrue(app.otherElements["code.swiftui.marquee.styled"].exists)
        ["Start", "Pause", "Resume", "Stop"].forEach {
            XCTAssertTrue(app.buttons[$0].exists)
        }
    }

    func testUIKitMarqueeTeachesInheritedRTLAndPlayback() {
        let app = open("Marquee View", inUIKit: true)
        assertSections(in: app)
        XCTAssertTrue(app.otherElements["code.uikit.marquee.styled"].exists)
        XCTAssertTrue(app.otherElements["marquee.uikit.rtl"].label
            .contains("مرحبا"))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Fitting text stays static", "Overflowing loop", "Attributed input",
         "Styled input", "Configuration", "Right to left"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
    }
}
```

- [ ] **Step 2: Run only `MarqueeCatalogUITests` and verify RED**

Expected: FAIL because the current catalog destination has no live marquee.

- [ ] **Step 3: Implement both platform pages with the same semantic fixtures**

Use `.init(speed: 40, spacing: 24, initialDelay: 0.5)` in the configuration
example. SwiftUI uses `.environment(\.layoutDirection, .rightToLeft)` only on
the RTL specimen. UIKit puts the RTL view inside a container with
`semanticContentAttribute = .forceRightToLeft`, leaving the child as
`.unspecified` so inherited direction is actually demonstrated.

Do not add gesture controls or rewrite newlines. All examples stay one line.

- [ ] **Step 4: Verify GREEN and commit**

Run the new UI suite plus package marquee engine/API tests. Commit:

```bash
git commit -m "feat: teach marquee APIs in example catalogs"
```

---

### Task 5: Complete Typewriter Teaching Pages

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUITypewriterExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitTypewriterExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/TypewriterCatalogUITests.swift`
- Modify: topic routers from Task 1.

**Interfaces:**
- Produces: plain, attributed, styled, wrapped, composed-character, intrinsic
  growth, and Replay examples without unsupported playback controls.

- [ ] **Step 1: Write failing Typewriter tests**

```swift
final class TypewriterCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUITypewriterTeachesAllSupportedBehaviorOnly() {
        let app = open("Typewriter")
        assertSections(in: app)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertTrue(app.otherElements["code.swiftui.typewriter.styled"].exists)
        app.buttons["Replay Typewriter"].tap()
        XCTAssertTrue(app.otherElements["A plain typewriter grows as it reveals."]
            .waitForExistence(timeout: 2))
    }

    func testUIKitTypewriterTeachesAutoLayoutAndReplay() {
        let app = open("Typewriter View", inUIKit: true)
        assertSections(in: app)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertTrue(app.otherElements["code.uikit.typewriter.styled"].exists)
        app.buttons["Replay Typewriter"].tap()
        XCTAssertTrue(app.otherElements["A plain typewriter grows as it reveals."]
            .waitForExistence(timeout: 2))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Plain input", "Attributed input", "Styled input",
         "Wrapping and growth", "Emoji stays whole"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
    }
}
```

- [ ] **Step 2: Run only `TypewriterCatalogUITests` and verify RED**

- [ ] **Step 3: Implement SwiftUI and UIKit pages**

SwiftUI Replay increments a local generation used by all typewriter examples.
Constrain only the wrapping card to 280 points; let other specimens use natural
size. Use `Rich 👨‍👩‍👧‍👦 typewriter` for the composed-character fixture.

UIKit Replay assigns empty input and then assigns fresh plain/attributed input,
matching the already validated Example behavior. Constrain the wrapping sample
to at most 280 points and let its intrinsic height grow. Do not add pause,
resume, stop, cursor, callback, sound, or haptic controls.

- [ ] **Step 4: Verify GREEN and commit**

Run the new UI suite and package Typewriter engine/API tests. Commit:

```bash
git commit -m "feat: teach typewriter APIs in example catalogs"
```

---

### Task 6: Complete Shimmer Teaching Pages and Preserve Pixel Regression

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUIShimmerExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitShimmerExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/ShimmerCatalogUITests.swift`
- Modify: topic routers from Task 1.
- Modify: move/adapt the existing shimmer-background pixel test from
  `ITextKitExampleUITests.swift`.

**Interfaces:**
- Produces: plain, attributed, styled, configuration, active toggle, highlight,
  modifier ordering, and UIKit intrinsic/accessibility examples.

- [ ] **Step 1: Write failing Shimmer catalog tests**

```swift
final class ShimmerCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIShimmerTeachesCompositionAndToggle() {
        let app = open("Shimmer")
        ["Plain text", "Attributed text", "Styled fill + stroke",
         "Configuration", "Correct modifier order"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
        XCTAssertTrue(app.otherElements["code.swiftui.shimmer.styled"].exists)
        app.switches["Shimmer active"].tap()
        XCTAssertTrue(app.staticTexts["Shimmer: Off"].exists)
    }

    func testUIKitShimmerTeachesNativeLabelBehavior() {
        let app = open("Shimmer Label", inUIKit: true)
        ["Plain label", "Attributed label", "Styled fill + stroke",
         "Configuration", "Intrinsic size"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
        XCTAssertTrue(app.otherElements["code.uikit.shimmer.styled"].exists)
        app.switches["Shimmer active"].tap()
        XCTAssertTrue(app.staticTexts["Shimmer: Off"].exists)
    }
}
```

Adapt the existing pixel regression to open `Shimmer`, locate
`SwiftUI shimmer background probe`, and retain the same 20 samples, 0.08-second
interval, and maximum RGB-channel variation threshold of 3.

- [ ] **Step 2: Run only `ShimmerCatalogUITests` and verify RED**

- [ ] **Step 3: Implement both pages with correct composition**

SwiftUI uses a complete local value rather than an omitted helper:

```swift
ITextStyledText(
    "Styled shimmer",
    font: .systemFont(ofSize: 28, weight: .bold),
    style: .init(
        fill: .linearGradient(.init(colors: [.pink, .orange])),
        stroke: .init(
            paint: .linearGradient(.init(colors: [.white, .yellow])),
            width: 2
        )
    )
)
    .shimmerText(isActive: isActive)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
```

UIKit uses `ITextShimmerLabel`, assigns `textStyle` with gradient fill and
stroke, and toggles `isShimmering`. Keep one accessibility owner; do not add an
overlay label for the state.

- [ ] **Step 4: Verify GREEN and commit**

Run the new UI suite, the pixel regression, and package Shimmer UIKit/SwiftUI
tests. Commit:

```bash
git commit -m "feat: teach shimmer APIs in example catalogs"
```

---

### Task 7: Accessibility and Environment Teaching Pages

**Files:**
- Create: `Example/ITextKitExample/SwiftUI/Examples/SwiftUIEnvironmentExamplesView.swift`
- Create: `Example/ITextKitExample/UIKit/Examples/UIKitEnvironmentExamplesViewController.swift`
- Create: `Example/ITextKitExampleUITests/EnvironmentCatalogUITests.swift`
- Modify: topic routers from Task 1.

**Interfaces:**
- Produces: honest LTR/RTL, Dynamic Type, current Reduce Motion, and VoiceOver
  ownership specimens without changing system accessibility state.

- [ ] **Step 1: Write failing environment tests**

```swift
final class EnvironmentCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIEnvironmentPageUsesHonestSystemStatus() {
        let app = open("Accessibility & Environment")
        assertEnvironmentSections(in: app)
        XCTAssertTrue(app.otherElements["code.swiftui.environment.rtl"].exists)
        XCTAssertTrue(app.otherElements["code.swiftui.environment.dynamicType"].exists)
    }

    func testUIKitEnvironmentPageUsesHonestSystemStatus() {
        let app = open("Accessibility & Environment", inUIKit: true)
        assertEnvironmentSections(in: app)
        XCTAssertTrue(app.otherElements["code.uikit.environment.rtl"].exists)
        XCTAssertTrue(app.otherElements["code.uikit.environment.dynamicType"].exists)
    }

    private func assertEnvironmentSections(in app: XCUIApplication) {
        ["Left to right", "Right to left", "Dynamic Type", "Reduce Motion",
         "VoiceOver"].forEach { XCTAssertTrue(app.staticTexts[$0].exists) }
        let on = app.staticTexts["System Reduce Motion: On"].exists
        let off = app.staticTexts["System Reduce Motion: Off"].exists
        XCTAssertNotEqual(on, off)
    }
}
```

- [ ] **Step 2: Run only `EnvironmentCatalogUITests` and verify RED**

- [ ] **Step 3: Implement honest environment specimens**

SwiftUI locally sets `.environment(\.layoutDirection, .leftToRight)` and
`.environment(\.layoutDirection, .rightToLeft)` on direction specimens, and
uses `.environment(\.dynamicTypeSize, .large)` plus
`.environment(\.dynamicTypeSize, .accessibility3)` on the two type specimens. Read
`@Environment(\.accessibilityReduceMotion)` for the status row.

UIKit uses containers with forced semantic directions and preferred fonts with
`adjustsFontForContentSizeCategory = true`. Read
`UIAccessibility.isReduceMotionEnabled`; do not mutate it. Explain that a real
VoiceOver or Reduce Motion validation is performed in Settings.

- [ ] **Step 4: Verify GREEN and commit**

Run the new UI suite and commit:

```bash
git commit -m "feat: teach accessibility environments in example"
```

---

### Task 8: Remove Superseded Pages, Complete Documentation, and Run All Gates

**Files:**
- Delete: `Example/ITextKitExample/SwiftUIExampleView.swift`
- Delete: `Example/ITextKitExample/UIKitExampleViewController.swift`
- Delete after all tests have moved: `Example/ITextKitExampleUITests/ITextKitExampleUITests.swift`
- Modify: `Example/README.md`
- Modify: `Example/ITextKitExample.xcodeproj/project.pbxproj` through XcodeGen.
- Verify: every file created in Tasks 1-7.

**Interfaces:**
- Consumes: all finished catalog pages and focused UI suites.
- Produces: one maintainable API-teaching Example with no chronological-page
  leftovers and no renderer/API changes.

- [ ] **Step 1: Confirm every legacy assertion has a focused replacement**

Map before deletion:

- Hidden performance launch → `PerformanceFixtureUITests`.
- SwiftUI shimmer background isolation → `ShimmerCatalogUITests`.
- Rotator controls/callback → `RotatorCatalogUITests`.
- Attributed marquee → `MarqueeCatalogUITests`.
- Plain/attributed typewriter and Replay → `TypewriterCatalogUITests`.
- UIKit native controls → focused UIKit paths in Tasks 2-7.

If any mapping is absent, add that exact assertion to its focused suite before
deleting the old test file.

- [ ] **Step 2: Delete old pages/tests and regenerate the project**

Use `apply_patch` to delete the three superseded source files, then:

```bash
cd Example
xcodegen generate
```

Expected: the generated project contains the new folder sources and no old page
references.

- [ ] **Step 3: Rewrite Example README as the catalog guide**

Document:

- SwiftUI/UIKit tab separation and all six destinations per platform.
- Live effect + complete code + Copy structure.
- The styled fill/stroke examples and real-point semantics.
- `xcodegen generate` and normal run commands.
- The maintainer-only `-ITextStyledPerformance` launch argument.
- No network/dependency requirement.

- [ ] **Step 4: Run full ITextKit package tests**

```bash
cd ..
xcodebuild -quiet -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO test
```

Expected: all Core, UIKit, and SwiftUI tests PASS.

- [ ] **Step 5: Run full Example UI tests and app-hosted regressions separately**

```bash
cd Example
xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExampleUITests test

xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExamplePerformanceTests test
```

Expected: all catalog, copy, behavior, pixel, hidden fixture, and app-hosted
performance regression tests PASS.

- [ ] **Step 6: Build Example Debug and Release**

```bash
xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build
xcodebuild -quiet -project ITextKitExample.xcodeproj -scheme ITextKitExample \
  -configuration Release -destination 'generic/platform=iOS Simulator' build
```

Expected: both builds exit 0.

- [ ] **Step 7: Build DocC and audit formatting/scope**

```bash
cd ..
xcodebuild -quiet -scheme ITextKit \
  -destination 'generic/platform=iOS Simulator' docbuild
git diff --check
git status --short
```

Expected: DocC exits 0, `git diff --check` is empty, and status contains only
the intended Example/catalog/test/README/project files.

- [ ] **Step 8: Commit the completed Demo catalog**

```bash
git add Example docs/superpowers/plans/2026-08-13-itextkit-example-api-catalog.md
git commit -m "docs: complete example API teaching catalog"
```

- [ ] **Step 9: Final evidence audit**

```bash
git status --short
git log -8 --oneline
git diff 0.3.0..HEAD --stat
```

Expected: worktree clean; commits are scoped by catalog/feature; the diff since
0.3.0 contains Example, tests, Example README, design, and plan only. Do not
tag or push a new release unless the user separately requests publication.

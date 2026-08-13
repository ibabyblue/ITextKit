struct DemoSnippet: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let capabilities: [DemoCapability]
    let code: String
}

import Testing
@testable import AppFoundation

@Test
func providerConfigurationDraftTracksNormalizedSavedState() {
    var draft = AppAIProviderConfigurationDraft(
        apiKey: "  saved-key\n",
        model: " model-a "
    )

    #expect(draft.apiKey == "saved-key")
    #expect(draft.model == "model-a")
    #expect(draft.hasSavedCredential)
    #expect(!draft.hasUnsavedChanges)
    #expect(!draft.canSave)
    #expect(draft.canTest)

    draft.model = " model-b "

    #expect(draft.hasUnsavedChanges)
    #expect(draft.canSave)
    #expect(draft.normalizedModel == "model-b")

    draft.discardChanges()

    #expect(draft.model == "model-a")
    #expect(!draft.hasUnsavedChanges)
}

@Test
func providerConfigurationDraftSupportsCredentialRemoval() {
    var draft = AppAIProviderConfigurationDraft(
        apiKey: "saved-key",
        model: "model-a"
    )

    draft.apiKey = "   "

    #expect(draft.hasSavedCredential)
    #expect(draft.hasUnsavedChanges)
    #expect(draft.canSave)
    #expect(!draft.canTest)

    draft.markSaved()

    #expect(draft.apiKey.isEmpty)
    #expect(!draft.hasSavedCredential)
    #expect(!draft.hasUnsavedChanges)
}

@Test
func providerConfigurationDraftRequiresModelBeforeSaving() {
    var draft = AppAIProviderConfigurationDraft()
    draft.apiKey = "new-key"

    #expect(draft.hasUnsavedChanges)
    #expect(!draft.canSave)
    #expect(!draft.canTest)

    draft.model = "model-a"

    #expect(draft.canSave)
    #expect(draft.canTest)
}

#if DEBUG
import AppFoundation
import SwiftUI

struct SimulatedPlansEditorView: View {
    @Environment(DemoPurchaseStore.self) private var purchaseStore
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss

    @State private var configuration = DemoSimulatedPlanConfiguration.load()
    @State private var validationMessage: String?

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        Form {
            Section {
                ForEach($configuration.plans) { $plan in
                    NavigationLink {
                        SimulatedPlanDetailView(plan: $plan)
                    } label: {
                        planLabel(plan)
                    }
                }
                .onDelete(perform: deletePlans)
                .onMove(perform: movePlans)

                Button("Add simulated plan", systemImage: "plus") {
                    configuration.plans.append(
                        .newPlan(index: configuration.plans.count + 1)
                    )
                }
            } header: {
                Text("Plans")
            } footer: {
                Text("Enabled plans are shown by the Demo paywalls in this order. Three or more plans use ClaudePaywallView’s compact stacked layout.")
            }
            .listRowBackground(theme.surfaceColor)

            Section("Default selection") {
                Picker("Preferred plan", selection: $configuration.preferredProductID) {
                    ForEach(configuration.enabledPlans) { plan in
                        Text(plan.displayName.isEmpty ? plan.period.title : plan.displayName)
                            .tag(plan.productID)
                    }
                }
            }
            .listRowBackground(theme.surfaceColor)

            Section {
                Button("Restore default plans", role: .destructive) {
                    configuration = .defaults
                }
            } footer: {
                Text("Applying replaces the Demo’s current PurchaseManager. Simulated purchase state is preserved when the selected product still exists.")
            }
            .listRowBackground(theme.surfaceColor)
        }
        .scrollContentBackground(.hidden)
        .background(AppThemeBackground(theme: theme))
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle("Simulated Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    applyConfiguration()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Cannot Apply Plans", isPresented: validationAlertBinding) {
            Button("OK", role: .cancel) {
                validationMessage = nil
            }
        } message: {
            Text(validationMessage ?? "")
        }
        .tint(theme.accentColor)
    }

    private func planLabel(_ plan: DemoSimulatedPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plan.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(plan.isEnabled ? theme.accentColor : theme.secondaryForegroundColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.displayName.isEmpty ? plan.period.title : plan.displayName)
                    .foregroundStyle(theme.primaryForegroundColor)
                Text("\(plan.displayPrice) · \(plan.period.title)")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }

            Spacer(minLength: 8)
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        configuration.plans.remove(atOffsets: offsets)
    }

    private func movePlans(from source: IndexSet, to destination: Int) {
        configuration.plans.move(fromOffsets: source, toOffset: destination)
    }

    private func applyConfiguration() {
        guard let message = configuration.validationMessage else {
            let normalized = configuration.normalized()
            purchaseStore.apply(normalized)
            configuration = normalized
            dismiss()
            return
        }
        validationMessage = message
    }

    private var validationAlertBinding: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )
    }
}

private struct SimulatedPlanDetailView: View {
    @Environment(ThemeManager.self) private var themes
    @Binding var plan: DemoSimulatedPlan

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        Form {
            Section("Availability") {
                Toggle("Enabled", isOn: $plan.isEnabled)
            }
            .listRowBackground(theme.surfaceColor)

            Section("Store product") {
                TextField("Product identifier", text: $plan.productID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Display name", text: $plan.displayName)
                TextField("Description", text: $plan.productDescription, axis: .vertical)
                    .lineLimit(2...4)
            }
            .listRowBackground(theme.surfaceColor)

            Section("Pricing") {
                TextField("Displayed price", text: $plan.displayPrice)
                TextField("Numeric price", value: $plan.price, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Billing period", selection: $plan.period) {
                    ForEach(DemoSimulatedPlanPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
            }
            .listRowBackground(theme.surfaceColor)
        }
        .scrollContentBackground(.hidden)
        .background(AppThemeBackground(theme: theme))
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(plan.period.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accentColor)
    }
}
#endif

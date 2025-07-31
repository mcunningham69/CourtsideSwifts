import SwiftUI
import Combine


struct CourtListView: View {
    @ObservedObject var viewModel: CourtsViewModel
    var sessionViewModel: PlayingSessionViewModel
    @State private var showEditSheet = false
    @State private var editIndex: Int? = nil
    @State private var newCourtNumber = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Courts")
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.courts.indices, id: \.self) { idx in
                        let court = viewModel.courts[idx]
                        CourtSessionView(
                            court: court,
                            viewModel: viewModel,
                            sessionViewModel: sessionViewModel
                        )
                        .onTapGesture {
                            // select for editing
                            editIndex = idx
                            newCourtNumber = String(court.courtNumber)
                            showEditSheet = true
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }

            HStack(spacing: 16) {
                Button(action: {
                    viewModel.addNewCourt()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Court")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Button(action: {
                    viewModel.removeLastCourt()
                }) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                        Text("Remove Court")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    TextField("Court Number", text: $newCourtNumber)
                        .keyboardType(.numberPad)
                }
                .navigationTitle("Edit Court")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let idx = editIndex,
                               let num = Int(newCourtNumber) {
                                viewModel.courts[idx].courtNumber = num
                            }
                            showEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showEditSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    CourtListView(
        viewModel: CourtsViewModel(),
        sessionViewModel: PlayingSessionViewModel(
            sessionID: UUID(),
            refreshTrigger: Just(()).eraseToAnyPublisher())
    )
}

//
//  AddDiamondView.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import SwiftUI

struct AddDiamondView: View {
    @ObservedObject var store: DiamondStore
    @Environment(\.dismiss) var dismiss
    
    @State private var certificateNumber = ""
    @State private var caratWeight = ""
    @State private var color = "D"
    @State private var clarity = "IF"
    @State private var cut = "Excellent"
    @State private var shape = "Round"
    @State private var price = ""
    @State private var origin = ""
    @State private var certifyingLab = "GIA"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Certificate") {
                    TextField("Certificate Number", text: $certificateNumber)
                    Picker("Lab", selection: $certifyingLab) {
                        Text("GIA").tag("GIA")
                        Text("AGS").tag("AGS")
                        Text("IGI").tag("IGI")
                    }
                }
                
                Section("Specifications") {
                    TextField("Carat Weight", text: $caratWeight)
                        .keyboardType(.decimalPad)
                    
                    Picker("Color", selection: $color) {
                        ForEach(["D", "E", "F", "G", "H", "I", "J"], id: \.self) { Text($0) }
                    }
                    
                    Picker("Clarity", selection: $clarity) {
                        ForEach(["FL", "IF", "VVS1", "VVS2", "VS1", "VS2"], id: \.self) { Text($0) }
                    }
                    
                    Picker("Cut", selection: $cut) {
                        ForEach(["Excellent", "Very Good", "Good"], id: \.self) { Text($0) }
                    }
                    
                    Picker("Shape", selection: $shape) {
                        ForEach(["Round", "Princess", "Oval", "Emerald"], id: \.self) { Text($0) }
                    }
                }
                
                Section("Details") {
                    TextField("Origin", text: $origin)
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Diamond")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveDiamond()
                        }
                    }
                }
            }
        }
    }
    
    private func saveDiamond() async {
        guard let carat = Double(caratWeight),
              let priceDecimal = Decimal(string: price) else { return }
        
        let diamond = Diamond(
            certificateNumber: certificateNumber,
            caratWeight: carat,
            color: color,
            clarity: clarity,
            cut: cut,
            shape: shape,
            price: priceDecimal,
            origin: origin,
            certifyingLab: certifyingLab
        )
        
        try? await store.addDiamond(diamond)
        dismiss()
    }
}

import SwiftUI
import SharedUI

struct TestingAreaView: View {
    var body: some View {
        VStack {
            Text("Testing Area")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Text("Drag and Drop Demo")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            DragDropDemoView()
                .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background", bundle: .sharedUI))
    }
}

#Preview {
    TestingAreaView()
}

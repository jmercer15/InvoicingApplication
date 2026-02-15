//
//  InvoiceCanvasView.swift
//  Feature.InvoiceTemplateEditor
//
//  Read-only canvas view for rendering invoices using templates.
//  This is a simplified version of ModernCanvasView without editing UI.
//

import SwiftUI
import Core

/// A public, read-only canvas view for rendering invoices using the template system.
/// This view can be used by other modules (e.g., Feature.Invoices) to display invoices
/// using the template editor's rendering approach without editing capabilities.
public struct InvoiceCanvasView: View {
    @ObservedObject var document: InvoiceDocument
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewportOffset: CGSize = .zero
    @State private var sectionHeightRatios: [CGFloat] = [1.0]
    
    /// Creates a new read-only invoice canvas view.
    /// - Parameter document: The InvoiceDocument containing template layout and components.
    public init(document: InvoiceDocument) {
        self.document = document
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Background
                Color(NSColor.underPageBackgroundColor)
                    .ignoresSafeArea()
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .center) {
                        // Spacer for minimum viewport size
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Page content
                        ZStack(alignment: .topLeading) {
                            pageBackground
                            contentArea
                        }
                        .frame(width: A4.width, height: A4.height)
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(viewportOffset)
                    }
                }
                
                // Zoom controls overlay
                zoomControls
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            autoFitScale()
        }
    }
    
    // MARK: - Page Background
    
    private var pageBackground: some View {
        Rectangle()
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 0)
            .frame(width: A4.width, height: A4.height)
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        let margins = document.margins
        let contentSize = CGSize(
            width: A4.width - margins.left - margins.right,
            height: A4.height - margins.top - margins.bottom
        )
        
        return RatioBasedLayout(
            ratios: sectionHeightRatios,
            direction: .vertical,
            containerSize: contentSize,
            onResize: { _, _ in } // No resizing in read-only mode
        ) { index, sectionSize in
            SplittableRectangleView(
                split: document.sectionSplits[index],
                leafComponents: [],
                containerSize: sectionSize,
                sectionIndex: index,
                nodePath: [],
                childIndex: index,
                childPadding: .zero,
                parentAlignment: document.sectionSplits[index]?.getAlignment(forChild: 0) ?? .default,
                context: readOnlyContext
            )
            .frame(width: sectionSize.width, height: sectionSize.height)
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .padding(.leading, margins.left)
        .padding(.trailing, margins.right)
        .padding(.top, margins.top)
        .padding(.bottom, margins.bottom)
        .clipShape(Rectangle())
    }
    
    // MARK: - Read-Only Interaction Context
    
    /// A no-op interaction context for read-only rendering
    private var readOnlyContext: SplitInteractionContext {
        SplitInteractionContext(
            onDrop: { _, _ in false },
            onSplitChild: { _, _, _, _, _ in },
            onUnsplitChild: { _ in },
            onResize: { _, _ in },
            onUpdateSplit: { _, _ in },
            onAddComponent: { _, _ in },
            onSetLabel: nil,
            onReorderChildren: nil,
            onComponentSelect: { _ in },
            onLeafSelect: nil,
            onSetWidthSizingMode: nil,
            onSetHeightSizingMode: nil,
            onSetGridSizingMode: nil,
            currentWidthSizingMode: nil,
            currentHeightSizingMode: nil,
            currentRowSizingMode: nil,
            currentColumnSizingMode: nil,
            showDividers: false
        )
    }
    
    // MARK: - Zoom Controls
    
    private var zoomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Button(action: autoFitScale) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 12, weight: .bold))
                            .contentShape(Rectangle())
                    }
                    .help("Fit to Page")
                    
                    Divider()
                        .frame(height: 16)
                    
                    Image(systemName: "magnifyingglass")
                    Text("\(Int(zoomScale * 100))%")
                    
                    Button(action: { withAnimation(.spring()) { zoomScale = 1.0 } }) {
                        Image(systemName: "arrow.counterclockwise")
                            .contentShape(Rectangle())
                    }
                    .help("Reset Zoom")
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 5)
                .padding()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func autoFitScale() {
        // Will auto-fit on next layout pass based on geometry
        // Default to a scale that fits the page nicely
        zoomScale = 0.8
    }
}

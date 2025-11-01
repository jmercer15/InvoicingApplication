//
//  SharedViews.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
@preconcurrency import MapKit







// MARK: - Shared Detail Views

// MARK: - Row Views

// MARK: - Button Styles
//struct ToolbarButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .padding(.horizontal, 10)
//            .padding(.vertical, 6)
//            .frame(height: 32)
//            .background(
//                RoundedRectangle(cornerRadius: 6)
//                    .fill(configuration.isPressed ?
//                          Color.accentColor.opacity(0.2) :
//                          Color.secondary.opacity(0.08))
//                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 6)
//                    .stroke(configuration.isPressed ?
//                            Color.accentColor.opacity(0.3) :
//                            Color.secondary.opacity(0.15),
//                            lineWidth: 1)
//            )
//            .foregroundColor(configuration.isPressed ? .accentColor : .primary)
//            .contentShape(Rectangle())
//    }
//}



extension View {
    /// Conditionally applies a transform to a view if the condition is true.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}





// MARK: - Generic List View (Refactored to use List)







// Keep EmptyStateView definition
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    public init(icon: String, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color("Text", bundle: .sharedUI))

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.clear)
    }
}

// Shared AddressMapView component for address map rendering
struct NonInteractiveMapView: View {
    var address: String
    var mapType: MKMapType
    var showsTraffic: Bool

    var body: some View {
        _MapView(address: address, mapType: mapType, showsTraffic: showsTraffic)
            .edgesIgnoringSafeArea(.all)
    }

    private struct _MapView: NSViewRepresentable {
        var address: String
        var mapType: MKMapType
        var showsTraffic: Bool

        func makeNSView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = false
            mapView.isPitchEnabled = false
            mapView.isRotateEnabled = false
            mapView.mapType = mapType
            mapView.showsTraffic = showsTraffic
            mapView.showsZoomControls = true
            return mapView
        }

        func updateNSView(_ nsView: MKMapView, context: Context) {
            nsView.mapType = mapType
            nsView.showsTraffic = showsTraffic
            nsView.showsZoomControls = true
            
            // Use the new MapKit geocoding API
            Task {
                do {
                    guard let request = MKGeocodingRequest(addressString: address) else {
                        print("Failed to create geocoding request for '\(address)'")
                        return
                    }
                    let mapItems = try await request.mapItems
                    
                    guard let firstItem = mapItems.first else {
                        return
                    }
                    let location = firstItem.location
                    
                    let coordinate = location.coordinate
                    let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                    nsView.setRegion(region, animated: false)
                    
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    nsView.removeAnnotations(nsView.annotations)
                    nsView.addAnnotation(annotation)
                } catch {
                    print("Geocoding failed for '\(address)': \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Interactive Map View

public struct InteractiveMapView: View {
    let address: String
    @Environment(\.dismiss) private var dismiss
    
    public init(address: String) {
        self.address = address
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Location")
                    .font(.headline)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .padding()
            .background(Color("Surface", bundle: .sharedUI))
            
            Divider()
            
            // Map
            MapViewRepresentable(address: address)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct MapViewRepresentable: NSViewRepresentable {
    let address: String
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Clear existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Use the new MapKit geocoding API
        Task {
            do {
                guard let request = MKGeocodingRequest(addressString: address) else {
                    print("Failed to create geocoding request for '\(address)'")
                    return
                }
                let mapItems = try await request.mapItems
                
                guard let firstItem = mapItems.first else {
                    return
                }
                let location = firstItem.location
                
                let coordinate = location.coordinate
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = address
                
                DispatchQueue.main.async {
                    mapView.addAnnotation(annotation)
                    
                    // Zoom to the annotation with wider view
                    let region = MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: 5000,
                        longitudinalMeters: 5000
                    )
                    mapView.setRegion(region, animated: true)
                }
            } catch {
                print("Geocoding failed for '\(address)': \(error.localizedDescription)")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
            
            let identifier = "AddressPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .red
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}





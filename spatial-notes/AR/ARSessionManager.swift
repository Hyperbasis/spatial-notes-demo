//
//  ARSessionManager.swift
//  spatial-notes
//

import ARKit
import RealityKit
import Combine

/// Manages the AR session and provides AR functionality
@MainActor
class ARSessionManager: NSObject, ObservableObject {

    // MARK: - Properties

    /// The RealityKit AR view
    let arView: ARView

    /// Current tracking state
    @Published var trackingState: ARCamera.TrackingState = .notAvailable

    /// Whether a surface has been detected
    @Published var surfaceDetected: Bool = false

    /// Error message if AR fails
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        arView = ARView(frame: .zero)
        super.init()
        setupARSession()
        setupSubscriptions()
    }

    // MARK: - Setup

    private func setupARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        arView.session.run(config)
    }

    private func setupSubscriptions() {
        arView.session.delegate = self
    }

    // MARK: - Public Methods

    /// Performs a raycast from screen point to find real-world surfaces
    func raycast(from point: CGPoint) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
        let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any)

        guard let result = results.first else { return nil }

        let position = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )

        let normal = SIMD3<Float>(
            result.worldTransform.columns.2.x,
            result.worldTransform.columns.2.y,
            result.worldTransform.columns.2.z
        )

        return (position, normal)
    }

    /// Adds an entity to the AR scene
    func addEntity(_ entity: Entity, at position: SIMD3<Float>) {
        let anchor = AnchorEntity(world: position)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
    }

    /// Removes an entity from the AR scene
    func removeEntity(_ entity: Entity) {
        entity.anchor?.removeFromParent()
    }

    /// Pauses the AR session
    func pause() {
        arView.session.pause()
    }

    /// Resumes the AR session
    func resume() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            self.trackingState = camera.trackingState

            switch camera.trackingState {
            case .normal:
                self.errorMessage = nil
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.errorMessage = "Initializing AR..."
                case .excessiveMotion:
                    self.errorMessage = "Slow down"
                case .insufficientFeatures:
                    self.errorMessage = "Point at more textured surfaces"
                case .relocalizing:
                    self.errorMessage = "Relocalizing..."
                @unknown default:
                    self.errorMessage = "Limited tracking"
                }
            case .notAvailable:
                self.errorMessage = "AR not available"
            }
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if anchor is ARPlaneAnchor {
                    self.surfaceDetected = true
                    break
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}

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

    /// Whether we're currently relocalizing
    @Published var isRelocalizing: Bool = false

    /// Whether relocalization completed successfully
    @Published var isRelocalized: Bool = false

    /// Debug mode enabled
    @Published var debugModeEnabled: Bool = false {
        didSet {
            updateDebugOptions()
        }
    }

    /// Number of detected planes
    @Published var planeCount: Int = 0

    /// Number of tracked anchors
    @Published var anchorCount: Int = 0

    /// Current frame info
    @Published var frameInfo: String = ""

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

    private func updateDebugOptions() {
        if debugModeEnabled {
            // Show debug visualizations
            arView.debugOptions = [
                .showFeaturePoints,
                .showWorldOrigin,
                .showAnchorOrigins,
                .showAnchorGeometry
            ]
        } else {
            arView.debugOptions = []
        }
    }

    // MARK: - Public Methods

    /// Performs a raycast from screen point to find real-world surfaces
    /// Returns the full transform for proper surface attachment
    func raycast(from point: CGPoint) -> (position: SIMD3<Float>, transform: simd_float4x4)? {
        // Try existing plane geometry first for best accuracy
        var results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .any)

        // Fall back to existing plane infinite (extends beyond detected bounds)
        if results.isEmpty {
            results = arView.raycast(from: point, allowing: .existingPlaneInfinite, alignment: .any)
        }

        // Last resort: estimated plane
        if results.isEmpty {
            results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any)
        }

        guard let result = results.first else { return nil }

        let position = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )

        return (position, result.worldTransform)
    }

    /// Adds an entity to the AR scene anchored to a surface
    func addEntity(_ entity: Entity, at position: SIMD3<Float>, transform: simd_float4x4? = nil) {
        if let transform = transform {
            // Create an ARAnchor at the exact raycast hit point for stable tracking
            let arAnchor = ARAnchor(name: "note", transform: transform)
            arView.session.add(anchor: arAnchor)

            // Create AnchorEntity attached to the AR anchor
            let anchorEntity = AnchorEntity(anchor: arAnchor)
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)
        } else {
            // Fallback for loaded notes without transform
            let anchor = AnchorEntity(world: position)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
        }
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

    // MARK: - World Map

    /// Gets the current world map from the AR session
    func getCurrentWorldMap() async throws -> ARWorldMap {
        return try await arView.session.currentWorldMap()
    }

    /// Checks if a world map can be captured
    var canCaptureWorldMap: Bool {
        guard case .normal = trackingState else { return false }
        return surfaceDetected
    }

    /// Relocalizes the AR session using a saved world map
    func relocalize(with worldMap: ARWorldMap) {
        isRelocalizing = true
        isRelocalized = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.initialWorldMap = worldMap

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
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
                // Check if we were relocalizing
                if self.isRelocalizing {
                    self.isRelocalized = true
                    self.isRelocalizing = false
                }
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.errorMessage = "Initializing AR..."
                case .excessiveMotion:
                    self.errorMessage = "Slow down"
                case .insufficientFeatures:
                    self.errorMessage = "Point at more textured surfaces"
                case .relocalizing:
                    self.errorMessage = "Relocalizing - look around the room..."
                    self.isRelocalizing = true
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
            self.updateAnchorCounts(session: session)
            for anchor in anchors {
                if anchor is ARPlaneAnchor {
                    self.surfaceDetected = true
                    break
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            self.updateAnchorCounts(session: session)
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            self.updateAnchorCounts(session: session)
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            if self.debugModeEnabled {
                self.updateFrameInfo(frame: frame)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Debug Helpers

    private func updateAnchorCounts(session: ARSession) {
        guard let anchors = session.currentFrame?.anchors else { return }
        self.planeCount = anchors.filter { $0 is ARPlaneAnchor }.count
        self.anchorCount = anchors.count
    }

    private func updateFrameInfo(frame: ARFrame) {
        let camera = frame.camera
        let pos = camera.transform.columns.3

        // World mapping status
        let mappingStatus: String
        switch frame.worldMappingStatus {
        case .notAvailable: mappingStatus = "Not Available"
        case .limited: mappingStatus = "Limited"
        case .extending: mappingStatus = "Extending"
        case .mapped: mappingStatus = "Mapped"
        @unknown default: mappingStatus = "Unknown"
        }

        // Light estimate
        let lightInfo: String
        if let light = frame.lightEstimate {
            lightInfo = String(format: "%.0f lux", light.ambientIntensity)
        } else {
            lightInfo = "N/A"
        }

        self.frameInfo = """
        Pos: (\(String(format: "%.2f", pos.x)), \(String(format: "%.2f", pos.y)), \(String(format: "%.2f", pos.z)))
        World Map: \(mappingStatus)
        Light: \(lightInfo)
        Features: \(frame.rawFeaturePoints?.points.count ?? 0)
        """
    }
}

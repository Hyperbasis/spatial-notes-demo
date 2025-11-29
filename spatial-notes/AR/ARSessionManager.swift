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
            log(debugModeEnabled ? "Debug mode enabled" : "Debug mode disabled", level: .info)
        }
    }

    /// Number of detected planes
    @Published var planeCount: Int = 0

    /// Number of tracked anchors
    @Published var anchorCount: Int = 0

    /// Current frame info
    @Published var frameInfo: String = ""

    /// Debug logs
    @Published var logs: [LogEntry] = []

    /// Maximum logs to keep
    private let maxLogs = 100

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Logging

    func log(_ message: String, level: LogEntry.LogLevel = .debug) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        // Also print to console for Xcode debugging
        print("[\(level.rawValue)] \(message)")
    }

    // MARK: - Initialization

    override init() {
        arView = ARView(frame: .zero)
        super.init()
        setupARSession()
        setupSubscriptions()
        log("ARSessionManager initialized", level: .info)
    }

    // MARK: - Setup

    private func setupARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        log("Starting AR session with plane detection: [horizontal, vertical]", level: .info)
        arView.session.run(config)
    }

    private func setupSubscriptions() {
        arView.session.delegate = self
        log("AR session delegate configured", level: .debug)
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
        log("Raycast from screen point: (\(String(format: "%.0f", point.x)), \(String(format: "%.0f", point.y)))", level: .debug)

        // Try existing plane geometry first for best accuracy
        var results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .any)
        var hitType = "existingPlaneGeometry"

        // Fall back to existing plane infinite (extends beyond detected bounds)
        if results.isEmpty {
            results = arView.raycast(from: point, allowing: .existingPlaneInfinite, alignment: .any)
            hitType = "existingPlaneInfinite"
        }

        // Last resort: estimated plane
        if results.isEmpty {
            results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any)
            hitType = "estimatedPlane"
        }

        guard let result = results.first else {
            log("Raycast MISSED - no surface found at tap location", level: .warning)
            return nil
        }

        let position = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )

        // Determine surface type
        let surfaceType: String
        if let planeAnchor = result.anchor as? ARPlaneAnchor {
            surfaceType = planeAnchor.alignment == .horizontal ? "horizontal" : "vertical"
        } else {
            surfaceType = "estimated"
        }

        // Calculate distance from camera
        let cameraPos = arView.cameraTransform.matrix.columns.3
        let distance = simd_distance(
            SIMD3<Float>(cameraPos.x, cameraPos.y, cameraPos.z),
            position
        )

        if distance < 0.3 {
            log("Raycast HIT: \(hitType) (\(surfaceType)) - WARNING: only \(String(format: "%.0f", distance * 100))cm away!", level: .warning)
        } else {
            log("Raycast HIT: \(hitType) (\(surfaceType)) at \(String(format: "%.1f", distance))m away", level: .info)
        }

        return (position, result.worldTransform)
    }

    /// Adds an entity to the AR scene anchored to a surface
    func addEntity(_ entity: Entity, at position: SIMD3<Float>, transform: simd_float4x4? = nil) {
        // Calculate distance for logging
        let cameraPos = arView.cameraTransform.matrix.columns.3
        let distance = simd_distance(
            SIMD3<Float>(cameraPos.x, cameraPos.y, cameraPos.z),
            position
        )

        if let transform = transform {
            // Create an ARAnchor at the exact raycast hit point for stable tracking
            let arAnchor = ARAnchor(name: "note", transform: transform)
            arView.session.add(anchor: arAnchor)

            // Create AnchorEntity attached to the AR anchor
            let anchorEntity = AnchorEntity(anchor: arAnchor)
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)

            log("Placed note \(String(format: "%.1f", distance))m from camera (anchored to surface)", level: .info)
        } else {
            // Fallback for loaded notes without transform
            let anchor = AnchorEntity(world: position)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            log("Placed note \(String(format: "%.1f", distance))m from camera (world position)", level: .info)
        }
    }

    /// Removes an entity from the AR scene
    func removeEntity(_ entity: Entity) {
        entity.anchor?.removeFromParent()
        log("Removed entity from scene", level: .info)
    }

    /// Pauses the AR session
    func pause() {
        arView.session.pause()
        log("AR session paused", level: .info)
    }

    /// Resumes the AR session
    func resume() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        log("AR session resumed", level: .info)
    }

    // MARK: - World Map

    /// Gets the current world map from the AR session
    func getCurrentWorldMap() async throws -> ARWorldMap {
        log("Capturing world map...", level: .info)
        let worldMap = try await arView.session.currentWorldMap()
        log("World map captured: \(worldMap.anchors.count) anchors, \(worldMap.rawFeaturePoints.points.count) feature points", level: .info)
        return worldMap
    }

    /// Checks if a world map can be captured
    var canCaptureWorldMap: Bool {
        guard case .normal = trackingState else { return false }
        return surfaceDetected
    }

    /// Relocalizes the AR session using a saved world map
    func relocalize(with worldMap: ARWorldMap) {
        log("Starting relocalization with saved world map (\(worldMap.anchors.count) anchors)", level: .info)
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
                self.log("Tracking: NORMAL", level: .info)
                // Check if we were relocalizing
                if self.isRelocalizing {
                    self.isRelocalized = true
                    self.isRelocalizing = false
                    self.log("Relocalization SUCCESS - space recognized", level: .info)
                }
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.errorMessage = "Initializing AR..."
                    self.log("Tracking: LIMITED (initializing)", level: .warning)
                case .excessiveMotion:
                    self.errorMessage = "Slow down"
                    self.log("Tracking: LIMITED (excessive motion - slow down!)", level: .warning)
                case .insufficientFeatures:
                    self.errorMessage = "Point at more textured surfaces"
                    self.log("Tracking: LIMITED (insufficient features - need more texture)", level: .warning)
                case .relocalizing:
                    self.errorMessage = "Relocalizing - look around the room..."
                    self.isRelocalizing = true
                    self.log("Tracking: LIMITED (relocalizing - looking for saved map)", level: .info)
                @unknown default:
                    self.errorMessage = "Limited tracking"
                    self.log("Tracking: LIMITED (unknown reason)", level: .warning)
                }
            case .notAvailable:
                self.errorMessage = "AR not available"
                self.log("Tracking: NOT AVAILABLE", level: .error)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Extract all data we need BEFORE the async task to avoid retaining ARFrame
        let currentAnchors = session.currentFrame?.anchors ?? []
        let planeCount = currentAnchors.filter { $0 is ARPlaneAnchor }.count
        let anchorCount = currentAnchors.count

        // Extract info about new anchors
        var planeInfos: [(alignment: String, width: Float, height: Float)] = []
        var hasPlane = false
        var hasNoteAnchor = false

        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let alignment = planeAnchor.alignment == .horizontal ? "horizontal" : "vertical"
                planeInfos.append((alignment, planeAnchor.extent.x, planeAnchor.extent.z))
                hasPlane = true
            } else if anchor.name == "note" {
                hasNoteAnchor = true
            }
        }

        Task { @MainActor in
            self.planeCount = planeCount
            self.anchorCount = anchorCount
            if hasPlane {
                self.surfaceDetected = true
            }
            for info in planeInfos {
                self.log("Plane detected: \(info.alignment) (\(String(format: "%.2f", info.width))m x \(String(format: "%.2f", info.height))m)", level: .info)
            }
            if hasNoteAnchor {
                self.log("Note anchor added", level: .debug)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Extract counts BEFORE async task
        let currentAnchors = session.currentFrame?.anchors ?? []
        let planeCount = currentAnchors.filter { $0 is ARPlaneAnchor }.count
        let anchorCount = currentAnchors.count

        Task { @MainActor in
            self.planeCount = planeCount
            self.anchorCount = anchorCount
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Extract data BEFORE async task
        let currentAnchors = session.currentFrame?.anchors ?? []
        let planeCount = currentAnchors.filter { $0 is ARPlaneAnchor }.count
        let anchorCount = currentAnchors.count

        var removedPlanes: [String] = []
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let alignment = planeAnchor.alignment == .horizontal ? "horizontal" : "vertical"
                removedPlanes.append(alignment)
            }
        }

        Task { @MainActor in
            for alignment in removedPlanes {
                self.log("Plane removed: \(alignment)", level: .warning)
            }
            self.planeCount = planeCount
            self.anchorCount = anchorCount
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Capture only the values we need - don't retain the ARFrame itself
        let cameraTransform = frame.camera.transform
        let worldMappingStatus = frame.worldMappingStatus
        let lightEstimate = frame.lightEstimate
        let featurePointCount = frame.rawFeaturePoints?.points.count ?? 0

        Task { @MainActor in
            if self.debugModeEnabled {
                self.updateFrameInfoFromValues(
                    cameraTransform: cameraTransform,
                    worldMappingStatus: worldMappingStatus,
                    lightEstimate: lightEstimate,
                    featurePointCount: featurePointCount
                )
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.log("AR Session FAILED: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Debug Helpers

    private func updateFrameInfoFromValues(
        cameraTransform: simd_float4x4,
        worldMappingStatus: ARFrame.WorldMappingStatus,
        lightEstimate: ARLightEstimate?,
        featurePointCount: Int
    ) {
        let pos = cameraTransform.columns.3

        // World mapping status
        let mappingStatus: String
        switch worldMappingStatus {
        case .notAvailable: mappingStatus = "Not Available"
        case .limited: mappingStatus = "Limited"
        case .extending: mappingStatus = "Extending"
        case .mapped: mappingStatus = "Mapped"
        @unknown default: mappingStatus = "Unknown"
        }

        // Light estimate
        let lightInfo: String
        if let light = lightEstimate {
            lightInfo = String(format: "%.0f lux", light.ambientIntensity)
        } else {
            lightInfo = "N/A"
        }

        self.frameInfo = """
        Pos: (\(String(format: "%.2f", pos.x)), \(String(format: "%.2f", pos.y)), \(String(format: "%.2f", pos.z)))
        World Map: \(mappingStatus)
        Light: \(lightInfo)
        Features: \(featurePointCount)
        """
    }
}

import UIKit
import ARKit
import RealityKit
import QuickLook

class ViewController: UIViewController {
    
    private var arView: ARView!
    private var environmentTexturingMode: ARWorldTrackingConfiguration.EnvironmentTexturing = .automatic
    private var sceneEntity: Entity?
    
    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Export USDZ", for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupUI()
        startARSession()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
    }
    
    private func setupUI() {
        view.addSubview(exportButton)
        
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            exportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            exportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 200),
            exportButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = environmentTexturingMode
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .mesh // Sử dụng LiDAR
        
        arView.session.run(configuration)
        
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
    }
    
    @objc private func exportButtonTapped() {
        showPreview()
    }
    
    private func showPreview() {
        guard let currentFrame = arView.session.currentFrame else {
            showAlert(message: "No AR frame available")
            return
        }
        
        var meshAnchors: [ARMeshAnchor] = []
        
        // Collect all mesh anchors
        if let anchors = currentFrame.anchors as? [ARMeshAnchor] {
            meshAnchors.append(contentsOf: anchors)
        }
        
        // Create a RealityKit scene and add the mesh anchors
        let entity = try! Entity.load(from: meshAnchors)
        
        // Apply environment texturing
        let textureResource = try! TextureResource.generate(from: currentFrame.capturedImage)
        let material = UnlitMaterial(baseColor: .init(textureResource))
        entity.model?.materials = [material]
        
        // Store the entity for later export
        sceneEntity = entity
        
        // Display the preview in a new ARView
        let previewVC = PreviewViewController()
        previewVC.setupPreview(with: entity)
        present(previewVC, animated: true, completion: nil)
    }
    
    private func exportScene() {
        guard let sceneEntity = sceneEntity else {
            showAlert(message: "No scene to export")
            return
        }
        
        // Create a RealityKit scene
        let scene = try! Scene()
        scene.addAnchor(sceneEntity)
        
        // Export the scene as a USDZ file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("exported_scene.usdz")
        
        do {
            try scene.export(to: url)
            showAlert(message: "Scene exported successfully", title: "Success")
        } catch {
            showAlert(message: "Failed to export scene: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(message: String, title: String = "Error") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension Entity {
    static func load(from meshAnchors: [ARMeshAnchor]) throws -> Entity {
        let entity = Entity()
        
        for anchor in meshAnchors {
            let vertices = anchor.geometry.vertices
            let faces = anchor.geometry.faces
            let normals = anchor.geometry.normals
            
            var meshVertices: [SIMD3<Float>] = []
            var meshIndices: [UInt32] = []
            
            for i in 0..<vertices.count {
                let vertex = vertices[i]
                meshVertices.append(vertex)
            }
            
            for i in 0..<faces.count {
                let face = faces[i]
                meshIndices.append(contentsOf: face.indices)
            }
            
            let mesh = MeshResource.generate(from: meshVertices, indices: meshIndices, normals: normals)
            let meshEntity = ModelEntity(mesh: mesh)
            
            entity.addChild(meshEntity)
        }
        
        return entity
    }
}

extension MeshResource {
    static func generate(from vertices: [SIMD3<Float>], indices: [UInt32], normals: [SIMD3<Float>]) -> MeshResource {
        var geometryDescriptor = MeshDescriptor(name: "scannedMesh")
        
        geometryDescriptor.positions = MeshBuffer(vertices)
        geometryDescriptor.normals = MeshBuffer(normals)
        geometryDescriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [geometryDescriptor])
    }
}

class PreviewViewController: UIViewController {
    private var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
    }
    
    func setupPreview(with entity: Entity) {
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(entity)
        arView.scene.anchors.append(anchor)
        
        // Add a button to export the scene
        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Export USDZ", for: .normal)
        exportButton.backgroundColor = UIColor.systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 8
        exportButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        
        view.addSubview(exportButton)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            exportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            exportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 200),
            exportButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func exportButtonTapped() {
        guard let presentingVC = presentingViewController as? ViewController else { return }
        presentingVC.exportScene()
        dismiss(animated: true, completion: nil)
    }
}

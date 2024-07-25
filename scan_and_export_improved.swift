import UIKit
import ARKit
import RealityKit
import QuickLook
import UniformTypeIdentifiers

class ViewController: UIViewController, ARSessionDelegate, UIDocumentPickerDelegate {
    
    private var arView: ARView!
    private var environmentTexturingMode: ARWorldTrackingConfiguration.EnvironmentTexturing = .automatic
    private var sceneEntity: Entity?
    private var meshAnchors: [ARMeshAnchor] = []
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.backgroundColor = UIColor.systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStartScreen()
    }
    
    private func setupStartScreen() {
        let startButton = UIButton(type: .system)
        startButton.setTitle("START", for: .normal)
        startButton.backgroundColor = UIColor.systemGreen
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        
        view.addSubview(startButton)
        
        startButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func startButtonTapped() {
        setupARView()
        setupUI()
        startARSession()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.session.delegate = self
        view.addSubview(arView)
    }
    
    private func setupUI() {
        view.addSubview(doneButton)
        view.addSubview(cancelButton)
        
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.widthAnchor.constraint(equalToConstant: 100),
            doneButton.heightAnchor.constraint(equalToConstant: 40),
            
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = environmentTexturingMode
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .mesh
        
        arView.session.run(configuration)
        
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
    }
    
    @objc private func doneButtonTapped() {
        showPreview()
    }
    
    @objc private func cancelButtonTapped() {
        let alertController = UIAlertController(title: "Confirmation", message: "Do you want to return to the Main screen?", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.arView.session.pause()
            self.dismiss(animated: true, completion: nil)
            self.setupStartScreen()
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    private func showPreview() {
        arView.session.pause()
        
        guard !meshAnchors.isEmpty else {
            showAlert(message: "No AR frame available")
            return
        }
        
        let entity = try! Entity.load(from: meshAnchors)
        
        let currentFrame = arView.session.currentFrame!
        let textureResource = try! TextureResource.generate(from: currentFrame.capturedImage)
        let material = UnlitMaterial(baseColor: .init(textureResource))
        entity.model?.materials = [material]
        
        sceneEntity = entity
        
        let previewVC = PreviewViewController()
        previewVC.setupPreview(with: entity)
        present(previewVC, animated: true, completion: nil)
    }
    
    private func exportScene() {
        guard let sceneEntity = sceneEntity else {
            showAlert(message: "No scene to export")
            return
        }
        
        let scene = try! Scene()
        scene.addAnchor(sceneEntity)
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("exported_scene.usdz")])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("exported_scene.usdz")
        
        do {
            try scene.export(to: tempURL)
        } catch {
            showAlert(message: "Failed to export scene: \(error.localizedDescription)")
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            showAlert(message: "No URL selected")
            return
        }
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("exported_scene.usdz")
        
        do {
            try FileManager.default.moveItem(at: tempURL, to: url)
            showAlert(message: "Scene exported successfully", title: "Success")
        } catch {
            showAlert(message: "Failed to move file: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(message: String, title: String = "Error") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
                renderMesh(for: meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                renderMesh(for: meshAnchor)
            }
        }
    }
    
    private func renderMesh(for meshAnchor: ARMeshAnchor) {
        let meshGeometry = meshAnchor.geometry
        let vertices = meshGeometry.vertices
        let faces = meshGeometry.faces
        let normals = meshGeometry.normals
        
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
        
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        meshEntity.model?.materials = [material]
        
        if let existingEntity = arView.scene.anchors.first(where: { $0.identifier == meshAnchor.identifier }) {
            existingEntity.children.removeAll()
            existingEntity.addChild(meshEntity)
        } else {
            let anchorEntity = AnchorEntity(anchor: meshAnchor)
            anchorEntity.addChild(meshEntity)
            arView.scene.addAnchor(anchorEntity)
        }
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
        
        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Export USDZ", for: .normal)
        exportButton.backgroundColor = UIColor.systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 8
        exportButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        
        view.addSubview(exportButton)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            exportButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
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

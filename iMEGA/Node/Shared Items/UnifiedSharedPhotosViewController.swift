import ContentLibraries
import MEGAAppSDKRepo
import MEGAAssets
import MEGADomain
import MEGARepo
import MEGAL10n
import UIKit

@MainActor
final class UnifiedSharedPhotosViewController: UIViewController, PhotoLibraryProvider {
    private let incomingNodes: [MEGANode]
    private let mediaDiscoveryUseCase: any MediaDiscoveryUseCaseProtocol
    private var loadTask: Task<Void, Never>?
    
    lazy var photoLibraryContentViewModel = PhotoLibraryContentViewModel(
        library: PhotoLibrary(),
        contentMode: .mediaDiscoverySharedItems
    )
    private lazy var emptyView = EmptyStateView(
        forHomeWith: MEGAAssets.UIImage.allPhotosEmptyState,
        title: Strings.localized("sharedPhotos.empty.title", comment: "Empty state title for shared photos."),
        description: nil,
        buttonTitle: nil
    )
    
    init(
        incomingNodes: [MEGANode],
        mediaDiscoveryUseCase: some MediaDiscoveryUseCaseProtocol = MediaDiscoveryUseCase(
            filesSearchRepository: FilesSearchRepository(sdk: MEGASdk.shared),
            nodeUpdateRepository: NodeUpdateRepository.newRepo)
    ) {
        self.incomingNodes = incomingNodes
        self.mediaDiscoveryUseCase = mediaDiscoveryUseCase
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = Strings.localized("sharedPhotos.title", comment: "Title for shared photos gallery.")
        
        configPhotoLibraryView(
            in: view,
            router: PhotoLibraryContentViewRouter(
                contentMode: photoLibraryContentViewModel.contentMode))
        
        loadUnifiedSharedPhotos()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        loadTask?.cancel()
    }
    
    func hideNavigationEditBarButton(_ hide: Bool) { }
    
    // MARK: - Private
    
    private func loadUnifiedSharedPhotos() {
        loadTask?.cancel()
        
        let decryptedNodes = incomingNodes.filter { $0.isNodeKeyDecrypted() && $0.isFolder() }
        guard decryptedNodes.isNotEmpty else {
            applyLoadedNodes([])
            return
        }
        
        loadTask = Task { [weak self] in
            guard let self else { return }
            let nodes = await loadMediaNodes(from: decryptedNodes)
            guard !Task.isCancelled else { return }
            applyLoadedNodes(nodes)
        }
    }
    
    private func loadMediaNodes(from nodes: [MEGANode]) async -> [NodeEntity] {
        var uniqueNodes = [HandleEntity: NodeEntity]()
        
        for node in nodes {
            if Task.isCancelled {
                break
            }
            do {
                let loadedNodes = try await mediaDiscoveryUseCase.nodes(
                    forParent: node.toNodeEntity(),
                    recursive: true,
                    excludeSensitive: false
                )
                for loadedNode in loadedNodes {
                    uniqueNodes[loadedNode.handle] = loadedNode
                }
            } catch {
                // Skip failing node queries and continue loading the rest.
            }
        }
        
        return Array(uniqueNodes.values)
    }
    
    private func applyLoadedNodes(_ nodes: [NodeEntity]) {
        photoLibraryContentViewModel.library = nodes.toPhotoLibrary(withSortType: .modificationDesc)
        updateEmptyState(isEmpty: nodes.isEmpty)
    }
    
    private func updateEmptyState(isEmpty: Bool) {
        if isEmpty {
            showEmptyView()
        } else {
            emptyView.removeFromSuperview()
        }
    }
    
    private func showEmptyView() {
        guard emptyView.superview == nil else { return }
        
        view.addSubview(emptyView)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
}

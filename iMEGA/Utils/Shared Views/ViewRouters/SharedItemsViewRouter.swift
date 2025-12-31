import MEGADomain
import UIKit

@MainActor
final class SharedItemsViewRouter: NSObject {
    
    func showShareFoldersContactView(withNodes nodes: [NodeEntity]) {
        let megaNodes = nodes.compactMap {
            MEGASdk.shared.node(forHandle: $0.handle)
        }
        showShareFoldersContactView(withNodes: megaNodes)
    }
    
    func showShareFoldersContactView(withNodes nodes: [MEGANode]) {
        NodeShareRouter(viewController: UIApplication.mnz_visibleViewController())
            .showSharingFolders(for: nodes)
    }
    
    @objc func showPendingOutShareModal(for email: String) {
        CustomModalAlertRouter(.pendingUnverifiedOutShare,
                               presenter: UIApplication.mnz_presentingViewController(),
                               outShareEmail: email).start()
    }

    func showUnifiedSharedPhotos(nodes: [MEGANode]) {
        guard let navigationController = UIApplication.mnz_visibleViewController().navigationController else {
            return
        }
        
        let viewController = UnifiedSharedPhotosViewController(incomingNodes: nodes)
        navigationController.pushViewController(viewController, animated: true)
    }
    
}

import SwiftUI
import UIKit

struct CatchPhotoPager: UIViewControllerRepresentable {
    let items: [CatchPhotoGalleryItem]
    let photoURL: (CatchPhotoItem) -> URL?
    @Binding var selectedPhotoID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        let coordinator = context.coordinator
        let index = items.firstIndex { $0.id == selectedPhotoID } ?? 0
        if let page = coordinator.page(at: index) {
            pager.setViewControllers([page], direction: .forward, animated: false)
        }
        pager.dataSource = coordinator
        pager.delegate = coordinator
        return pager
    }

    func updateUIViewController(_: UIPageViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: CatchPhotoPager

        init(parent: CatchPhotoPager) {
            self.parent = parent
        }

        fileprivate func page(at index: Int) -> ZoomableCatchPhoto? {
            guard parent.items.indices.contains(index) else { return nil }
            let item = parent.items[index]
            return ZoomableCatchPhoto(index: index, item: item, url: parent.photoURL(item.photo))
        }

        func pageViewController(
            _: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let current = viewController as? ZoomableCatchPhoto else { return nil }
            return page(at: current.index - 1)
        }

        func pageViewController(
            _: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let current = viewController as? ZoomableCatchPhoto else { return nil }
            return page(at: current.index + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating _: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let current = pageViewController.viewControllers?.first as? ZoomableCatchPhoto
            else { return }

            (previousViewControllers.first as? ZoomableCatchPhoto)?.resetZoom()
            parent.selectedPhotoID = parent.items[current.index].id
        }
    }
}

private final class ZoomableCatchPhoto: UIViewController, UIScrollViewDelegate {
    let index: Int
    private let item: CatchPhotoGalleryItem
    private let url: URL?
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private lazy var placeholder = UIHostingController(
        rootView: CatchPhotoPlaceholder(species: item.catchItem.species)
    )
    private var loading: Task<Void, Never>?
    private var fittedSize: CGSize = .zero

    init(index: Int, item: CatchPhotoGalleryItem, url: URL?) {
        self.index = index
        self.item = item
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.maximumZoomScale = 4
        scrollView.delegate = self
        scrollView.panGestureRecognizer.isEnabled = false
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.isHidden = true
        view.addSubview(scrollView)

        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityIdentifier = "photo.viewer.image"
        imageView.accessibilityLabel = item.accessibilityLabel
        imageView.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Zoom in or out") { [weak self] _ in
                guard let self else { return false }
                toggleZoom(at: CGPoint(x: imageView.bounds.midX, y: imageView.bounds.midY))
                return true
            }
        ]
        scrollView.addSubview(imageView)

        addChild(placeholder)
        placeholder.view.frame = view.bounds
        placeholder.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholder.view.backgroundColor = .clear
        view.addSubview(placeholder.view)
        placeholder.didMove(toParent: self)

        guard let url else { return }
        loading = Task { [weak self] in
            let decoded = await Task.detached(priority: .userInitiated) {
                PhotoDownsampler.image(at: url, maximumPixelSize: 2400)
            }.value
            guard let self, let decoded, !Task.isCancelled else { return }
            imageView.image = UIImage(cgImage: decoded)
            placeholder.view.isHidden = true
            scrollView.isHidden = false
            view.setNeedsLayout()
        }
    }

    deinit {
        loading?.cancel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = scrollView.bounds.size
        guard let image = imageView.image, size != fittedSize, size.width > 0, size.height > 0 else { return }
        fittedSize = size
        resetZoom()
        let fit = min(size.width / image.size.width, size.height / image.size.height)
        imageView.frame.size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
        scrollView.contentSize = imageView.frame.size
        centerImage()
    }

    func resetZoom() {
        scrollView.setZoomScale(1, animated: false)
        scrollView.panGestureRecognizer.isEnabled = false
        imageView.accessibilityValue = "Fit to screen"
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        let isZoomed = scrollView.zoomScale > 1.001
        if scrollView.panGestureRecognizer.isEnabled != isZoomed {
            scrollView.panGestureRecognizer.isEnabled = isZoomed
        }
        imageView.accessibilityValue = isZoomed ? "Zoomed in" : "Fit to screen"
        centerImage()
    }

    private func centerImage() {
        let viewport = scrollView.bounds.size
        imageView.center = CGPoint(
            x: max(viewport.width, imageView.frame.width) / 2,
            y: max(viewport.height, imageView.frame.height) / 2
        )
    }

    @objc private func doubleTap(_ recognizer: UITapGestureRecognizer) {
        toggleZoom(at: recognizer.location(in: imageView))
    }

    private func toggleZoom(at point: CGPoint) {
        if scrollView.zoomScale > 1.001 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            let width = scrollView.bounds.width / 2.5
            let height = scrollView.bounds.height / 2.5
            scrollView.zoom(
                to: CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height),
                animated: true
            )
        }
    }
}

// CroppedImagesViewController.swift
import UIKit

class CroppedImagesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    // IBOutlets from Storyboard

    @IBOutlet weak var tableView: UITableView!
//    @IBOutlet weak var hoveringTabButton: UIButton!
//    
//    private var croppedHistory: [(carImage: UIImage, plateImage: UIImage)] = []
    override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            
            title = "Cropped History"
            navigationItem.backButtonTitle = ""
            
            // Explicitly set tableView dataSource and delegate
            tableView.dataSource = self
            tableView.delegate = self
            tableView.register(CroppedImageCell.self, forCellReuseIdentifier: "CroppedImageCell")

            NotificationCenter.default.addObserver(self, selector: #selector(updateImages), name: NSNotification.Name("CroppedImagesUpdated"), object: nil)
            
            // Debug: Check initial history count on load
            print("CroppedImagesViewController loaded with history count: \(ViewController.croppedHistory.count)")
            tableView.reloadData() // Ensure initial data is displayed
        }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .white
//        
//        title = "Cropped History"
//        navigationItem.backButtonTitle = ""
//        
//        // Configure table view
//        tableView.dataSource = self
//        tableView.delegate = self
//        tableView.register(CroppedImageCell.self, forCellReuseIdentifier: "CroppedImageCell")
//        
//        // Configure hovering tab button
////        hoveringTabButton.setImage(UIImage(systemName: "video"), for: .normal)
//        hoveringTabButton.tintColor = .white
//        hoveringTabButton.backgroundColor = .systemBlue
//        hoveringTabButton.layer.cornerRadius = 25
//        hoveringTabButton.layer.shadowColor = UIColor.black.cgColor
//        hoveringTabButton.layer.shadowOpacity = 0.5
//        hoveringTabButton.layer.shadowOffset = CGSize(width: 0, height: 2)
//        hoveringTabButton.layer.shadowRadius = 4
//        
//        NotificationCenter.default.addObserver(self, selector: #selector(updateImages), name: NSNotification.Name("CroppedImagesUpdated"), object: nil)
//    }
//    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
//    
//    @IBAction func returnToVideoView(_ sender: UIButton) {
//        print("Hovering tab button tapped in CroppedImagesViewController")
//        navigationController?.popViewController(animated: true)
//    }
    
    
    @objc private func updateImages(notification: Notification) {
        if let userInfo = notification.userInfo,
           let history = userInfo["history"] as? [(carImage: UIImage, plateImage: UIImage)] {
            // Optional: Store locally if needed, but here we use the shared history directly
            tableView.reloadData()
        } else {
            tableView.reloadData() // Reload even if no new update to reflect current state
        }
    }
    
    // UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ViewController.croppedHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CroppedImageCell", for: indexPath) as! CroppedImageCell
        let entry = ViewController.croppedHistory[indexPath.row]
        cell.carImageView.image = entry.carImage
        cell.plateImageView.image = entry.plateImage
        return cell
    }
    // UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200 // Adjust height as needed
    }
}

// Custom UITableViewCell for cropped images
class CroppedImageCell: UITableViewCell {
    let carImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // Scale to fit while preserving aspect ratio
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .white
        return imageView
    }()
    
    let plateImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // Scale to fit while preserving aspect ratio
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .white
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(carImageView)
        contentView.addSubview(plateImageView)
        
        NSLayoutConstraint.activate([
            // Car Image View
            carImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            carImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            carImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            carImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.45), // Half width minus padding
            
            // Plate Image View
            plateImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            plateImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            plateImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            plateImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.45) // Half width minus padding
        ])
    }
}

//
//  SceneDelegate.swift
//  lightcompressorsample
//
//  Created by AbedElaziz shehadeh on 28/08/2020.
//  Copyright © 2020 AbedElaziz shehadeh. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVKit
import Photos
import LightCompressor

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIImageView!
    @IBOutlet weak var originalSize: UILabel!
    @IBOutlet weak var sizeAfterCompression: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var progressView: UIStackView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    private var imagePickerController: UIImagePickerController?
    private var compression: Compression?
    
    private var compressedPath: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // create tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(gesture:)))
        
        // add it to the image view;
        videoView.addGestureRecognizer(tapGesture)
        // make sure imageView can be interacted with by user
        videoView.isUserInteractionEnabled = true
        
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.imagePickerController?.dismiss(animated: true, completion: nil)
        
        // Get source video
        let videoToCompress = info[UIImagePickerController.InfoKey(rawValue: "UIImagePickerControllerMediaURL")] as! URL
        
        let thumbnail = createThumbnailOfVideoFromFileURL(videoURL: videoToCompress.absoluteString)
        videoView.image = UIImage(cgImage: thumbnail!)
        
        DispatchQueue.main.async { [unowned self] in
            self.originalSize.isHidden = false
            self.originalSize.text = "Original size: \(videoToCompress.fileSizeInMB())"
        }
        
        // Declare destination path and remove anything exists in it
        let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("compressed.mp4")
        try? FileManager.default.removeItem(at: destinationPath)
        
        let startingPoint = Date()
        let videoCompressor = LightCompressor()
        
        compression = videoCompressor.compressVideo(videos: [.init(source: videoToCompress, destination: destinationPath, configuration: .init(quality: VideoQuality.very_high, videoBitrateInMbps: 5, disableAudio: false, keepOriginalResolution: false, videoSize: CGSize(width: 360, height: 480) ))],
                                                   progressQueue: .main,
                                                   progressHandler: { progress in
                                                    DispatchQueue.main.async { [unowned self] in
                                                        self.progressBar.progress = Float(progress.fractionCompleted)
                                                        self.progressLabel.text = "\(String(format: "%.0f", progress.fractionCompleted * 100))%"
                                                    }},
                                                   
                                                   completion: {[weak self] result in
                                                    guard let `self` = self else { return }
                                                    
                                                    switch result {
                                                        
                                                    case .onSuccess(let index, let path):
                                                        self.compressedPath = path
                                                        DispatchQueue.main.async { [unowned self] in
                                                            self.sizeAfterCompression.isHidden = false
                                                            self.duration.isHidden = false
                                                            self.progressBar.isHidden = true
                                                            self.progressLabel.isHidden = true
                                                            
                                                            self.sizeAfterCompression.text = "Size after compression: \(path.fileSizeInMB())"
                                                            self.duration.text = "Duration: \(String(format: "%.2f", startingPoint.timeIntervalSinceNow * -1)) seconds"
                                                            
                                                            PHPhotoLibrary.shared().performChanges({
                                                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
                                                            })
                                                        }
                                                        
                                                    case .onStart:
                                                        self.progressBar.isHidden = false
                                                        self.progressLabel.isHidden = false
                                                        self.sizeAfterCompression.isHidden = true
                                                        self.duration.isHidden = true
                                                        //self.originalSize.visiblity(gone: false)
                                                        
                                                    case .onFailure(let index, let error):
                                                        self.progressBar.isHidden = true
                                                        self.progressLabel.isHidden = false
                                                        self.progressLabel.text = (error as! CompressionError).title
                                                        
                                                        
                                                    case .onCancelled:
                                                        print("---------------------------")
                                                        print("Cancelled")
                                                        print("---------------------------")
                                                    }
        })
        
    }
    
    @IBAction func pickVideoPressed(_ sender: UIButton) {
        
        DispatchQueue.main.async { [unowned self] in
            self.imagePickerController = UIImagePickerController()
            self.imagePickerController?.delegate = self
            self.imagePickerController?.sourceType = .photoLibrary
            self.imagePickerController?.mediaTypes = ["public.movie"]
            self.imagePickerController?.videoQuality = UIImagePickerController.QualityType.typeHigh
            self.imagePickerController?.videoExportPreset = AVAssetExportPresetPassthrough
            self.present(self.imagePickerController!, animated: true, completion: nil)
        }
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        compression?.cancel = true
    }
    
    @objc func imageTapped(gesture: UIGestureRecognizer) {
        // if the tapped view is a UIImageView then set it to imageview
        if (gesture.view as? UIImageView) != nil {
            
            DispatchQueue.main.async { [unowned self] in
                let player = AVPlayer(url: self.compressedPath! as URL)
                let controller = AVPlayerViewController()
                controller.player = player
                self.present(controller, animated: true) {
                    player.play()
                }
            }
            
        }
    }
    
    func createThumbnailOfVideoFromFileURL(videoURL: String) -> CGImage? {
        let asset = AVAsset(url: URL(string: videoURL)!)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time = CMTimeMakeWithSeconds(Float64(1), preferredTimescale: 100)
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            return img
        } catch {
            return nil
        }
    }
}


extension URL {
    func fileSizeInMB() -> String {
        let p = self.path
        
        let attr = try? FileManager.default.attributesOfItem(atPath: p)
        
        if let attr = attr {
            let fileSize = Float(attr[FileAttributeKey.size] as! UInt64) / (1024.0 * 1024.0)
            
            return String(format: "%.2f MB", fileSize)
        } else {
            return "Failed to get size"
        }
    }
}

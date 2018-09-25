//
//  ViewController.swift
//  Vision Detection
//
//  Created by Huy Trinh Duc on 9/25/18.
//  Copyright © 2018 Huy Trinh Duc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState {
    case off
    case on
}

class CameraViewController: UIViewController {

    @IBOutlet weak var mCaptureImageView: UIImageView!
    
    @IBAction func onTouchedFlashButton(_ sender: Any) {
        switch flashControlState {
        case .off:
            mFlashBtn.setTitle("FLASH ON", for: .normal)
            flashControlState = .on
        case .on:
            mFlashBtn.setTitle("FLASH OFF", for: .normal)
            flashControlState = .off
        }
    }
    
    @IBOutlet weak var mFlashBtn: UIButton!
    
    @IBOutlet weak var mSpinnerLoading: UIActivityIndicatorView!
    
    @IBOutlet weak var mCameraView: UIView!
    
    @IBOutlet weak var mLabelNameItem: UILabel!
    
    @IBOutlet weak var mLabelConfidence: UILabel!
    
    var captureSession: AVCaptureSession!
    var cameraOuput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var photoData: Data?
    var flashControlState: FlashState = .off
    
    var speechSynthesizer = AVSpeechSynthesizer()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    //Hieu ung mo camera
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer.frame = mCameraView.bounds
        speechSynthesizer.delegate = self
        mSpinnerLoading.isHidden = true
        
    }
    
    //Mo camera session
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        tap.numberOfTapsRequired = 1

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do
        {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) == true
            {
                captureSession.addInput(input)
            }
            cameraOuput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOuput) == true
            {
                captureSession.addOutput(cameraOuput!)
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                mCameraView.layer.addSublayer(previewLayer!)
                mCameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
        }
        catch
        {
            print("Error camera")
        }
        
    }
    
    //function xu ly giong noi
    func synthesizeSpeech(fromString string: String) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterance)
    }
    
    @objc func didTapCameraView()
    {
        self.mCameraView.isUserInteractionEnabled = false
        self.mSpinnerLoading.isHidden = false
        self.mSpinnerLoading.startAnimating()
        
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType, kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 160]
        
        settings.previewPhotoFormat = previewFormat
        
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOuput.capturePhoto(with: settings, delegate: self)
    }
    
    //hien thi ket qua nhan dien
    func resultsMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        for classification in results {
            if classification.confidence < 0.5 {
                let unknownObjectMessage = "I'm not sure what is this, please try again."
                self.mLabelNameItem.text = unknownObjectMessage
                synthesizeSpeech(fromString: unknownObjectMessage)
                self.mLabelConfidence.text = ""
                break
            } else {
                let identification = classification.identifier
                let confidence = Int(classification.confidence * 100)
                self.mLabelNameItem.text = identification
                self.mLabelConfidence.text = "CONFIDENCE: \(confidence)%"
                let completeSentence = "This looks like a \(identification) and I'm \(confidence) percent sure."
                synthesizeSpeech(fromString: completeSentence)
                break
            }
        }
    }
}
//khai bao coreml
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            self.mCaptureImageView.image = image
        }
    }
}
extension CameraViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.mCameraView.isUserInteractionEnabled = true
        self.mSpinnerLoading.isHidden = true
        self.mSpinnerLoading.stopAnimating()
    }
}

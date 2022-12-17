# LightCompressor

A powerful and easy-to-use video compression swift package for iOS.  It  generates a compressed MP4 video with a modified width, height, and bitrate (the number of bits per seconds that determines the video and audio files’ size and quality). It is based on [LightCompressor](https://github.com/AbedElazizShe/LightCompressor) for Android.

The general idea of how the library works is that, extreme high bitrate is reduced while maintaining a good video quality resulting in a smaller size.

I would like to mention that the set attributes for size and quality worked just great in my projects and met the expectations. It may or may not meet yours. I’d appreciate your feedback so I can enhance the compression process.

## How it works
When the video file is called to be compressed, the library checks if the user wants to set a min bitrate to avoid compressing low resolution videos. This becomes handy if you don’t want the video to be compressed every time it is to be processed to avoid having very bad quality after multiple rounds of compression. The minimum bitrate set is 2mbps.

You can pass one of  5 video qualities; `.very_high`, `.high`, `.medium`, `.low` or `.very_low` and the package will handle generating the right bitrate and size values for the output video.


Usage
--------
To import this swift package to your XCode project follow the following;
- Go to File -> Swift Packages then choose to **Add package dependency**.
- Add  `https://github.com/AbedElazizShe/LightCompressor_iOS.git`, to the text field shown on the popup window and click next.
- Specifiy the minimum release version and confirm. The project will be imported and you can start using it.
- In case on a new release update, you can choose File -> Swift packages and then click on `Update to latest package version`.

In order to use the compressor, just call [compressVideo()] and pass the following:

- A list of videos to be compressed where each video contains:
    - source: which is the source path of the input video. **required**
    - destination: which is the path where the output video should be saved. **required**
    - configuration: a set of configurations to control video compression - see configuration below. **optional**
    
- Callbacks: the method has a callback for 5 functions;
1) onStart - called when compression started.
2) onSuccess - called when compression completed with no errors/exceptions.
3) onFailure - called when an exception occurred or video bitrate and size are below the minimum required for compression.
4) onProgress - called with progress new value.
5) onCancelled - called when the job is cancelled.

### Configuration

- VideoQuality: VERY_HIGH (original-bitrate * 0.6) , HIGH (original-bitrate * 0.4), MEDIUM (original-bitrate * 0.3), LOW (original-bitrate * 0.2), OR VERY_LOW (original-bitrate * 0.1) - .medium by default.

- isMinBitrateCheckEnabled: this means, don't compress if bitrate is less than 2mbps - true by default.

- videoBitrateInMbps: any custom bitrate value in Mbps - nil by default.

- disableAudio: true/false to generate a video without audio - false by default.

- keepOriginalResolution: true/false to tell the library not to change the resolution - false by default.

- videoSize: it contains; videoWidth: custom video width, and videoHeight: custom video height - nil by default


#### Example

```swift
import LightCompressor
...

let videoCompressor = LightCompressor()
 
compression = videoCompressor.compressVideo(videos: [
    .init(
        source: videoToCompress, 
        destination: destinationPath, 
        configuration: .init(
            quality: VideoQuality.very_high, 
            videoBitrateInMbps: 5, 
            disableAudio: false, 
            keepOriginalResolution: 
            false, videoSize: 
            CGSize(width: 360, height: 480) 
            )
        )
    ],
    progressQueue: .main,
    progressHandler: { progress in
                    DispatchQueue.main.async { [unowned self] in
                       // Handle progress- "\(String(format: "%.0f", progress.fractionCompleted * 100))%"                            
                    }},
                                                   
    completion: {[weak self] result in
                    guard let `self` = self else { return }
                                                    
                    switch result {
                                                        
                    case .onSuccess(let index, let path):
                        // Handle onSuccess
                                                        
                    case .onStart:
                        // Handle onStart                              
                                                        
                    case .onFailure(let index, let error):
                        // Handle onFailure                
                                                        
                    case .onCancelled:
                        // Handle onCancelled                          
                    }
})

// to cancel call
compression.cancel = true

```

## Compatibility
The minimum iOS version supported is 14.

## Getting help
For questions, suggestions, or anything else, email elaziz.shehadeh(at)gmail.com.

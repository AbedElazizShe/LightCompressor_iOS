# LightCompressor

A powerful and easy-to-use video compression swift package for iOS.  It  generates a compressed MP4 video with a modified width, height, and bitrate (the number of bits per seconds that determines the video and audio files’ size and quality). It is based on [LightCompressor](https://github.com/AbedElazizShe/LightCompressor) for Android.

The general idea of how the library works is that, extreme high bitrate is reduced while maintaining a good video quality resulting in a smaller size.

I would like to mention that the set attributes for size and quality worked just great in my projects and met the expectations. It may or may not meet yours. I’d appreciate your feedback so I can enhance the compression process.

## How it works
When the video file is called to be compressed, the library checks if the user wants to set a min bitrate to avoid compressing low resolution videos. This becomes handy if you don’t want the video to be compressed every time it is to be processed to avoid having very bad quality after multiple rounds of compression. The minimum bitrate set is 2mbps.

You can pass one of  3 video qualities; `.high`, `.medium`, or `.low` and the package will handle generating the right bitrate and size values for the output video.

For a sample app, you can have a look at [LightCompressor_iOS_Sample](https://github.com/AbedElazizShe/LightCompressor_iOS_Sample).

Usage
--------
To import this swift package to your XCode project follow the following;
- Go to File -> Swift Packages then choose to **Add package dependency**.
- Add  `https://github.com/AbedElazizShe/LightCompressor_iOS.git`, to the text field shown on the popup window and click next.
- Specifiy the minimum release version and confirm. The project will be imported and you can start using it.
- In case on a new release update, you can choose File -> Swift packages and then click on `Update to latest package version`.

In order to use the compressor, just call [compressVideo()] and pass both source and destination file paths. The method has a callback for 5 functions;
1) onStart - called when compression started.
2) onSuccess - called when compression completed with no errors/exceptions.
3) onFailure - called when an exception occurred or video bitrate and size are below the minimum required for compression.
4) onProgress - called with progress new value.
5) onCancelled - called when the job is cancelled.

In addition, you can pass the video quality (default is medium)  to enable checking for min bitrate (default is true), and if you wish to keep the
original video width and height from being changed during compression, you can pass true or false for keepOriginalResolution where default is false.

#### Example

```swift
import LightCompressor
...

let videoCompressor = LightCompressor()
 
let compression: Compression = videoCompressor.compressVideo(
                                source: videoToCompress,
                                destination: destinationPath as URL,
                                quality: .medium,
                                isMinBitRateEnabled: true,
                                keepOriginalResolution: false,
                                progressQueue: .main,
                                progressHandler: { progress in
                                    // progress
                                },                                            
                                completion: {[weak self] result in
                                    guard let `self` = self else { return }
                                             
                                    switch result {                                                 
                                    case .onSuccess(let path):
                                        // success 
                                                 
                                    case .onStart:
                                        // when compression starts
                                                 
                                    case .onFailure(let error):
                                        // failure error 
                                                 
                                    case .onCancelled:
                                        // if cancelled
                                    }
                                }
 )

// to cancel call
compression.cancel = true

```

## Compatibility
The minimum iOS version supported is 11.

## Getting help
For questions, suggestions, or anything else, email elaziz.shehadeh(at)gmail.com.

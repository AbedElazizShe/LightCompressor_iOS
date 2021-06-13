import AVFoundation
import UIKit

public enum VideoQuality {
    case very_high
    case high
    case medium
    case low
    case very_low
}

// Compression Result
public enum CompressionResult {
    case onStart
    case onSuccess(URL)
    case onFailure(CompressionError)
    case onCancelled
}

// Compression Interruption Wrapper
public class Compression {
    public init() {}

    public var cancel = false
}

// Compression Error Messages
public struct CompressionError: LocalizedError {
    public let title: String

    init(title: String = "Compression Error") {
        self.title = title
    }
}

@available(iOS 11.0, *)
public struct LightCompressor {

    public init() {}

    private let MIN_BITRATE = Float(2000000)
    private let MIN_HEIGHT = 640.0
    private let MIN_WIDTH = 360.0

    /**
     * This function compresses a given [source] video file and writes the compressed video file at
     * [destination]
     *
     * @param [source] the path of the provided video file to be compressed
     * @param [destination] the path where the output compressed video file should be saved
     * @param [quality] to allow choosing a video quality that can be [.very_low], [.low],
     * [.medium],  [.high], and [very_high]. This defaults to [.medium]
     * @param [isMinBitRateEnabled] to determine if the checking for a minimum bitrate threshold
     * before compression is enabled or not. This default to `true`
     * @param [keepOriginalResolution] to keep the original video height and width when compressing.
     * This defaults to `false`
     * @param [progressHandler] a compression progress  listener that listens to compression progress status
     * @param [completion] to return completion status that can be [onStart], [onSuccess], [onFailure],
     * and if the compression was [onCancelled]
     */

    public func compressVideo(source: URL,
                              destination: URL,
                              quality: VideoQuality,
                              isMinBitRateEnabled: Bool = true,
                              keepOriginalResolution: Bool = false,
                              progressQueue: DispatchQueue,
                              progressHandler: ((Progress) -> ())?,
                              completion: @escaping (CompressionResult) -> ()) -> Compression {

        var frameCount = 0
        let compressionOperation = Compression()

        // Compression started
        completion(.onStart)

        let videoAsset = AVURLAsset(url: source)
        guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else {
            let error = CompressionError(title: "Cannot find video track")
            completion(.onFailure(error))
            return Compression()
        }

        let bitrate = videoTrack.estimatedDataRate
        // Check for a min video bitrate before compression
        if isMinBitRateEnabled && bitrate <= MIN_BITRATE {
            let error = CompressionError(title: "The provided bitrate is smaller than what is needed for compression try to set isMinBitRateEnabled to false")
            completion(.onFailure(error))
            return Compression()
        }

        // Generate a bitrate based on desired quality
        let newBitrate = getBitrate(bitrate: bitrate, quality: quality)

        // Handle new width and height values
        let videoSize = videoTrack.naturalSize
        let size = generateWidthAndHeight(width: videoSize.width, height: videoSize.height, keepOriginalResolution: keepOriginalResolution)
        let newWidth = size.width
        let newHeight = size.height

        // Total Frames
        let durationInSeconds = videoAsset.duration.seconds
        let frameRate = videoTrack.nominalFrameRate
        let totalFrames = ceil(durationInSeconds * Double(frameRate))

        // Progress
        let totalUnits = Int64(totalFrames)
        let progress = Progress(totalUnitCount: totalUnits)

        // Setup video writer input
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: getVideoWriterSettings(bitrate: newBitrate, width: newWidth, height: newHeight))
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.transform = videoTrack.preferredTransform

        let videoWriter = try! AVAssetWriter(outputURL: destination, fileType: AVFileType.mov)
        videoWriter.add(videoWriterInput)

        // Setup video reader output
        let videoReaderSettings:[String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) as AnyObject
        ]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)

        var videoReader: AVAssetReader!
        do{
            videoReader = try AVAssetReader(asset: videoAsset)
        }
        catch {
            let compressionError = CompressionError(title: error.localizedDescription)
            completion(.onFailure(compressionError))
        }

        videoReader.add(videoReaderOutput)
        //setup audio writer
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
        audioWriterInput.expectsMediaDataInRealTime = false
        videoWriter.add(audioWriterInput)
        //setup audio reader
        let audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
        var audioReader: AVAssetReader?
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if(audioTrack != nil) {
            audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil)
            audioReader = try! AVAssetReader(asset: videoAsset)
            audioReader?.add(audioReaderOutput!)
        }
        videoWriter.startWriting()

        //start writing from video reader
        videoReader.startReading()
        videoWriter.startSession(atSourceTime: CMTime.zero)
        let processingQueue = DispatchQueue(label: "processingQueue1")

        var isFirstBuffer = true
        videoWriterInput.requestMediaDataWhenReady(on: processingQueue, using: {() -> Void in
            while videoWriterInput.isReadyForMoreMediaData {

                // Observe any cancellation
                if compressionOperation.cancel {
                    videoReader.cancelReading()
                    videoWriter.cancelWriting()
                    completion(.onCancelled)
                    return
                }

                // Update progress based on number of processed frames
                frameCount += 1
                if let handler = progressHandler {
                    progress.completedUnitCount = Int64(frameCount)
                    progressQueue.async { handler(progress) }
                }

                let sampleBuffer: CMSampleBuffer? = videoReaderOutput.copyNextSampleBuffer()

                if videoReader.status == .reading && sampleBuffer != nil {
                    videoWriterInput.append(sampleBuffer!)
                } else {
                    videoWriterInput.markAsFinished()
                    if videoReader.status == .completed {
                        if(audioReader != nil){
                            if(!(audioReader!.status == .reading) || !(audioReader!.status == .completed)){
                                //start writing from audio reader
                                audioReader?.startReading()
                                videoWriter.startSession(atSourceTime: CMTime.zero)
                                let processingQueue = DispatchQueue(label: "processingQueue2")

                                audioWriterInput.requestMediaDataWhenReady(on: processingQueue, using: {() -> Void in
                                    while audioWriterInput.isReadyForMoreMediaData {
                                        let sampleBuffer: CMSampleBuffer? = audioReaderOutput?.copyNextSampleBuffer()
                                        if audioReader?.status == .reading && sampleBuffer != nil {
                                            if isFirstBuffer {
                                                let dict = CMTimeCopyAsDictionary(CMTimeMake(value: 1024, timescale: 44100), allocator: kCFAllocatorDefault);
                                                CMSetAttachment(sampleBuffer as CMAttachmentBearer, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart, value: dict, attachmentMode: kCMAttachmentMode_ShouldNotPropagate);
                                                isFirstBuffer = false
                                            }
                                            audioWriterInput.append(sampleBuffer!)
                                        } else {
                                            audioWriterInput.markAsFinished()

                                            videoWriter.finishWriting(completionHandler: {() -> Void in
                                                completion(.onSuccess(destination))
                                            })

                                        }
                                    }
                                })
                            }
                        } else {
                            videoWriter.finishWriting(completionHandler: {() -> Void in
                                completion(.onSuccess(destination))
                            })
                        }
                    }
                }
            }
        })
        
        return compressionOperation
    }
    
    private func getBitrate(bitrate: Float, quality: VideoQuality) -> Int {
        
        if quality == .very_low {
            return Int(bitrate * 0.08)
        } else if quality == .low {
            return Int(bitrate * 0.1)
        } else if quality == .medium {
            return Int(bitrate * 0.2)
        } else if quality == .high {
            return Int(bitrate * 0.3)
        } else if quality == .very_high {
            return Int(bitrate * 0.5)
        } else {
            return Int(bitrate * 0.2)
        }
    }
    
    private func generateWidthAndHeight(
        width: CGFloat,
        height: CGFloat,
        keepOriginalResolution: Bool
    ) -> (width: Int, height: Int) {
        
        if (keepOriginalResolution) {
            return (Int(width), Int(height))
        }
        
        var newWidth: Int
        var newHeight: Int
        
        if width >= 1920 || height >= 1920 {
            
            newWidth = Int(width * 0.5 / 16) * 16
            newHeight = Int(height * 0.5 / 16 ) * 16
            
        } else if width >= 1280 || height >= 1280 {
            newWidth = Int(width * 0.75 / 16) * 16
            newHeight = Int(height * 0.75 / 16) * 16
        } else if width >= 960 || height >= 960 {
            if(width > height){
                newWidth = Int(MIN_HEIGHT * 0.95 / 16) * 16
                newHeight = Int(MIN_WIDTH * 0.95 / 16) * 16
            } else {
                newWidth = Int(MIN_WIDTH * 0.95 / 16) * 16
                newHeight = Int(MIN_HEIGHT * 0.95 / 16) * 16
            }
        } else {
            newWidth = Int(width * 0.9 / 16) * 16
            newHeight = Int(height * 0.9 / 16) * 16
        }
        
        return (newWidth, newHeight)
    }
    
    private func getVideoWriterSettings(bitrate: Int, width: Int, height: Int) -> [String : AnyObject] {
        
        let videoWriterCompressionSettings = [
            AVVideoAverageBitRateKey : bitrate
        ]
        
        let videoWriterSettings: [String : AnyObject] = [
            AVVideoCodecKey : AVVideoCodecType.h264 as AnyObject,
            AVVideoCompressionPropertiesKey : videoWriterCompressionSettings as AnyObject,
            AVVideoWidthKey : width as AnyObject,
            AVVideoHeightKey : height as AnyObject
        ]
        
        return videoWriterSettings
    }
    
}

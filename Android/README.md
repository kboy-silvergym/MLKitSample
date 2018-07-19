# MLKitSample-Android


## Show camera using camera2 api

Wrote flow for [here](https://qiita.com/k-boy/items/3b64c4e9921e29cc4471). (Written in Japanese)

## Get camera frame every render, and pass the bitmap to Firebase MLKit 

### set the ImageAvailableListener to imageReader

```kotlin
    private val surfaceTextureListener = object : TextureView.SurfaceTextureListener {

        override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
            imageReader = ImageReader.newInstance(width, height, ImageFormat.JPEG, /*maxImages*/ 2);
            imageReader?.setOnImageAvailableListener(mOnImageAvailableListener, backgroundHandler)
            openCamera()
        }
    }
```

### Then called every time frame rendered, so pass the bitmap to Firebase MLKit

```kotlin
    private val mOnImageAvailableListener = ImageReader.OnImageAvailableListener {
        val bitmap = textureView.bitmap
        val visionImage = FirebaseVisionImage.fromBitmap(bitmap)
        val options = FirebaseVisionFaceDetectorOptions.Builder()
                .setModeType(FirebaseVisionFaceDetectorOptions.FAST_MODE)
                .setLandmarkType(FirebaseVisionFaceDetectorOptions.ALL_LANDMARKS)
                .setClassificationType(FirebaseVisionFaceDetectorOptions.ALL_CLASSIFICATIONS)
                .setMinFaceSize(0.15f)
                .setTrackingEnabled(true)
                .build()
        val detector = FirebaseVision.getInstance().getVisionFaceDetector(options)
        detector.detectInImage(visionImage)
                .addOnSuccessListener {
                    print("good job")
                }
                .addOnFailureListener {
                    it.printStackTrace()
                }
    }
```

Actually, my codes have something wrong, so this listener never called...😇
